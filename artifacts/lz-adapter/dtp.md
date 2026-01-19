# Development and Test Plan: LayerZero Bridge Adapter

**Version:** 1.0
**Date:** 2026-01-19
**Status:** Draft
**Author:** Claude (sc-dtp skill)
**Runtime:** EVM (Solidity/Foundry)

---

## References

- **Software Design Document:** `./artifacts/lz-adapter/sdd.md`
- **Product Requirements Document:** `./artifacts/lz-adapter/prd.md`

---

## Overview

This plan covers the implementation and testing of the LayerZero Bridge Adapter for Portal V2. The adapter integrates with LayerZero V2's OApp standard to provide cross-chain messaging capabilities alongside the existing Hyperlane and Wormhole adapters.

The implementation follows the established adapter patterns in the codebase, inheriting from `BridgeAdapter` and implementing `IBridgeAdapter` while adding LayerZero-specific functionality via `OAppReceiver`.

### Testing Strategy

**Runtime:** EVM

- **Unit Tests:** Branch coverage pattern using Foundry
  - One test file per function (e.g., `LayerZeroBridgeAdapter.sendMessage.t.sol`)
  - TODO list at top of each test file enumerating all branch test cases
  - Implement tests to achieve 100% branch coverage
- **Fuzz Tests:** Foundry fuzz testing for external function parameters
- **Integration Tests:** Foundry tests for cross-contract interactions with mocked LayerZero Endpoint

---

## Phase 1: Foundation

Setup interfaces, mocks, and base test infrastructure.

### 1.1 LayerZero Interface

#### Implementation

- [ ] **Create `ILayerZeroBridgeAdapter` interface**
  - Reference: SDD Section 3.2 (LayerZero-Specific Interface)
  - File: `evm/src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol`
  - Define:
    - `endpoint()` view function
    - `skip(uint32 srcEid, bytes32 sender, uint64 nonce)` admin recovery function
    - `clear(Origin calldata origin, bytes32 guid, bytes calldata message)` admin recovery function
    - `NonceSkipped` event
    - `PayloadCleared` event
    - `ZeroEndpoint()` error
    - `InvalidPeer(bytes32 sender)` error

### 1.2 LayerZero Mock Contracts

#### Implementation

- [ ] **Create `MockLayerZeroEndpoint` mock contract**
  - File: `evm/test/mocks/MockLayerZeroEndpoint.sol`
  - Implement:
    - `send()` function that records calls and returns MessagingReceipt
    - `quote()` function that returns configurable MessagingFee
    - `setDelegate()` function (no-op for testing)
    - `skip()` function for recovery testing
    - `clear()` function for recovery testing
    - State tracking for sent messages (destination, payload, options)
    - Configurable fee responses
  - Follow pattern from `MockHyperlaneMailbox` and `MockWormholeCoreBridge`

- [ ] **Create LayerZero type definitions**
  - File: `evm/src/bridgeAdapters/layerzero/interfaces/ILayerZeroTypes.sol`
  - Define (or import from `@layerzerolabs/oapp-evm`):
    - `Origin` struct (srcEid, sender, nonce)
    - `MessagingFee` struct (nativeFee, lzTokenFee)
    - `MessagingReceipt` struct (guid, nonce, fee)
    - `MessagingParams` struct for send parameters

### 1.3 Test Base Contract

#### Implementation

