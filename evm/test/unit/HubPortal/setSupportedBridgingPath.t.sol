// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SetSupportedBridgingPathUnitTest is HubPortalUnitTestBase {
    address internal sourceToken = makeAddr("sourceToken");
    bytes32 internal destinationToken = bytes32(uint256(1));

    function test_setSupportedBridgingPath_setsAsSupported() external {
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.SupportedBridgingPathSet(sourceToken, SPOKE_CHAIN_ID, destinationToken, true);

        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken, true);

        assertTrue(hubPortal.supportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken));
    }

    function test_setSupportedBridgingPath_setsAsUnsupported() external {
        // First add as supported
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken, true);

        // Then remove support
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.SupportedBridgingPathSet(sourceToken, SPOKE_CHAIN_ID, destinationToken, false);

        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken, false);

        assertFalse(hubPortal.supportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken));
    }

    function test_setSupportedBridgingPath_revertsIfCalledByNonOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, hubPortal.OPERATOR_ROLE()));
        vm.prank(admin);
        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken, true);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));
        vm.prank(user);
        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, destinationToken, true);
    }

    function test_setSupportedBridgingPath_revertsIfInvalidDestinationChain() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidDestinationChain.selector, HUB_CHAIN_ID));
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(sourceToken, HUB_CHAIN_ID, destinationToken, true);
    }

    function test_setSupportedBridgingPath_revertsIfZeroSourceToken() external {
        vm.expectRevert(IPortal.ZeroSourceToken.selector);
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(address(0), SPOKE_CHAIN_ID, destinationToken, true);
    }

    function test_setSupportedBridgingPath_revertsIfZeroDestinationToken() external {
        vm.expectRevert(IPortal.ZeroDestinationToken.selector);
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(sourceToken, SPOKE_CHAIN_ID, bytes32(0), true);
    }
}
