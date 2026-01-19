# Software Design Document: LayerZero Bridge Adapter

**Version:** 1.0
**Date:** 2026-01-19
**Status:** Draft
**Author:** Claude (sc-sdd skill)
**Runtime:** EVM (Solidity/Foundry)

---

## 1. Overview

### 1.1 Document Purpose

This document describes the technical design for the LayerZero Bridge Adapter. It specifies the architecture, interfaces, invariants, and design patterns required to implement the feature as defined in the PRD.

### 1.2 Design Goals

- **Feature parity**: Match the capabilities of existing Hyperlane and Wormhole adapters
- **LayerZero V2 compliance**: Properly implement OApp patterns for message send/receive
- **Protocol-level replay protection**: Leverage LayerZero's nonce system without duplicating replay tracking
- **Configurable security**: Enable admin-controlled DVN configuration per pathway
- **Operational resilience**: Provide admin recovery functions for stuck messages

### 1.3 Design Non-Goals

- **Composed messages**: No multi-hop message execution
- **Ordered execution**: Unordered delivery matches existing adapter behavior
- **Native token drops**: No airdrop of native tokens to recipients
- **LZ token payments**: Fees paid in native tokens only
- **OFT/ONFT integration**: Generic message adapter, not token standard

### 1.4 References

- PRD: `./artifacts/lz-adapter/prd.md`
- [LayerZero OApp Overview](https://docs.layerzero.network/v2/developers/evm/oapp/overview)
- [LayerZero Integration Checklist](https://docs.layerzero.network/v2/tools/integration-checklist)
- [LayerZero Security Stack (DVNs)](https://docs.layerzero.network/v2/concepts/modular-security/security-stack-dvns)
- Existing adapter: `evm/src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol`
- Existing adapter: `evm/src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol`

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Source Chain                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐         ┌──────────────────────────┐                       │
│  │   Portal    │────────▶│  LayerZeroBridgeAdapter  │                       │
│  └─────────────┘         └────────────┬─────────────┘                       │
│                                       │                                     │
│                                       │ _lzSend()                           │
│                                       ▼                                     │
│                          ┌──────────────────────────┐                       │
│                          │  LayerZero Endpoint V2   │                       │
│                          └────────────┬─────────────┘                       │
│                                       │                                     │
└───────────────────────────────────────┼─────────────────────────────────────┘
                                        │
                        ┌───────────────┼───────────────┐
                        │               │               │
                        ▼               ▼               ▼
                   ┌─────────┐    ┌─────────┐    ┌──────────┐
                   │  DVN 1  │    │  DVN 2  │    │ Executor │
                   └─────────┘    └─────────┘    └──────────┘
                        │               │               │
                        └───────────────┼───────────────┘
                                        │
┌───────────────────────────────────────┼─────────────────────────────────────┐
│                                       │                                     │
│                          ┌────────────▼─────────────┐                       │
│                          │  LayerZero Endpoint V2   │                       │
│                          └────────────┬─────────────┘                       │
│                                       │ lzReceive()                         │
│                                       ▼                                     │
│                          ┌──────────────────────────┐                       │
│                          │  LayerZeroBridgeAdapter  │                       │
│                          └────────────┬─────────────┘                       │
│                                       │                                     │
│  ┌─────────────┐                      │ receiveMessage()                    │
│  │   Portal    │◀─────────────────────┘                                     │
│  └─────────────┘                                                            │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                            Destination Chain                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Overview

| Component | Responsibility | Interactions |
|-----------|---------------|--------------|
| `LayerZeroBridgeAdapter` | Implements `IBridgeAdapter`; wraps LayerZero OApp for Portal | Portal (caller), LayerZero Endpoint (send/receive) |
| `BridgeAdapter` (base) | Common chain ID mapping, peer management, access control | Inherited by `LayerZeroBridgeAdapter` |
| LayerZero Endpoint V2 | Protocol-level message routing, DVN/Executor coordination | Called by adapter for send/quote, calls adapter for receive |
| DVNs | Verify message payload hashes across chains | Configured via Endpoint's `setConfig()` |
| Executor | Delivers verified messages to destination | Included in execution options |

### 2.3 Contract Structure

```
┌───────────────────────────────────────────────────────────────────────┐
│                       LayerZeroBridgeAdapter                          │
├───────────────────────────────────────────────────────────────────────┤
│  Inherits:                                                            │
│  ├── BridgeAdapter (common adapter functionality)                     │
│  │   ├── IBridgeAdapter (interface)                                   │
│  │   ├── BridgeAdapterStorageLayout (ERC-7201 storage)               │
│  │   ├── AccessControlUpgradeable (roles)                            │
│  │   └── UUPSUpgradeable (proxy pattern)                             │
│  └── OAppReceiver (LayerZero receive callback)                        │
│      └── OAppCore (endpoint binding, peer management override)        │
├───────────────────────────────────────────────────────────────────────┤
│  Immutables:                                                          │
│  ├── portal (address) - from BridgeAdapter                            │
│  └── endpoint (address) - LayerZero Endpoint V2                       │
├───────────────────────────────────────────────────────────────────────┤
│  Storage (ERC-7201 namespaced):                                       │
│  ├── BridgeAdapterStorageStruct (inherited)                          │
│  │   ├── internalToBridgeChainId mapping                             │
│  │   ├── bridgeToInternalChainId mapping                             │
│  │   └── remotePeer mapping                                          │
│  └── (No additional storage needed - LZ handles replay protection)    │
└───────────────────────────────────────────────────────────────────────┘
```

### 2.4 External Dependencies

| Dependency | Type | Purpose | Trust Assumptions |
|------------|------|---------|-------------------|
| LayerZero Endpoint V2 | Protocol | Message routing, verification | Trusted protocol; deployed by LayerZero |
| DVNs | Verifiers | Attest to message validity | Configurable; at least 1 required DVN must be honest |
| Executor | Delivery | Delivers messages to destination | Trusted to deliver; gas limits enforced on-chain |
| OpenZeppelin Contracts | Library | Access control, upgradeability | Audited, industry standard |
| `@layerzerolabs/oapp-evm` | Library | OApp base contracts, OptionsBuilder | Official LayerZero SDK |

---

## 3. Interface Definitions

### 3.1 Primary Interface (IBridgeAdapter)

The adapter must implement the existing `IBridgeAdapter` interface exactly:

```solidity
/// @title  IBridgeAdapter interface
/// @notice Interface defining a bridge adapter for cross-chain messaging functionality.
interface IBridgeAdapter {
    /// @notice Emitted when the address of bridge adapter on the remote chain is set.
    event PeerSet(uint32 chainId, bytes32 peer);

    /// @notice Emitted when the provider-specific chain ID is set.
    event BridgeChainIdSet(uint32 chainId, uint256 bridgeChainId);

    error NotPortal();
    error ZeroPortal();
    error ZeroAdmin();
    error ZeroOperator();
    error ZeroChain();
    error ZeroBridgeChain();
    error ZeroPeer();
    error UnsupportedChain(uint32 chainId);
    error UnsupportedBridgeChain(uint256 bridgeChainId);

    function portal() external view returns (address);

    function quote(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes memory payload
    ) external view returns (uint256 fee);

    function getPeer(uint32 chainId) external view returns (bytes32);
    function getBridgeChainId(uint32 chainId) external view returns (uint256);
    function getChainId(uint256 bridgeChainId) external view returns (uint32);

    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata extraArguments
    ) external payable;

    function setPeer(uint32 destinationChainId, bytes32 destinationPeer) external;
    function setBridgeChainId(uint32 chainId, uint256 bridgeChainId) external;
    function initialize(address admin, address operator) external;
}
```

### 3.2 LayerZero-Specific Interface

```solidity
/// @title  ILayerZeroBridgeAdapter interface
/// @notice LayerZero-specific interface extending the base bridge adapter.
interface ILayerZeroBridgeAdapter is IBridgeAdapter {
    /// @notice Emitted when a nonce is skipped for recovery.
    /// @param srcEid The source endpoint ID.
    /// @param sender The sender address (bytes32).
    /// @param nonce  The skipped nonce.
    event NonceSkipped(uint32 indexed srcEid, bytes32 indexed sender, uint64 nonce);

    /// @notice Emitted when a payload is cleared for recovery.
    /// @param srcEid The source endpoint ID.
    /// @param sender The sender address (bytes32).
    /// @param nonce  The nonce of the cleared payload.
    /// @param guid   The global unique identifier of the message.
    event PayloadCleared(uint32 indexed srcEid, bytes32 indexed sender, uint64 nonce, bytes32 guid);

    /// @notice Thrown when the LayerZero Endpoint address is zero.
    error ZeroEndpoint();

    /// @notice Thrown when the message sender is not the expected peer.
    /// @param sender The actual sender address.
    error InvalidPeer(bytes32 sender);

    /// @notice Returns the LayerZero Endpoint V2 address.
    function endpoint() external view returns (address);

    /// @notice Skips a blocked inbound nonce to unblock subsequent messages.
    /// @dev    Only callable by DEFAULT_ADMIN_ROLE.
    /// @param srcEid The source endpoint ID.
    /// @param sender The sender address (bytes32).
    /// @param nonce  The nonce to skip.
    function skip(uint32 srcEid, bytes32 sender, uint64 nonce) external;

    /// @notice Clears a stored payload hash that failed execution.
    /// @dev    Only callable by DEFAULT_ADMIN_ROLE.
    /// @param origin  The origin information (srcEid, sender, nonce).
    /// @param guid    The global unique identifier.
    /// @param message The original message bytes.
    function clear(Origin calldata origin, bytes32 guid, bytes calldata message) external;
}
```

### 3.3 LayerZero OApp Interface (from `@layerzerolabs/oapp-evm`)

The adapter will use these LayerZero interfaces:

```solidity
/// @notice Origin struct for incoming messages
struct Origin {
    uint32 srcEid;      // Source endpoint ID
    bytes32 sender;     // Sender address as bytes32
    uint64 nonce;       // Message nonce
}

/// @notice MessagingFee struct for fee handling
struct MessagingFee {
    uint256 nativeFee;  // Fee in native token
    uint256 lzTokenFee; // Fee in LZ token (we use 0)
}

/// @notice MessagingReceipt returned from send
struct MessagingReceipt {
    bytes32 guid;       // Global unique identifier
    uint64 nonce;       // Assigned nonce
    MessagingFee fee;   // Actual fee charged
}

/// @dev Internal function signature in OAppReceiver that we override
function _lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _message,
    address _executor,
    bytes calldata _extraData
) internal virtual;
```

### 3.4 Admin/Privileged Interface

```solidity
/// @notice Admin functions for DVN configuration and recovery
interface ILayerZeroBridgeAdapterAdmin {
    /// @notice Sets the DVN configuration for a specific pathway.
    /// @dev    Calls through to LayerZero Endpoint's setConfig().
    ///         Only callable by DEFAULT_ADMIN_ROLE.
    /// @param remoteEid The remote endpoint ID.
    /// @param configType The configuration type (e.g., CONFIG_TYPE_ULN).
    /// @param config The encoded configuration bytes.
    function setDVNConfig(uint32 remoteEid, uint32 configType, bytes calldata config) external;
}
```

---

## 4. Data Structures

### 4.1 State Variables

```solidity
contract LayerZeroBridgeAdapter is BridgeAdapter, OAppReceiver, ILayerZeroBridgeAdapter {
    using OptionsBuilder for bytes;

    // ═══════════════════════════════════════════════════════════════════════
    //                              IMMUTABLES
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc ILayerZeroBridgeAdapter
    /// @dev Set in constructor, cannot be changed. The LayerZero Endpoint V2 contract.
    address public immutable endpoint;

    // ═══════════════════════════════════════════════════════════════════════
    //                           INHERITED STORAGE
    // ═══════════════════════════════════════════════════════════════════════

    // From BridgeAdapterStorageLayout (ERC-7201 namespaced):
    //
    // struct BridgeAdapterStorageStruct {
    //     mapping(uint32 internalChainId => uint256 bridgeChainId) internalToBridgeChainId;
    //     mapping(uint32 internalChainId => bytes32 peer) remotePeer;
    //     mapping(uint256 bridgeChainId => uint32 internalChainId) bridgeToInternalChainId;
    // }

    // ═══════════════════════════════════════════════════════════════════════
    //                     NO ADDITIONAL STORAGE NEEDED
    // ═══════════════════════════════════════════════════════════════════════

    // LayerZero's nonce-based replay protection is handled at the protocol level.
    // Portal also tracks processedMessages[messageId] as defense-in-depth.
    // Therefore, we do NOT need to duplicate replay tracking in this adapter
    // (unlike WormholeBridgeAdapter which requires explicit hash tracking).
}
```

### 4.2 Chain ID Mapping

LayerZero uses 32-bit Endpoint IDs (EIDs) that differ from EVM chain IDs:

| Chain | EVM Chain ID | LayerZero EID (Mainnet) | LayerZero EID (Testnet) |
|-------|--------------|-------------------------|-------------------------|
| Ethereum | 1 | 30101 | 40101 |
| Arbitrum | 42161 | 30110 | 40110 |
| Optimism | 10 | 30111 | 40111 |
| Base | 8453 | 30184 | 40184 |
| Polygon | 137 | 30109 | 40109 |

The adapter uses `bridgeChainId` to store the LayerZero EID, maintaining consistency with existing adapters.

### 4.3 Execution Options Encoding

```solidity
/// @dev Builds LayerZero execution options with the specified gas limit.
/// @param gasLimit The gas limit for destination execution.
/// @return options The encoded options bytes.
function _buildOptions(uint256 gasLimit) internal pure returns (bytes memory options) {
    // Uses OptionsBuilder from @layerzerolabs/oapp-evm
    // TYPE_3 options allow for extensible execution parameters
    options = OptionsBuilder.newOptions()
        .addExecutorLzReceiveOption(uint128(gasLimit), 0) // gas, msg.value
        .toBytes();
}
```

---

## 5. Mathematical Invariants

### 5.1 Core Invariants

**Invariant 1: Sender Verification**
```
∀ received messages m:
    origin.sender == peers[origin.srcEid]
```
*Description: Every received message must originate from a registered peer address for the source chain.*

**Invariant 2: Chain ID Mapping Bijection**
```
∀ chainId c, bridgeChainId b:
    internalToBridgeChainId[c] = b ⟺ bridgeToInternalChainId[b] = c
```
*Description: Chain ID mappings are always bidirectional and consistent.*

**Invariant 3: Message Delivery Guarantee**
```
∀ sent messages m via sendMessage():
    LayerZero.send() succeeds ⟹ m will be delivered to destination
    (subject to DVN verification and executor delivery)
```
*Description: Successfully sent messages will be delivered by the LayerZero protocol.*

### 5.2 State Transition Constraints

**Constraint 1: Peer Configuration**
```
Pre-condition:  msg.sender has OPERATOR_ROLE
Post-condition: remotePeer[chainId] = newPeer ∧ PeerSet event emitted
```

**Constraint 2: Message Send**
```
Pre-condition:  msg.sender == portal ∧ msg.value >= quote()
Post-condition: LayerZero Endpoint.send() called ∧ excess refunded
```

**Constraint 3: Message Receive**
```
Pre-condition:  msg.sender == endpoint ∧ origin.sender == peers[origin.srcEid]
Post-condition: Portal.receiveMessage() called with converted chainId
```

### 5.3 Fee Invariants

**Invariant 4: Quote Accuracy**
```
∀ quotes q for (destinationChainId, gasLimit, payload):
    quote() returns fee f ⟹ sendMessage() with msg.value >= f succeeds
```
*Description: The quote function returns a fee that is sufficient for message delivery.*

---

## 6. Detailed Design

### 6.1 Send Message Flow

**Purpose:** Dispatch a cross-chain message from Portal through LayerZero.

**Flow Diagram:**
```
┌──────────────────┐
│  Portal calls    │
│  sendMessage()   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Verify caller    │
│ is portal        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Get peer and     │
│ convert chain ID │
│ to LayerZero EID │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Build execution  │
│ options with     │
│ gas limit        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Call Endpoint    │
│ .send() with     │
│ msg.value        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Excess fee       │
│ refunded to      │
│ refundAddress    │
└──────────────────┘
```

**Algorithm:**
1. Verify `msg.sender == portal` (revert with `NotPortal()` otherwise)
2. Retrieve peer address: `peer = _getPeerOrRevert(destinationChainId)`
3. Convert chain ID: `dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32()`
4. Build options: `options = _buildOptions(gasLimit)`
5. Prepare messaging params and call `_lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), refundAddress.toAddress())`
6. LayerZero handles refund of excess fees to `refundAddress`

**Edge Cases:**
- **Peer not configured**: Reverts with `UnsupportedChain(chainId)`
- **Chain ID not mapped**: Reverts with `UnsupportedChain(chainId)`
- **Insufficient fee**: LayerZero Endpoint reverts (fee validation at protocol level)

### 6.2 Receive Message Flow

**Purpose:** Process incoming messages from LayerZero and forward to Portal.

**Flow Diagram:**
```
┌──────────────────┐
│ LayerZero        │
│ Endpoint calls   │
│ lzReceive()      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ OAppReceiver     │
│ validates        │
│ msg.sender       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ _lzReceive()     │
│ called with      │
│ Origin, payload  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Verify sender    │
│ matches peer     │
│ for srcEid       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Convert EID to   │
│ internal chain   │
│ ID               │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Call Portal      │
│ .receiveMessage  │
│ (chainId,payload)│
└──────────────────┘
```

**Algorithm:**
1. `OAppReceiver` base validates `msg.sender == endpoint` (built-in)
2. Override `_lzReceive()` to implement business logic
3. Verify peer: `if (origin.sender != _getPeer(sourceChainId)) revert InvalidPeer(origin.sender)`
4. Convert EID to internal chain ID: `sourceChainId = _getChainIdOrRevert(origin.srcEid)`
5. Forward to Portal: `IPortal(portal).receiveMessage(sourceChainId, message)`

**Edge Cases:**
- **Unknown source EID**: Reverts with `UnsupportedBridgeChain(origin.srcEid)`
- **Peer mismatch**: Reverts with `InvalidPeer(origin.sender)`
- **Portal reverts**: Transaction reverts entirely (no partial state changes)

### 6.3 Fee Quoting Flow

**Purpose:** Provide accurate fee estimate for sending a message.

**Algorithm:**
1. Build options with same logic as `sendMessage()`: `options = _buildOptions(gasLimit)`
2. Convert chain ID: `dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32()`
3. Get peer: `peer = _getPeerOrRevert(destinationChainId)`
4. Call LayerZero's quote: `fee = _quote(dstEid, payload, options, false).nativeFee`
5. Return `fee`

**Critical:** Quote must use identical option encoding as `sendMessage()` to ensure accuracy.

### 6.4 Recovery Functions

**Purpose:** Allow admin to recover from stuck message states.

**skip() - Skip Blocked Nonce:**
```solidity
function skip(uint32 srcEid, bytes32 sender, uint64 nonce) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ILayerZeroEndpointV2(endpoint).skip(address(this), srcEid, sender, nonce);
    emit NonceSkipped(srcEid, sender, nonce);
}
```

**clear() - Clear Failed Payload:**
```solidity
function clear(
    Origin calldata origin,
    bytes32 guid,
    bytes calldata message
) external onlyRole(DEFAULT_ADMIN_ROLE) {
    ILayerZeroEndpointV2(endpoint).clear(address(this), origin, guid, message);
    emit PayloadCleared(origin.srcEid, origin.sender, origin.nonce, guid);
}
```

---

## 7. Access Control

### 7.1 Roles

| Role | Description | Assignment |
|------|-------------|------------|
| DEFAULT_ADMIN_ROLE | Upgrade authorization, DVN configuration, recovery functions | Assigned during `initialize()` |
| OPERATOR_ROLE | Peer management, chain ID mapping | Assigned during `initialize()` |
| Portal | Exclusive caller of `sendMessage()` | Immutable, set in constructor |
| LayerZero Endpoint | Exclusive caller of `lzReceive()` | Enforced by OAppReceiver base |

### 7.2 Permission Matrix

| Function | Admin | Operator | Portal | Endpoint | Anyone |
|----------|-------|----------|--------|----------|--------|
| `sendMessage()` | - | - | Yes | - | - |
| `_lzReceive()` | - | - | - | Yes | - |
| `quote()` | - | - | - | - | Yes (view) |
| `setPeer()` | - | Yes | - | - | - |
| `setBridgeChainId()` | - | Yes | - | - | - |
| `setDVNConfig()` | Yes | - | - | - | - |
| `skip()` | Yes | - | - | - | - |
| `clear()` | Yes | - | - | - | - |
| `_authorizeUpgrade()` | Yes | - | - | - | - |

### 7.3 Access Control Implementation

```solidity
contract LayerZeroBridgeAdapter is BridgeAdapter, OAppReceiver, ILayerZeroBridgeAdapter {
    // Portal check (from BridgeAdapter)
    function sendMessage(...) external payable {
        _revertIfNotPortal(); // Checks msg.sender == portal
        // ...
    }

    // Endpoint check (from OAppReceiver base)
    function lzReceive(...) public payable virtual override {
        // OAppReceiver enforces: require(msg.sender == address(endpoint))
        _lzReceive(...);
    }

    // Admin-only functions
    function skip(...) external onlyRole(DEFAULT_ADMIN_ROLE) { ... }
    function clear(...) external onlyRole(DEFAULT_ADMIN_ROLE) { ... }
    function setDVNConfig(...) external onlyRole(DEFAULT_ADMIN_ROLE) { ... }

    // Operator functions (inherited from BridgeAdapter)
    function setPeer(...) external onlyRole(OPERATOR_ROLE) { ... }
    function setBridgeChainId(...) external onlyRole(OPERATOR_ROLE) { ... }

    // Upgrade authorization
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
```

---

## 8. Security Considerations

### 8.1 Threat Model

#### 8.1.1 Assets at Risk

| Asset | Value | Protection Priority |
|-------|-------|---------------------|
| User funds (M tokens) | High | Critical |
| Protocol state (index, registrar) | High | Critical |
| Admin keys | High | Critical |
| Message integrity | High | Critical |

#### 8.1.2 Threat Actors

| Actor | Motivation | Capabilities |
|-------|------------|--------------|
| Malicious User | Steal funds, replay messages | Can call public functions, send arbitrary data |
| Compromised Operator | Misconfigure peers, redirect messages | Can set peers and chain mappings |
| Compromised DVN | Approve fraudulent messages | Can attest to invalid payload hashes |
| Malicious External Contract | Inject unauthorized messages | Can call `lzReceive()` but blocked by endpoint check |

#### 8.1.3 Attack Vectors

**AV-1: Unauthorized Message Injection**
- *Description:* Attacker attempts to call receive function directly to inject fake messages
- *Impact:* Could mint tokens or change protocol state without actual cross-chain transfer
- *Mitigation:* OAppReceiver base enforces `msg.sender == endpoint`; adapter verifies `origin.sender == peer`

**AV-2: Peer Spoofing**
- *Description:* Attacker deploys malicious contract on source chain claiming to be the peer
- *Impact:* Could send fraudulent messages that pass peer verification
- *Mitigation:* Peers must be explicitly configured by OPERATOR_ROLE; peer addresses verified against registered mapping

**AV-3: Replay Attack**
- *Description:* Attacker attempts to re-execute a previously delivered message
- *Impact:* Could duplicate token transfers or state changes
- *Mitigation:* LayerZero's nonce system prevents replay at protocol level; Portal's `processedMessages[messageId]` provides defense-in-depth

**AV-4: Chain ID Confusion**
- *Description:* Attacker exploits misconfigured chain ID mappings to redirect messages
- *Impact:* Messages could be sent to wrong chains or accepted from wrong sources
- *Mitigation:* Bidirectional chain ID mapping with cleanup on changes; reverts on missing mappings

**AV-5: DVN Collusion**
- *Description:* Multiple DVNs collude to approve fraudulent message
- *Impact:* Invalid messages could be committed and executed
- *Mitigation:* Admin can configure multiple required DVNs from independent operators; threshold requirements

**AV-6: Gas Griefing**
- *Description:* Attacker provides insufficient gas causing message execution to fail
- *Impact:* Messages stuck in pending state
- *Mitigation:* Portal configures gas limits per payload type; quote uses same options as send; admin recovery functions available

### 8.2 Security Patterns Used

- [x] **Endpoint verification**: OAppReceiver enforces only LayerZero Endpoint can call receive
- [x] **Peer verification**: Explicit check that `origin.sender == peers[srcEid]`
- [x] **Protocol-level replay protection**: LayerZero's nonce system
- [x] **Defense-in-depth replay**: Portal tracks `processedMessages[messageId]`
- [x] **Access control**: OpenZeppelin AccessControlUpgradeable for role management
- [x] **Upgradeable proxy**: UUPS pattern with admin-only authorization
- [x] **Namespaced storage**: ERC-7201 prevents storage collisions on upgrade
- [x] **Input validation**: Zero checks on all configuration inputs
- [x] **Consistent fee encoding**: Quote uses identical options as send

### 8.3 Security Assumptions

1. LayerZero Endpoint V2 is correctly implemented and secure
2. At least one required DVN is honest and operational
3. LayerZero's nonce system correctly prevents replay at protocol level
4. Admin and Operator keys are properly secured (multisig recommended)
5. DVN configurations on source and destination chains are consistent

---

## 9. Off-Chain Components

### 9.1 Required Off-Chain Infrastructure

| Component | Purpose | Criticality |
|-----------|---------|-------------|
| LayerZero DVNs | Verify message payload hashes | Required (protocol-level) |
| LayerZero Executor | Deliver verified messages | Required (protocol-level) |
| Fee estimation service | Get accurate quotes | Optional (on-chain quote available) |

### 9.2 DVN Configuration

DVNs are configured per pathway using LayerZero's `setConfig()` mechanism:

```solidity
// Example DVN configuration structure
struct UlnConfig {
    uint64 confirmations;           // Block confirmations required
    uint8 requiredDVNCount;         // Number of required DVNs
    uint8 optionalDVNCount;         // Number of optional DVNs
    uint8 optionalDVNThreshold;     // How many optional DVNs must verify
    address[] requiredDVNs;         // Addresses of required DVNs
    address[] optionalDVNs;         // Addresses of optional DVNs
}
```

**Critical Requirement:** Send Library config on Chain A must match Receive Library config on Chain B for the pathway to work correctly.

---

## 10. Best Practices & Patterns

### 10.1 EVM/Solidity Best Practices

| Practice | Rationale | Implementation |
|----------|-----------|----------------|
| Use immutables for fixed addresses | Gas savings, prevents accidental modification | `endpoint` and `portal` are immutable |
| ERC-7201 namespaced storage | Prevents storage collisions on upgrade | Inherit `BridgeAdapterStorageLayout` |
| Explicit visibility modifiers | Prevents accidental exposure | All functions have explicit visibility |
| Custom errors over require strings | Gas savings, better error handling | Use typed errors like `InvalidPeer(sender)` |
| Consistent option encoding | Ensures quote accuracy | `_buildOptions()` used in both quote and send |

### 10.2 LayerZero-Specific Patterns

| Pattern | Rationale | Implementation |
|---------|-----------|----------------|
| Inherit OAppReceiver | Built-in endpoint verification, proper callback handling | Extends `OAppReceiver` from `@layerzerolabs/oapp-evm` |
| Use OptionsBuilder | Correct option encoding | Import and use `OptionsBuilder.newOptions().addExecutorLzReceiveOption()` |
| Verify peer in _lzReceive | Prevents unauthorized message injection | Check `origin.sender == _getPeer(chainId)` |
| Don't duplicate replay protection | LayerZero handles nonces; Portal handles messageId | No `consumedMessages` mapping needed |
| Expose recovery functions | Operational resilience | `skip()` and `clear()` for admin |

### 10.3 Anti-Patterns to Avoid

| Anti-Pattern | Why Problematic | Alternative |
|--------------|-----------------|-------------|
| Direct endpoint calls without OApp base | Missing security checks | Use `OAppReceiver` base contract |
| Hardcoded DVN addresses | Inflexible, requires upgrade to change | Use `setDVNConfig()` for runtime configuration |
| Duplicating replay protection | Wastes gas, adds complexity | Trust LayerZero's nonce system + Portal's messageId |
| Ordered execution mode | Can block all messages if one fails | Use unordered (default) execution |
| Manual nonce tracking | Diverges from protocol state | Rely on LayerZero's `skip()` for recovery |

---

## 11. Testing Strategy Guidance

### 11.1 Critical Test Scenarios

| Scenario | Type | Priority |
|----------|------|----------|
| Send message with valid parameters | Unit | High |
| Send message with unconfigured peer | Unit | High |
| Send message with unconfigured chain ID | Unit | High |
| Send message from non-portal caller | Unit | High |
| Receive message from endpoint with valid peer | Unit | High |
| Receive message with invalid peer | Unit | High |
| Receive message with unconfigured source EID | Unit | High |
| Quote accuracy matches actual send cost | Integration | High |
| End-to-end message flow (send → receive) | Fork/Integration | High |
| Admin recovery: skip blocked nonce | Unit | Medium |
| Admin recovery: clear failed payload | Unit | Medium |
| DVN configuration changes | Integration | Medium |
| Upgrade preserves storage | Unit | High |

### 11.2 Invariant Testing

| Invariant | Fuzz Strategy |
|-----------|---------------|
| Sender verification | Random origin.sender values; only registered peer should succeed |
| Chain ID bijection | Random set/get operations; mappings always consistent |
| Quote accuracy | Random gas limits and payloads; quote >= actual cost |
| Access control | Random callers; only authorized roles succeed |

### 11.3 Edge Cases to Test

- Zero gas limit (should this be allowed or rejected?)
- Maximum gas limit (uint256 max)
- Empty payload
- Maximum payload size
- Concurrent messages to same destination
- Upgrade mid-flight (message sent but not yet received)
- Peer changed while message in flight
- Chain ID mapping changed while message in flight

---

## 12. Open Design Questions

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Should adapter inherit OApp fully or only OAppReceiver? | A) Full OApp (includes OAppSender), B) OAppReceiver only | B - OAppReceiver only. We use `_lzSend` directly; full OApp adds unnecessary delegate complexity |
| 2 | How to handle LayerZero's delegate pattern? | A) Set delegate to admin, B) Set delegate to adapter itself, C) No delegate | C - No delegate needed; we call endpoint directly for config |
| 3 | Should `extraArguments` in sendMessage be used? | A) Ignore, B) Parse for additional LZ options | A - Ignore initially; can be extended later if needed for advanced options |