- [ ] **Create `LayerZeroBridgeAdapterUnitTestBase` test base contract**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/LayerZeroBridgeAdapterUnitTestBase.sol`
  - Reference: `HyperlaneBridgeAdapterUnitTestBase.sol` pattern
  - Define constants:
    - `HUB_CHAIN_ID = 1`
    - `SPOKE_CHAIN_ID = 2`
    - `SPOKE_LZ_EID = 30110` (Arbitrum EID as example)
    - `HUB_LZ_EID = 30101` (Ethereum EID)
  - Deploy contracts in `setUp()`:
    - `MockLayerZeroEndpoint`
    - `MockPortal`
    - `LayerZeroBridgeAdapter` implementation
    - UUPS proxy with initialize call
  - Configure:
    - Peer address for SPOKE_CHAIN_ID
    - Bridge chain ID mapping (SPOKE_CHAIN_ID ↔ SPOKE_LZ_EID)
  - Create accounts: `admin`, `operator`, `user`
  - Fund all accounts with 1 ether

---

## Phase 2: Core Implementation

Main contract implementation, function by function.

### 2.1 Contract Structure and Constructor

#### Implementation

- [ ] **Create `LayerZeroBridgeAdapter` contract skeleton**
  - Reference: SDD Section 2.3 (Contract Structure), Section 4.1 (State Variables)
  - File: `evm/src/bridgeAdapters/layerzero/LayerZeroBridgeAdapter.sol`
  - Inherit from:
    - `BridgeAdapter` (common adapter functionality)
    - `OAppReceiver` (LayerZero receive callback)
    - `ILayerZeroBridgeAdapter` (LZ-specific interface)
  - Define immutable: `endpoint` (LayerZero Endpoint V2 address)
  - Constructor:
    - Accept `endpoint_` and `portal_` parameters
    - Call `BridgeAdapter(portal_)` constructor
    - Revert with `ZeroEndpoint()` if endpoint is zero
    - Call `_disableInitializers()` (inherited from BridgeAdapter)

#### Unit Tests

- [ ] **Create unit test file for constructor**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/constructor.t.sol`
  - Add TODO list at top of file:
    ```solidity
    /**
     * @notice Unit tests for LayerZeroBridgeAdapter constructor
     *
     * Branch coverage TODOs:
     * - [ ] when endpoint is zero address
     *     - [ ] reverts with ZeroEndpoint
     * - [ ] when portal is zero address
     *     - [ ] reverts with ZeroPortal (inherited)
     * - [ ] when both addresses are valid
     *     - [ ] succeeds
     *     - [ ] sets endpoint immutable correctly
     *     - [ ] sets portal immutable correctly
     */
    ```

### 2.2 Initialize Function

#### Implementation

- [ ] **Implement `initialize` function**
  - Reference: SDD Section 7 (Access Control)
  - Signature: `function initialize(address admin, address operator) external initializer`
  - Call `_initialize(admin, operator)` from BridgeAdapter base
  - Grant DEFAULT_ADMIN_ROLE and OPERATOR_ROLE

#### Unit Tests

- [ ] **Create unit test file for `initialize`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/initialize.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for initialize
     *
     * Branch coverage TODOs:
     * - [ ] when admin is zero address
     *     - [ ] reverts with ZeroAdmin
     * - [ ] when operator is zero address
     *     - [ ] reverts with ZeroOperator
     * - [ ] when both addresses are valid
     *     - [ ] succeeds
     *     - [ ] grants DEFAULT_ADMIN_ROLE to admin
     *     - [ ] grants OPERATOR_ROLE to operator
     * - [ ] when called twice
     *     - [ ] reverts (already initialized)
     */
    ```

### 2.3 Quote Function

#### Implementation

- [ ] **Implement `quote` function**
  - Reference: SDD Section 6.3 (Fee Quoting Flow)
  - Signature: `function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee)`
  - Algorithm:
    1. Build options: `options = _buildOptions(gasLimit)`
    2. Convert chain ID: `dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32()`
    3. Get peer: `_getPeerOrRevert(destinationChainId)` (validates config exists)
    4. Call `_quote(dstEid, payload, options, false)` and return `nativeFee`
  - Critical: Use identical option encoding as `sendMessage()`

#### Unit Tests

- [ ] **Create unit test file for `quote`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/quote.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for quote
     *
     * Branch coverage TODOs:
     * - [ ] when chain ID is not configured (no peer)
     *     - [ ] reverts with UnsupportedChain
     * - [ ] when chain ID is not configured (no bridge chain ID)
     *     - [ ] reverts with UnsupportedChain
     * - [ ] when chain is properly configured
     *     - [ ] succeeds
     *     - [ ] returns fee from endpoint quote
     *     - [ ] calls endpoint with correct EID
     *     - [ ] calls endpoint with correct options encoding
     */
    ```

