package op_e2e

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	eth2 "github.com/ethereum-optimism/optimism/op-node/eth"
	"github.com/ethereum-optimism/optimism/op-node/sources"
	"github.com/ethereum-optimism/optimism/op-service/clock"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/eth"
	"github.com/ethereum/go-ethereum/eth/catalyst"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"
)

// fakePoS is a testing-only utility to attach to Geth,
// to build a fake proof-of-stake L1 chain with fixed block time and basic lagging safe/finalized blocks.
type fakePoS struct {
	clock     clock.Clock
	eth       *eth.Ethereum
	log       log.Logger
	blockTime uint64

	finalizedDistance uint64
	safeDistance      uint64

	engineAPI *catalyst.ConsensusAPI
	sub       ethereum.Subscription

	// directory to store blob contents in after the blobs are persisted in a block
	blobsDir  string
	blobsLock sync.Mutex

	beaconSrv         *http.Server
	beaconAPIListener net.Listener
}

func (f *fakePoS) Start() error {
	mux := new(http.ServeMux)
	mux.HandleFunc("/eth/v1/beacon/genesis", func(w http.ResponseWriter, r *http.Request) {
		err := json.NewEncoder(w).Encode(&sources.APIGenesisResponse{Data: sources.ReducedGenesisData{GenesisTime: eth2.Uint64String(f.eth.BlockChain().Genesis().Time())}})
		if err != nil {
			f.log.Error("genesis handler err", "err", err)
		}
	})
	mux.HandleFunc("/eth/v1/config/spec", func(w http.ResponseWriter, r *http.Request) {
		err := json.NewEncoder(w).Encode(&sources.APIConfigResponse{Data: sources.ReducedConfigData{SecondsPerSlot: eth2.Uint64String(f.blockTime)}})
		if err != nil {
			f.log.Error("config handler err", "err", err)
		}
	})
	mux.HandleFunc("/eth/v1/beacon/blobs_sidecars/", func(w http.ResponseWriter, r *http.Request) {
		blockID := strings.TrimPrefix(r.URL.Path, "/eth/v1/beacon/blobs_sidecars/")
		slot, err := strconv.ParseUint(blockID, 10, 64)
		if err != nil {
			f.log.Error("bad request", "url", r.URL.Path)
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		bundle, err := f.LoadBlobsBundle(slot)
		if err != nil {
			f.log.Error("failed to load blobs bundle", "slot", slot)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		var mockBeaconBlockRoot [32]byte
		mockBeaconBlockRoot[0] = 42
		binary.LittleEndian.PutUint64(mockBeaconBlockRoot[32-8:], slot)
		sidecar := sources.BlobsSidecarData{
			BeaconBlockRoot: mockBeaconBlockRoot,
			BeaconBlockSlot: eth2.Uint64String(slot),
			Blobs:           make([]eth2.Blob, len(bundle.Blobs)),
			// TODO: we can include the proof/commitment data in the response, but we don't consume that on client-side
		}
		for i, bl := range bundle.Blobs {
			copy(sidecar.Blobs[i][:], bl)
		}
		if err := json.NewEncoder(w).Encode(&sources.APIBlobsSidecarResponse{Data: sidecar}); err != nil {
			f.log.Error("blobs handler err", "err", err)
		}
	})
	f.beaconSrv = &http.Server{
		Handler:           mux,
		ReadTimeout:       time.Second * 20,
		ReadHeaderTimeout: time.Second * 20,
		WriteTimeout:      time.Second * 20,
		IdleTimeout:       time.Second * 20,
	}
	go func() {
		if err := f.beaconSrv.Serve(f.beaconAPIListener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			f.log.Error("failed to start fake-pos beacon server for blobs testing", "err", err)
		}
	}()

	if advancing, ok := f.clock.(*clock.AdvancingClock); ok {
		advancing.Start()
	}
	f.sub = event.NewSubscription(func(quit <-chan struct{}) error {
		// poll every half a second: enough to catch up with any block time when ticks are missed
		t := f.clock.NewTicker(time.Second / 2)
		for {
			select {
			case now := <-t.Ch():
				chain := f.eth.BlockChain()
				head := chain.CurrentBlock()
				finalized := chain.CurrentFinalBlock()
				if finalized == nil { // fallback to genesis if nothing is finalized
					finalized = chain.Genesis().Header()
				}
				safe := chain.CurrentSafeBlock()
				if safe == nil { // fallback to finalized if nothing is safe
					safe = finalized
				}
				if head.Number.Uint64() > f.finalizedDistance { // progress finalized block, if we can
					finalized = f.eth.BlockChain().GetHeaderByNumber(head.Number.Uint64() - f.finalizedDistance)
				}
				if head.Number.Uint64() > f.safeDistance { // progress safe block, if we can
					safe = f.eth.BlockChain().GetHeaderByNumber(head.Number.Uint64() - f.safeDistance)
				}
				// start building the block as soon as we are past the current head time
				if head.Time >= uint64(now.Unix()) {
					continue
				}
				newBlockTime := head.Time + f.blockTime
				if time.Unix(int64(newBlockTime), 0).Add(5 * time.Minute).Before(f.clock.Now()) {
					// We're a long way behind, let's skip some blocks...
					newBlockTime = uint64(f.clock.Now().Unix())
				}
				res, err := f.engineAPI.ForkchoiceUpdatedV2(engine.ForkchoiceStateV1{
					HeadBlockHash:      head.Hash(),
					SafeBlockHash:      safe.Hash(),
					FinalizedBlockHash: finalized.Hash(),
				}, &engine.PayloadAttributes{
					Timestamp:             newBlockTime,
					Random:                common.Hash{},
					SuggestedFeeRecipient: head.Coinbase,
					Withdrawals:           make([]*types.Withdrawal, 0),
				})
				if err != nil {
					f.log.Error("failed to start building L1 block", "err", err)
					continue
				}
				if res.PayloadID == nil {
					f.log.Error("failed to start block building", "res", res)
					continue
				}
				// wait with sealing, if we are not behind already
				delay := time.Unix(int64(newBlockTime), 0).Sub(f.clock.Now())
				tim := f.clock.NewTimer(delay)
				select {
				case <-tim.Ch():
					// no-op
				case <-quit:
					tim.Stop()
					return nil
				}
				envelope, err := f.engineAPI.GetPayloadV2(*res.PayloadID)
				if err != nil {
					f.log.Error("failed to finish building L1 block", "err", err)
					continue
				}

				var blobHashes []common.Hash
				for _, commitment := range envelope.BlobsBundle.Commitments {
					if len(commitment) != 48 {
						f.log.Error("got malformed kzg commitment from engine", "commitment", commitment)
						break
					}
					blobHashes = append(blobHashes, eth2.KzgToVersionedHash(*(*[48]byte)(commitment)))
				}
				if len(blobHashes) != len(envelope.BlobsBundle.Commitments) {
					f.log.Error("invalid or incomplete blob data", "collected", len(blobHashes), "engine", len(envelope.BlobsBundle.Commitments))
					continue
				}
				if f.eth.BlockChain().Config().IsCancun(new(big.Int).SetUint64(envelope.ExecutionPayload.Number), envelope.ExecutionPayload.Timestamp) {
					if _, err := f.engineAPI.NewPayloadV3(*envelope.ExecutionPayload, &blobHashes); err != nil {
						f.log.Error("failed to insert built L1 block", "err", err)
						continue
					}
				} else {
					if _, err := f.engineAPI.NewPayloadV2(*envelope.ExecutionPayload); err != nil {
						f.log.Error("failed to insert built L1 block", "err", err)
						continue
					}
				}
				if envelope.BlobsBundle != nil {
					slot := (envelope.ExecutionPayload.Timestamp - f.eth.BlockChain().Genesis().Time()) / f.blockTime
					if err := f.StoreBlobsBundle(slot, envelope.BlobsBundle); err != nil {
						f.log.Error("failed to persist blobs-bundle of block, not making block canonical now", "err", err)
						continue
					}
				}
				if _, err := f.engineAPI.ForkchoiceUpdatedV2(engine.ForkchoiceStateV1{
					HeadBlockHash:      envelope.ExecutionPayload.BlockHash,
					SafeBlockHash:      safe.Hash(),
					FinalizedBlockHash: finalized.Hash(),
				}, nil); err != nil {
					f.log.Error("failed to make built L1 block canonical", "err", err)
					continue
				}
			case <-quit:
				return nil
			}
		}
	})
	return nil
}

func (f *fakePoS) StoreBlobsBundle(slot uint64, bundle *engine.BlobsBundleV1) error {
	data, err := json.Marshal(bundle)
	if err != nil {
		return fmt.Errorf("failed to encode blobs bundle of slot %d: %w", slot, err)
	}

	f.blobsLock.Lock()
	defer f.blobsLock.Unlock()
	bundlePath := fmt.Sprintf("blobs_bundle_%d.json", slot)
	if err := os.MkdirAll(f.blobsDir, 0755); err != nil {
		return fmt.Errorf("failed to create dir for blob storage: %w", err)
	}
	err = os.WriteFile(filepath.Join(f.blobsDir, bundlePath), data, 0755)
	if err != nil {
		return fmt.Errorf("failed to write blobs bundle of slot %d: %w", slot, err)
	}
	return nil
}

func (f *fakePoS) LoadBlobsBundle(slot uint64) (*engine.BlobsBundleV1, error) {
	f.blobsLock.Lock()
	defer f.blobsLock.Unlock()
	bundlePath := fmt.Sprintf("blobs_bundle_%d.json", slot)
	data, err := os.ReadFile(filepath.Join(f.blobsDir, bundlePath))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("no blobs bundle found for slot %d (%q): %w", slot, bundlePath, ethereum.NotFound)
		} else {
			return nil, fmt.Errorf("failed to read blobs bundle of slot %d (%q): %w", slot, bundlePath, err)
		}
	}
	var out engine.BlobsBundleV1
	if err := json.Unmarshal(data, &out); err != nil {
		return nil, fmt.Errorf("failed to decode blobs bundle of slot %d (%q): %w", slot, bundlePath, err)
	}
	return &out, nil
}

func (f *fakePoS) Stop() error {
	f.sub.Unsubscribe()
	if advancing, ok := f.clock.(*clock.AdvancingClock); ok {
		advancing.Stop()
	}
	if f.beaconSrv != nil {
		_ = f.beaconSrv.Close()
	}
	if f.beaconAPIListener != nil {
		_ = f.beaconAPIListener.Close()
	}
	return nil
}

func (f *fakePoS) BeaconAPIAddr() string {
	if f.beaconAPIListener == nil {
		return ""
	}
	return f.beaconAPIListener.Addr().String()
}
