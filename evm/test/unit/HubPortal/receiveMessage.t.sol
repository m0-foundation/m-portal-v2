// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IOrderBookLike } from "../../../src/interfaces/IOrderBookLike.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract ReceiveMessageUnitTest is HubPortalUnitTestBase {
    using TypeConverter for *;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal bridgeUser = makeAddr("bridgeUser");
    uint256 internal amount = 10e6;
    uint128 internal index = 1_100_000_068_703;
    uint128 internal testIndex = 1_250_000_000_000; // 1.25 - principal != balance, clean conversions
    bytes32 internal messageId = bytes32(uint256(1));

    function setUp() public override {
        super.setUp();

        // Fund hubPortal with M tokens for receiving
        mToken.mint(address(hubPortal), 100e6);

        // Fund wrappedMToken with M tokens for wrapping
        mToken.mint(address(wrappedMToken), 100e6);

        // Fund bridgeUser with ETH for gas
        vm.deal(bridgeUser, 1 ether);
    }

    /// @dev Helper to bridge tokens to an isolated spoke (increases principal)
    function _bridgeTokensToSpoke(uint256 _amount) internal {
        mToken.mint(bridgeUser, _amount);
        vm.startPrank(bridgeUser);
        mToken.approve(address(hubPortal), _amount);
        hubPortal.sendToken{ value: 1 }(
            _amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, sender.toBytes32(), bridgeUser.toBytes32(), ""
        );
        vm.stopPrank();
    }

    function test_receiveMessage_tokenTransfer_mToken() external {
        // Enable cross-spoke transfer to skip principal tracking for this test
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(SPOKE_CHAIN_ID, address(mToken), sender.toBytes32(), recipient, amount, index, messageId);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(mToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_tokenTransfer_wrappedMToken() external {
        // Enable cross-spoke transfer to skip principal tracking for this test
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(wrappedMToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(SPOKE_CHAIN_ID, address(wrappedMToken), sender.toBytes32(), recipient, amount, index, messageId);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(wrappedMToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_fillReport() external {
        bytes32 orderId = bytes32("orderId");
        uint128 amountInToRelease = 5e6;
        uint128 amountOutFilled = 10e6;
        bytes32 originRecipient = recipient.toBytes32();
        bytes32 tokenIn = address(mToken).toBytes32();

        bytes memory payload = PayloadEncoder.encodeFillReport(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            orderId,
            amountInToRelease,
            amountOutFilled,
            originRecipient,
            tokenIn
        );

        vm.expectCall(
            address(mockOrderBook),
            abi.encodeCall(
                IOrderBookLike.reportFill,
                (
                    SPOKE_CHAIN_ID,
                    IOrderBookLike.FillReport({
                        orderId: orderId,
                        amountInToRelease: amountInToRelease,
                        amountOutFilled: amountOutFilled,
                        originRecipient: originRecipient,
                        tokenIn: tokenIn
                    })
                )
            )
        );

        vm.expectEmit();
        emit IPortal.FillReportReceived(
            SPOKE_CHAIN_ID, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn, index, messageId
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_cancelReport() external {
        bytes32 orderId = bytes32("orderId");
        bytes32 originSender = sender.toBytes32();
        bytes32 tokenIn = address(mToken).toBytes32();
        uint128 amountInToRefund = 1000e6;

        bytes memory payload = PayloadEncoder.encodeCancelReport(
            SPOKE_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, index, orderId, originSender, tokenIn, amountInToRefund
        );

        vm.expectCall(
            address(mockOrderBook),
            abi.encodeCall(
                IOrderBookLike.reportCancel,
                (
                    SPOKE_CHAIN_ID,
                    IOrderBookLike.CancelReport({
                        orderId: orderId, originSender: originSender, tokenIn: tokenIn, amountInToRefund: amountInToRefund
                    })
                )
            )
        );

        vm.expectEmit();
        emit IPortal.CancelReportReceived(SPOKE_CHAIN_ID, orderId, originSender, tokenIn, amountInToRefund, index, messageId);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_tokenTransfer_wrapFails() external {
        // Use an address that doesn't implement wrap() - wrapping will fail
        address invalidWrappedToken = makeAddr("invalidWrappedToken");

        // Enable cross-spoke transfer to skip principal tracking for this test
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        // Configure this as a supported bridging path
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID, invalidWrappedToken.toBytes32(), true);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            invalidWrappedToken.toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(SPOKE_CHAIN_ID, invalidWrappedToken, sender.toBytes32(), recipient, amount, index, messageId);

        vm.expectEmit();
        emit IPortal.WrapFailed(invalidWrappedToken, recipient, amount);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        // Recipient should receive M tokens instead of wrapped tokens
        assertEq(mToken.balanceOf(recipient), amount);
        assertEq(mToken.balanceOf(address(hubPortal)), 100e6 - amount); // Started with 100e6
    }

    function test_receiveMessage_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        vm.prank(unsupportedAdapter);
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_revertsIfReceivePaused() external {
        vm.prank(pauser);
        hubPortal.pauseReceive();

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectRevert(IPortal.ReceivingPaused.selector);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_revertsIfMessageAlreadyProcessed() external {
        // Enable cross-spoke transfer to skip principal tracking for this test
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        // First call should succeed
        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        // Second call with the same payload should revert
        vm.expectRevert(abi.encodeWithSelector(IPortal.MessageAlreadyProcessed.selector, messageId));

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    // ==================== PRINCIPAL DECREASE TESTS ====================

    function test_receiveMessage_decreasesPrincipalForIsolatedSpoke() external {
        _enableEarningWithIndex(testIndex);
        _bridgeTokensToSpoke(amount);

        uint248 principalBeforeReceive = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);
        assertTrue(principalBeforeReceive > 0);

        // Now receive tokens back FROM the spoke (decreases principal)
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            testIndex,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        uint248 principalAfterReceive = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);
        assertTrue(principalAfterReceive < principalBeforeReceive);
    }

    function test_receiveMessage_decreasesPrincipalToZero() external {
        _enableEarningWithIndex(testIndex);
        _bridgeTokensToSpoke(amount);

        // Receive the exact same amount back
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            testIndex,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_receiveMessage_partialPrincipalDecrease() external {
        uint256 sendAmount = amount * 2;
        uint256 receiveAmount = amount;

        _enableEarningWithIndex(testIndex);
        _bridgeTokensToSpoke(sendAmount);

        uint248 principalBeforeReceive = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);

        // Receive only 1x amount back
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            testIndex,
            receiveAmount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        uint248 principalAfterReceive = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);

        // Sent 2x amount, received 1x amount back, so half the principal remains
        assertEq(principalAfterReceive, principalBeforeReceive / 2);
    }

    function test_receiveMessage_doesNotDecreasePrincipalForConnectedSpoke() external {
        // Enable cross-spoke transfer for this spoke
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        // Principal tracking is disabled for connected spokes, so this should not revert
        // even though there is no principal to decrease
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            index,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        // Should succeed and principal should remain 0
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
        assertEq(mToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_revertsIfInsufficientBridgedBalance() external {
        _enableEarningWithIndex(testIndex);
        _bridgeTokensToSpoke(amount / 2);

        // Try to receive 10e6 back (more than was bridged)
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            testIndex,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectRevert(IHubPortal.InsufficientBridgedBalance.selector);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_revertsIfNothingBridged() external {
        mToken.setCurrentIndex(testIndex);

        // Try to receive tokens when nothing was bridged
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            testIndex,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.expectRevert(IHubPortal.InsufficientBridgedBalance.selector);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_principalCalculationWithChangingIndex() external {
        uint128 sendIndex = 1_250_000_000_000; // 1.25
        uint128 receiveIndex = 1_500_000_000_000; // 1.5

        _enableEarningWithIndex(sendIndex);
        _bridgeTokensToSpoke(amount);

        // At index 1.25, principal = 10e6 / 1.25 = 8e6
        uint248 principalAfterSend = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);
        uint248 expectedPrincipal = uint248((uint256(amount) * 1e12) / sendIndex);
        assertEq(principalAfterSend, expectedPrincipal);
        assertTrue(principalAfterSend != amount); // Verify principal != balance

        // Change index to 1.5
        mToken.setCurrentIndex(receiveIndex);

        // To unlock principal at index 1.5, we need to receive: principal * 1.5 = 8e6 * 1.5 = 12e6
        uint256 receiveAmount = (uint256(principalAfterSend) * receiveIndex) / 1e12;

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            receiveIndex,
            receiveAmount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32()
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        // Principal should be 0 (fully unlocked)
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }
}
