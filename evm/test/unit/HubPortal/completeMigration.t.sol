// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract CompleteMigrationUnitTest is HubPortalUnitTestBase {
    function test_completeMigration_success() external {
        assertTrue(hubPortal.migrating());

        vm.expectEmit();
        emit IHubPortal.MigrationCompleted();

        vm.prank(operator);
        hubPortal.completeMigration();

        assertFalse(hubPortal.migrating());
    }

    function test_completeMigration_alreadyCompleteNoAction() external {
        // Complete migration first
        vm.prank(operator);
        hubPortal.completeMigration();

        assertFalse(hubPortal.migrating());

        vm.prank(operator);
        hubPortal.completeMigration();

        assertFalse(hubPortal.migrating());
    }

    function test_completeMigration_revertsIfNotOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));

        vm.prank(user);
        hubPortal.completeMigration();
    }
}