#### Fuzz Tests

- [ ] **Implement fuzz tests for `quote`**
  - Add to same test file
  - Fuzzable parameters: `gasLimit`, `payload` (length)
  - Invariants:
    - Quote should return non-negative value
    - Quote with same parameters returns same value (deterministic)

### 2.4 Send Message Function

#### Implementation

- [ ] **Implement `sendMessage` function**
  - Reference: SDD Section 6.1 (Send Message Flow)
  - Signature:
    ```solidity
    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata /* extraArguments */
    ) external payable
    ```
  - Algorithm:
    1. `_revertIfNotPortal()` - verify caller is portal
    2. Get peer: `peer = _getPeerOrRevert(destinationChainId)`
    3. Convert chain ID: `dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32()`
    4. Build options: `options = _buildOptions(gasLimit)`
    5. Call `_lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), refundAddress.toAddress())`
  - LayerZero handles refund of excess fees to `refundAddress`

- [ ] **Implement `_buildOptions` internal function**
  - Reference: SDD Section 4.3 (Execution Options Encoding)
  - Use `OptionsBuilder` from `@layerzerolabs/oapp-evm`
  - Build TYPE_3 options with `addExecutorLzReceiveOption(uint128(gasLimit), 0)`

#### Unit Tests

- [ ] **Create unit test file for `sendMessage`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/sendMessage.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for sendMessage
     *
     * Branch coverage TODOs:
     * - [ ] when caller is not portal
     *     - [ ] reverts with NotPortal
     * - [ ] when peer is not configured
     *     - [ ] reverts with UnsupportedChain
     * - [ ] when bridge chain ID is not configured
     *     - [ ] reverts with UnsupportedChain
     * - [ ] when all parameters are valid
     *     - [ ] succeeds
     *     - [ ] calls endpoint send with correct destination EID
     *     - [ ] calls endpoint send with correct payload
     *     - [ ] calls endpoint send with correct options
     *     - [ ] passes msg.value to endpoint
     *     - [ ] uses refundAddress for excess fee refund
     */
    ```

### 2.5 Receive Message Function (_lzReceive)

#### Implementation

- [ ] **Implement `_lzReceive` internal override**
  - Reference: SDD Section 6.2 (Receive Message Flow)
  - Signature (override from OAppReceiver):
    ```solidity
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /* _guid */,
        bytes calldata _message,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) internal override
    ```
  - Algorithm:
    1. Convert EID to internal chain ID: `sourceChainId = _getChainIdOrRevert(_origin.srcEid)`
    2. Verify peer: `if (_origin.sender != _getPeer(sourceChainId)) revert InvalidPeer(_origin.sender)`
    3. Forward to Portal: `IPortal(portal).receiveMessage(sourceChainId, _message)`
  - Note: OAppReceiver base validates `msg.sender == endpoint`

#### Unit Tests

- [ ] **Create unit test file for `lzReceive`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/lzReceive.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for lzReceive (via _lzReceive)
     *
     * Branch coverage TODOs:
     * - [ ] when caller is not endpoint
     *     - [ ] reverts (enforced by OAppReceiver base)
     * - [ ] when source EID is not configured
     *     - [ ] reverts with UnsupportedBridgeChain
     * - [ ] when sender does not match peer for source chain
     *     - [ ] reverts with InvalidPeer
     * - [ ] when sender matches configured peer
     *     - [ ] succeeds
     *     - [ ] calls portal.receiveMessage with correct source chain ID
     *     - [ ] calls portal.receiveMessage with correct payload
     */
    ```

### 2.6 OAppCore Peer Override

#### Implementation

