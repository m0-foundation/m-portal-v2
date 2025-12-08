# Portal v2 Implementation for EVM

Portal v2 is a cross-chain messaging and asset transfer protocol built on the Hub-and-Spoke architecture. This repository contains the EVM implementation with support for multiple bridge adapters (Hyperlane and Wormhole).

## Core Components

### Portal Contracts

#### [HubPortal.sol](src/HubPortal.sol)
The central contract on the Hub chain that:
- Receives messages from Spoke chains via bridge adapters
- Routes messages to destination Spoke chains
- Manages cross-chain asset transfers and state
- Integrates with M^0 protocol components (OrderBook, SwapFacility, Registrar)

Key functions:
- `receiveMessage(uint32 srcChainId, bytes calldata message)` - Receives cross-chain messages
- `sendMessage(uint32 dstChainId, bytes calldata message)` - Sends messages to Spoke chains
- Message types: Token Transfer, Fill Report for OrderBook, $M Index Update, Registrar Key Update, Registrar List Update

#### [SpokePortal.sol](src/SpokePortal.sol)
The contract on each Spoke chain that:
- Sends messages to the Hub via bridge adapters
- Receives messages from the Hub
- Manages local mToken balances
- Handles deposits and withdrawals

Key functions:
- `receiveMessage(uint32 srcChainId, bytes calldata message)` - Process messages from Hub
- Message types:

### Bridge Adapters

Bridge adapters provide an abstraction layer for different cross-chain messaging protocols.

#### [BridgeAdapter.sol](src/bridgeAdapters/BridgeAdapter.sol)
Abstract base contract providing:
- Peer adapter management (mapping chain IDs to peer addresses)
- Bridge chain ID mapping (protocol-specific chain IDs)
- Access control (operator role)
- Common interface for Portal integration

Key features:
- `setPeer(uint32 chainId, bytes32 peerAddress)` - Configure peer adapters
- `setBridgeChainId(uint32 chainId, uint256 bridgeChainId)` - Map chain IDs to bridge-specific IDs
- `sendMessage()` - Abstract method for sending cross-chain messages
- `receiveMessage()` - Internal method to forward messages to Portal

#### [HyperlaneBridgeAdapter.sol](src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol)
Hyperlane protocol integration:
- Uses Hyperlane's Mailbox for message dispatch and delivery
- Implements `IMessageRecipient.handle()` for receiving messages
- Supports custom gas limits and refund addresses
- On-chain fee quoting via `Mailbox.quoteDispatch()`

#### [WormholeBridgeAdapter.sol](src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol)
Wormhole protocol integration:
- Uses Wormhole's CoreBridge for message publishing
- Integrates with Wormhole Executor for automatic relaying
- Implements `IVaaV1Receiver.executeVAAv1()` for VAA verification
- Supports consistency levels for guardian consensus

### Utilities

#### [TypeConverter.sol](src/libraries/TypeConverter.sol)
Provides type conversions for cross-chain compatibility:
- `address ↔ bytes32` - EVM address to universal bytes32 format
- `uint16 ↔ uint32` - Chain ID conversions between protocols
- Zero-padding and type-safe conversions

#### [PayloadEncoder.sol](src/libraries/PayloadEncoder.sol)
Encoding/decoding for cross-chain message payloads:
- Message type identification
- Structured encoding of amounts, balances, and collateral updates
- Efficient payload parsing

#### [ReentrancyLock.sol](src/utils/ReentrancyLock.sol)
Lightweight reentrancy protection for critical functions.

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity 0.8.30

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd m-portal-v2/evm

# Install dependencies
forge install

# Build contracts
forge build
```
