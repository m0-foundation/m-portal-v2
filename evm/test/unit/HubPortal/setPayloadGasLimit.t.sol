// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SetPayloadGasLimitUnitTest is HubPortalUnitTestBase {
    function test_setPayloadGasLimit() external {
        uint256 newGasLimit = 300_000;
        vm.prank(operator);
        vm.expectEmit();
        emit IPortal.PayloadGasLimitSet(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, newGasLimit);

        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, newGasLimit);

        assertEq(hubPortal.payloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer), newGasLimit);
    }

    function test_setPayloadGasLimit_revertsIfCalledByNonOperator() external {
        uint256 newGasLimit = 300_000;

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, admin, hubPortal.OPERATOR_ROLE()));
        vm.prank(admin);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, newGasLimit);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));
        vm.prank(user);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, newGasLimit);
    }

    function test_setPayloadGasLimit_revertsIfInvalidDestinationChain() external {
        uint256 gasLimit = 100_000;

        vm.expectRevert(abi.encodeWithSelector(IPortal.InvalidDestinationChain.selector, HUB_CHAIN_ID));
        vm.prank(operator);
        hubPortal.setPayloadGasLimit(HUB_CHAIN_ID, PayloadType.TokenTransfer, gasLimit);
    }

    function test_setPayloadGasLimit_revertsIfZeroGasLimit() external {
        vm.expectRevert(IPortal.ZeroPayloadGasLimit.selector);
        vm.prank(operator);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, 0);
    }
}
