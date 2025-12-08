// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ERC1967Proxy
} from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { WormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract InitializeUnitTest is WormholeBridgeAdapterUnitTestBase {
    function test_initialize_initialState() external view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), operator));
    }

    function test_initialize_cannotReinitialize() external {
        vm.expectRevert();
        adapter.initialize(admin, operator);
    }

    function test_initialize_zeroAdmin() external {
        WormholeBridgeAdapter newImplementation =
            new WormholeBridgeAdapter(address(coreBridge), address(executor), CONSISTENCY_LEVEL, HUB_WORMHOLE_CHAIN_ID, address(portal));

        bytes memory initializeData = abi.encodeCall(WormholeBridgeAdapter.initialize, (address(0), operator));

        vm.expectRevert(IBridgeAdapter.ZeroAdmin.selector);
        new ERC1967Proxy(address(newImplementation), initializeData);
    }

    function test_initialize_zeroOperator() external {
        WormholeBridgeAdapter newImplementation =
            new WormholeBridgeAdapter(address(coreBridge), address(executor), CONSISTENCY_LEVEL, HUB_WORMHOLE_CHAIN_ID, address(portal));

        bytes memory initializeData = abi.encodeCall(WormholeBridgeAdapter.initialize, (admin, address(0)));

        vm.expectRevert(IBridgeAdapter.ZeroOperator.selector);
        new ERC1967Proxy(address(newImplementation), initializeData);
    }
}
