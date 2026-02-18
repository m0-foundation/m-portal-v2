// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SetSupportedBridgeAdapterUnitTest is HubPortalUnitTestBase {
    address internal newBridgeAdapter = makeAddr("newBridgeAdapter");

    function test_setSupportedBridgeAdapter_setsAsSupported() external {
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.SupportedBridgeAdapterSet(SPOKE_CHAIN_ID, newBridgeAdapter, true);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, true);

        assertTrue(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter));
    }

    function test_setSupportedBridgeAdapter_setsAsUnsupported() external {
        // First add as supported
        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, true);

        // Then remove support
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.SupportedBridgeAdapterSet(SPOKE_CHAIN_ID, newBridgeAdapter, false);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, false);

        assertFalse(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter));
    }

    function test_setSupportedBridgeAdapter_revertsIfCalledByNonOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, hubPortal.OPERATOR_ROLE()));
        vm.prank(admin);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, true);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));
        vm.prank(user);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, true);
    }

    function test_setSupportedBridgeAdapter_revertsIfInvalidDestinationChain() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidDestinationChain.selector, HUB_CHAIN_ID));
        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(HUB_CHAIN_ID, newBridgeAdapter, true);
    }

    function test_setSupportedBridgeAdapter_revertsIfZeroBridgeAdapter() external {
        vm.expectRevert(IPortal.ZeroBridgeAdapter.selector);
        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(0), true);
    }

    function test_setSupportedBridgeAdapter_multipleAdaptersPerChain() external {
        address adapter1 = makeAddr("adapter1");
        address adapter2 = makeAddr("adapter2");
        address adapter3 = makeAddr("adapter3");

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, adapter1, true);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, adapter2, true);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, adapter3, true);

        assertTrue(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, adapter1));
        assertTrue(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, adapter2));
        assertTrue(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, adapter3));
    }

    function test_setSupportedBridgeAdapter_clearsDefaultAdapterWhenUnsupported() external {
        // Add the adapter as supported
        vm.startPrank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, true);

        // Set it as the default adapter
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);

        // Verify it's set as default
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), newBridgeAdapter);

        // Set the adapter as unsupported, which clears the default
        vm.expectEmit();
        emit IPortal.DefaultBridgeAdapterSet(SPOKE_CHAIN_ID, address(0));
        vm.expectEmit();
        emit IPortal.SupportedBridgeAdapterSet(SPOKE_CHAIN_ID, newBridgeAdapter, false);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter, false);

        // Verify the adapter is no longer supported
        assertFalse(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter));

        // Verify the default adapter was cleared
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), address(0));
    }
}
