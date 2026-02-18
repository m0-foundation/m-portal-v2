// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SetBridgeChainIdUnitTest is WormholeBridgeAdapterUnitTestBase {
    function test_setBridgeChainId() external {
        uint32 newChainId = 3;
        uint256 newWormholeChainId = 3000;

        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(newChainId, newWormholeChainId);

        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, newWormholeChainId);

        assertEq(adapter.getBridgeChainId(newChainId), newWormholeChainId);
        assertEq(adapter.getChainId(newWormholeChainId), newChainId);
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
