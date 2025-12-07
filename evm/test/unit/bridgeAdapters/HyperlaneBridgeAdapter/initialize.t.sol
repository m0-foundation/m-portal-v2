// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC1967Proxy } from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessControlUpgradeable } from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import { HyperlaneBridge } from "../../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract InitializeUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    function test_initialize_initialState() external view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), operator));
    }

    function test_initialize_cannotReinitialize() external {
        vm.expectRevert();
        adapter.initialize(admin, operator);
    }

    function test_initialize_zeroAdmin() external {
        HyperlaneBridge newImplementationSPOKE_CHAIN_ID = new HyperlaneBridge(address(mailbox), address(portal));

        bytes memory initializeData = abi.encodeCall(HyperlaneBridge.initialize, (address(0), operator));

        vm.expectRevert(IBridgeAdapter.ZeroAdmin.selector);
        new ERC1967Proxy(address(newImplementationSPOKE_CHAIN_ID), initializeData);
    }

    function test_initialize_zeroOperator() external {
        HyperlaneBridge newImplementationSPOKE_CHAIN_ID = new HyperlaneBridge(address(mailbox), address(portal));

        bytes memory initializeData = abi.encodeCall(HyperlaneBridge.initialize, (admin, address(0)));

        vm.expectRevert(IBridgeAdapter.ZeroOperator.selector);
        new ERC1967Proxy(address(newImplementationSPOKE_CHAIN_ID), initializeData);
    }
}