- [ ] **Override `_getPeerOrRevert` for OAppCore compatibility**
  - Reference: SDD Section 2.3 (Contract Structure)
  - LayerZero's OAppCore expects `peers(uint32 eid)` function
  - Override or implement to use BridgeAdapter's peer storage
  - Ensure both BridgeAdapter peer management and OApp peer queries work correctly

#### Unit Tests

- [ ] **Add peer compatibility tests to existing peer test file**
  - Verify OApp's peer query mechanism works with BridgeAdapter storage
  - Verify `setPeer` updates are reflected in OApp peer queries

---

## Phase 3: Access Control & Security

Role setup, permission checks, recovery functions.

### 3.1 Skip Recovery Function

#### Implementation

- [ ] **Implement `skip` admin recovery function**
  - Reference: SDD Section 6.4 (Recovery Functions)
  - Signature: `function skip(uint32 srcEid, bytes32 sender, uint64 nonce) external onlyRole(DEFAULT_ADMIN_ROLE)`
  - Call `ILayerZeroEndpointV2(endpoint).skip(address(this), srcEid, sender, nonce)`
  - Emit `NonceSkipped(srcEid, sender, nonce)`

#### Unit Tests

- [ ] **Create unit test file for `skip`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/skip.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for skip
     *
     * Branch coverage TODOs:
     * - [ ] when caller does not have DEFAULT_ADMIN_ROLE
     *     - [ ] reverts with AccessControlUnauthorizedAccount
     * - [ ] when caller has DEFAULT_ADMIN_ROLE
     *     - [ ] succeeds
     *     - [ ] calls endpoint.skip with correct parameters
     *     - [ ] emits NonceSkipped event
     */
    ```

### 3.2 Clear Recovery Function

#### Implementation

- [ ] **Implement `clear` admin recovery function**
  - Reference: SDD Section 6.4 (Recovery Functions)
  - Signature: `function clear(Origin calldata origin, bytes32 guid, bytes calldata message) external onlyRole(DEFAULT_ADMIN_ROLE)`
  - Call `ILayerZeroEndpointV2(endpoint).clear(address(this), origin, guid, message)`
  - Emit `PayloadCleared(origin.srcEid, origin.sender, origin.nonce, guid)`

#### Unit Tests

- [ ] **Create unit test file for `clear`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/clear.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for clear
     *
     * Branch coverage TODOs:
     * - [ ] when caller does not have DEFAULT_ADMIN_ROLE
     *     - [ ] reverts with AccessControlUnauthorizedAccount
     * - [ ] when caller has DEFAULT_ADMIN_ROLE
     *     - [ ] succeeds
     *     - [ ] calls endpoint.clear with correct parameters
     *     - [ ] emits PayloadCleared event
     */
    ```

### 3.3 Inherited Access Control Tests

#### Unit Tests

- [ ] **Create unit test file for `setPeer`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/setPeer.t.sol`
  - Follow pattern from `HyperlaneBridgeAdapter/setPeer.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for setPeer (inherited from BridgeAdapter)
     *
     * Branch coverage TODOs:
     * - [ ] when caller does not have OPERATOR_ROLE
     *     - [ ] reverts with AccessControlUnauthorizedAccount
     * - [ ] when chainId is zero
     *     - [ ] reverts with ZeroChain
     * - [ ] when peer is zero bytes32
     *     - [ ] reverts with ZeroPeer
     * - [ ] when peer is already set to same value
     *     - [ ] succeeds but does not emit event (no-op)
     * - [ ] when setting new peer
     *     - [ ] succeeds
     *     - [ ] updates storage
     *     - [ ] emits PeerSet event
     */
    ```

- [ ] **Create unit test file for `setBridgeChainId`**
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/setBridgeChainId.t.sol`
  - Follow pattern from `HyperlaneBridgeAdapter/setBridgeChainId.t.sol`
  - Add TODO list:
    ```solidity
    /**
     * @notice Unit tests for setBridgeChainId (inherited from BridgeAdapter)
     *
     * Branch coverage TODOs:
     * - [ ] when caller does not have OPERATOR_ROLE
     *     - [ ] reverts with AccessControlUnauthorizedAccount
     * - [ ] when chainId is zero
     *     - [ ] reverts with ZeroChain
     * - [ ] when bridgeChainId is zero
     *     - [ ] reverts with ZeroBridgeChain
     * - [ ] when mapping is already set to same value
     *     - [ ] succeeds but does not emit event (no-op)
     * - [ ] when setting new mapping
     *     - [ ] succeeds
     *     - [ ] updates forward mapping
     *     - [ ] updates reverse mapping
     *     - [ ] emits BridgeChainIdSet event
     * - [ ] when changing existing mapping
     *     - [ ] cleans up old forward mapping
     *     - [ ] cleans up old reverse mapping
     *     - [ ] sets new mappings correctly
     */
    ```

