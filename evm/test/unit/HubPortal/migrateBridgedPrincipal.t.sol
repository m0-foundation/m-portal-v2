// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract MigrateBridgedPrincipalUnitTest is HubPortalUnitTestBase {
    uint248 internal migratedPrincipal = 1_000_000e6;

    function test_migrateBridgedPrincipal_success() external {
        assertTrue(hubPortal.migrating());
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);

        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), migratedPrincipal);
    }

    function testFuzz_migrateBridgedPrincipal_setsCorrectPrincipal(uint248 principal) external {
        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, principal);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), principal);
    }

    function test_migrateBridgedPrincipal_multipleSpokes() external {
        uint248 principal1 = 500_000e6;
        uint248 principal2 = 750_000e6;

        vm.startPrank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, principal1);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID_2, principal2);
        vm.stopPrank();

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), principal1);
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID_2), principal2);
    }

    function test_migrateBridgedPrincipal_withZeroPrincipal() external {
        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, 0);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_migrateBridgedPrincipal_revertsWhenNotMigrating() external {
        // Complete migration first
        vm.prank(operator);
        hubPortal.completeMigration();

        assertFalse(hubPortal.migrating());

        vm.expectRevert(IHubPortal.NotMigrating.selector);

        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);
    }

    function test_migrateBridgedPrincipal_revertsWhenSpokeAlreadyConnected() external {
        // First enable cross-spoke transfer
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));

        vm.expectRevert(abi.encodeWithSelector(IHubPortal.ConnectedSpoke.selector, SPOKE_CHAIN_ID));

        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);
    }

    function test_migrateBridgedPrincipal_revertsIfNotOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));

        vm.prank(user);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);
    }
}
