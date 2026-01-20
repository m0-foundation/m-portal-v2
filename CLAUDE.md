# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Portal V2 is M0 Foundation's cross-chain messaging system for bridging $M tokens and propagating protocol state (earning index, registrar values) across EVM chains. It uses a hub-and-spoke architecture with pluggable bridge adapters.

## Build & Test Commands

All EVM commands run from the `evm/` directory:

```bash
# Build contracts
forge build

# Run all tests
forge test

# Run a single test file
forge test --match-path test/unit/HubPortal/sendToken.t.sol

# Run a single test function
forge test --match-test test_sendToken_success

# Format code
forge fmt

# Check code coverage
forge coverage
```

Using Makefile targets (from `evm/lib/common/`):
```bash
make build      # Production build
make tests      # Run tests with default profile
make gas        # Run tests with gas reporting
make sizes      # Show contract sizes
make coverage   # Generate coverage report
```

## Architecture

### Core Contracts

- **Portal** (`src/Portal.sol`) - Base contract with shared functionality for cross-chain messaging, token transfers, and bridge adapter management
- **HubPortal** (`src/HubPortal.sol`) - Deployed on Ethereum. Uses lock-and-release for tokens. Propagates $M index and registrar state to spokes
- **SpokePortal** (`src/SpokePortal.sol`) - Deployed on L2s. Uses mint-and-burn for tokens. Receives state updates from hub

### Bridge Adapters

Bridge adapters abstract the underlying cross-chain messaging protocol:

- **BridgeAdapter** (`src/bridgeAdapters/BridgeAdapter.sol`) - Abstract base with chain ID mapping and peer management
- **HyperlaneBridgeAdapter** - Hyperlane integration
- **WormholeBridgeAdapter** - Wormhole integration
- **LayerZeroBridgeAdapter** - LayerZero V2 integration

Adapters are UUPS upgradeable proxies with role-based access control (admin + operator roles).

### Message Types (PayloadEncoder)

Cross-chain payloads have a common header (type, destination chain, peer, message ID, index) followed by type-specific data:

- `TokenTransfer` - Token bridging with amount, sender, recipient
- `Index` - $M token index propagation
- `RegistrarKey` - Key-value pair updates
- `RegistrarList` - List membership updates (earners, etc.)
- `FillReport` / `CancelReport` - OrderBook integration
- `EarnerMerkleRoot` - SVM earner list propagation

### Key Patterns

- **Cross-Spoke Transfers**: Spokes can be "isolated" (only hub<->spoke) or "connected" (spoke<->spoke). Controlled via `crossSpokeTokenTransferEnabled`
- **Index Propagation**: Hub reads $M index from MToken contract and broadcasts to spokes for yield synchronization
- **Registrar Sync**: Hub propagates registrar key-values and list memberships to spokes
- **Token Wrapping**: Supports $M Extensions (wrapped $M). If wrap fails on destination, recipient gets unwrapped $M

## Project Structure

```
evm/
├── src/
│   ├── Portal.sol, HubPortal.sol, SpokePortal.sol
│   ├── bridgeAdapters/
│   │   ├── BridgeAdapter.sol
│   │   ├── hyperlane/
│   │   ├── layerzero/
│   │   └── wormhole/
│   ├── interfaces/
│   └── libraries/
│       ├── PayloadEncoder.sol  # Message encoding/decoding
│       ├── BytesParser.sol     # Low-level bytes parsing
│       └── TypeConverter.sol   # Type conversions for cross-chain
├── test/
│   ├── unit/          # Unit tests per contract
│   ├── fork/          # Fork tests against live networks
│   └── mocks/         # Mock contracts for testing
└── lib/common/        # Shared dependencies (OZ, forge-std)

sdk-evm/               # TypeScript SDK (WIP)
```

## Code Conventions

- Solidity 0.8.30 with optimizer (10,000 runs)
- ERC-7201 namespaced storage for upgradeable contracts
- NatSpec documentation on all public interfaces
- Use `bytes32` for addresses in payloads (cross-VM compatibility)
- Formatting: 140 char line length, 4-space tabs, bracket spacing enabled
