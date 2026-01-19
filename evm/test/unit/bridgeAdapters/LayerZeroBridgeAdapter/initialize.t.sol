// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import {
    ERC1967Proxy
} from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { LayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/LayerZeroBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

/**
 * @notice Unit tests for initialize
 *
 * Branch coverage TODOs:
 * - [x] when admin is zero address
 *     - [x] reverts with ZeroAdmin
 * - [x] when operator is zero address
 *     - [x] reverts with ZeroOperator
 * - [x] when both addresses are valid
 *     - [x] succeeds
 *     - [x] grants DEFAULT_ADMIN_ROLE to admin
 *     - [x] grants OPERATOR_ROLE to operator
 * - [x] when called twice
 *     - [x] reverts (already initialized)
 *
 * Upgrade authorization TODOs:
 * - [x] when caller has DEFAULT_ADMIN_ROLE
 *     - [x] upgrade succeeds
 * - [x] when caller does not have DEFAULT_ADMIN_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 */
contract InitializeUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    function test_initialize_initialState() external view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), operator));
    }

    function test_initialize_cannotReinitialize() external {
        vm.expectRevert();
        adapter.initialize(admin, operator);
    }

    function test_initialize_zeroAdmin() external {
        LayerZeroBridgeAdapter newImplementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        bytes memory initializeData = abi.encodeCall(LayerZeroBridgeAdapter.initialize, (address(0), operator));

        vm.expectRevert(IBridgeAdapter.ZeroAdmin.selector);
        new ERC1967Proxy(address(newImplementation), initializeData);
    }

    function test_initialize_zeroOperator() external {
        LayerZeroBridgeAdapter newImplementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        bytes memory initializeData = abi.encodeCall(LayerZeroBridgeAdapter.initialize, (admin, address(0)));

        vm.expectRevert(IBridgeAdapter.ZeroOperator.selector);
        new ERC1967Proxy(address(newImplementation), initializeData);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      UPGRADE AUTHORIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function test_upgrade_succeeds_whenCallerHasAdminRole() external {
        // Deploy a new implementation
        LayerZeroBridgeAdapter newImplementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        // Admin should be able to upgrade
        vm.prank(admin);
        adapter.upgradeToAndCall(address(newImplementation), "");
    }

    function test_upgrade_revertsIfCallerIsOperator() external {
        // Deploy a new implementation
        LayerZeroBridgeAdapter newImplementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        // Operator should not be able to upgrade
        vm.prank(operator);
        vm.expectRevert();
        adapter.upgradeToAndCall(address(newImplementation), "");
    }

    function test_upgrade_revertsIfCallerIsUser() external {
        // Deploy a new implementation
        LayerZeroBridgeAdapter newImplementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        // Regular user should not be able to upgrade
        vm.prank(user);
        vm.expectRevert();
        adapter.upgradeToAndCall(address(newImplementation), "");
    }
}
