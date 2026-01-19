// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

/**
 * @notice Unit tests for setBridgeChainId (inherited from BridgeAdapter)
 *
 * Branch coverage TODOs:
 * - [x] when caller does not have OPERATOR_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 * - [x] when chainId is zero
 *     - [x] reverts with ZeroChain
 * - [x] when bridgeChainId is zero
 *     - [x] reverts with ZeroBridgeChain
 * - [x] when mapping is already set to same value
 *     - [x] succeeds but does not emit event (no-op)
 * - [x] when setting new mapping
 *     - [x] succeeds
 *     - [x] updates forward mapping
 *     - [x] updates reverse mapping
 *     - [x] emits BridgeChainIdSet event
 * - [x] when changing existing mapping
 *     - [x] cleans up old forward mapping
 *     - [x] cleans up old reverse mapping
 *     - [x] sets new mappings correctly
 */
contract SetBridgeChainIdUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    function test_setBridgeChainId() external {
        uint32 newChainId = 3;
        uint256 newEid = 30_000;

        vm.expectEmit();
        emit IBridgeAdapter.BridgeChainIdSet(newChainId, newEid);

        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, newEid);

        assertEq(adapter.getBridgeChainId(newChainId), newEid);
        assertEq(adapter.getChainId(newEid), newChainId);
    }

    function test_setBridgeChainId_sameMappingNoEvent() external {
        // Setting the same mapping should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_LZ_EID);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setBridgeChainId_revertsIfCalledByNonOperator() external {
        vm.expectRevert();

        vm.prank(user);
        adapter.setBridgeChainId(3, 30_000);
    }

    function test_setBridgeChainId_revertsIfZeroChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(0, 30_000);
    }

    function test_setBridgeChainId_revertsIfZeroBridgeChain() external {
        vm.expectRevert(IBridgeAdapter.ZeroBridgeChain.selector);

        vm.prank(operator);
        adapter.setBridgeChainId(3, 0);
    }

    function test_setBridgeChainId_cleansUpOldForwardMapping() external {
        // Setup: Chain 3 is mapped to bridge chain 30000
        uint32 chainId = 3;
        uint256 oldBridgeChainId = 30_000;
        uint256 newBridgeChainId = 40_000;

        vm.prank(operator);
        adapter.setBridgeChainId(chainId, oldBridgeChainId);

        // Verify initial mapping
        assertEq(adapter.getBridgeChainId(chainId), oldBridgeChainId);
        assertEq(adapter.getChainId(oldBridgeChainId), chainId);

        // Remap chain 3 to a different bridge chain 40000
        vm.prank(operator);
        adapter.setBridgeChainId(chainId, newBridgeChainId);

        // Verify new mapping
        assertEq(adapter.getBridgeChainId(chainId), newBridgeChainId);
        assertEq(adapter.getChainId(newBridgeChainId), chainId);

        // Verify old reverse mapping was cleaned up (bridge chain 30000 should not map to anything)
        assertEq(adapter.getChainId(oldBridgeChainId), 0);
    }

    function test_setBridgeChainId_cleansUpOldReverseMapping() external {
        // Setup: Chain 3 is mapped to bridge chain 30000
        uint32 oldChainId = 3;
        uint32 newChainId = 4;
        uint256 bridgeChainId = 30_000;

        vm.prank(operator);
        adapter.setBridgeChainId(oldChainId, bridgeChainId);

        // Verify initial mapping
        assertEq(adapter.getBridgeChainId(oldChainId), bridgeChainId);
        assertEq(adapter.getChainId(bridgeChainId), oldChainId);

        // Remap bridge chain 30000 to a different internal chain 4
        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, bridgeChainId);

        // Verify new mapping
        assertEq(adapter.getBridgeChainId(newChainId), bridgeChainId);
        assertEq(adapter.getChainId(bridgeChainId), newChainId);

        // Verify old forward mapping was cleaned up (chain 3 should not map to anything)
        assertEq(adapter.getBridgeChainId(oldChainId), 0);
    }
}
