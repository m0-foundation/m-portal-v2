// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { BridgeAdapterStatus, IPortal } from "../../../src/interfaces/IPortal.sol";
import { IOrderBookLike } from "../../../src/interfaces/IOrderBookLike.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendFillReportUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    uint128 internal index = 1_100_000_068_703;

    IOrderBookLike.FillReport internal testReport = IOrderBookLike.FillReport({
        orderId: bytes32(uint256(1)),
        amountInToRelease: 1000e6,
        amountOutFilled: 990e6,
        originRecipient: makeAddr("recipient").toBytes32(),
        tokenIn: makeAddr("tokenIn").toBytes32()
    });

    function setUp() public override {
        super.setUp();
        _enableEarningWithIndex(index);
    }

    function test_sendFillReport_withDefaultAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeFillReport(
            SPOKE_CHAIN_ID,
            spokeBridgeAdapter,
            messageId,
            index,
            testReport.orderId,
            testReport.amountInToRelease,
            testReport.amountOutFilled,
            testReport.originRecipient,
            testReport.tokenIn
        );
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, FILL_REPORT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.FillReportSent(
            SPOKE_CHAIN_ID,
            testReport.orderId,
            testReport.amountInToRelease,
            testReport.amountOutFilled,
            testReport.originRecipient,
            testReport.tokenIn,
            index,
            defaultBridgeAdapter,
            messageId
        );

        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport{ value: fee }(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendFillReport_withSpecificAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeFillReport(
            SPOKE_CHAIN_ID,
            spokeBridgeAdapter,
            messageId,
            index,
            testReport.orderId,
            testReport.amountInToRelease,
            testReport.amountOutFilled,
            testReport.originRecipient,
            testReport.tokenIn
        );

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, address(customAdapter), BridgeAdapterStatus.Enabled);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, FILL_REPORT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.FillReportSent(
            SPOKE_CHAIN_ID,
            testReport.orderId,
            testReport.amountInToRelease,
            testReport.amountOutFilled,
            testReport.originRecipient,
            testReport.tokenIn,
            index,
            address(customAdapter),
            messageId
        );

        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport{ value: fee }(SPOKE_CHAIN_ID, testReport, refundAddress, address(customAdapter), bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport(SPOKE_CHAIN_ID, testReport, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, unconfiguredChain, address(0)));
        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport(unconfiguredChain, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport(SPOKE_CHAIN_ID, testReport, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfNotOrderBook() external {
        vm.expectRevert(IPortal.NotOrderBook.selector);
        vm.prank(user);
        hubPortal.sendFillReport(SPOKE_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }

    function test_sendFillReport_revertsIfSendToSelf() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, HUB_CHAIN_ID, address(0)));
        vm.prank(address(mockOrderBook));
        hubPortal.sendFillReport(HUB_CHAIN_ID, testReport, refundAddress, bridgeAdapterArgs);
    }
}
