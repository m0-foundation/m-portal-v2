// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { PayloadType, PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

contract PayloadEncoderTest is Test {
    using PayloadEncoder for bytes;
    using TypeConverter for *;

    uint32 DESTINATION_CHAIN_ID = 1;
    bytes32 DESTINATION_PEER = "peer";
    bytes32 MESSAGE_ID = "message id";

    /// forge-config: default.allow_internal_expect_revert = true
    function test_decodePayloadType_invalidPayloadLength() external {
        bytes memory payload = "";

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadLength.selector, payload.length));
        PayloadEncoder.decodePayloadType(payload);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_decodePayloadType_invalidPayloadType() external {
        bytes memory payload = abi.encodePacked(uint8(6), DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadType.selector, 6));
        PayloadEncoder.decodePayloadType(payload);
    }

    function test_decodePayloadType() external view {
        bytes memory payload = abi.encodePacked(PayloadType.TokenTransfer, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);
        assertEq(uint8(PayloadEncoder.decodePayloadType(payload)), uint8(PayloadType.TokenTransfer));

        payload = abi.encodePacked(PayloadType.Index, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);
        assertEq(uint8(PayloadEncoder.decodePayloadType(payload)), uint8(PayloadType.Index));

        payload = abi.encodePacked(PayloadType.RegistrarKey, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);
        assertEq(uint8(PayloadEncoder.decodePayloadType(payload)), uint8(PayloadType.RegistrarKey));

        payload = abi.encodePacked(PayloadType.RegistrarList, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);
        assertEq(uint8(PayloadEncoder.decodePayloadType(payload)), uint8(PayloadType.RegistrarList));

        payload = abi.encodePacked(PayloadType.FillReport, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID);
        assertEq(uint8(PayloadEncoder.decodePayloadType(payload)), uint8(PayloadType.FillReport));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_decodeDestinationChainIdAndPeer_invalidPayloadLength() external {
        bytes memory payload = abi.encodePacked(uint8(1), uint8(2), uint8(3));

        vm.expectRevert(abi.encodeWithSelector(PayloadEncoder.InvalidPayloadLength.selector, payload.length));
        PayloadEncoder.decodeDestinationChainIdAndPeer(payload);
    }

    function test_decodeDestinationChainIdAndPeer() external view {
        bytes memory payload = abi.encodePacked(PayloadType.Index, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, uint128(100));

        (uint32 decodedDestinationChainId, bytes32 decodedDestinationPeer) = PayloadEncoder.decodeDestinationChainIdAndPeer(payload);
        assertEq(decodedDestinationChainId, DESTINATION_CHAIN_ID);
        assertEq(decodedDestinationPeer, DESTINATION_PEER);
    }

    function testFuzz_decodeDestinationChainIdAndPeer(uint32 destinationChainId, bytes32 destinationPeer) external view {
        bytes memory payload = abi.encodePacked(PayloadType.Index, destinationChainId, destinationPeer, MESSAGE_ID, uint128(100));

        (uint32 decodedDestinationChainId, bytes32 decodedDestinationPeer) = PayloadEncoder.decodeDestinationChainIdAndPeer(payload);
        assertEq(decodedDestinationChainId, destinationChainId);
        assertEq(decodedDestinationPeer, destinationPeer);
    }

    function test_encodeTokenTransfer() external {
        uint256 amount = 1e6;
        bytes32 token = "destinationToken";
        bytes32 recipient = "recipient";
        address sender = makeAddr("sender");
        uint128 index = 1.2e12;

        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, amount, token, sender, recipient, index);

        assertEq(
            payload,
            abi.encodePacked(
                PayloadType.TokenTransfer,
                DESTINATION_CHAIN_ID,
                DESTINATION_PEER,
                MESSAGE_ID,
                amount.toUint128(),
                token,
                sender.toBytes32(),
                recipient,
                index
            )
        );
    }

    function testFuzz_encodeTokenTransfer(
        bytes32 messageId,
        uint256 amount,
        bytes32 token,
        address sender,
        bytes32 recipient,
        uint128 index
    ) external view {
        vm.assume(amount < type(uint128).max);
        vm.assume(index < type(uint128).max);
        bytes memory payload =
            PayloadEncoder.encodeTokenTransfer(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, amount, token, sender, recipient, index);
        assertEq(
            payload,
            abi.encodePacked(
                PayloadType.TokenTransfer,
                DESTINATION_CHAIN_ID,
                DESTINATION_PEER,
                messageId,
                amount.toUint128(),
                token,
                sender.toBytes32(),
                recipient,
                index
            )
        );
    }

    function test_decodeTokenTransfer() external {
        bytes32 messageId = "messageId";
        uint256 amount = 1e6;
        address token = makeAddr("destinationToken");
        address recipient = makeAddr("recipient");
        address sender = makeAddr("sender");
        uint128 index = 1.2e12;

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, amount, token.toBytes32(), sender, recipient.toBytes32(), index
        );

        (
            bytes32 decodedMessageId,
            uint256 decodedAmount,
            address decodedToken,
            bytes32 decodedSender,
            address decodedRecipient,
            uint128 decodedIndex
        ) = PayloadEncoder.decodeTokenTransfer(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedAmount, amount);
        assertEq(decodedToken, token);
        assertEq(decodedSender, sender.toBytes32());
        assertEq(decodedRecipient, recipient);
        assertEq(decodedIndex, index);
    }

    function testFuzz_decodeTokenTransfer(
        bytes32 messageId,
        uint256 amount,
        address token,
        address sender,
        address recipient,
        uint128 index
    ) external view {
        vm.assume(amount < type(uint128).max);
        vm.assume(index < type(uint128).max);

        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, amount, token.toBytes32(), sender, recipient.toBytes32(), index
        );
        (
            bytes32 decodedMessageId,
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
        assertEq(decodedMessageId, messageId);
    }

    function test_encodeIndex() external view {
        uint128 index = 1.2e12;

        bytes memory payload = PayloadEncoder.encodeIndex(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index);

        assertEq(payload, abi.encodePacked(PayloadType.Index, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index));
    }

    function testFuzz_encodeIndex(uint128 index) external view {
        vm.assume(index < type(uint128).max);

        bytes memory payload = PayloadEncoder.encodeIndex(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index);
        assertEq(payload, abi.encodePacked(PayloadType.Index, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index));
    }

    function test_decodeIndex() external view {
        bytes32 messageId = "messageId";
        uint128 index = 1.2e12;
        bytes memory payload = PayloadEncoder.encodeIndex(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index);

        (bytes32 decodedMessageId, uint128 decodedIndex) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedMessageId, messageId);
        assertEq(decodedIndex, index);
    }

    function testFuzz_decodeIndex(bytes32 messageId, uint128 index) external view {
        vm.assume(index < type(uint128).max);
        bytes memory payload = PayloadEncoder.encodeIndex(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index);

        (bytes32 decodedMessageId, uint128 decodedIndex) = PayloadEncoder.decodeIndex(payload);
        assertEq(decodedMessageId, messageId);
        assertEq(decodedIndex, index);
    }

    function test_encodeKey() external view {
        bytes32 key = "key";
        bytes32 value = "value";

        bytes memory payload = PayloadEncoder.encodeRegistrarKey(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, key, value);

        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, key, value));
    }

    function testFuzz_encodeKey(bytes32 key, bytes32 value, bytes32 messageId) external view {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, key, value);

        assertEq(payload, abi.encodePacked(PayloadType.RegistrarKey, DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, key, value));
    }

    function test_decodeKey() external view {
        bytes32 messageId = "messageId";
        bytes32 key = "key";
        bytes32 value = "value";
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, key, value);

        (bytes32 decodedMessageId, bytes32 decodedKey, bytes32 decodedValue) = PayloadEncoder.decodeRegistrarKey(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
    }

    function testFuzz_decodeKey(bytes32 messageId, bytes32 key, bytes32 value) external view {
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, key, value);

        (bytes32 decodedMessageId, bytes32 decodedKey, bytes32 decodedValue) = PayloadEncoder.decodeRegistrarKey(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedKey, key);
        assertEq(decodedValue, value);
    }

    function test_encodeListUpdate() external {
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes memory payload =
            abi.encodePacked(PayloadType.RegistrarList, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, listName, account, add);

        assertEq(PayloadEncoder.encodeRegistrarList(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, listName, account, add), payload);
    }

    function testFuzz_encodeListUpdate(bytes32 messageId, bytes32 listName, address account, bool add) external view {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, listName, account, add);
        assertEq(
            payload, abi.encodePacked(PayloadType.RegistrarList, DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, listName, account, add)
        );
    }

    function test_decodeListUpdate() external {
        bytes32 messageId = "messageId";
        bytes32 listName = "list";
        address account = makeAddr("account");
        bool add = true;
        bytes memory payload = PayloadEncoder.encodeRegistrarList(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, listName, account, add);
        (bytes32 decodedMessageId, bytes32 decodedListName, address decodedAccount, bool decodedStatus) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
    }

    function testFuzz_decodeListUpdate(bytes32 messageId, bytes32 listName, address account, bool add) external view {
        bytes memory payload = PayloadEncoder.encodeRegistrarList(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, listName, account, add);
        (bytes32 decodedMessageId, bytes32 decodedListName, address decodedAccount, bool decodedStatus) =
            PayloadEncoder.decodeRegistrarList(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedListName, listName);
        assertEq(decodedAccount, account);
        assertEq(decodedStatus, add);
    }

    function test_encodeFillReport() external view {
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes32 tokenIn = "tokenIn";
        bytes memory payload = abi.encodePacked(
            PayloadType.FillReport,
            DESTINATION_CHAIN_ID,
            DESTINATION_PEER,
            MESSAGE_ID,
            orderId,
            amountInToRelease,
            amountOutFilled,
            originRecipient,
            tokenIn
        );

        assertEq(
            PayloadEncoder.encodeFillReport(
                DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn
            ),
            payload
        );
    }

    function test_decodeFillReport() external view {
        bytes32 messageId = "messageId";
        bytes32 orderId = "1";
        uint128 amountInToRelease = 100;
        uint128 amountOutFilled = 100;
        bytes32 originRecipient = "recipient";
        bytes32 tokenIn = "tokenIn";
        bytes memory payload = PayloadEncoder.encodeFillReport(
            DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn
        );
        (
            bytes32 decodedMessageId,
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient,
            bytes32 decodedTokenIn
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
        assertEq(decodedTokenIn, tokenIn);
    }

    function testFuzz_decodeFillReport(
        bytes32 messageId,
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 tokenIn
    ) external view {
        vm.assume(amountInToRelease < type(uint128).max);
        vm.assume(amountOutFilled < type(uint128).max);
        bytes memory payload = PayloadEncoder.encodeFillReport(
            DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn
        );
        (
            bytes32 decodedMessageId,
            bytes32 decodedOrderId,
            uint128 decodedAmountInToRelease,
            uint128 decodedAmountOutFilled,
            bytes32 decodedOriginRecipient,
            bytes32 decodedTokenIn
        ) = PayloadEncoder.decodeFillReport(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedOrderId, orderId);
        assertEq(decodedAmountInToRelease, amountInToRelease);
        assertEq(decodedAmountOutFilled, amountOutFilled);
        assertEq(decodedOriginRecipient, originRecipient);
        assertEq(decodedTokenIn, tokenIn);
    }

    function test_encodeEarnerMerkleRoot() external view {
        uint128 index = 1.2e12;
        bytes32 earnerMerkleRoot = "merkleRoot";
        bytes32 messageId = "messageId";

        bytes memory payload =
            PayloadEncoder.encodeEarnerMerkleRoot(DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index, earnerMerkleRoot);

        assertEq(
            payload,
            abi.encodePacked(PayloadType.EarnerMerkleRoot, DESTINATION_CHAIN_ID, DESTINATION_PEER, MESSAGE_ID, index, earnerMerkleRoot)
        );
    }

    function testFuzz_encodeEarnerMerkleRoot(bytes32 messageId, uint128 index, bytes32 earnerMerkleRoot) external view {
        vm.assume(index < type(uint128).max);

        bytes memory payload =
            PayloadEncoder.encodeEarnerMerkleRoot(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index, earnerMerkleRoot);

        assertEq(
            payload,
            abi.encodePacked(PayloadType.EarnerMerkleRoot, DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index, earnerMerkleRoot)
        );
    }

    function test_decodeEarnerMerkleRoot() external view {
        bytes32 messageId = "messageId";
        uint128 index = 1.2e12;
        bytes32 earnerMerkleRoot = "merkleRoot";
        bytes memory payload =
            PayloadEncoder.encodeEarnerMerkleRoot(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index, earnerMerkleRoot);

        (bytes32 decodedMessageId, uint128 decodedIndex, bytes32 decodedEarnerMerkleRoot) = PayloadEncoder.decodeEarnerMerkleRoot(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedIndex, index);
        assertEq(decodedEarnerMerkleRoot, earnerMerkleRoot);
    }

    function testFuzz_decodeEarnerMerkleRoot(bytes32 messageId, uint128 index, bytes32 earnerMerkleRoot) external view {
        vm.assume(index < type(uint128).max);
        bytes memory payload =
            PayloadEncoder.encodeEarnerMerkleRoot(DESTINATION_CHAIN_ID, DESTINATION_PEER, messageId, index, earnerMerkleRoot);

        (bytes32 decodedMessageId, uint128 decodedIndex, bytes32 decodedEarnerMerkleRoot) = PayloadEncoder.decodeEarnerMerkleRoot(payload);

        assertEq(decodedMessageId, messageId);
        assertEq(decodedIndex, index);
        assertEq(decodedEarnerMerkleRoot, earnerMerkleRoot);
    }
}
