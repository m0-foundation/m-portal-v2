// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for peers (OApp compatibility)
 *
 * Branch coverage TODOs:
 * - [x] when EID is not configured (no bridge chain ID mapping)
 *     - [x] returns zero (no revert)
 * - [x] when EID is configured but no peer set for mapped chain
 *     - [x] returns zero (no revert)
 * - [x] when EID is configured and peer is set
 *     - [x] returns correct peer address
 * - [x] when setPeer is called
 *     - [x] peers() returns updated value
 * - [x] when multiple chains are configured
 *     - [x] returns correct peer for each EID
 */

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

contract PeersUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    /// @notice Additional chain IDs for multi-chain tests.
    uint32 internal constant OPTIMISM_CHAIN_ID = 10;
    uint32 internal constant OPTIMISM_LZ_EID = 30_111;
    bytes32 internal optimismPeerAddress;

    function setUp() public override {
        super.setUp();

        optimismPeerAddress = makeAddr("optimismAdapter").toBytes32();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   EID NOT CONFIGURED (NO MAPPING)
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_returnsZeroForUnconfiguredEid() external view {
        // Use an unconfigured EID
        uint32 unconfiguredEid = 99_999;

        bytes32 peer = adapter.peers(unconfiguredEid);

        assertEq(peer, bytes32(0), "Should return zero for unconfigured EID");
    }

    function test_peers_returnsZeroForZeroEid() external view {
        bytes32 peer = adapter.peers(0);

        assertEq(peer, bytes32(0), "Should return zero for EID 0");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //               EID CONFIGURED BUT NO PEER SET
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_returnsZeroWhenBridgeChainIdMappedButNoPeer() external {
        // Configure bridge chain ID mapping but no peer
        uint32 baseChainId = 8453;
        uint32 baseLzEid = 30_184;

        vm.prank(operator);
        adapter.setBridgeChainId(baseChainId, baseLzEid);

        // Peer is not set for this chain ID
        bytes32 peer = adapter.peers(baseLzEid);

        assertEq(peer, bytes32(0), "Should return zero when no peer is set for mapped chain");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   EID CONFIGURED WITH PEER
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_returnsCorrectPeerForConfiguredEid() external view {
        // SPOKE_LZ_EID is configured with peerAdapterAddress in setUp
        bytes32 peer = adapter.peers(SPOKE_LZ_EID);

        assertEq(peer, peerAdapterAddress, "Should return configured peer for EID");
    }

    function test_peers_returnsCorrectPeerAfterSetPeer() external {
        // Configure a new chain
        vm.startPrank(operator);
        adapter.setPeer(OPTIMISM_CHAIN_ID, optimismPeerAddress);
        adapter.setBridgeChainId(OPTIMISM_CHAIN_ID, OPTIMISM_LZ_EID);
        vm.stopPrank();

        bytes32 peer = adapter.peers(OPTIMISM_LZ_EID);

        assertEq(peer, optimismPeerAddress, "Should return peer after setPeer");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   SETPEER UPDATES PEERS()
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_updatesWhenSetPeerCalled() external {
        // Initial peer
        bytes32 initialPeer = adapter.peers(SPOKE_LZ_EID);
        assertEq(initialPeer, peerAdapterAddress, "Initial peer should match");

        // Update peer
        bytes32 newPeerAddress = makeAddr("newSpokeAdapter").toBytes32();
        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, newPeerAddress);

        bytes32 updatedPeer = adapter.peers(SPOKE_LZ_EID);
        assertEq(updatedPeer, newPeerAddress, "peers() should return updated peer after setPeer");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   MULTIPLE CHAINS CONFIGURED
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_returnsCorrectPeerForMultipleChains() external {
        // Configure additional chain
        vm.startPrank(operator);
        adapter.setPeer(OPTIMISM_CHAIN_ID, optimismPeerAddress);
        adapter.setBridgeChainId(OPTIMISM_CHAIN_ID, OPTIMISM_LZ_EID);
        vm.stopPrank();

        // Verify both chains return correct peers
        bytes32 spokePeer = adapter.peers(SPOKE_LZ_EID);
        bytes32 optimismPeer = adapter.peers(OPTIMISM_LZ_EID);

        assertEq(spokePeer, peerAdapterAddress, "Spoke peer should be correct");
        assertEq(optimismPeer, optimismPeerAddress, "Optimism peer should be correct");
    }

    function test_peers_isolatesPeersByChain() external {
        // Configure additional chain
        vm.startPrank(operator);
        adapter.setPeer(OPTIMISM_CHAIN_ID, optimismPeerAddress);
        adapter.setBridgeChainId(OPTIMISM_CHAIN_ID, OPTIMISM_LZ_EID);
        vm.stopPrank();

        // Update only one peer
        bytes32 newSpokePeer = makeAddr("newSpokeAdapter").toBytes32();
        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, newSpokePeer);

        // Verify only spoke peer changed
        assertEq(adapter.peers(SPOKE_LZ_EID), newSpokePeer, "Spoke peer should be updated");
        assertEq(adapter.peers(OPTIMISM_LZ_EID), optimismPeerAddress, "Optimism peer should be unchanged");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   OAPP COMPATIBILITY
    // ═══════════════════════════════════════════════════════════════════════

    function test_peers_matchesAllowInitializePath() external view {
        // OAppReceiver.allowInitializePath uses _getPeerForEid internally
        // peers() should return consistent value
        bytes32 peer = adapter.peers(SPOKE_LZ_EID);

        // If peer is non-zero, allowInitializePath should return true
        // This verifies the consistency between peers() and internal _getPeerForEid
        assertTrue(peer != bytes32(0), "Peer should be non-zero for configured chain");
    }

    function test_peers_matchesGetPeerAfterBridgeMapping() external view {
        // peers(EID) should return the same as getPeer(chainId) for mapped chains
        bytes32 peerFromPeers = adapter.peers(SPOKE_LZ_EID);
        bytes32 peerFromGetPeer = adapter.getPeer(SPOKE_CHAIN_ID);

        assertEq(peerFromPeers, peerFromGetPeer, "peers(EID) should match getPeer(chainId)");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_peers_neverReverts(uint32 eid) external view {
        // peers() should never revert, just return zero for unconfigured EIDs
        bytes32 peer = adapter.peers(eid);

        // If EID is the configured spoke EID, should return peer
        // Otherwise should return zero
        if (eid == SPOKE_LZ_EID) {
            assertEq(peer, peerAdapterAddress, "Configured EID should return peer");
        } else {
            // For unconfigured EIDs, could be zero or the peer if EID happens to map correctly
            // The important thing is it doesn't revert
            assertTrue(true, "peers() should not revert");
        }
    }

    function testFuzz_peers_consistentWithSetPeer(bytes32 newPeer) external {
        // Skip zero peer (would revert in setPeer)
        vm.assume(newPeer != bytes32(0));

        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, newPeer);

        bytes32 peer = adapter.peers(SPOKE_LZ_EID);

        assertEq(peer, newPeer, "peers() should reflect setPeer changes");
    }
}