---

## 13. Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| **OApp** | Omnichain Application - LayerZero's standard for cross-chain contracts |
| **EID** | Endpoint ID - LayerZero's chain identifier (e.g., Ethereum mainnet = 30101) |
| **DVN** | Decentralized Verifier Network - entities that verify cross-chain message validity |
| **Executor** | Off-chain service that delivers messages to destination chains |
| **GUID** | Global Unique Identifier - LayerZero's unique message identifier |
| **Nonce** | Sequential counter per sender-receiver path for message ordering |
| **Peer** | Trusted counterpart contract on a remote chain |
| **ULN** | Ultra Light Node - LayerZero's message verification library |
| **SendLib/ReceiveLib** | Libraries that handle send/receive verification logic |

### B. External References

- [LayerZero V2 Documentation](https://docs.layerzero.network/v2) - Official protocol documentation
- [LayerZero OApp EVM Package](https://www.npmjs.com/package/@layerzerolabs/oapp-evm) - Solidity SDK
- [LayerZero Deployed Contracts](https://docs.layerzero.network/v2/deployments/deployed-contracts) - Endpoint addresses per chain
- [LayerZero DVN Addresses](https://docs.layerzero.network/v2/deployments/dvn-addresses) - Available DVN providers
- [Composable Security - LayerZero Integration](https://composable-security.com/blog/secure-integration-with-layerzero/) - Security best practices

### C. LayerZero Endpoint V2 Addresses

| Chain | Endpoint Address |
|-------|------------------|
| Ethereum Mainnet | `0x1a44076050125825900e736c501f859c50fE728c` |
| Arbitrum | `0x1a44076050125825900e736c501f859c50fE728c` |
| Optimism | `0x1a44076050125825900e736c501f859c50fE728c` |
| Base | `0x1a44076050125825900e736c501f859c50fE728c` |
| Polygon | `0x1a44076050125825900e736c501f859c50fE728c` |

*Note: LayerZero V2 uses the same endpoint address across all EVM chains.*

### D. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-19 | Claude | Initial design |
