// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SetSenderPeerUnitTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_setSenderPeer() external {
        uint32 newChainId = 3;
        bytes32 newSenderPeer = makeAddr("newSenderPeer").toBytes32();

        vm.expectEmit();
        emit IWormholeBridgeAdapter.SenderPeerSet(newChainId, newSenderPeer);

        vm.prank(operator);
        adapter.setSenderPeer(newChainId, newSenderPeer);

        assertEq(adapter.getSenderPeer(newChainId), newSenderPeer);
    }

    function test_setSenderPeer_samePeerNoEvent() external {
        uint32 chainId = 3;
        bytes32 senderPeer = makeAddr("senderPeer").toBytes32();

        // First set the sender peer
        vm.prank(operator);
        adapter.setSenderPeer(chainId, senderPeer);

        // Setting the same peer should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setSenderPeer(chainId, senderPeer);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setSenderPeer_revertsIfCalledByNonOperator() external {
        bytes32 newSenderPeer = makeAddr("newSenderPeer").toBytes32();

        vm.expectRevert();

        vm.prank(user);
        adapter.setSenderPeer(SPOKE_CHAIN_ID, newSenderPeer);
    }

    function test_setSenderPeer_revertsIfZeroChain() external {
        bytes32 newSenderPeer = makeAddr("newSenderPeer").toBytes32();

        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setSenderPeer(0, newSenderPeer);
    }

    function test_setSenderPeer_revertsIfZeroPeer() external {
        vm.expectRevert(IBridgeAdapter.ZeroPeer.selector);

        vm.prank(operator);
        adapter.setSenderPeer(SPOKE_CHAIN_ID, bytes32(0));
    }
}
