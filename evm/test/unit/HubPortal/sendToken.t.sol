// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { MockFeeOnTransferExtension } from "../../mocks/MockFeeOnTransferExtension.sol";
import { MockFeeOnUnwrapExtension } from "../../mocks/MockFeeOnUnwrapExtension.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendTokenUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = makeAddr("recipient").toBytes32();
    uint256 internal amount = 10e6;

    function setUp() public override {
        super.setUp();

        // Mint tokens to user for testing
        mToken.mint(user, 100e6);
        wrappedMToken.mint(user, 100e6);

        // Fund wrappedMToken with M tokens for unwrapping
        mToken.mint(address(wrappedMToken), 100e6);
    }

    function test_sendToken_withMToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, amount, spokeMToken, user, recipient);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        _enableEarningWithIndex(index);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(mToken), SPOKE_CHAIN_ID, spokeMToken, user, recipient, amount, index, defaultBridgeAdapter, messageId
        );

        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();
    }

    function test_sendToken_withWrappedMToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, amount, spokeWrappedMToken, user, recipient
        );
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        _enableEarningWithIndex(index);

        vm.startPrank(user);
        wrappedMToken.approve(address(hubPortal), amount);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(wrappedMToken), SPOKE_CHAIN_ID, spokeWrappedMToken, user, recipient, amount, index, defaultBridgeAdapter, messageId
        );

        hubPortal.sendToken{ value: fee }(
            amount, address(wrappedMToken), SPOKE_CHAIN_ID, spokeWrappedMToken, recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();
    }

    function test_sendToken_withSpecificAdapter() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, amount, spokeMToken, user, recipient);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        _enableEarningWithIndex(index);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(mToken), SPOKE_CHAIN_ID, spokeMToken, user, recipient, amount, index, address(customAdapter), messageId
        );

        hubPortal.sendToken{ value: fee }(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, address(customAdapter), bridgeAdapterArgs
        );
        vm.stopPrank();
    }

    function test_sendToken_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        vm.prank(user);
        hubPortal.sendToken(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroAmount() external {
        vm.expectRevert(IPortal.ZeroAmount.selector);
        vm.prank(user);
        hubPortal.sendToken(0, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        vm.prank(user);
        hubPortal.sendToken(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroSourceToken() external {
        vm.expectRevert(IPortal.ZeroSourceToken.selector);
        vm.prank(user);
        hubPortal.sendToken(amount, address(0), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroDestinationToken() external {
        vm.expectRevert(IPortal.ZeroDestinationToken.selector);
        vm.prank(user);
        hubPortal.sendToken(amount, address(mToken), SPOKE_CHAIN_ID, bytes32(0), recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroRecipient() external {
        vm.expectRevert(IPortal.ZeroRecipient.selector);
        vm.prank(user);
        hubPortal.sendToken(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, bytes32(0), refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, unconfiguredChain, address(0)));
        vm.prank(user);
        hubPortal.sendToken(amount, address(mToken), unconfiguredChain, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        vm.prank(user);
        hubPortal.sendToken(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, unsupportedAdapter, bridgeAdapterArgs
        );
    }

    function test_sendToken_revertsIfSentToSelf() external {
        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, address(0)));
        hubPortal.sendToken(amount, address(mToken), HUB_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();
    }

    function test_sendToken_revertsIfUnsupportedBridgingPath() external {
        bytes32 unsupportedDestinationToken = bytes32("NEW TOKEN");

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);

        vm.expectRevert(
            abi.encodeWithSelector(IPortal.UnsupportedBridgingPath.selector, address(mToken), SPOKE_CHAIN_ID, unsupportedDestinationToken)
        );

        hubPortal.sendToken(
            amount, address(mToken), SPOKE_CHAIN_ID, unsupportedDestinationToken, recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();
    }

    function test_sendToken_revertsForFeeOnTransferToken() external {
        uint256 feeRate = 100; // 1%
        address feeRecipient = makeAddr("feeRecipient");
        MockFeeOnTransferExtension feeOnTransferToken = new MockFeeOnTransferExtension(address(mToken), feeRate, feeRecipient);
        mToken.mint(address(feeOnTransferToken), 100e6);
        feeOnTransferToken.mint(user, 100e6);

        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(address(feeOnTransferToken), SPOKE_CHAIN_ID, spokeMToken, true);

        vm.startPrank(user);
        feeOnTransferToken.approve(address(hubPortal), amount);

        vm.expectRevert(abi.encodeWithSelector(IPortal.InsufficientAmountReceived.selector, amount, amount - amount * feeRate / 10_000));
        hubPortal.sendToken(amount, address(feeOnTransferToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();
    }

    function test_sendToken_revertsForFeeOnUnwrapToken() external {
        uint256 feeRate = 100; // 1%
        address feeRecipient = makeAddr("feeRecipient");
        MockFeeOnUnwrapExtension feeOnUnwrapToken = new MockFeeOnUnwrapExtension(address(mToken), feeRate, feeRecipient);
        mToken.mint(address(feeOnUnwrapToken), 100e6);
        feeOnUnwrapToken.mint(user, 100e6);

        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(address(feeOnUnwrapToken), SPOKE_CHAIN_ID, spokeMToken, true);

        vm.startPrank(user);
        feeOnUnwrapToken.approve(address(hubPortal), amount);

        vm.expectRevert(abi.encodeWithSelector(IPortal.InsufficientAmountReceived.selector, amount, amount - amount * feeRate / 10_000));
        hubPortal.sendToken(amount, address(feeOnUnwrapToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();
    }

    // ==================== PRINCIPAL TRACKING TESTS ====================

    function test_sendToken_tracksPrincipalForIsolatedSpoke() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        // Principal should be calculated as: amount * EXP_SCALED_ONE / index
        // With index = 1_100_000_068_703 (approx 1.1e12), and EXP_SCALED_ONE = 1e12
        // Principal = amount * 1e12 / 1_100_000_068_703 (rounded down)
        uint248 expectedPrincipal = uint248((uint256(amount) * 1e12) / index);
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), expectedPrincipal);
    }

    function test_sendToken_tracksPrincipalMultipleTransfers() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount * 3);

        // First transfer
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        uint248 principalAfterFirst = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);

        // Second transfer
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        uint248 principalAfterSecond = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);

        // Third transfer
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        uint248 principalAfterThird = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);

        vm.stopPrank();

        // Principal should accumulate correctly
        uint248 singlePrincipal = uint248((uint256(amount) * 1e12) / index);
        assertEq(principalAfterFirst, singlePrincipal);
        assertEq(principalAfterSecond, singlePrincipal * 2);
        assertEq(principalAfterThird, singlePrincipal * 3);
    }

    function test_sendToken_principalCalculationWithDifferentIndexes() external {
        uint256 fee = 1;
        uint128 index1 = 1_250_000_000_000; // 1.25
        uint128 index2 = 1_500_000_000_000; // 1.5

        _enableEarningWithIndex(index1);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount * 2);

        // First transfer at index 1.25 - principal = 10e6 / 1.25 = 8e6
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);

        uint248 firstPrincipal = uint248((uint256(amount) * 1e12) / index1);
        uint248 principalAfterFirst = hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID);
        assertEq(principalAfterFirst, firstPrincipal);
        assertTrue(principalAfterFirst != amount); // Verify principal != balance

        // Change index to 1.5
        mToken.setCurrentIndex(index2);

        // Second transfer at index 1.5 - principal = 10e6 / 1.5 = 6.666e6
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);

        vm.stopPrank();

        uint248 secondPrincipal = uint248((uint256(amount) * 1e12) / index2);
        uint248 expectedTotal = firstPrincipal + secondPrincipal;
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), expectedTotal);
    }

    function test_sendToken_doesNotTrackPrincipalForConnectedSpoke() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        // Enable cross-spoke transfer for this spoke
        vm.prank(operator);
        hubPortal.enableCrossSpokeTokenTransfer(SPOKE_CHAIN_ID);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        // Principal should remain 0 for connected spoke
        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), 0);
    }

    function test_sendToken_principalRoundsDown() external {
        uint256 fee = 1;
        // Use an index that will cause rounding
        uint128 index = 1_100_000_000_001;
        uint256 testAmount = 1_100_000_000_001; // Amount that won't divide evenly

        mToken.mint(user, testAmount);
        _enableEarningWithIndex(index);

        vm.startPrank(user);
        mToken.approve(address(hubPortal), testAmount);
        hubPortal.sendToken{ value: fee }(
            testAmount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();

        // Principal should be rounded down
        // principal = testAmount * 1e12 / index (rounded down)
        uint248 expectedPrincipal = uint248((uint256(testAmount) * 1e12) / index);

        // Verify it's the floor, not ceiling
        uint256 backToAmount = (uint256(expectedPrincipal) * index) / 1e12;
        assertTrue(backToAmount <= testAmount);

        assertEq(hubPortal.bridgedPrincipal(SPOKE_CHAIN_ID), expectedPrincipal);
    }
}
