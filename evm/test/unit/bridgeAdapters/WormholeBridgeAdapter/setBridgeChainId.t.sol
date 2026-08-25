// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SetBridgeChainIdUnitTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for address;

    uint32 internal constant OTHER_CHAIN_ID = 3;
    uint256 internal constant OTHER_WORMHOLE_CHAIN_ID = 3000;
    uint128 internal constant SPOKE_MSG_VALUE = 1_000_000;

    function test_setBridgeChainId() external {
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(OTHER_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        vm.prank(operator);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), OTHER_WORMHOLE_CHAIN_ID);
        assertEq(adapter.getChainId(OTHER_WORMHOLE_CHAIN_ID), OTHER_CHAIN_ID);
    }

    function test_setBridgeChainId_keepsChainConfigOnFreshAssignment() external {
        // Setting a Wormhole chain ID for a chain for the first time must not clear
        // the chain's peer, sender peer, or msg value.
        bytes32 otherPeer = makeAddr("otherAdapter").toBytes32();

        vm.startPrank(operator);
        adapter.setPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setSenderPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setMsgValue(OTHER_CHAIN_ID, SPOKE_MSG_VALUE);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);
        vm.stopPrank();

        assertEq(adapter.getPeer(OTHER_CHAIN_ID), otherPeer);
        assertEq(adapter.getSenderPeer(OTHER_CHAIN_ID), otherPeer);
        assertEq(adapter.getMsgValue(OTHER_CHAIN_ID), SPOKE_MSG_VALUE);
        assertEq(adapter.getSenderPeer(SPOKE_CHAIN_ID), peerAdapterAddress);
    }

    function test_setBridgeChainId_reassignsBridgeChainToNewInternalChain_clearsChainConfig() external {
        // Reassign SPOKE_WORMHOLE_CHAIN_ID from SPOKE_CHAIN_ID to OTHER_CHAIN_ID.
        // The orphaned chain must lose its peer, sender peer, and msg value, so a stale
        // sender peer can never authenticate inbound VAAs under a reassigned chain ID.
        vm.prank(operator);
        adapter.setMsgValue(SPOKE_CHAIN_ID, SPOKE_MSG_VALUE);

        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IWormholeBridgeAdapter.SenderPeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IWormholeBridgeAdapter.MsgValueSet(SPOKE_CHAIN_ID, 0);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(OTHER_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);

        adapter.setBridgeChainId(OTHER_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);

        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), SPOKE_WORMHOLE_CHAIN_ID);
        assertEq(adapter.getChainId(SPOKE_WORMHOLE_CHAIN_ID), OTHER_CHAIN_ID);
        // Old internal chain is orphaned with all chain-coupled configuration cleared.
        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), 0);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getSenderPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getMsgValue(SPOKE_CHAIN_ID), 0);
    }

    function test_setBridgeChainId_reassignsInternalChainToNewBridgeChain_clearsChainConfig() external {
        // Repoint SPOKE_CHAIN_ID from SPOKE_WORMHOLE_CHAIN_ID to OTHER_WORMHOLE_CHAIN_ID.
        // The reassigned chain must lose its peer, sender peer, and msg value.
        vm.prank(operator);
        adapter.setMsgValue(SPOKE_CHAIN_ID, SPOKE_MSG_VALUE);

        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);
        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IWormholeBridgeAdapter.SenderPeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IWormholeBridgeAdapter.MsgValueSet(SPOKE_CHAIN_ID, 0);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(SPOKE_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        adapter.setBridgeChainId(SPOKE_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), OTHER_WORMHOLE_CHAIN_ID);
        assertEq(adapter.getChainId(OTHER_WORMHOLE_CHAIN_ID), SPOKE_CHAIN_ID);
        // Old Wormhole chain is orphaned; the repointed chain's configuration must be re-asserted.
        assertEq(adapter.getChainId(SPOKE_WORMHOLE_CHAIN_ID), 0);
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getSenderPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getMsgValue(SPOKE_CHAIN_ID), 0);
    }

    function test_setBridgeChainId_reassignsBothSides_clearsChainConfig() external {
        // Pre-configure a second pair with full chain-coupled configuration
        // so both cleanup branches fire.
        bytes32 otherPeer = makeAddr("otherAdapter").toBytes32();

        vm.startPrank(operator);
        adapter.setPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setSenderPeer(OTHER_CHAIN_ID, otherPeer);
        adapter.setBridgeChainId(OTHER_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);
        vm.stopPrank();

        // setBridgeChainId(SPOKE_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID) removes both existing pairs;
        // both affected chains lose their sender peers.
        vm.prank(operator);
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(OTHER_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);
        vm.expectEmit();
        emit IWormholeBridgeAdapter.SenderPeerSet(OTHER_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdRemoved(SPOKE_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);
        vm.expectEmit();
        emit IWormholeBridgeAdapter.SenderPeerSet(SPOKE_CHAIN_ID, bytes32(0));
        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(SPOKE_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        adapter.setBridgeChainId(SPOKE_CHAIN_ID, OTHER_WORMHOLE_CHAIN_ID);

        // Final state: only (SPOKE_CHAIN_ID <-> OTHER_WORMHOLE_CHAIN_ID) is mapped, no peers remain.
        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), OTHER_WORMHOLE_CHAIN_ID);
        assertEq(adapter.getChainId(OTHER_WORMHOLE_CHAIN_ID), SPOKE_CHAIN_ID);
        assertEq(adapter.getBridgeChainId(OTHER_CHAIN_ID), 0);
        assertEq(adapter.getChainId(SPOKE_WORMHOLE_CHAIN_ID), 0);
        assertEq(adapter.getSenderPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getSenderPeer(OTHER_CHAIN_ID), bytes32(0));
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
        assertEq(adapter.getPeer(OTHER_CHAIN_ID), bytes32(0));
    }

    function test_setBridgeChainId_sameMappingNoEvent() external {
        // Setting the same mapping should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setBridgeChainId_revertsIfCalledByNonOperator() external {
        vm.expectRevert();

        vm.prank(user);
        adapter.setBridgeChainId(3, 3000);
    }

    function test_setBridgeChainId_revertsIfZeroChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(0, 3000);
    }

    function test_setBridgeChainId_revertsIfZeroBridgeChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroBridgeChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(3, 0);
    }
}
