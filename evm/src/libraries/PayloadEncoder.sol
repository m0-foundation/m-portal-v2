// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { BytesParser } from "./BytesParser.sol";
import { TypeConverter } from "./TypeConverter.sol";

enum PayloadType {
    TokenTransfer,
    Index,
    RegistrarKey,
    RegistrarList,
    FillReport
}

/// @title  PayloadEncoder
/// @author M0 Labs
/// @notice Encodes and decodes cross-chain message payloads.
library PayloadEncoder {
    using BytesParser for bytes;
    using TypeConverter for *;

    uint256 internal constant PAYLOAD_TYPE_LENGTH = 1;

    /// @dev PayloadType.TokenTransfer = 0,
    ///      PayloadType.Index = 1,
    ///      PayloadType.RegistrarKey = 2,
    ///      PayloadType.RegistrarList = 3,
    ///      PayloadType.FillReport = 4
    uint256 internal constant MAX_PAYLOAD_TYPE = 4;

    error InvalidPayloadLength(uint256 length);
    error InvalidPayloadType(uint8 value);

    /// @notice Decodes the payload type from the payload.
    /// @param payload      The payload to decode.
    /// @return payloadType The decoded payload type.
    function getPayloadType(bytes memory payload) internal pure returns (PayloadType) {
        if (payload.length < PAYLOAD_TYPE_LENGTH) revert InvalidPayloadLength(payload.length);

        uint8 type_;
        (type_,) = payload.asUint8Unchecked(0);

        if (type_ > MAX_PAYLOAD_TYPE) revert InvalidPayloadType(type_);
        return PayloadType(type_);
    }

    /// @notice Encodes a token transfer payload.
    /// @dev    Encoded values are packed using `abi.encodePacked`.
    /// @param amount           The amount of tokens to transfer.
    /// @param destinationToken The address of the destination token.
    /// @param sender           The address of the sender.
    /// @param recipient        The address of the recipient.
    /// @param index            The M token index.
    /// @return                 The encoded payload.
    function encodeTokenTransfer(
        uint256 amount,
        bytes32 destinationToken,
        address sender,
        bytes32 recipient,
        uint128 index
    ) internal pure returns (bytes memory) {
        // Converting addresses to `bytes32` and numbers to `uint64` to support non-EVM chains.
        return abi.encodePacked(
            PayloadType.TokenTransfer,
            amount.toUint64(),
            destinationToken,
            sender.toBytes32(),
            recipient,
            index.toUint64()
        );
    }

    /// @notice Decodes a token transfer payload.
    /// @param payload            The payload to decode.
    /// @return amount            The amount of tokens to transfer.
    /// @return destinationToken  The address of the destination token.
    /// @return sender            The address of the sender.
    /// @return recipient         The address of the recipient.
    /// @return index             The M token index.
    function decodeTokenTransfer(bytes memory payload)
        internal
        pure
        returns (uint256 amount, address destinationToken, bytes32 sender, address recipient, uint128 index)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;
        bytes32 destinationTokenBytes32;
        bytes32 recipientBytes32;

        (amount, offset) = payload.asUint64Unchecked(offset);
        (destinationTokenBytes32, offset) = payload.asBytes32Unchecked(offset);
        (sender, offset) = payload.asBytes32Unchecked(offset);
        (recipientBytes32, offset) = payload.asBytes32Unchecked(offset);
        (index, offset) = payload.asUint64Unchecked(offset);

        destinationToken = destinationTokenBytes32.toAddress();
        recipient = recipientBytes32.toAddress();

        payload.checkLength(offset);
    }

    /// @notice Encodes M token index payload.
    /// @param index The M token index.
    /// @return      Encoded payload.
    function encodeIndex(uint128 index) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.Index, index.toUint64());
    }

    /// @notice Decodes M token index payload.
    /// @param payload The payload to decode.
    /// @return        $M token index.
    function decodeIndex(bytes memory payload) internal pure returns (uint128) {
        uint256 offset = PAYLOAD_TYPE_LENGTH;
        uint128 index;

        (index, offset) = payload.asUint64Unchecked(offset);

        payload.checkLength(offset);
        return index;
    }

    /// @notice Encodes Registrar key-value pair payload.
    /// @param key      The key.
    /// @param value    The value.
    /// @return encoded The encoded payload.
    function encodeRegistrarKey(bytes32 key, bytes32 value) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarKey, key, value);
    }

    /// @notice Decodes Registrar key-value pair payload.
    /// @param payload The payload to decode.
    /// @return key    The key.
    /// @return value  The value.
    function decodeRegistrarKey(bytes memory payload) internal pure returns (bytes32 key, bytes32 value) {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (key, offset) = payload.asBytes32Unchecked(offset);
        (value, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Registrar list update payload.
    /// @param listName The name of the list.
    /// @param account  The address of the account.
    /// @param add      Indicates whether to add or remove the account from the list.
    /// @return         The encoded payload.
    function encodeRegistrarList(bytes32 listName, address account, bool add) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarList, listName, account, add);
    }

    /// @notice Decodes Registrar list update payload.
    /// @param payload   The payload to decode.
    /// @return listName The name of the list.
    /// @return account  The address of the account.
    /// @return add      Indicates whether the account was added or removed from the list.
    function decodeRegistrarList(bytes memory payload)
        internal
        pure
        returns (bytes32 listName, address account, bool add)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (listName, offset) = payload.asBytes32Unchecked(offset);
        (account, offset) = payload.asAddressUnchecked(offset);
        (add, offset) = payload.asBoolUnchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes OrderBook fill report payload.
    /// @param orderId           The ID of the order being reported.
    /// @param amountInToRelease The amount of input token to release to the filler on the source chain.
    /// @param amountOutFilled   The amount of output tokens filled.
    /// @param originRecipient   The amount of output token that was filled on the destination chain.
    /// @return                  The encoded payload.
    function encodeFillReport(
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            PayloadType.FillReport, orderId, amountInToRelease.toUint64(), amountOutFilled.toUint64(), originRecipient
        );
    }

    /// @notice Decodes a fill report payload.
    /// @param payload            The payload to decode.
    /// @return orderId           The ID of the order being reported.
    /// @return amountInToRelease The amount of input token to release to the filler on the source chain.
    /// @return amountOutFilled   The amount of output tokens filled.
    /// @return originRecipient   The amount of output token that was filled on the destination chain.
    function decodeFillReport(bytes memory payload)
        internal
        pure
        returns (bytes32 orderId, uint128 amountInToRelease, uint128 amountOutFilled, bytes32 originRecipient)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (orderId, offset) = payload.asBytes32Unchecked(offset);
        (amountInToRelease, offset) = payload.asUint64Unchecked(offset);
        (amountOutFilled, offset) = payload.asUint64Unchecked(offset);
        (originRecipient, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }
}
