// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { IOrderBookLike } from "../../../src/interfaces/IOrderBookLike.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendCancelReportUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    uint128 internal index = 1_100_000_068_703;

    function setUp() public override {
        super.setUp();
        _enableEarningWithIndex(index);
    }

    IOrderBookLike.CancelReport internal testReport = IOrderBookLike.CancelReport({
        orderId: bytes32(uint256(1)),
        originSender: makeAddr("originSender").toBytes32(),
        tokenIn: makeAddr("tokenIn").toBytes32(),
        amountInToRefund: 1000e6
    });

    function test_sendCancelReport_withDefaultAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeCancelReport(
            SPOKE_CHAIN_ID,
            spokeBridgeAdapter,
            messageId,
            index,
            testReport.orderId,
            testReport.originSender,
            testReport.tokenIn,
            testReport.amountInToRefund
        );
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, CANCEL_REPORT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.CancelReportSent(
            SPOKE_CHAIN_ID,
            testReport.orderId,
            testReport.originSender,
            testReport.tokenIn,
            testReport.amountInToRefund,
            index,
            defaultBridgeAdapter,
            messageId
        );

        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport{ value: fee }(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendCancelReport_withSpecificAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeCancelReport(
            SPOKE_CHAIN_ID,
            spokeBridgeAdapter,
            messageId,
            index,
            testReport.orderId,
            testReport.originSender,
            testReport.tokenIn,
            testReport.amountInToRefund
        );

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, CANCEL_REPORT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.CancelReportSent(
            SPOKE_CHAIN_ID,
            testReport.orderId,
            testReport.originSender,
            testReport.tokenIn,
            testReport.amountInToRefund,
            index,
            address(customAdapter),
            messageId
        );

        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport{ value: fee }(SPOKE_CHAIN_ID, testReport, refundAddress, address(customAdapter), bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport(SPOKE_CHAIN_ID, testReport, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, unconfiguredChain, address(0)));
        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport(unconfiguredChain, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport(SPOKE_CHAIN_ID, testReport, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfNotOrderBook() external {
        vm.expectRevert(IPortal.NotOrderBook.selector);
        vm.prank(user);
        hubPortal.sendCancelReport(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendCancelReport_revertsIfISendToSelf() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, address(0)));
        vm.prank(address(mockOrderBook));
        hubPortal.sendCancelReport(HUB_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }
}
