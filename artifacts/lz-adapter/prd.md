# Product Requirements Document: LayerZero Bridge Adapter

**Version:** 1.1
**Date:** 2026-01-19
**Status:** Ready for Technical Design
**Author:** Claude (sc-prd skill)

---

## 1. Overview

### 1.1 Problem Statement

Portal V2 currently supports cross-chain messaging via Hyperlane and Wormhole adapters. Adding LayerZero as a third option increases network redundancy, provides access to LayerZero's extensive chain coverage (120+ chains), and gives M0 operational flexibility to choose the most reliable or cost-effective bridge for each pathway.

### 1.2 Proposed Solution

Build a LayerZero Bridge Adapter that implements LayerZero's OApp standard to enable Portal to send and receive cross-chain messages via LayerZero's messaging infrastructure. The adapter will have feature parity with existing Hyperlane and Wormhole adapters while following LayerZero-specific patterns for security and configuration.

### 1.3 Success Criteria

- Adapter successfully sends and receives all Portal message types (TokenTransfer, Index, RegistrarKey, RegistrarList, FillReport, CancelReport, EarnerMerkleRoot)
- Sender verification prevents unauthorized message injection
- Replay protection ensures messages cannot be executed twice
- Fee quoting works on-chain via the `quote()` function
- DVN configuration is admin-manageable per pathway
- Adapter passes security audit with no critical/high findings
- Integration tests demonstrate end-to-end message flow on testnets

---

## 2. Background & Context

### 2.1 Current State

Portal V2 uses a pluggable bridge adapter architecture where:
- `Portal.sol` handles business logic (token transfers, index propagation, registrar sync)
- Bridge adapters abstract the underlying messaging protocol
- Two adapters exist: `HyperlaneBridgeAdapter` and `WormholeBridgeAdapter`
- Adapters implement `IBridgeAdapter` interface with `sendMessage()`, `quote()`, and chain ID mapping

Each adapter follows common patterns:
- UUPS upgradeable proxy with ERC-7201 namespaced storage
- Role-based access control (DEFAULT_ADMIN_ROLE, OPERATOR_ROLE)
- Dual chain ID mapping (internal M0 chain IDs ↔ protocol-specific IDs)
- Peer address management per remote chain

### 2.2 Strategic Fit

- **Redundancy**: Third messaging network reduces single-point-of-failure risk
- **Chain coverage**: LayerZero supports 120+ chains, enabling future expansion
- **Cost optimization**: Different networks have different fee structures; more options enable cost optimization
- **Decentralization**: Reduces dependency on any single bridge provider

### 2.3 Prior Art & Research

