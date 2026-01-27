// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SetDefaultBridgeAdapterUnitTest is HubPortalUnitTestBase {
    address internal newBridgeAdapter = makeAddr("newBridgeAdapter");

    function test_setDefaultBridgeAdapter() external {
        vm.prank(operator);

        vm.expectEmit();
        emit IPortal.DefaultBridgeAdapterSet(SPOKE_CHAIN_ID, newBridgeAdapter);

        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);

        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), newBridgeAdapter);
    }

    function test_setDefaultBridgeAdapter_addsToSupportedAdaptersIfNotPresent() external {
        vm.prank(operator);

        vm.expectEmit();
        emit IPortal.SupportedBridgeAdapterSet(SPOKE_CHAIN_ID, newBridgeAdapter, true);

        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);

        assertTrue(hubPortal.supportedBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter));
    }

    function test_setDefaultBridgeAdapter_revertsIfCalledByNonOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, hubPortal.OPERATOR_ROLE()));
        vm.prank(admin);
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));
        vm.prank(user);
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);
    }

    function test_setDefaultBridgeAdapter_revertsIfInvalidDestinationChain() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidDestinationChain.selector, HUB_CHAIN_ID));
        vm.prank(operator);
        hubPortal.setDefaultBridgeAdapter(HUB_CHAIN_ID, newBridgeAdapter);
    }

    function test_setDefaultBridgeAdapter_revertsIfZeroBridgeAdapter() external {
        vm.expectRevert(IPortal.ZeroBridgeAdapter.selector);
        vm.prank(operator);
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, address(0));
    }
}
