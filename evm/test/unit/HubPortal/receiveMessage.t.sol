// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { IOrderBookLike } from "../../../src/interfaces/IOrderBookLike.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract ReceiveMessageUnitTest is HubPortalUnitTestBase {
    using TypeConverter for *;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    uint256 internal amount = 10e6;
    uint128 internal index = 1_100_000_068_703;
    bytes32 internal messageId = bytes32(uint256(1));

    function setUp() public override {
        super.setUp();

        // Fund hubPortal with M tokens for receiving
        mToken.mint(address(hubPortal), 100e6);

        // Fund wrappedMToken with M tokens for wrapping
        mToken.mint(address(wrappedMToken), 100e6);
    }

    function test_receiveMessage_tokenTransfer_mToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(SPOKE_CHAIN_ID, address(mToken), sender.toBytes32(), recipient, amount, index, messageId);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(mToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_tokenTransfer_wrappedMToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(wrappedMToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
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
                IOrderBookLike.FillReport({
                    orderId: orderId,
                    amountInToRelease: amountInToRelease,
                    amountOutFilled: amountOutFilled,
                    originRecipient: originRecipient,
                    tokenIn: tokenIn
                })
            )
        );

        vm.expectEmit();
        emit IPortal.FillReportReceived(SPOKE_CHAIN_ID, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn, messageId);

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }

    function test_receiveMessage_tokenTransfer_wrapFails() external {
        // Use an address that doesn't implement wrap() - wrapping will fail
        address invalidWrappedToken = makeAddr("invalidWrappedToken");

        // First configure this as a supported bridging path
        vm.prank(operator);
        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID, invalidWrappedToken.toBytes32(), true);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            invalidWrappedToken.toBytes32(),
            sender,
            recipient.toBytes32(),
            index
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
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        vm.prank(unsupportedAdapter);
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }
}
