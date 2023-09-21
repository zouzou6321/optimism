package types

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

var (
	ErrGameDepthReached = errors.New("game depth reached")
)

// PreimageOracleData encapsulates the preimage oracle data
// to load into the onchain oracle.
type PreimageOracleData struct {
	IsLocal      bool
	OracleKey    []byte
	OracleData   []byte
	OracleOffset uint32
}

// GetType returns the type for the preimage oracle data.
func (p *PreimageOracleData) GetType() *big.Int {
	return big.NewInt(int64(p.OracleKey[0]))
}

// GetIdent returns the ident for the preimage oracle data.
func (p *PreimageOracleData) GetIdent() *big.Int {
	return big.NewInt(0).SetBytes(p.OracleKey[1:])
}

// GetPreimageWithoutSize returns the preimage for the preimage oracle data.
func (p *PreimageOracleData) GetPreimageWithoutSize() []byte {
	return p.OracleData[8:]
}

// NewPreimageOracleData creates a new [PreimageOracleData] instance.
func NewPreimageOracleData(key []byte, data []byte, offset uint32) *PreimageOracleData {
	return &PreimageOracleData{
		IsLocal:      len(key) > 0 && key[0] == byte(1),
		OracleKey:    key,
		OracleData:   data,
		OracleOffset: offset,
	}
}

// StepCallData encapsulates the data needed to perform a step.
type StepCallData struct {
	ClaimIndex uint64
	IsAttack   bool
	StateData  []byte
	Proof      []byte
}

// OracleUpdater is a generic interface for updating oracles.
type OracleUpdater interface {
	// UpdateOracle updates the oracle with the given data.
	UpdateOracle(ctx context.Context, data *PreimageOracleData) error
}

// TraceProvider is a generic way to get a claim value at a specific step in the trace.
type TraceProvider interface {
	// Get returns the claim value at the requested index.
	// Get(i) = Keccak256(GetPreimage(i))
	Get(ctx context.Context, i uint64) (common.Hash, error)

	// GetStepData returns the data required to execute the step at the specified trace index.
	// This includes the pre-state of the step (not hashed), the proof data required during step execution
	// and any pre-image data that needs to be loaded into the oracle prior to execution (may be nil)
	// The prestate returned from GetStepData for trace 10 should be the pre-image of the claim from trace 9
	GetStepData(ctx context.Context, i uint64) (prestate []byte, proofData []byte, preimageData *PreimageOracleData, err error)

	// AbsolutePreState is the pre-image value of the trace that transitions to the trace value at index 0
	AbsolutePreState(ctx context.Context) (preimage []byte, err error)

	// AbsolutePreStateCommitment is the commitment of the pre-image value of the trace that transitions to the trace value at index 0
	AbsolutePreStateCommitment(ctx context.Context) (hash common.Hash, err error)
}

// ClaimData is the core of a claim. It must be unique inside a specific game.
type ClaimData struct {
	Value common.Hash
	Position
}

func (c *ClaimData) ValueBytes() [32]byte {
	responseBytes := c.Value.Bytes()
	var responseArr [32]byte
	copy(responseArr[:], responseBytes[:32])
	return responseArr
}

// Claim extends ClaimData with information about the relationship between two claims.
// It uses ClaimData to break cyclicity without using pointers.
// If the position of the game is Depth 0, IndexAtDepth 0 it is the root claim
// and the Parent field is empty & meaningless.
type Claim struct {
	ClaimData
	// WARN: Countered is a mutable field in the FaultDisputeGame contract
	//       and rely on it for determining whether to step on leaf claims.
	//       When caching is implemented for the Challenger, this will need
	//       to be changed/removed to avoid invalid/stale contract state.
	Countered bool
	Clock     uint64
	Parent    ClaimData
	// Location of the claim & it's parent inside the contract. Does not exist
	// for claims that have not made it to the contract.
	ContractIndex       int
	ParentContractIndex int
}

// IsRoot returns true if this claim is the root claim.
func (c *Claim) IsRoot() bool {
	return c.Position.IsRootPosition()
}

// DefendsParent returns true if the the claim is a defense (i.e. goes right) of the
// parent. It returns false if the claim is an attack (i.e. goes left) of the parent.
func (c *Claim) DefendsParent() bool {
	return c.Position.DefendsParent(c.Parent.IndexAtDepth())
}
