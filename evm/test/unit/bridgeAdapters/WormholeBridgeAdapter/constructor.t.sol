// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { WormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract ConstructorUnitTest is WormholeBridgeAdapterUnitTestBase {
    function test_constructor_initialState() external view {
        assertEq(implementation.portal(), address(portal));
        assertEq(implementation.coreBridge(), address(coreBridge));
        assertEq(implementation.executor(), address(executor));
        assertEq(implementation.consistencyLevel(), CONSISTENCY_LEVEL);
        assertEq(implementation.currentWormholeChainId(), HUB_WORMHOLE_CHAIN_ID);
    }

    function test_constructor_zeroPortal() external {
        vm.expectRevert(IBridgeAdapter.ZeroPortal.selector);
        new WormholeBridgeAdapter(address(coreBridge), address(executor), CONSISTENCY_LEVEL, address(0));
    }

    function test_constructor_zeroCoreBridge() external {
        vm.expectRevert(IWormholeBridgeAdapter.ZeroCoreBridge.selector);
        new WormholeBridgeAdapter(address(0), address(executor), CONSISTENCY_LEVEL, address(portal));
    }

    function test_constructor_zeroExecutor() external {
        vm.expectRevert(IWormholeBridgeAdapter.ZeroExecutor.selector);
        new WormholeBridgeAdapter(address(coreBridge), address(0), CONSISTENCY_LEVEL, address(portal));
    }
}
