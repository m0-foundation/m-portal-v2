// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendMTokenIndexUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";

    function test_sendMTokenIndex_withDefaultAdapter() external {
        uint128 index = 1_100_000_068_703;
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeIndex(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, INDEX_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(SPOKE_CHAIN_ID, index, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendMTokenIndex{ value: fee }(SPOKE_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_withSpecificAdapter() external {
        uint128 index = 1_100_000_068_703;
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeIndex(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, INDEX_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(SPOKE_CHAIN_ID, index, address(customAdapter), messageId);

        vm.prank(user);
        hubPortal.sendMTokenIndex{ value: fee }(SPOKE_CHAIN_ID, refundAddress, address(customAdapter), bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        hubPortal.sendMTokenIndex(SPOKE_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        hubPortal.sendMTokenIndex(SPOKE_CHAIN_ID, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, unconfiguredChain));
        hubPortal.sendMTokenIndex(unconfiguredChain, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));
        hubPortal.sendMTokenIndex(SPOKE_CHAIN_ID, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfInvalidDestinationChain() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, HUB_CHAIN_ID));
        hubPortal.sendMTokenIndex(HUB_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }
}