### 3.4 Upgrade Authorization

#### Unit Tests

- [ ] **Add upgrade authorization tests to initialize test file**
  - Verify only DEFAULT_ADMIN_ROLE can authorize upgrades
  - Test `_authorizeUpgrade` access control

---

## Phase 4: Integration

DVN configuration and endpoint interactions.

### 4.1 DVN Configuration (Optional Enhancement)

#### Implementation

- [ ] **Implement `setDVNConfig` admin function** (if needed per SDD Section 3.4)
  - Reference: SDD Section 3.4 (Admin/Privileged Interface)
  - Signature: `function setDVNConfig(uint32 remoteEid, uint32 configType, bytes calldata config) external onlyRole(DEFAULT_ADMIN_ROLE)`
  - Call through to LayerZero Endpoint's `setConfig()` via MessageLib
  - Note: This may be handled outside the adapter via direct Endpoint interaction

#### Unit Tests

- [ ] **Create unit test file for DVN configuration** (if implemented)
  - File: `evm/test/unit/bridgeAdapters/LayerZeroBridgeAdapter/setDVNConfig.t.sol`
  - Test access control and correct endpoint interaction

---

## Phase 5: Invariant & Property Tests

Comprehensive invariant testing based on SDD mathematical invariants.

### 5.1 Core Invariants

- [ ] **Implement invariant test suite**
  - Reference: SDD Section 5 (Mathematical Invariants)
  - File: `evm/test/invariants/LayerZeroBridgeAdapter.invariants.t.sol`
  - Invariants to test:
    - [ ] **Sender Verification**: Every received message origin.sender == peers[origin.srcEid]
    - [ ] **Chain ID Bijection**: internalToBridgeChainId[c] = b ⟺ bridgeToInternalChainId[b] = c
    - [ ] **Quote Accuracy**: quote() returns fee >= actual send cost

### 5.2 Stateful Fuzz Testing

- [ ] **Implement stateful fuzz test handlers**
  - Define actor functions:
    - `setPeer(uint32 chainId, bytes32 peer)`
    - `setBridgeChainId(uint32 chainId, uint256 bridgeChainId)`
    - `sendMessage(...)` (as portal)
    - `lzReceive(...)` (as endpoint)
  - Verify invariants hold after each action sequence
  - Target functions for fuzzing: configuration functions, send/receive flows

---

## Task Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| Phase 1: Foundation | 4 | Interfaces, mocks, test base contract |
| Phase 2: Core Implementation | 12 | Contract skeleton, constructor, initialize, quote, sendMessage, lzReceive |
| Phase 3: Access Control | 8 | skip, clear, setPeer, setBridgeChainId, upgrade auth |
| Phase 4: Integration | 2 | DVN configuration (optional) |
| Phase 5: Invariant Tests | 2 | Core invariants, stateful fuzzing |
| **Total** | **28** | |

---

## Execution Notes

### For Agents

