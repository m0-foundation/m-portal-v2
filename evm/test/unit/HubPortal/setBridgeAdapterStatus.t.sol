// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Vm } from "forge-std/Vm.sol";

import { BridgeAdapterStatus, IPortal } from "../../../src/interfaces/IPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SetBridgeAdapterStatusUnitTest is HubPortalUnitTestBase {
    address internal newBridgeAdapter = makeAddr("newBridgeAdapter");

    function test_setBridgeAdapterStatus_setsAsEnabled() external {
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.BridgeAdapterStatusSet(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        assertEq(uint8(hubPortal.bridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter)), uint8(BridgeAdapterStatus.Enabled));
    }

    function test_setBridgeAdapterStatus_setsAsReceiveOnly() external {
        // First enable the adapter
        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        // Then set to ReceiveOnly
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.BridgeAdapterStatusSet(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);

        assertEq(uint8(hubPortal.bridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter)), uint8(BridgeAdapterStatus.ReceiveOnly));
    }

    function test_setBridgeAdapterStatus_setsAsDisabled() external {
        // First enable the adapter
        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        // Then disable it
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.BridgeAdapterStatusSet(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Disabled);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Disabled);

        assertEq(uint8(hubPortal.bridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter)), uint8(BridgeAdapterStatus.Disabled));
    }

    function test_setBridgeAdapterStatus_clearsDefaultWhenSetToReceiveOnly() external {
        vm.startPrank(operator);

        // Set adapter as default (this also enables it)
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), newBridgeAdapter);

        // Set to ReceiveOnly - should clear default
        vm.expectEmit();
        emit IPortal.DefaultBridgeAdapterSet(SPOKE_CHAIN_ID, address(0));
        vm.expectEmit();
        emit IPortal.BridgeAdapterStatusSet(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);

        // Default should be cleared
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), address(0));

        vm.stopPrank();
    }

    function test_setBridgeAdapterStatus_clearsDefaultWhenSetToDisabled() external {
        vm.startPrank(operator);

        // Set adapter as default (this also enables it)
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, newBridgeAdapter);
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), newBridgeAdapter);

        // Set to Disabled - should clear default
        vm.expectEmit();
        emit IPortal.DefaultBridgeAdapterSet(SPOKE_CHAIN_ID, address(0));
        vm.expectEmit();
        emit IPortal.BridgeAdapterStatusSet(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Disabled);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Disabled);

        // Default should be cleared
        assertEq(hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID), address(0));

        vm.stopPrank();
    }

    function test_setBridgeAdapterStatus_receiveOnlyBlocksSend() external {
        vm.startPrank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);
        vm.stopPrank();

        // Trying to quote with ReceiveOnly adapter should fail
        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, SPOKE_CHAIN_ID, newBridgeAdapter));
        hubPortal.quote(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, newBridgeAdapter);
    }

    function test_setBridgeAdapterStatus_receiveOnlyAllowsReceive() external {
        vm.startPrank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.ReceiveOnly);
        vm.stopPrank();

        // The adapter should be ReceiveOnly status (allowed for receiving)
        assertEq(uint8(hubPortal.bridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter)), uint8(BridgeAdapterStatus.ReceiveOnly));
    }

    function test_setBridgeAdapterStatus_revertsIfCalledByNonOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, hubPortal.OPERATOR_ROLE()));
        vm.prank(admin);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));
        vm.prank(user);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);
    }

    function test_setBridgeAdapterStatus_revertsIfInvalidDestinationChain() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidDestinationChain.selector, HUB_CHAIN_ID));
        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(HUB_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);
    }

    function test_setBridgeAdapterStatus_revertsIfZeroBridgeAdapter() external {
        vm.expectRevert(IPortal.ZeroBridgeAdapter.selector);
        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, address(0), BridgeAdapterStatus.Enabled);
    }

    function test_setBridgeAdapterStatus_noEventIfSameStatus() external {
        vm.startPrank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        // Setting same status should not emit event (function returns early)
        vm.recordLogs();
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, newBridgeAdapter, BridgeAdapterStatus.Enabled);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0);

        vm.stopPrank();
    }
}
