// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { ISpokePortal } from "../../../src/interfaces/ISpokePortal.sol";
import { IOrderBookLike } from "../../../src/interfaces/IOrderBookLike.sol";
import { IRegistrarLike } from "../../../src/interfaces/IRegistrarLike.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { SpokePortalUnitTestBase } from "./SpokePortalUnitTestBase.sol";

contract ReceiveMessageUnitTest is SpokePortalUnitTestBase {
    using TypeConverter for *;

    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    uint256 internal amount = 10e6;
    uint128 internal index = 1_100_000_068_703;
    bytes32 internal messageId = bytes32(uint256(1));

    function test_receiveMessage_tokenTransfer_mToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            HUB_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(HUB_CHAIN_ID, address(mToken), sender.toBytes32(), recipient, amount, index, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        assertEq(mToken.balanceOf(recipient), amount);
        assertEq(mToken.currentIndex(), index);
    }

    function test_receiveMessage_tokenTransfer_wrappedMToken() external {
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            HUB_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(wrappedMToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(HUB_CHAIN_ID, address(wrappedMToken), sender.toBytes32(), recipient, amount, index, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        assertEq(wrappedMToken.balanceOf(recipient), amount);
        assertEq(mToken.currentIndex(), index);
    }

    function test_receiveMessage_tokenTransfer_mToken_lowerIndex() external {
        // Set a higher index first
        uint128 higherIndex = 1_300_000_000_000;
        mToken.updateIndex(higherIndex);

        // Receive tokens with a lower index
        uint128 lowerIndex = 1_100_000_000_000;
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            HUB_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            lowerIndex
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(HUB_CHAIN_ID, address(mToken), sender.toBytes32(), recipient, amount, lowerIndex, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        // Tokens are minted
        assertEq(mToken.balanceOf(recipient), amount);
        // Index remains at the higher value
        assertEq(mToken.currentIndex(), higherIndex);
    }

    function test_receiveMessage_index() external {
        uint128 newIndex = 1_200_000_000_000;
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, newIndex);

        vm.expectEmit();
        emit ISpokePortal.MTokenIndexReceived(newIndex, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        assertEq(mToken.currentIndex(), newIndex);
    }

    function test_receiveMessage_index_lowerIndex() external {
        // First set a higher index
        uint128 higherIndex = 1_300_000_000_000;
        mToken.updateIndex(higherIndex);

        // Try to update with a lower index
        uint128 lowerIndex = 1_100_000_000_000;
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, lowerIndex);

        vm.expectEmit();
        emit ISpokePortal.MTokenIndexReceived(lowerIndex, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        // Index should remain the higher value
        assertEq(mToken.currentIndex(), higherIndex);
    }

    function test_receiveMessage_registrarKey() external {
        bytes32 key = bytes32("test_key");
        bytes32 value = bytes32("test_value");
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(HUB_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, key, value);

        vm.expectEmit();
        emit ISpokePortal.RegistrarKeyReceived(key, value, messageId);
        vm.expectCall(address(registrar), abi.encodeCall(IRegistrarLike.setKey, (key, value)));

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        assertEq(registrar.get(key), value);
    }

    function test_receiveMessage_registrarList_add() external {
        bytes32 listName = EARNERS_LIST;
        address account = makeAddr("earner");
        bool add = true;
        bytes memory payload =
            PayloadEncoder.encodeRegistrarList(HUB_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, listName, account, add);

        vm.expectEmit();
        emit ISpokePortal.RegistrarListUpdateReceived(listName, account, add, messageId);
        vm.expectCall(address(registrar), abi.encodeCall(IRegistrarLike.addToList, (listName, account)));

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);
    }

    function test_receiveMessage_registrarList_remove() external {
        bytes32 listName = EARNERS_LIST;
        address account = makeAddr("earner");
        bool add = false;
        bytes memory payload =
            PayloadEncoder.encodeRegistrarList(HUB_CHAIN_ID, address(bridgeAdapter).toBytes32(), messageId, listName, account, add);

        vm.expectEmit();
        emit ISpokePortal.RegistrarListUpdateReceived(listName, account, add, messageId);
        vm.expectCall(address(registrar), abi.encodeCall(IRegistrarLike.removeFromList, (listName, account)));

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);
    }

    function test_receiveMessage_fillReport() external {
        bytes32 orderId = bytes32("orderId");
        uint128 amountInToRelease = 5e6;
        uint128 amountOutFilled = 10e6;
        bytes32 originRecipient = recipient.toBytes32();
        bytes32 tokenIn = address(mToken).toBytes32();

        bytes memory payload = PayloadEncoder.encodeFillReport(
            HUB_CHAIN_ID,
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
        emit IPortal.FillReportReceived(HUB_CHAIN_ID, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn, messageId);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);
    }

    function test_receiveMessage_tokenTransfer_wrapFails() external {
        // Use an address that doesn't implement wrap() - wrapping will fail
        address invalidWrappedToken = makeAddr("invalidWrappedToken");

        // First configure this as a supported bridging path
        vm.prank(operator);
        spokePortal.setSupportedBridgingPath(address(mToken), HUB_CHAIN_ID, invalidWrappedToken.toBytes32(), true);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            HUB_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            invalidWrappedToken.toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectEmit();
        emit IPortal.TokenReceived(HUB_CHAIN_ID, invalidWrappedToken, sender.toBytes32(), recipient, amount, index, messageId);

        vm.expectEmit();
        emit IPortal.WrapFailed(invalidWrappedToken, recipient, amount);

        vm.prank(address(bridgeAdapter));
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);

        // Recipient should receive M tokens instead of wrapped tokens
        assertEq(mToken.balanceOf(recipient), amount);
        // SpokePortal mints, so balance doesn't decrease
        assertEq(mToken.balanceOf(address(spokePortal)), 0);
    }

    function test_receiveMessage_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            HUB_CHAIN_ID,
            address(bridgeAdapter).toBytes32(),
            messageId,
            amount,
            address(mToken).toBytes32(),
            sender,
            recipient.toBytes32(),
            index
        );

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, unsupportedAdapter));

        vm.prank(unsupportedAdapter);
        spokePortal.receiveMessage(HUB_CHAIN_ID, payload);
    }
}