1. **Work sequentially**: Complete tasks in order as later tasks may depend on earlier ones
2. **Check off tasks**: Mark tasks as `[x]` when complete
3. **Consult the SDD**: Each task references SDD sections—read them for full context
4. **Run tests frequently**: After implementing each function, run its tests before proceeding
5. **Maintain coverage**: Ensure all branches are covered before moving to the next function

### Branch Coverage Workflow (EVM)

1. Create a test file for the function (e.g., `LayerZeroBridgeAdapter.sendMessage.t.sol`)
2. Add a TODO list at the top enumerating all branches to test
3. Implement each test case, checking off TODOs as completed
4. Run `forge test --match-path test/unit/bridgeAdapters/LayerZeroBridgeAdapter/sendMessage.t.sol` to execute tests
5. Run `forge coverage` to verify branch coverage

### Test Naming Convention

Follow existing project patterns:
- Success cases: `test_<function>_<expectedBehavior>()`
- Revert cases: `test_<function>_revertsIf<Condition>()`
- Fuzz tests: `testFuzz_<function>(<params>)`

### LayerZero-Specific Considerations

1. **OApp Base Integration**: Inherit `OAppReceiver` from `@layerzerolabs/oapp-evm`. This provides built-in endpoint verification.

2. **OptionsBuilder Usage**: Use LayerZero's `OptionsBuilder` library for correct option encoding:
   ```solidity
   using OptionsBuilder for bytes;
   bytes memory options = OptionsBuilder.newOptions()
       .addExecutorLzReceiveOption(uint128(gasLimit), 0);
   ```

3. **No Replay Protection Storage**: LayerZero handles replay protection via nonces at the protocol level. Do NOT add a `consumedMessages` mapping like WormholeBridgeAdapter.

4. **Peer Storage Compatibility**: BridgeAdapter stores peers by internal chain ID. LayerZero OApp expects peers by EID. Ensure the adapter correctly maps between these.

5. **Mock Endpoint Design**: The mock endpoint should simulate:
   - `send()` - record calls, return MessagingReceipt
   - `quote()` - return configurable fees
   - `lzReceive()` - should be callable to simulate inbound messages
   - `skip()` / `clear()` - for recovery function testing

---

## Appendix

### A. File Structure

Expected file structure after implementation:

```
evm/
├── src/
│   └── bridgeAdapters/
│       └── layerzero/
│           ├── LayerZeroBridgeAdapter.sol
│           └── interfaces/
│               ├── ILayerZeroBridgeAdapter.sol
│               └── ILayerZeroTypes.sol (or imports from @layerzerolabs)
├── test/
│   ├── unit/
│   │   └── bridgeAdapters/
│   │       └── LayerZeroBridgeAdapter/
│   │           ├── LayerZeroBridgeAdapterUnitTestBase.sol
│   │           ├── constructor.t.sol
│   │           ├── initialize.t.sol
│   │           ├── quote.t.sol
│   │           ├── sendMessage.t.sol
│   │           ├── lzReceive.t.sol
│   │           ├── skip.t.sol
│   │           ├── clear.t.sol
│   │           ├── setPeer.t.sol
│   │           └── setBridgeChainId.t.sol
│   ├── invariants/
│   │   └── LayerZeroBridgeAdapter.invariants.t.sol
│   └── mocks/
│       └── MockLayerZeroEndpoint.sol
```

### B. LayerZero Dependencies


Copy the necessary base contracts from the LayerZero Devtools repo (https://github.com/LayerZero-Labs/devtools/tree/main/packages/oapp-evm). Don't use remappings, instead specify relative paths to files.
- `OAppReceiver.sol` - receive callback handling
- `OAppCore.sol` - endpoint binding
- `OptionsBuilder.sol` - option encoding library

### C. Chain ID Reference

| Chain | M0 Internal ID | LayerZero EID |
|-------|----------------|---------------|
| Ethereum | 1 | 30101 |
| Arbitrum | 42161 | 30110 |
| Optimism | 10 | 30111 |
| Base | 8453 | 30184 |

### D. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-19 | Claude | Initial plan |
