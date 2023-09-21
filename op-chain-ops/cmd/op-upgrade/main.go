package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/ethereum/go-ethereum/log"
	"github.com/mattn/go-isatty"

	"github.com/ethereum-optimism/optimism/op-chain-ops/clients"
	"github.com/ethereum-optimism/optimism/op-chain-ops/genesis"
	"github.com/ethereum-optimism/optimism/op-chain-ops/safe"
	"github.com/ethereum-optimism/optimism/op-chain-ops/upgrades"

	"github.com/ethereum-optimism/superchain-registry/superchain"

	"github.com/urfave/cli/v2"
)

func main() {
	log.Root().SetHandler(log.StreamHandler(os.Stderr, log.TerminalFormat(isatty.IsTerminal(os.Stderr.Fd()))))

	app := &cli.App{
		Name:  "op-upgrade",
		Usage: "Build transactions useful for upgrading the Superchain",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "l1-rpc-url",
				Value:   "http://127.0.0.1:8545",
				Usage:   "L1 RPC URL",
				EnvVars: []string{"L1_RPC_URL"},
			},
			&cli.StringFlag{
				Name:    "l2-rpc-url",
				Value:   "http://127.0.0.1:9545",
				Usage:   "L2 RPC URL",
				EnvVars: []string{"L2_RPC_URL"},
			},
			&cli.Uint64SliceFlag{
				Name:  "chain-ids",
				Usage: "Chain IDs corresponding to chains to upgrade. Corresponds to all chains if empty",
			},
			&cli.PathFlag{
				Name:     "deploy-config",
				Usage:    "The path to the deploy config file",
				Required: true,
				EnvVars:  []string{"DEPLOY_CONFIG"},
			},
			&cli.PathFlag{
				Name:    "outfile",
				Usage:   "The file to write the output to. If not specified, output is written to stdout",
				EnvVars: []string{"OUTFILE"},
			},
		},
		Action: entrypoint,
	}

	if err := app.Run(os.Args); err != nil {
		log.Crit("error op-upgrade", "err", err)
	}
}

func containsUint64(slice []uint64, val uint64) bool {
	for _, v := range slice {
		if v == val {
			return true
		}
	}
	return false
}

func entrypoint(ctx *cli.Context) error {
	//chainIDs := ctx.Uint64Slice("chain-ids")

	config, err := genesis.NewDeployConfig(ctx.Path("deploy-config"))
	if err != nil {
		return err
	}

	clients, err := clients.NewClients(ctx)
	if err != nil {
		return err
	}

	l1ChainID, err := clients.L1Client.ChainID(ctx.Context)
	if err != nil {
		return err
	}
	l2ChainID, err := clients.L2Client.ChainID(ctx.Context)
	if err != nil {
		return err
	}
	log.Info("Chain IDs", "l1", l1ChainID, "l2", l2ChainID)

	chainConfig, ok := superchain.OPChains[l2ChainID.Uint64()]
	if !ok {
		return fmt.Errorf("no chain config for chain ID %d", l2ChainID.Uint64())
	}

	log.Info("Detecting on chain contracts")
	// Tracking the individual addresses can be deprecated once the system is upgraded
	// to the new contracts where the system config has a reference to each address.
	addresses, ok := superchain.Addresses[l2ChainID.Uint64()]
	if !ok {
		return fmt.Errorf("no addresses for chain ID %d", l2ChainID.Uint64())
	}
	versions, err := upgrades.GetContractVersions(ctx.Context, addresses, chainConfig, clients.L1Client)
	if err != nil {
		return fmt.Errorf("error getting contract versions: %w", err)
	}

	log.Info("L1CrossDomainMessenger", "version", versions.L1CrossDomainMessenger, "address", addresses.L1CrossDomainMessengerProxy)
	log.Info("L1ERC721Bridge", "version", versions.L1ERC721Bridge, "address", addresses.L1ERC721BridgeProxy)
	log.Info("L1StandardBridge", "version", versions.L1StandardBridge, "address", addresses.L1StandardBridgeProxy)
	log.Info("L2OutputOracle", "version", versions.L2OutputOracle, "address", addresses.L2OutputOracleProxy)
	log.Info("OptimismMintableERC20Factory", "version", versions.OptimismMintableERC20Factory, "address", addresses.OptimismMintableERC20FactoryProxy)
	log.Info("OptimismPortal", "version", versions.OptimismPortal, "address", addresses.OptimismPortalProxy)
	log.Info("SystemConfig", "version", versions.SystemConfig, "address", chainConfig.SystemConfigAddr)

	implementations, ok := superchain.Implementations[l1ChainID.Uint64()]
	if !ok {
		return fmt.Errorf("no implementations for chain ID %d", l1ChainID.Uint64())
	}

	list, err := implementations.Resolve(superchain.SuperchainSemver)
	if err != nil {
		return err
	}

	log.Info("Upgrading to the following versions")
	log.Info("L1CrossDomainMessenger", "version", list.L1CrossDomainMessenger.Version, "address", list.L1CrossDomainMessenger.Address)
	log.Info("L1ERC721Bridge", "version", list.L1ERC721Bridge.Version, "address", list.L1ERC721Bridge.Address)
	log.Info("L1StandardBridge", "version", list.L1StandardBridge.Version, "address", list.L1StandardBridge.Address)
	log.Info("L2OutputOracle", "version", list.L2OutputOracle.Version, "address", list.L2OutputOracle.Address)
	log.Info("OptimismMintableERC20Factory", "version", list.OptimismMintableERC20Factory.Version, "address", list.OptimismMintableERC20Factory.Address)
	log.Info("OptimismPortal", "version", list.OptimismPortal.Version, "address", list.OptimismPortal.Address)
	log.Info("SystemConfig", "version", list.SystemConfig.Version, "address", list.SystemConfig.Address)

	if err := upgrades.CheckL1(ctx.Context, &list, clients.L1Client); err != nil {
		return fmt.Errorf("error checking L1: %w", err)
	}

	batch := safe.Batch{}
	if err := upgrades.L1(&batch, list, *addresses, config, chainConfig); err != nil {
		return err
	}

	if outfile := ctx.Path("outfile"); outfile != "" {
		if err := writeJSON(outfile, batch); err != nil {
			return err
		}
	} else {
		data, err := json.MarshalIndent(batch, "", "  ")
		if err != nil {
			return err
		}
		fmt.Println(string(data))
	}

	return nil
}

func writeJSON(outfile string, input interface{}) error {
	f, err := os.OpenFile(outfile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	defer f.Close()

	enc := json.NewEncoder(f)
	enc.SetIndent("", "  ")
	return enc.Encode(input)
}
