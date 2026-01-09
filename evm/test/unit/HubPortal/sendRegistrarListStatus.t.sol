// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendRegistrarListStatusUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal testListName = bytes32("LIST");
    address internal testAccount = makeAddr("account");
    uint128 internal index = 1_100_000_068_703;

    function setUp() public override {
        super.setUp();
        _enableEarningWithIndex(index);
    }

    function test_sendRegistrarListStatus_withDefaultAdapter_accountInList() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bool status = true;
        bytes memory payload =
            PayloadEncoder.encodeRegistrarList(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, testListName, testAccount, status);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        registrar.setListContains(testListName, testAccount, status);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, LIST_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.RegistrarListStatusSent(SPOKE_CHAIN_ID, testListName, testAccount, status, index, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendRegistrarListStatus{ value: fee }(SPOKE_CHAIN_ID, testListName, testAccount, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarListStatus_withDefaultAdapter_accountNotInList() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bool status = false;
        bytes memory payload =
            PayloadEncoder.encodeRegistrarList(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, testListName, testAccount, status);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        registrar.setListContains(testListName, testAccount, status);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, LIST_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.RegistrarListStatusSent(SPOKE_CHAIN_ID, testListName, testAccount, status, index, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendRegistrarListStatus{ value: fee }(SPOKE_CHAIN_ID, testListName, testAccount, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarListStatus_withSpecificAdapter() external {
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bool status = true;
        bytes memory payload =
            PayloadEncoder.encodeRegistrarList(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, testListName, testAccount, status);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        registrar.setListContains(testListName, testAccount, status);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, LIST_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.RegistrarListStatusSent(SPOKE_CHAIN_ID, testListName, testAccount, status, index, address(customAdapter), messageId);

        vm.prank(user);
        hubPortal.sendRegistrarListStatus{ value: fee }(
            SPOKE_CHAIN_ID, testListName, testAccount, refundAddress, address(customAdapter), bridgeAdapterArgs
        );
    }

    function test_sendRegistrarListStatus_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        hubPortal.sendRegistrarListStatus(SPOKE_CHAIN_ID, testListName, testAccount, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarListStatus_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        hubPortal.sendRegistrarListStatus(SPOKE_CHAIN_ID, testListName, testAccount, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendRegistrarListStatus_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, unconfiguredChain));
        hubPortal.sendRegistrarListStatus(unconfiguredChain, testListName, testAccount, refundAddress, bridgeAdapterArgs);
    }

    function test_sendRegistrarListStatus_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));

        hubPortal.sendRegistrarListStatus(SPOKE_CHAIN_ID, testListName, testAccount, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }
}
