// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { BytesParser } from "./BytesParser.sol";
import { TypeConverter } from "./TypeConverter.sol";

enum PayloadType {
    TokenTransfer,
    Index,
    RegistrarKey,
    RegistrarList,
    FillReport,
    EarnerMerkleRoot
}

/// @title  PayloadEncoder
/// @author M0 Labs
/// @notice Encodes and decodes cross-chain message payloads.
library PayloadEncoder {
    using BytesParser for bytes;
    using TypeConverter for *;

    uint256 internal constant PAYLOAD_TYPE_LENGTH = 1;

    error InvalidPayloadLength(uint256 length);
    error InvalidPayloadType(uint8 value);

    /// @notice Decodes the payload type from the payload.
    /// @param payload The payload to decode.
    /// @return The decoded payload type.
    function getPayloadType(bytes memory payload) internal pure returns (PayloadType) {
        if (payload.length < PAYLOAD_TYPE_LENGTH) revert InvalidPayloadLength(payload.length);

        uint8 type_;
        (type_,) = payload.asUint8Unchecked(0);

        if (type_ > uint8(type(PayloadType).max)) revert InvalidPayloadType(type_);
        return PayloadType(type_);
    }

    /// @notice Encodes a token transfer payload.
    /// @dev    Encoded values are packed using `abi.encodePacked`.
    /// @param amount           The amount of tokens to transfer.
    /// @param destinationToken The address of the destination token.
    /// @param sender           The address of the sender.
    /// @param recipient        The address of the recipient.
    /// @param index            The M token index.
    /// @param messageId        The message ID.
    /// @return The encoded payload.
    function encodeTokenTransfer(
        uint256 amount,
        bytes32 destinationToken,
        address sender,
        bytes32 recipient,
        uint128 index,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        // Converting addresses to `bytes32` and amount to `uint128` to support non-EVM chains.
        return abi.encodePacked(
            PayloadType.TokenTransfer, amount.toUint128(), destinationToken, sender.toBytes32(), recipient, index, messageId
        );
    }

    /// @notice Decodes a token transfer payload.
    /// @param payload           The payload to decode.
    /// @return amount           The amount of tokens to transfer.
    /// @return destinationToken The address of the destination token.
    /// @return sender           The address of the sender.
    /// @return recipient        The address of the recipient.
    /// @return index            The M token index.
    /// @return messageId        The message ID.
    function decodeTokenTransfer(bytes memory payload)
        internal
        pure
        returns (uint256 amount, address destinationToken, bytes32 sender, address recipient, uint128 index, bytes32 messageId)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;
        bytes32 destinationTokenBytes32;
        bytes32 recipientBytes32;

        (amount, offset) = payload.asUint128Unchecked(offset);
        (destinationTokenBytes32, offset) = payload.asBytes32Unchecked(offset);
        (sender, offset) = payload.asBytes32Unchecked(offset);
        (recipientBytes32, offset) = payload.asBytes32Unchecked(offset);
        (index, offset) = payload.asUint128Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        destinationToken = destinationTokenBytes32.toAddress();
        recipient = recipientBytes32.toAddress();

        payload.checkLength(offset);
    }

    /// @notice Encodes M token index payload.
    /// @param  index     The M token index.
    /// @param  messageId The message ID.
    /// @return The encoded payload.
    function encodeIndex(uint128 index, bytes32 messageId) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.Index, index, messageId);
    }

    /// @notice Decodes M token index payload.
    /// @param payload    The payload to decode.
    /// @return index     $M token index.
    /// @return messageId The message ID.
    function decodeIndex(bytes memory payload) internal pure returns (uint128 index, bytes32 messageId) {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (index, offset) = payload.asUint128Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Registrar key-value pair payload.
    /// @param  key       The Registrar key.
    /// @param  value     The Registrar value.
    /// @param  messageId The message ID.
    /// @return The encoded payload.
    function encodeRegistrarKey(bytes32 key, bytes32 value, bytes32 messageId) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarKey, key, value, messageId);
    }

    /// @notice Decodes Registrar key-value pair payload.
    /// @param payload    The payload to decode.
    /// @return key       The Registrar key.
    /// @return value     The Registrar value.
    /// @return messageId The message ID.
    function decodeRegistrarKey(bytes memory payload) internal pure returns (bytes32 key, bytes32 value, bytes32 messageId) {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (key, offset) = payload.asBytes32Unchecked(offset);
        (value, offset) = payload.asBytes32Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Registrar list update payload.
    /// @param listName  The name of the list.
    /// @param account   The address of the account.
    /// @param add       Indicates whether to add or remove the account from the list.
    /// @param messageId The message ID.
    /// @return The encoded payload.
    function encodeRegistrarList(bytes32 listName, address account, bool add, bytes32 messageId) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarList, listName, account, add, messageId);
    }

    /// @notice Decodes Registrar list update payload.
    /// @param payload    The payload to decode.
    /// @return listName  The name of the list.
    /// @return account   The address of the account.
    /// @return add       Indicates whether the account was added or removed from the list.
    /// @return messageId The message ID.
    function decodeRegistrarList(bytes memory payload)
        internal
        pure
        returns (bytes32 listName, address account, bool add, bytes32 messageId)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (listName, offset) = payload.asBytes32Unchecked(offset);
        (account, offset) = payload.asAddressUnchecked(offset);
        (add, offset) = payload.asBoolUnchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes OrderBook fill report payload.
    /// @param orderId           The ID of the order being reported.
    /// @param amountInToRelease The amount of input token to release to the filler on the source chain.
    /// @param amountOutFilled   The amount of output tokens filled.
    /// @param originRecipient   The address on the origin chain that should receive released funds.
    /// @param tokenIn           The address of the input token on the origin chain.
    /// @param messageId         The message ID.
    /// @return The encoded payload.
    function encodeFillReport(
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 tokenIn,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.FillReport, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn, messageId);
    }

    /// @notice Decodes a fill report payload.
    /// @param payload            The payload to decode.
    /// @return orderId           The ID of the order being reported.
    /// @return amountInToRelease The amount of input token to release to the filler on the source chain.
    /// @return amountOutFilled   The amount of output tokens filled.
    /// @return originRecipient   The address on the origin chain that should receive released funds.
    /// @return tokenIn           The address of the input token on the origin chain.
    /// @return messageId         The message ID.
    function decodeFillReport(bytes memory payload)
        internal
        pure
        returns (
            bytes32 orderId,
            uint128 amountInToRelease,
            uint128 amountOutFilled,
            bytes32 originRecipient,
            bytes32 tokenIn,
            bytes32 messageId
        )
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (orderId, offset) = payload.asBytes32Unchecked(offset);
        (amountInToRelease, offset) = payload.asUint128Unchecked(offset);
        (amountOutFilled, offset) = payload.asUint128Unchecked(offset);
        (originRecipient, offset) = payload.asBytes32Unchecked(offset);
        (tokenIn, offset) = payload.asBytes32Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Earner Merkle Root payload.
    /// @param  index            $M token index.
    /// @param  earnerMerkleRoot The Earner Merkle Root.
    /// @param  messageId        The message ID.
    function encodeEarnerMerkleRoot(uint128 index, bytes32 earnerMerkleRoot, bytes32 messageId) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.EarnerMerkleRoot, index, earnerMerkleRoot, messageId);
    }

    /// @notice Decodes Earner Merkle Root payload.
    /// @param  payload          The payload to decode.
    /// @return index            $M token index.
    /// @return earnerMerkleRoot The Earner Merkle Root.
    /// @return messageId        The message ID.
    function decodeEarnerMerkleRoot(bytes memory payload)
        internal
        pure
        returns (uint128 index, bytes32 earnerMerkleRoot, bytes32 messageId)
    {
        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (index, offset) = payload.asUint128Unchecked(offset);
        (earnerMerkleRoot, offset) = payload.asBytes32Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Generates a payload with empty data for the given payload type.
    /// @dev    Used for estimating gas costs for different payload types.
    function generateEmptyPayload(PayloadType payloadType) internal pure returns (bytes memory) {
        if (payloadType == PayloadType.TokenTransfer) {
            return encodeTokenTransfer(0, bytes32(0), address(0), bytes32(0), 0, bytes32(0));
        } else if (payloadType == PayloadType.Index) {
            return encodeIndex(0, bytes32(0));
        } else if (payloadType == PayloadType.RegistrarKey) {
            return encodeRegistrarKey(bytes32(0), bytes32(0), bytes32(0));
        } else if (payloadType == PayloadType.RegistrarList) {
            return encodeRegistrarList(bytes32(0), address(0), false, bytes32(0));
        } else if (payloadType == PayloadType.FillReport) {
            return encodeFillReport(bytes32(0), 0, 0, bytes32(0), bytes32(0), bytes32(0));
        } else if (payloadType == PayloadType.EarnerMerkleRoot) {
            return encodeEarnerMerkleRoot(0, bytes32(0), bytes32(0));
        }

        revert InvalidPayloadType(uint8(payloadType));
    }
}