| Resource | Relevance |
|----------|-----------|
| [LayerZero OApp Overview](https://docs.layerzero.network/v2/developers/evm/oapp/overview) | Core OApp standard documentation |
| [LayerZero Integration Checklist](https://docs.layerzero.network/v2/tools/integration-checklist) | Production readiness requirements |
| [LayerZero Security Stack (DVNs)](https://docs.layerzero.network/v2/concepts/modular-security/security-stack-dvns) | DVN configuration and security model |
| [Composable Security - LayerZero Integration](https://composable-security.com/blog/secure-integration-with-layerzero/) | Security best practices and common pitfalls |
| [LayerZero V2 Deep Dive](https://medium.com/layerzero-official/layerzero-v2-deep-dive-869f93e09850) | Architecture overview |
| Existing `HyperlaneBridgeAdapter.sol` | Reference implementation for adapter patterns |
| Existing `WormholeBridgeAdapter.sol` | Reference implementation with explicit replay protection |

---

## 3. User Stories & Actors

### 3.1 Actors

| Actor | Description |
|-------|-------------|
| Portal Contract | The Portal contract that calls `sendMessage()` to dispatch cross-chain messages |
| Admin | Holder of DEFAULT_ADMIN_ROLE; can upgrade adapter and manage critical settings |
| Operator | Holder of OPERATOR_ROLE; can configure peers, chain IDs, and DVN settings |
| LayerZero Endpoint | LayerZero's on-chain contract that routes messages and calls `lzReceive()` |
| DVNs | Decentralized Verifier Networks that attest to message validity |
| Executor | LayerZero's off-chain service that delivers messages to destination chains |

### 3.2 User Stories

#### US-1: Send Cross-Chain Message
**As a** Portal contract
**I want to** send a message via LayerZero
**So that** the message is delivered to the destination chain's Portal

**Acceptance Criteria:**
- [ ] Portal can call `sendMessage()` with destination chain, gas limit, refund address, and payload
- [ ] Adapter converts internal chain ID to LayerZero endpoint ID (EID)
- [ ] Adapter encodes gas options for destination execution
- [ ] Adapter forwards message to LayerZero Endpoint with correct fee payment
- [ ] Excess fees are refunded to the specified refund address on source chain

#### US-2: Receive Cross-Chain Message
**As a** LayerZero Endpoint
**I want to** deliver a verified message to the adapter
**So that** the adapter can forward it to Portal for processing

**Acceptance Criteria:**
- [ ] Only LayerZero Endpoint can call the receive function
- [ ] Adapter verifies the sender is a registered peer for the source chain
- [ ] Adapter converts LayerZero EID to internal chain ID
- [ ] Adapter forwards payload to Portal via `receiveMessage()`
- [ ] Replay protection prevents the same message from being processed twice

#### US-3: Quote Bridge Fee
**As a** user or frontend
**I want to** get an accurate fee quote before sending
**So that** I can provide sufficient payment for the cross-chain message

**Acceptance Criteria:**
- [ ] `quote()` function returns estimated fee in native token
- [ ] Quote accounts for destination gas limit and payload size
- [ ] Quote uses same encoding logic as actual send to ensure accuracy

#### US-4: Configure Chain Mapping
**As an** Operator
**I want to** map internal chain IDs to LayerZero endpoint IDs
**So that** the adapter can route messages to correct destinations

**Acceptance Criteria:**
- [ ] Operator can set bidirectional mapping between chain ID and LayerZero EID
- [ ] Invalid or zero values are rejected
- [ ] Mapping changes emit events for off-chain tracking

#### US-5: Configure Peer Addresses
**As an** Operator
**I want to** register trusted peer adapters on remote chains
**So that** only authorized senders can deliver messages

**Acceptance Criteria:**
- [ ] Operator can set peer address (bytes32) per remote chain
- [ ] Peer address is verified on message receipt
- [ ] Zero address peers are rejected or handled appropriately

#### US-6: Configure DVN Security
**As an** Admin
**I want to** configure which DVNs verify messages for each pathway
**So that** I can customize security based on route requirements

**Acceptance Criteria:**
- [ ] Admin can set required DVNs and optional DVNs per pathway
- [ ] Admin can set confirmation requirements
- [ ] Configuration applies to both send and receive paths
- [ ] Default LayerZero DVN is used if no explicit config is set

#### US-7: Upgrade Adapter
**As an** Admin
**I want to** upgrade the adapter implementation
**So that** bugs can be fixed and features added without redeployment

**Acceptance Criteria:**
- [ ] Only Admin can authorize upgrades
- [ ] Upgrade preserves storage (peers, chain mappings, DVN config)
- [ ] Upgrade follows UUPS proxy pattern

#### US-8: Recover Stuck Messages
**As an** Admin
**I want to** recover from stuck or failed message states
**So that** the adapter can resume normal operation without redeployment

**Acceptance Criteria:**
- [ ] Admin can call `skip()` to skip a blocked inbound nonce
- [ ] Admin can call `clear()` to clear a stored payload hash
- [ ] Admin can call `forceResumeReceive()` to unblock the receive pathway
- [ ] Recovery functions emit events for auditability
- [ ] Recovery functions are restricted to DEFAULT_ADMIN_ROLE

---

## 4. Functional Requirements

### 4.1 Core Functionality

#### FR-1: Send Message via LayerZero
**Priority:** Must Have
**Description:** Implement `sendMessage()` that dispatches payloads through LayerZero Endpoint V2
**Rationale:** Core functionality required for outbound cross-chain messaging

**Details:**
- Accept Portal's standard parameters: `destinationChainId`, `gasLimit`, `refundAddress`, `payload`, `extraArguments`
- Convert internal chain ID to LayerZero EID
- Encode execution options with gas limit using LayerZero's OptionsBuilder pattern
- Call LayerZero Endpoint's `send()` function with appropriate fee
- Refund address receives excess fees on source chain (LayerZero's default behavior)

#### FR-2: Receive Message from LayerZero
**Priority:** Must Have
**Description:** Implement LayerZero's `_lzReceive()` callback to process inbound messages
**Rationale:** Core functionality required for inbound cross-chain messaging

**Details:**
- Inherit from LayerZero's OApp base contract (or implement ILayerZeroReceiver)
- Only accept calls from LayerZero Endpoint (enforced by base contract)
- Verify sender is registered peer for source EID
- Convert source EID to internal chain ID
- Forward payload to Portal via `IPortal(portal).receiveMessage()`

#### FR-3: On-Chain Fee Quoting
**Priority:** Must Have
**Description:** Implement `quote()` that returns estimated fee for a message
**Rationale:** Enables accurate fee estimation without off-chain dependencies

**Details:**
- Use same option encoding as `sendMessage()` for consistency
- Call LayerZero Endpoint's `quote()` function
- Return fee in native token (wei)

#### FR-4: Chain ID Mapping
**Priority:** Must Have
**Description:** Bidirectional mapping between M0 internal chain IDs (uint32) and LayerZero EIDs (uint32)
**Rationale:** LayerZero uses its own endpoint ID system distinct from EVM chain IDs

**Details:**
- Store mappings in ERC-7201 namespaced storage
- Provide getter functions: `getBridgeChainId()`, `getChainId()`
- Operator can set mappings via `setBridgeChainId()`
- Revert if mapping not found when sending/receiving

#### FR-5: Peer Management
**Priority:** Must Have
**Description:** Register and verify trusted peer addresses per remote chain
**Rationale:** Prevents unauthorized message injection from untrusted sources

**Details:**
- Store peers as bytes32 (LayerZero uses bytes32 for cross-VM compatibility)
- Operator can set peers via `setPeer()`
- Verify `origin.sender == peers[srcEid]` on receive
- Revert with descriptive error if peer mismatch

#### FR-6: DVN Configuration
**Priority:** Must Have
**Description:** Allow admin to configure DVN security settings per pathway
**Rationale:** Enables customizable security beyond LayerZero defaults

**Details:**
- Admin can call LayerZero Endpoint's `setConfig()` to configure DVNs
- Support setting required DVNs, optional DVNs, and thresholds
- Support setting block confirmation requirements
- Provide getter to query current DVN config
- Document that send and receive configs must match across chains

#### FR-7: Access Control
**Priority:** Must Have
**Description:** Role-based permissions matching existing adapter pattern
**Rationale:** Consistent security model across all adapters

**Details:**
- DEFAULT_ADMIN_ROLE: upgrade authorization, DVN configuration
- OPERATOR_ROLE: peer management, chain ID mapping
- Portal address: exclusive caller of `sendMessage()`

#### FR-8: Upgradeability
**Priority:** Must Have
**Description:** UUPS proxy pattern for contract upgrades
**Rationale:** Enables bug fixes and feature additions without redeployment

**Details:**
- Inherit from OpenZeppelin's UUPSUpgradeable
- `_authorizeUpgrade()` restricted to DEFAULT_ADMIN_ROLE
- Use ERC-7201 namespaced storage to prevent collisions

#### FR-9: Message Recovery Functions
**Priority:** Must Have
**Description:** Admin functions to recover from stuck message states
**Rationale:** Provides operational resilience without requiring contract redeployment

**Details:**
- `skip(uint32 srcEid, bytes32 sender, uint64 nonce)` - Skip a blocked inbound nonce to unblock subsequent messages
- `clear(Origin calldata origin, bytes32 guid, bytes calldata message)` - Clear a stored payload that failed execution
- Wrapper functions call through to LayerZero Endpoint's recovery methods
- All recovery functions restricted to DEFAULT_ADMIN_ROLE
- Emit events for each recovery action for audit trail
- Document in runbook when and how to use each recovery function

### 4.2 Smart Contract-Specific Requirements

#### 4.2.1 State Changes

| State Variable | Purpose | Mutability |
|---------------|---------|------------|
| `portal` | Address of Portal contract | Immutable (set in constructor) |
| `endpoint` | LayerZero Endpoint V2 address | Immutable (set in constructor) |
| `internalToBridgeChainId` | Maps M0 chain ID → LayerZero EID | OPERATOR_ROLE |
| `bridgeToInternalChainId` | Maps LayerZero EID → M0 chain ID | OPERATOR_ROLE |
| `peers` | Maps chain ID → trusted peer address | OPERATOR_ROLE |

#### 4.2.2 Access Control

| Function/Action | Permitted Actors | Conditions |
|----------------|------------------|------------|
| `sendMessage()` | Portal contract only | None |
| `_lzReceive()` | LayerZero Endpoint only | Sender must be registered peer |
| `quote()` | Anyone (view) | None |
| `setPeer()` | OPERATOR_ROLE | Valid chain ID, non-zero peer |
| `setBridgeChainId()` | OPERATOR_ROLE | Valid chain IDs |
| `setDVNConfig()` | DEFAULT_ADMIN_ROLE | Valid DVN addresses |
| `skip()` | DEFAULT_ADMIN_ROLE | Valid nonce to skip |
| `clear()` | DEFAULT_ADMIN_ROLE | Valid payload to clear |
| `_authorizeUpgrade()` | DEFAULT_ADMIN_ROLE | None |

#### 4.2.3 Events

| Event | Purpose | Key Data |
|-------|---------|----------|
| `PeerSet` | Track peer configuration changes | chainId, peer address |
| `BridgeChainIdSet` | Track chain ID mapping changes | internalChainId, bridgeChainId |
| `MessageSent` | Track outbound messages | destinationChainId, messageId (from payload) |
| `MessageReceived` | Track inbound messages | sourceChainId, messageId |
| `DVNConfigSet` | Track DVN configuration changes | eid, configType, config |
| `MessageSkipped` | Track nonce skip recovery actions | srcEid, sender, nonce |
| `PayloadCleared` | Track payload clear recovery actions | srcEid, sender, nonce, guid |

#### 4.2.4 External Interactions

| External System | Interaction Type | Purpose |
|----------------|------------------|---------|
| LayerZero Endpoint V2 | Write (send) | Dispatch outbound messages |
| LayerZero Endpoint V2 | Read (quote) | Get fee estimates |
| LayerZero Endpoint V2 | Write (setConfig) | Configure DVN settings |
| LayerZero Endpoint V2 | Callback (lzReceive) | Receive inbound messages |
| Portal | Write (receiveMessage) | Forward inbound payloads |

---

## 5. Non-Functional Requirements

### 5.1 Security Requirements

- **Sender Verification**: Only accept messages from registered peers (enforced in `_lzReceive`)
- **Endpoint Verification**: Only LayerZero Endpoint can invoke receive callback (enforced by OApp base)
- **Replay Protection**: LayerZero's nonce system handles replay protection at protocol level; Portal also tracks `processedMessages[messageId]` as defense-in-depth
- **No Hardcoded Addresses**: All peer and chain mappings must be configurable
- **Input Validation**: Validate all parameters (non-zero addresses, valid chain IDs)
- **Reentrancy Safety**: LayerZero clears payload hash before calling `_lzReceive`, preventing reentrancy
- **Unordered Execution**: Use unordered message execution to match Portal's existing behavior and avoid blocking on failed messages

### 5.2 Performance Requirements

- **Gas Efficiency**: Minimize storage reads/writes; use immutables where possible
- **Quote Accuracy**: `quote()` must use identical encoding to `sendMessage()` for accurate estimates
- **No Unnecessary Storage**: Don't duplicate replay protection if LayerZero handles it

### 5.3 Upgrade & Migration

- Adapter is upgradeable via UUPS proxy
- Storage layout must be append-only (no reordering existing variables)
- Use ERC-7201 namespaced storage pattern
- Migration from existing adapters not required (new adapter, not replacement)

---

## 6. Constraints & Assumptions

### 6.1 Constraints

- **LayerZero V2 Only**: Must use LayerZero Endpoint V2 (not V1)
- **EVM Chains Only**: This adapter is for EVM chains; SVM/other VMs out of scope
- **Solidity 0.8.30**: Must match project's Solidity version
- **Existing Interface**: Must implement `IBridgeAdapter` interface exactly
- **No Protocol Modifications**: Cannot modify Portal or other adapters

### 6.2 Assumptions

- LayerZero Endpoint V2 is deployed on all target chains
- LayerZero's nonce-based system provides adequate replay protection (Portal's `messageId` tracking is defense-in-depth)
- Fee refunds occur on source chain (LayerZero's documented behavior)
- DVN configuration changes take effect immediately (no warm-up period)
- LayerZero Executor reliably delivers messages (standard SLA assumptions)

---

## 7. Anti-Goals (Out of Scope)

**The following are explicitly NOT part of this feature:**

- **Composed Messages**: LayerZero's composed message feature (multi-hop execution) is not needed; Portal uses simple single-destination messages
- **Ordered Execution**: No requirement for strict message ordering; unordered execution matches existing adapters
- **Native Token Drops**: No need to drop native tokens to recipients as part of message delivery
- **LZ Token Payments**: Fees will be paid in native tokens only, not LZ tokens
- **OFT/ONFT Integration**: This is a generic message adapter, not a token standard implementation
- **Read Operations (lzRead)**: LayerZero's cross-chain read feature is not needed
- **Automatic Retry Logic**: Failed messages are handled at Portal level, not adapter level
- **Multi-Adapter Aggregation**: No need to split messages across multiple DVN paths simultaneously

---

## 8. Resolved Questions

| # | Question | Resolution |
|---|----------|------------|
| 1 | What is the maximum message size supported by LayerZero's default config? | **10,000 bytes** (default, configurable via ExecutorConfig). Portal's largest payload (~200 bytes) is well within this limit. No validation needed. |
| 2 | Should we implement `forceResumeReceive()` for emergency unblocking? | **Yes.** Expose admin-only recovery functions (`skip()`, `clear()`) to handle stuck messages without redeployment. See FR-9. |
| 3 | What DVN combination should be used for production (required count, optional threshold)? | **1 required DVN as baseline**, with admin flexibility to configure additional DVNs per pathway. Balances cost with ability to strengthen security when needed. |
| 4 | Should enforced options (minimum gas) be set at adapter level or rely on Portal's gas limit configuration? | **Rely on Portal's config.** Portal already configures gas limits per payload type via `_getPayloadGasLimitOrRevert()`. No duplication at adapter level. |
| 5 | How should the adapter handle LayerZero's `skip()`, `burn()`, `clear()` recovery functions? | **Expose `skip()` and `clear()` as admin-only functions.** These allow recovery from stuck nonces and failed payloads. `burn()` not needed (used for ZRO token burning). |

---

## 9. Dependencies & Risks

### 9.1 Dependencies

| Dependency | Type | Status |
|------------|------|--------|
| LayerZero Endpoint V2 deployment | External | Deployed on major chains |
| LayerZero OApp contracts (`@layerzerolabs/oapp-evm`) | External | Available via npm |
| Portal V2 contracts | Internal | Deployed |
| OpenZeppelin contracts (UUPS, AccessControl) | External | Available in lib/common |

### 9.2 Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LayerZero DVN unavailability | Low | High | Configure multiple DVNs; can fall back to other adapters |
| Incorrect peer configuration | Medium | High | Careful deployment checklist; testnet validation |
| Fee estimation inaccuracy | Low | Medium | Test quote accuracy; allow buffer in frontend |
| Message stuck due to DVN mismatch | Medium | Medium | Ensure send/receive DVN configs match; document in runbook |
| LayerZero protocol upgrade breaks adapter | Low | High | Pin to specific versions; monitor LayerZero announcements |
| Message stuck requiring recovery | Low | Medium | Admin recovery functions (`skip()`, `clear()`) enable unblocking without redeployment |

---

## 10. References

### 10.1 Project Files

- `evm/src/interfaces/IBridgeAdapter.sol` - Interface the adapter must implement
- `evm/src/bridgeAdapters/BridgeAdapter.sol` - Base contract with common functionality
- `evm/src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol` - Reference implementation (pull model)
- `evm/src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol` - Reference implementation (push model with explicit replay protection)
- `evm/src/Portal.sol` - Portal contract that interacts with adapters
- `evm/src/libraries/PayloadEncoder.sol` - Payload encoding/decoding library

### 10.2 External References

- [LayerZero OApp Overview](https://docs.layerzero.network/v2/developers/evm/oapp/overview) - Core OApp standard
- [LayerZero V2 Protocol Overview](https://docs.layerzero.network/v2/developers/evm/protocol-contracts-overview) - Architecture and message flow
- [LayerZero Options SDK](https://docs.layerzero.network/v2/tools/sdks/options) - Gas option encoding
- [LayerZero Integration Checklist](https://docs.layerzero.network/v2/tools/integration-checklist) - Production readiness guide
- [LayerZero Deployed Contracts](https://docs.layerzero.network/v2/deployments/deployed-contracts) - Endpoint addresses and EIDs
- [LayerZero Security Stack](https://docs.layerzero.network/v2/concepts/modular-security/security-stack-dvns) - DVN configuration
- [Composable Security - LayerZero Integration](https://composable-security.com/blog/secure-integration-with-layerzero/) - Security best practices

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| **OApp** | Omnichain Application - LayerZero's standard for cross-chain contracts |
| **EID** | Endpoint ID - LayerZero's chain identifier (e.g., Ethereum = 30101) |
| **DVN** | Decentralized Verifier Network - Entities that verify cross-chain messages |
| **Executor** | Off-chain service that delivers messages to destination chains |
| **GUID** | Global Unique Identifier - LayerZero's unique message identifier |
| **Nonce** | Sequential counter for message ordering |
| **Peer** | Trusted counterpart contract on a remote chain |
| **ULN** | Ultra Light Node - LayerZero's message library |

### B. LayerZero EID Examples

| Chain | EID (Mainnet) | EID (Testnet) |
|-------|---------------|---------------|
| Ethereum | 30101 | 40101 |
| Arbitrum | 30110 | 40110 |
| Optimism | 30111 | 40111 |
| Base | 30184 | 40184 |
| Polygon | 30109 | 40109 |

### C. Comparison with Existing Adapters

| Feature | Hyperlane | Wormhole | LayerZero (Proposed) |
|---------|-----------|----------|----------------------|
| Message Model | Pull (stateless) | Push (VAA relay) | Pull (OApp callback) |
| Replay Protection | Protocol-level | Explicit hash tracking | Protocol-level (nonce) |
| Fee Quoting | On-chain | Off-chain only | On-chain |
| Fee Refund | Source chain | Source chain | Source chain |
| Sender Verification | Mailbox-mediated | VAA signature + peer check | Endpoint-mediated + peer check |
| Chain ID Type | uint32 (domain) | uint16 | uint32 (EID) |
| Security Config | ISM | Guardian set | DVN configuration |

### D. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-19 | Claude | Initial draft |
| 1.1 | 2026-01-19 | Claude | Resolved all open questions; added US-8 (message recovery), FR-9 (recovery functions), recovery events |
