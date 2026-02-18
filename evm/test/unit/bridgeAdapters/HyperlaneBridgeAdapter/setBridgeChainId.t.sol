// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract SetBridgeChainIdUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    function test_setBridgeChainId() external {
        uint32 newChainId = 3;
        uint256 newDomain = 3000;

        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(newChainId, newDomain);

        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, newDomain);

        assertEq(adapter.getBridgeChainId(newChainId), newDomain);
        assertEq(adapter.getChainId(newDomain), newChainId);
    }

    function test_setBridgeChainId_sameMappingNoEvent() external {
        // Setting the same mapping should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);

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

    function test_setBridgeChainId_cleansUpOldForwardMapping() external {
        // Setup: Chain 3 is mapped to bridge chain 3000
        uint32 chainId = 3;
        uint256 oldBridgeChainId = 3000;
        uint256 newBridgeChainId = 4000;

        vm.prank(operator);
        adapter.setBridgeChainId(chainId, oldBridgeChainId);

        // Verify initial mapping
        assertEq(adapter.getBridgeChainId(chainId), oldBridgeChainId);
        assertEq(adapter.getChainId(oldBridgeChainId), chainId);

        // Remap chain 3 to a different bridge chain 4000
        vm.prank(operator);
        adapter.setBridgeChainId(chainId, newBridgeChainId);

        // Verify new mapping
        assertEq(adapter.getBridgeChainId(chainId), newBridgeChainId);
        assertEq(adapter.getChainId(newBridgeChainId), chainId);

        // Verify old reverse mapping was cleaned up (bridge chain 3000 should not map to anything)
        assertEq(adapter.getChainId(oldBridgeChainId), 0);
    }

    function test_setBridgeChainId_cleansUpOldReverseMapping() external {
        // Setup: Chain 3 is mapped to bridge chain 3000
        uint32 oldChainId = 3;
        uint32 newChainId = 4;
        uint256 bridgeChainId = 3000;

        vm.prank(operator);
        adapter.setBridgeChainId(oldChainId, bridgeChainId);

        // Verify initial mapping
        assertEq(adapter.getBridgeChainId(oldChainId), bridgeChainId);
        assertEq(adapter.getChainId(bridgeChainId), oldChainId);

        // Remap bridge chain 3000 to a different internal chain 4
        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, bridgeChainId);

        // Verify new mapping
        assertEq(adapter.getBridgeChainId(newChainId), bridgeChainId);
        assertEq(adapter.getChainId(bridgeChainId), newChainId);

        // Verify old forward mapping was cleaned up (chain 3 should not map to anything)
        assertEq(adapter.getBridgeChainId(oldChainId), 0);
    }
}
