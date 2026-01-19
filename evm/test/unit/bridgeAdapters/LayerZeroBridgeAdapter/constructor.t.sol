// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for LayerZeroBridgeAdapter constructor
 *
 * Branch coverage TODOs:
 * - [x] when endpoint is zero address
 *     - [x] reverts with ZeroEndpoint
 * - [x] when portal is zero address
 *     - [x] reverts with ZeroPortal (inherited)
 * - [x] when both addresses are valid
 *     - [x] succeeds
 *     - [x] sets endpoint immutable correctly
 *     - [x] sets portal immutable correctly
 */

import { LayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/LayerZeroBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract ConstructorUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    function test_constructor_initialState() external view {
        assertEq(implementation.portal(), address(portal));
        assertEq(implementation.endpoint(), address(lzEndpoint));
    }

    function test_constructor_zeroEndpoint() external {
        vm.expectRevert(ILayerZeroBridgeAdapter.ZeroEndpoint.selector);
        new LayerZeroBridgeAdapter(address(0), address(portal));
    }

    function test_constructor_zeroPortal() external {
        vm.expectRevert(IBridgeAdapter.ZeroPortal.selector);
        new LayerZeroBridgeAdapter(address(lzEndpoint), address(0));
    }
}
