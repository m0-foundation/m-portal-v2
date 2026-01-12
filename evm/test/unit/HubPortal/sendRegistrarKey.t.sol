// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendRegistrarKeyUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal testKey = bytes32("TEST_KEY");
    bytes32 internal testValue = bytes32("TEST_VALUE");
    uint128 internal index = 1_100_000_068_703;

    function setUp() public override {
        super.setUp();
        _enableEarningWithIndex(index);
    }

    function test_sendRegistrarKey_withDefaultAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, testKey, testValue);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        registrar.set(testKey, testValue);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, KEY_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.RegistrarKeySent(SPOKE_CHAIN_ID, testKey, testValue, index, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendRegistrarKey{ value: fee }(SPOKE_CHAIN_ID, testKey, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_withSpecificAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, testKey, testValue);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        registrar.set(testKey, testValue);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, KEY_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.RegistrarKeySent(SPOKE_CHAIN_ID, testKey, testValue, index, address(customAdapter), messageId);

        vm.prank(user);
        hubPortal.sendRegistrarKey{ value: fee }(SPOKE_CHAIN_ID, testKey, refundAddress, address(customAdapter), bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        hubPortal.sendRegistrarKey(SPOKE_CHAIN_ID, testKey, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        hubPortal.sendRegistrarKey(SPOKE_CHAIN_ID, testKey, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, unconfiguredChain, address(0)));
        hubPortal.sendRegistrarKey(unconfiguredChain, testKey, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));
        hubPortal.sendRegistrarKey(SPOKE_CHAIN_ID, testKey, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }

    function test_sendRegistrarKey_revertsIfSendToSelf() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, address(0)));
        hubPortal.sendRegistrarKey(HUB_CHAIN_ID, testKey, refundAddress, bridgeAdapterArgs);
    }
}
