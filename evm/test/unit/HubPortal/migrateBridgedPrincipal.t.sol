// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract MigrateBridgedPrincipalUnitTest is HubPortalUnitTestBase {
    uint248 internal migratedPrincipal = 1_000_000e6;

    function test_migrateBridgedPrincipal_success() external {
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

    function test_migrateBridgedPrincipal_doNothingWhenCrossSpokeEnabled() external {
        // First enable cross-spoke transfer
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);

        // Attempt to migrate bridged principal - should be no-op
        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);

        // Principal should remain 0
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_migrateBridgedPrincipal_doNothingWhenAlreadyMigrated() external {
        uint248 initialPrincipal = 500_000e6;
        uint248 newPrincipal = 1_000_000e6;

        // First migration
        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, initialPrincipal);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), initialPrincipal);

        // Attempt second migration - should be no-op
        vm.prank(operator);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, newPrincipal);

        // Principal should remain unchanged
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), initialPrincipal);
    }
    
    function test_migrateBridgedPrincipal_revertsIfNotOperator() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, hubPortal.OPERATOR_ROLE()));

        vm.prank(user);
        hubPortal.migrateBridgedPrincipal(SPOKE_CHAIN_ID, migratedPrincipal);
    }
}
