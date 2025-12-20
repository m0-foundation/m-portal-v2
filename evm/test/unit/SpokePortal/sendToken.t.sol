// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { PausableUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { SpokePortalUnitTestBase } from "./SpokePortalUnitTestBase.sol";

contract SendTokenUnitTest is SpokePortalUnitTestBase {
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

    function test_sendToken_mToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(HUB_CHAIN_ID, hubBridgeAdapter, messageId, amount, hubMToken, user, recipient, index);
        address defaultBridgeAdapter = spokePortal.defaultBridgeAdapter(HUB_CHAIN_ID);

        mToken.setCurrentIndex(index);

        uint256 initialBalance = wrappedMToken.balanceOf(user);
        vm.startPrank(user);
        mToken.approve(address(spokePortal), amount);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (HUB_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.TokenSent(address(mToken), HUB_CHAIN_ID, hubMToken, user, recipient, amount, index, defaultBridgeAdapter, messageId);

        spokePortal.sendToken{ value: fee }(amount, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        assertEq(mToken.balanceOf(user), initialBalance - amount);
        assertEq(mToken.balanceOf(address(spokePortal)), 0);
    }

    function test_sendToken_wrappedMToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(HUB_CHAIN_ID, hubBridgeAdapter, messageId, amount, hubWrappedMToken, user, recipient, index);
        address defaultBridgeAdapter = spokePortal.defaultBridgeAdapter(HUB_CHAIN_ID);

        mToken.setCurrentIndex(index);

        uint256 initialBalance = wrappedMToken.balanceOf(user);
        vm.startPrank(user);
        wrappedMToken.approve(address(spokePortal), amount);

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(IBridgeAdapter.sendMessage, (HUB_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(wrappedMToken), HUB_CHAIN_ID, hubWrappedMToken, user, recipient, amount, index, defaultBridgeAdapter, messageId
        );

        spokePortal.sendToken{ value: fee }(
            amount, address(wrappedMToken), HUB_CHAIN_ID, hubWrappedMToken, recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();

        assertEq(wrappedMToken.balanceOf(user), initialBalance - amount);
        assertEq(mToken.balanceOf(address(spokePortal)), 0);
    }

    function test_sendToken_withSpecificAdapter() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(HUB_CHAIN_ID, hubBridgeAdapter, messageId, amount, hubMToken, user, recipient, index);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(spokePortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (HUB_CHAIN_ID)), abi.encode(hubBridgeAdapter));

        mToken.setCurrentIndex(index);

        vm.prank(operator);
        spokePortal.setSupportedBridgeAdapter(HUB_CHAIN_ID, address(customAdapter), true);

        vm.startPrank(user);
        mToken.approve(address(spokePortal), amount);

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(IBridgeAdapter.sendMessage, (HUB_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IPortal.TokenSent(address(mToken), HUB_CHAIN_ID, hubMToken, user, recipient, amount, index, address(customAdapter), messageId);

        spokePortal.sendToken{ value: fee }(
            amount, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, address(customAdapter), bridgeAdapterArgs
        );
        vm.stopPrank();
    }

    function test_sendToken_revertsIfPaused() external {
        vm.prank(pauser);
        spokePortal.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(user);
        spokePortal.sendToken(amount, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroAmount() external {
        vm.expectRevert(IPortal.ZeroAmount.selector);
        vm.prank(user);
        spokePortal.sendToken(0, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        vm.prank(user);
        spokePortal.sendToken(amount, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroSourceToken() external {
        vm.expectRevert(IPortal.ZeroSourceToken.selector);
        vm.prank(user);
        spokePortal.sendToken(amount, address(0), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroDestinationToken() external {
        vm.expectRevert(IPortal.ZeroDestinationToken.selector);
        vm.prank(user);
        spokePortal.sendToken(amount, address(mToken), HUB_CHAIN_ID, bytes32(0), recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfZeroRecipient() external {
        vm.expectRevert(IPortal.ZeroRecipient.selector);
        vm.prank(user);
        spokePortal.sendToken(amount, address(mToken), HUB_CHAIN_ID, hubMToken, bytes32(0), refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 3;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, unconfiguredChain));
        vm.prank(user);
        spokePortal.sendToken(amount, address(mToken), unconfiguredChain, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
    }

    function test_sendToken_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, unsupportedAdapter));

        vm.prank(user);
        spokePortal.sendToken(
            amount, address(mToken), HUB_CHAIN_ID, hubMToken, recipient, refundAddress, unsupportedAdapter, bridgeAdapterArgs
        );
    }

    function test_sendToken_revertsIfInvalidDestinationChain() external {
        vm.startPrank(user);
        mToken.approve(address(spokePortal), amount);

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, SPOKE_CHAIN_ID));
        spokePortal.sendToken(amount, address(mToken), SPOKE_CHAIN_ID, hubMToken, recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();
    }

    function test_sendToken_revertsIfUnsupportedBridgingPath() external {
        bytes32 unsupportedDestinationToken = bytes32("NEW TOKEN");

        vm.startPrank(user);
        mToken.approve(address(spokePortal), amount);

        vm.expectRevert(
            abi.encodeWithSelector(IPortal.UnsupportedBridgingPath.selector, address(mToken), HUB_CHAIN_ID, unsupportedDestinationToken)
        );

        spokePortal.sendToken(
            amount, address(mToken), HUB_CHAIN_ID, unsupportedDestinationToken, recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();
    }
}
