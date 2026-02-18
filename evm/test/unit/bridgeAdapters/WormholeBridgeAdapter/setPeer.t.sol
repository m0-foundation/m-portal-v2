// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SetPeerUnitTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_setPeer() external {
        uint32 newChainId = 3;
        bytes32 newPeer = makeAddr("newPeer").toBytes32();

        vm.expectEmit();
        emit IBridgeAdapter.PeerSet(newChainId, newPeer);

        vm.prank(operator);
        adapter.setPeer(newChainId, newPeer);

        assertEq(adapter.getPeer(newChainId), newPeer);
    }

    function test_setPeer_zeroAddress() external {
        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, bytes32(0));

        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), bytes32(0));
    }

    function test_setPeer_samePeerNoEvent() external {
        // Setting the same peer should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, peerAdapterAddress);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setPeer_revertsIfCalledByNonOperator() external {
        bytes32 newPeer = makeAddr("newPeer").toBytes32();

        vm.expectRevert();

        vm.prank(user);
        adapter.setPeer(SPOKE_CHAIN_ID, newPeer);
    }

    function test_setPeer_revertsIfZeroChain() external {
        bytes32 newPeer = makeAddr("newPeer").toBytes32();

        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setPeer(0, newPeer);
    }
}
