// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { PausableUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { HubPortal } from "../../../src/HubPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract ReceiveMessageUnitTest is HubPortalUnitTestBase {
    using TypeConverter for *;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    uint256 internal amount = 10e6;
    uint128 internal index = 1_100000068703;
    bytes32 internal messageId = bytes32(uint256(1));

    function setUp() public override {
        super.setUp();

        // Fund hubPortal with M tokens for receiving
        mToken.mint(address(hubPortal), 100e6);

        // Fund wrappedMToken with M tokens for wrapping
        mToken.mint(address(wrappedMToken), 100e6);
    }

    function test_receiveMessage_mToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index,
            messageId
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(
            SPOKE_CHAIN_ID,
            address(mToken),
            sender.toBytes32(),
            recipient,
            amount,
            index,
            messageId
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(mToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_wrappedMToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            amount,
            address(wrappedMToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index,
            messageId
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(
            SPOKE_CHAIN_ID,
            address(wrappedMToken),
            sender.toBytes32(),
            recipient,
            amount,
            index,
            messageId
        );

        vm.prank(address(bridgeAdapter));
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);

        assertEq(wrappedMToken.balanceOf(recipient), amount);
    }

    function test_receiveMessage_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index,
            messageId
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IPortal.UnsupportedBridgeAdapter.selector,
                SPOKE_CHAIN_ID,
                unsupportedAdapter
            )
        );

        vm.prank(unsupportedAdapter);
        hubPortal.receiveMessage(SPOKE_CHAIN_ID, payload);
    }
}
