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

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(amount, token, sender, recipient, uint128(index));
        assertEq(
            payload,
            abi.encodePacked(
                PayloadType.TokenTransfer, amount.toUint64(), token, sender.toBytes32(), recipient, index.toUint64()
            )
        );
    }

    function testFuzz_encodeTokenTransfer(
        uint256 amount,
        bytes32 token,
        address sender,
        bytes32 recipient,
        uint128 index
    ) external pure {
        vm.assume(amount < type(uint64).max);
        vm.assume(index < type(uint64).max);
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(amount, token, sender, recipient, index);
        assertEq(
            payload,
            abi.encodePacked(
                PayloadType.TokenTransfer, amount.toUint64(), token, sender.toBytes32(), recipient, index.toUint64()
            )
        );
    }

    function test_decodeTokenTransfer() external {
        uint256 amount = 1e6;
        address token = makeAddr("destinationToken");
        address recipient = makeAddr("recipient");
        address sender = makeAddr("sender");
        uint128 index = 1.2e12;

        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(amount, token.toBytes32(), sender, recipient.toBytes32(), index);

        (
            uint256 decodedAmount,
            address decodedToken,
            bytes32 decodedSender,
            address decodedRecipient,
            uint128 decodedIndex
        ) = PayloadEncoder.decodeTokenTransfer(payload);

        assertEq(decodedAmount, amount);
        assertEq(decodedToken, token);
        assertEq(decodedSender, sender.toBytes32());
        assertEq(decodedRecipient, recipient);
        assertEq(decodedIndex, index);
    }

    function testFuzz_decodeTokenTransfer(
        uint256 amount,
        address token,
        address sender,
        address recipient,
        uint128 index
    ) external pure {
        vm.assume(amount < type(uint64).max);
        vm.assume(index < type(uint64).max);

        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(amount, token.toBytes32(), sender, recipient.toBytes32(), index);
        (
            uint256 decodedAmount,
            address decodedToken,
            bytes32 decodedSender,
            address decodedRecipient,
            uint128 decodedIndex
        ) = PayloadEncoder.decodeTokenTransfer(payload);

        assertEq(decodedAmount, amount);
        assertEq(decodedToken, token);
        assertEq(decodedSender, sender.toBytes32());
        assertEq(decodedRecipient, recipient);
        assertEq(decodedIndex, index);
    }

    function test_encodeIndex() external pure {
        uint128 index = 1.2e12;
        bytes memory payload = PayloadEncoder.encodeIndex(index);
        assertEq(payload, abi.encodePacked(PayloadType.Index, index.toUint64()));
    }

    function testFuzz_encodeIndex(uint128 index) external pure {
        vm.assume(index < type(uint64).max);
        bytes memory payload = PayloadEncoder.encodeIndex(index);
        assertEq(payload, abi.encodePacked(PayloadType.Index, index.toUint64()));
    }

    function test_decodeIndex() external pure {
        uint128 index = 1.2e12;
        bytes memory payload = PayloadEncoder.encodeIndex(index.toUint64());
        (uint128 decodedIndex) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedIndex, index);
    }

    function testFuzz_decodeIndex(uint128 index) external pure {
        vm.assume(index < type(uint64).max);
        bytes memory payload = PayloadEncoder.encodeIndex(index.toUint64());
        (uint128 decodedIndex) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedIndex, index);
    }

    function test_encodeKey() external pure {
        bytes32 key = "key";
        bytes32 value = "value";
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value);
        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, key, value));
    }

    function testFuzz_encodeKey(bytes32 key, bytes32 value) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value);
        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, key, value));
    }

    function test_decodeKey() external pure {
        bytes32 key = "key";
        bytes32 value = "value";
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value);

        (bytes32 decodedKey, bytes32 decodedValue) = PayloadEncoder.decodeRegistrarKey(payload);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
    }

    function testFuzz_decodeKey(bytes32 key, bytes32 value) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value);
        (bytes32 decodedKey, bytes32 decodedValue) = PayloadEncoder.decodeRegistrarKey(payload);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
    }

    function test_encodeListUpdate() external {
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes memory payload = abi.encodePacked(PayloadType.RegistrarList, listName, account, add);

        assertEq(PayloadEncoder.encodeRegistrarList(listName, account, add), payload);
    }

    function testFuzz_encodeListUpdate(bytes32 listName, address account, bool add) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add);
        assertEq(payload, abi.encodePacked(PayloadType.RegistrarList, listName, account, add));
    }

    function test_decodeListUpdate() external {
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add);
        (bytes32 decodedListName, address decodedAccount, bool decodedStatus) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
    }

    function testFuzz_decodeListUpdate(bytes32 listName, address account, bool add) external pure {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, add);
        (bytes32 decodedListName, address decodedAccount, bool decodedStatus) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
    }

    function test_encodeFillReport() external pure {
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes memory payload = abi.encodePacked(
            PayloadType.FillReport, orderId, amountInToRelease.toUint64(), amountOutFilled.toUint64(), originRecipient
        );

        assertEq(PayloadEncoder.encodeFillReport(orderId, amountInToRelease, amountOutFilled, originRecipient), payload);
    }

    function test_decodeFillReport() external pure {
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes memory payload = PayloadEncoder.encodeFillReport(
            orderId, amountInToRelease.toUint64(), amountOutFilled.toUint64(), originRecipient
        );
        (
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
    }

    function testFuzz_decodeFillReport(
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient
    ) external pure {
        vm.assume(amountInToRelease < type(uint64).max);
        vm.assume(amountOutFilled < type(uint64).max);
        bytes memory payload = PayloadEncoder.encodeFillReport(
            orderId, amountInToRelease.toUint64(), amountOutFilled.toUint64(), originRecipient
        );
        (
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
    }
}
