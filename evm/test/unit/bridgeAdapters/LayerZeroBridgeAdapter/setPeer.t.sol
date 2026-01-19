// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

/**
 * @notice Unit tests for setPeer (inherited from BridgeAdapter)
 *
 * Branch coverage TODOs:
 * - [x] when caller does not have OPERATOR_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 * - [x] when chainId is zero
 *     - [x] reverts with ZeroChain
 * - [x] when peer is zero bytes32
 *     - [x] reverts with ZeroPeer
 * - [x] when peer is already set to same value
 *     - [x] succeeds but does not emit event (no-op)
 * - [x] when setting new peer
 *     - [x] succeeds
 *     - [x] updates storage
 *     - [x] emits PeerSet event
 */
contract SetPeerUnitTest is LayerZeroBridgeAdapterUnitTestBase {
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

    function test_setPeer_revertsIfZeroPeer() external {
        vm.expectRevert(IBridgeAdapter.ZeroPeer.selector);

        vm.prank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, bytes32(0));
    }
}
