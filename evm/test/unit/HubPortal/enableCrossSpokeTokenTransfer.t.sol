// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract EnableCrossSpokeTokenTransferUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = makeAddr("recipient").toBytes32();
    uint256 internal amount = 10e6;

    function setUp() public override {
        super.setUp();

        // Mint tokens to user for testing
        mToken.mint(user, 100e6);
    }

    // ==================== POSITIVE TESTS ====================

    function test_enableCrossSpokeTokenTransfer_success() external {
        assertFalse(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));

        vm.expectEmit();
        emit IHubPortal.CrossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID, 0);

        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_enableCrossSpokeTokenTransfer_emitsEventWithPrincipal() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        // Bridge tokens to spoke to accumulate principal
        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        uint248 bridgedPrincipal = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);
        assertTrue(bridgedPrincipal > 0);

        vm.expectEmit();
        emit IHubPortal.CrossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID, bridgedPrincipal);

        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_enableCrossSpokeTokenTransfer_idempotent() external {
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));

        // Second call should return early without emitting event
        vm.recordLogs();
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        // Should still be enabled
        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));

        // No event should be emitted on second call
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_enableCrossSpokeTokenTransfer_multipleSpokes() external {
        // Enable for spoke 1
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));
        assertFalse(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID_2));

        // Enable for spoke 2
        vm.expectEmit();
        emit IHubPortal.CrossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID_2, 0);

        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID_2);

        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID));
        assertTrue(hubPortal.crossSpokeTokenTransferEnabled(SPOKE_CHAIN_ID_2));
    }

    // ==================== NEGATIVE TESTS ====================

    function testFuzz_enableCrossSpokeTokenTransfer_revertsIfNotOperator(address caller) external {
        vm.assume(caller != operator);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, hubPortal.OPERATOR_ROLE()));

        vm.prank(caller);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);
    }
}
