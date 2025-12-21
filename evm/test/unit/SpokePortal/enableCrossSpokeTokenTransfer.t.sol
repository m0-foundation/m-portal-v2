// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { ISpokePortal } from "../../../src/interfaces/ISpokePortal.sol";

import { SpokePortalUnitTestBase } from "./SpokePortalUnitTestBase.sol";

contract EnableCrossSpokeTokenTransferUnitTest is SpokePortalUnitTestBase {
    // ==================== POSITIVE TESTS ====================

    function test_enableCrossSpokeTokenTransfer_success() external {
        assertFalse(spokePortal.crossSpokeTokenTransferEnabled());

        vm.expectEmit();
        emit ISpokePortal.CrossSpokeTokenTransferEnabled();

        vm.prank(operator);
        spokePortal.enableCrossSpokeTokenTransfer();

        assertTrue(spokePortal.crossSpokeTokenTransferEnabled());
    }

    function test_enableCrossSpokeTokenTransfer_idempotent() external {
        vm.prank(operator);
        spokePortal.enableCrossSpokeTokenTransfer();

        assertTrue(spokePortal.crossSpokeTokenTransferEnabled());

        // Second call should return early without emitting event
        vm.recordLogs();
        vm.prank(operator);
        spokePortal.enableCrossSpokeTokenTransfer();

        // Should still be enabled
        assertTrue(spokePortal.crossSpokeTokenTransferEnabled());

        // No event should be emitted on second call
        assertEq(vm.getRecordedLogs().length, 0);
    }

    // ==================== NEGATIVE TESTS ====================

    function testFuzz_enableCrossSpokeTokenTransfer_revertsIfNotOperator(address caller) external {
        vm.assume(caller != operator);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, spokePortal.OPERATOR_ROLE())
        );

        vm.prank(caller);
        spokePortal.enableCrossSpokeTokenTransfer();
    }
}
