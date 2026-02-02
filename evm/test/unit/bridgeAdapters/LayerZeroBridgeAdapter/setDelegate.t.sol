// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ILayerZeroEndpointV2 } from "../../../../src/bridgeAdapters/layerZero/interfaces/ILayerZeroEndpointV2.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract SetDelegateUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    function test_setDelegate() external {
        address newDelegate = makeAddr("newDelegate");

        vm.expectCall(address(lzEndpoint), abi.encodeWithSelector(ILayerZeroEndpointV2.setDelegate.selector, newDelegate));

        vm.prank(operator);
        adapter.setDelegate(newDelegate);
    }

    function test_setDelegate_revertsIfCalledByNonOperator() external {
        address newDelegate = makeAddr("newDelegate");

        vm.expectRevert();

        vm.prank(user);
        adapter.setDelegate(newDelegate);
    }
}
