// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract SetBridgeChainIdUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    using TypeConverter for address;

    uint32 internal constant OTHER_CHAIN_ID = 3;
    uint256 internal constant OTHER_HYPERLANE_DOMAIN = 3000;

    function test_setBridgeChainId() external {
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        vm.prank(operator);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), OTHER_HYPERLANE_DOMAIN);
        assertEq(adapter.getChainId(OTHER_HYPERLANE_DOMAIN), OTHER_CHAIN_ID);
    }

    function test_setBridgeChainId_keepsPeerOnFreshAssignment() external {
        // Peers are only cleared when an existing pair is replaced. Setting a domain for
        // a chain for the first time must not clear the chain's peer, otherwise calling
        // `setPeer` before `setBridgeChainId` during initial configuration would be impossible.
        bytes32 otherPeer = makeAddr("otherAdapter").toBytes32();

        vm.startPrank(operator);
        adapter.setPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);
        vm.stopPrank();

        assertEq(adapter.getPeer(OTHER_CHAIN_ID), otherPeer);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), peerAdapterAddress);
    }

    function test_setBridgeChainId_sameMappingNoEvent() external {
        // Setting the same mapping should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setBridgeChainId_reassignsBridgeChainToNewInternalChain() external {
        // Reassign SPOKE_HYPERLANE_DOMAIN from SPOKE_CHAIN_ID to OTHER_CHAIN_ID.
        // The old (SPOKE_CHAIN_ID -> SPOKE_HYPERLANE_DOMAIN) forward mapping must be removed and
        // logged, and the orphaned chain's peer must be cleared.
        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(OTHER_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);

        adapter.setBridgeChainId(OTHER_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);

        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), SPOKE_HYPERLANE_DOMAIN);
        assertEq(adapter.getChainId(SPOKE_HYPERLANE_DOMAIN), OTHER_CHAIN_ID);
        // Old internal chain is now orphaned and its peer cleared.
        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), 0);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
    }

    function test_setBridgeChainId_reassignsInternalChainToNewBridgeChain() external {
        // Repoint SPOKE_CHAIN_ID from SPOKE_HYPERLANE_DOMAIN to OTHER_HYPERLANE_DOMAIN.
        // The old (SPOKE_HYPERLANE_DOMAIN -> SPOKE_CHAIN_ID) reverse mapping must be removed and
        // logged, and the reassigned chain's peer must be cleared.
        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(SPOKE_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        adapter.setBridgeChainId(SPOKE_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), OTHER_HYPERLANE_DOMAIN);
        assertEq(adapter.getChainId(OTHER_HYPERLANE_DOMAIN), SPOKE_CHAIN_ID);
        // Old bridge chain is now orphaned; the repointed chain's peer must be re-asserted.
        assertEq(adapter.getChainId(SPOKE_HYPERLANE_DOMAIN), 0);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
    }

    function test_setBridgeChainId_reassignsBothSides() external {
        // Pre-configure a second pair (with a peer) so both cleanup branches fire.
        bytes32 otherPeer = makeAddr("otherAdapter").toBytes32();

        vm.startPrank(operator);
        adapter.setPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);
        vm.stopPrank();

        // Now call setBridgeChainId(SPOKE_CHAIN_ID, OTHER_HYPERLANE_DOMAIN):
        //  - Forward cleanup: OTHER_HYPERLANE_DOMAIN was mapped to OTHER_CHAIN_ID
        //    -> remove (OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN).
        //  - Reverse cleanup: SPOKE_CHAIN_ID was mapped to SPOKE_HYPERLANE_DOMAIN
        //    -> remove (SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN).
        // Both affected chains lose their peers.
        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(OTHER_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(SPOKE_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        adapter.setBridgeChainId(SPOKE_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);

        // Final state: only (SPOKE_CHAIN_ID <-> OTHER_HYPERLANE_DOMAIN) is mapped, with no peers.
        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), OTHER_HYPERLANE_DOMAIN);
        assertEq(adapter.getChainId(OTHER_HYPERLANE_DOMAIN), SPOKE_CHAIN_ID);
        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), 0);
        assertEq(adapter.getChainId(SPOKE_HYPERLANE_DOMAIN), 0);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getPeer(OTHER_CHAIN_ID), bytes32(0));
    }

    function test_setBridgeChainId_revertsIfCalledByNonOperator() external {
        vm.expectRevert();

        vm.prank(user);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_HYPERLANE_DOMAIN);
    }

    function test_setBridgeChainId_revertsIfZeroChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(0, OTHER_HYPERLANE_DOMAIN);
    }

    function test_setBridgeChainId_revertsIfZeroBridgeChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroBridgeChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, 0);
    }
}
