// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { PayloadType, PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

contract PayloadEncoderTest is Test {
    using PayloadEncoder for bytes;
    using TypeConverter for *;

    /// forge-config: default.allow_internal_expect_revert = true
    function test_getPayloadType_invalidPayloadLength() external {
        bytes memory payload = "";

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadLength.selector, payload.length));
        PayloadEncoder.getPayloadType(payload);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_getPayloadType_invalidPayloadType() external {
        bytes memory payload = abi.encodePacked(uint8(5));

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadType.selector, 5));
        PayloadEncoder.getPayloadType(payload);
    }

    function test_getPayloadType() external pure {
        bytes memory payload = abi.encodePacked(PayloadType.TokenTransfer);
        assertEq(uint8(PayloadEncoder.getPayloadType(payload)), uint8(PayloadType.TokenTransfer));

        payload = abi.encodePacked(PayloadType.Index);
        assertEq(uint8(PayloadEncoder.getPayloadType(payload)), uint8(PayloadType.Index));

        payload = abi.encodePacked(PayloadType.RegistrarKey);
        assertEq(uint8(PayloadEncoder.getPayloadType(payload)), uint8(PayloadType.RegistrarKey));

        payload = abi.encodePacked(PayloadType.RegistrarList);
        assertEq(uint8(PayloadEncoder.getPayloadType(payload)), uint8(PayloadType.RegistrarList));

        payload = abi.encodePacked(PayloadType.FillReport);
        assertEq(uint8(PayloadEncoder.getPayloadType(payload)), uint8(PayloadType.FillReport));
    }

    function test_encodeTokenTransfer() external {
        uint256 amount = 1e6;
        bytes32 token = "destinationToken";
        bytes32 recipient = "recipient";
        address sender = makeAddr("sender");
        uint128 index = 1.2e12;
        bytes32 messageId = "messageId";

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(amount, token, sender, recipient, uint128(index), messageId);
        assertEq(
            payload, abi.encodePacked(PayloadType.TokenTransfer, amount.toUint128(), token, sender.toBytes32(), recipient, index, messageId)
        );
    }

    function testFuzz_encodeTokenTransfer(
        uint256 amount,
        bytes32 token,
        address sender,
        bytes32 recipient,
        uint128 index,
        bytes32 messageId
    ) external pure {
        vm.assume(amount < type(uint128).max);
        vm.assume(index < type(uint128).max);
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(amount, token, sender, recipient, index, messageId);
        assertEq(
            payload, abi.encodePacked(PayloadType.TokenTransfer, amount.toUint128(), token, sender.toBytes32(), recipient, index, messageId)
        );
    }

    function test_decodeTokenTransfer() external {
        uint256 amount = 1e6;
        address token = makeAddr("destinationToken");
        address recipient = makeAddr("recipient");
        address sender = makeAddr("sender");
        uint128 index = 1.2e12;
        bytes32 messageId = "messageId";

        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(amount, token.toBytes32(), sender, recipient.toBytes32(), index, messageId);

        (
            uint256 decodedAmount,
            address decodedToken,
            bytes32 decodedSender,
            address decodedRecipient,
            uint128 decodedIndex,
            bytes32 decodedMessageId
        ) = PayloadEncoder.decodeTokenTransfer(payload);

        assertEq(decodedAmount, amount);
        assertEq(decodedToken, token);
        assertEq(decodedSender, sender.toBytes32());
        assertEq(decodedRecipient, recipient);
        assertEq(decodedIndex, index);
        assertEq(decodedMessageId, messageId);
    }

    function testFuzz_decodeTokenTransfer(
        uint256 amount,
        address token,
        address sender,
        address recipient,
        uint128 index,
        bytes32 messageId
    ) external pure {
        vm.assume(amount < type(uint128).max);
        vm.assume(index < type(uint128).max);

        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(amount, token.toBytes32(), sender, recipient.toBytes32(), index, messageId);
        (
            uint256 decodedAmount,
            address decodedToken,
            bytes32 decodedSender,
            address decodedRecipient,
            uint128 decodedIndex,
            bytes32 decodedMessageId
        ) = PayloadEncoder.decodeTokenTransfer(payload);

        assertEq(decodedAmount, amount);
        assertEq(decodedToken, token);
        assertEq(decodedSender, sender.toBytes32());
        assertEq(decodedRecipient, recipient);
        assertEq(decodedIndex, index);
        assertEq(decodedMessageId, messageId);
    }

    function test_encodeIndex() external pure {
        uint128 index = 1.2e12;
        bytes32 messageId = "messageId";

        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);

        assertEq(payload, abi.encodePacked(PayloadType.Index, index, messageId));
    }

    function testFuzz_encodeIndex(uint128 index, bytes32 messageId) external pure {
        vm.assume(index < type(uint128).max);

        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);
        assertEq(payload, abi.encodePacked(PayloadType.Index, index, messageId));
    }

    function test_decodeIndex() external pure {
        uint128 index = 1.2e12;
        bytes32 messageId = "messageId";
        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);

        (uint128 decodedIndex, bytes32 decodedMessageId) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedIndex, index);
        assertEq(decodedMessageId, messageId);
    }

    function testFuzz_decodeIndex(uint128 index, bytes32 messageId) external pure {
        vm.assume(index < type(uint128).max);
        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);

        (uint128 decodedIndex, bytes32 decodedMessageId) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedIndex, index);
        assertEq(decodedMessageId, messageId);
    }

    function test_encodeKey() external pure {
        bytes32 key = "key";
        bytes32 value = "value";
        bytes32 messageId = "messageId";
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value, messageId);

        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, key, value, messageId));
    }

    function testFuzz_encodeKey(bytes32 key, bytes32 value, bytes32 messageId) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value, messageId);

        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, key, value, messageId));
    }

    function test_decodeKey() external pure {
        bytes32 key = "key";
        bytes32 value = "value";
        bytes32 messageId = "messageId";
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value, messageId);

        (bytes32 decodedKey, bytes32 decodedValue, bytes32 decodedMessageId) = PayloadEncoder.decodeRegistrarKey(payload);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
        assertEq(decodedMessageId, messageId);
    }

    function testFuzz_decodeKey(bytes32 key, bytes32 value, bytes32 messageId) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value, messageId);

        (bytes32 decodedKey, bytes32 decodedValue, bytes32 decodedMessageId) = PayloadEncoder.decodeRegistrarKey(payload);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
        assertEq(decodedMessageId, messageId);
    }

    function test_encodeListUpdate() external {
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes32 messageId = "messageId";
        bytes memory payload = abi.encodePacked(PayloadType.RegistrarList, listName, account, add, messageId);

        assertEq(PayloadEncoder.encodeRegistrarList(listName, account, add, messageId), payload);
    }

    function testFuzz_encodeListUpdate(bytes32 listName, address account, bool add, bytes32 messageId) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add, messageId);
        assertEq(payload, abi.encodePacked(PayloadType.RegistrarList, listName, account, add, messageId));
    }

    function test_decodeListUpdate() external {
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes32 messageId = "messageId";
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add, messageId);
        (bytes32 decodedListName, address decodedAccount, bool decodedStatus, bytes32 decodedMessageId) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
        assertEq(decodedMessageId, messageId);
    }

    function testFuzz_decodeListUpdate(bytes32 listName, address account, bool add, bytes32 messageId) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add, messageId);
        (bytes32 decodedListName, address decodedAccount, bool decodedStatus, bytes32 decodedMessageId) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
        assertEq(decodedMessageId, messageId);
    }

    function test_encodeFillReport() external pure {
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes32 messageId = "messageId";
        bytes memory payload =
            abi.encodePacked(PayloadType.FillReport, orderId, amountInToRelease, amountOutFilled, originRecipient, messageId);

        assertEq(PayloadEncoder.encodeFillReport(orderId, amountInToRelease, amountOutFilled, originRecipient, messageId), payload);
    }

    function test_decodeFillReport() external pure {
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes32 messageId = "messageId";
        bytes memory payload = PayloadEncoder.encodeFillReport(orderId, amountInToRelease, amountOutFilled, originRecipient, messageId);
        (
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient,
            bytes32 decodedMessageId
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
        assertEq(decodedMessageId, messageId);
    }

    function testFuzz_decodeFillReport(
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 messageId
    ) external pure {
        vm.assume(amountInToRelease < type(uint128).max);
        vm.assume(amountOutFilled < type(uint128).max);
        bytes memory payload = PayloadEncoder.encodeFillReport(orderId, amountInToRelease, amountOutFilled, originRecipient, messageId);
        (
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient,
            bytes32 decodedMessageId
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
        assertEq(decodedMessageId, messageId);
    }
}
