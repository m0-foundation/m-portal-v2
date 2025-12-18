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

    /// @dev All payloads have a common header structure:
    /// ┌──────────────┬──────────────────────┬──────────────────┬───────────────────────┐
    /// │ Payload Type │ Destination Chain ID │ Destination Peer │ Payload Specific Data │
    /// │   (uint8)    │       (uint32)       │    (bytes32)     │     (variable)        │
    /// │   1 byte     │       4 bytes        │     32 bytes     │         ...           │
    /// └──────────────┴──────────────────────┴──────────────────┴───────────────────────┘
    uint256 internal constant PAYLOAD_TYPE_LENGTH = 1;
    uint256 internal constant DESTINATION_CHAIN_ID_LENGTH = 4;
    uint256 internal constant DESTINATION_PEER_LENGTH = 32;
    uint256 internal constant HEADER_LENGTH = PAYLOAD_TYPE_LENGTH + DESTINATION_CHAIN_ID_LENGTH + DESTINATION_PEER_LENGTH;

    error InvalidPayloadLength(uint256 length);
    error InvalidPayloadType(uint8 value);

    /// @notice Decodes the payload type from the payload.
    /// @param  payload The payload to decode.
    function decodePayloadType(bytes memory payload) internal pure returns (PayloadType) {
        if (payload.length < HEADER_LENGTH) revert InvalidPayloadLength(payload.length);

        uint8 payloadType;
        (payloadType,) = payload.asUint8Unchecked(0);

        if (payloadType > uint8(type(PayloadType).max)) revert InvalidPayloadType(payloadType);
        return PayloadType(payloadType);
    }

    /// @notice Decodes the destination ID and peer from the payload.
    /// @param  payload            The payload to decode.
    /// @return destinationChainId The destination chain ID.
    /// @return destinationPeer    The address of the peer bridge adapter on the destination chain.
    function decodeDestinationChainIdAndPeer(bytes memory payload)
        internal
        pure
        returns (uint32 destinationChainId, bytes32 destinationPeer)
    {
        if (payload.length < HEADER_LENGTH) revert InvalidPayloadLength(payload.length);

        uint256 offset = PAYLOAD_TYPE_LENGTH;

        (destinationChainId, offset) = payload.asUint32Unchecked(offset);
        (destinationPeer, offset) = payload.asBytes32Unchecked(offset);
    }

    /// @notice Encodes a token transfer payload.
    /// @dev    Encoded values are packed using `abi.encodePacked`.
    /// @param destinationChainId The destination chain ID.
    /// @param destinationPeer    The address of the peer bridge adapter on the destination chain.
    /// @param amount             The amount of tokens to transfer.
    /// @param destinationToken   The address of the destination token.
    /// @param sender             The address of the sender.
    /// @param recipient          The address of the recipient.
    /// @param index              The $M token index.
    /// @param messageId          The message ID.

    /// @return The encoded payload.
    function encodeTokenTransfer(
        uint32 destinationChainId,
        bytes32 destinationPeer,
        uint256 amount,
        bytes32 destinationToken,
        address sender,
        bytes32 recipient,
        uint128 index,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        // Converting addresses to `bytes32` and amount to `uint128` to support non-EVM chains.
        return abi.encodePacked(
            PayloadType.TokenTransfer,
            destinationChainId,
            destinationPeer,
            amount.toUint128(),
            destinationToken,
            sender.toBytes32(),
            recipient,
            index,
            messageId
        );
    }

    /// @notice Decodes a token transfer payload.
    /// @param  payload          The payload to decode.
    /// @return amount           The amount of tokens to transfer.
    /// @return destinationToken The address of the destination token.
    /// @return sender           The address of the sender.
    /// @return recipient        The address of the recipient.
    /// @return index            The $M token index.
    /// @return messageId        The message ID.
    function decodeTokenTransfer(bytes memory payload)
        internal
        pure
        returns (uint256 amount, address destinationToken, bytes32 sender, address recipient, uint128 index, bytes32 messageId)
    {
        uint256 offset = HEADER_LENGTH;
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

    /// @notice Encodes $M token index payload.
    /// @param destinationChainId The destination chain ID.
    /// @param destinationPeer    The address of the peer bridge adapter on the destination chain.
    /// @param index              The $M token index.
    /// @param messageId          The message ID.
    function encodeIndex(
        uint32 destinationChainId,
        bytes32 destinationPeer,
        uint128 index,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.Index, destinationChainId, destinationPeer, index, messageId);
    }

    /// @notice Decodes M token index payload.
    /// @param payload    The payload to decode.
    /// @return index     $M token index.
    /// @return messageId The message ID.
    function decodeIndex(bytes memory payload) internal pure returns (uint128 index, bytes32 messageId) {
        uint256 offset = HEADER_LENGTH;

        (index, offset) = payload.asUint128Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Registrar key-value pair payload.
    /// @param destinationChainId The destination chain ID.
    /// @param destinationPeer    The address of the peer bridge adapter on the destination chain.
    /// @param key                The Registrar key.
    /// @param value              The Registrar value.
    /// @param messageId          The message ID.
    function encodeRegistrarKey(
        uint32 destinationChainId,
        bytes32 destinationPeer,
        bytes32 key,
        bytes32 value,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarKey, destinationChainId, destinationPeer, key, value, messageId);
    }

    /// @notice Decodes Registrar key-value pair payload.
    /// @param  payload   The payload to decode.
    /// @return key       The Registrar key.
    /// @return value     The Registrar value.
    /// @return messageId The message ID.
    function decodeRegistrarKey(bytes memory payload) internal pure returns (bytes32 key, bytes32 value, bytes32 messageId) {
        uint256 offset = HEADER_LENGTH;

        (key, offset) = payload.asBytes32Unchecked(offset);
        (value, offset) = payload.asBytes32Unchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes Registrar list update payload.
    /// @param destinationChainId The destination chain ID.
    /// @param destinationPeer    The address of the peer bridge adapter on the destination chain.
    /// @param listName           The name of the list.
    /// @param account            The address of the account.
    /// @param add                Indicates whether to add or remove the account from the list.
    /// @param messageId          The message ID.
    function encodeRegistrarList(
        uint32 destinationChainId,
        bytes32 destinationPeer,
        bytes32 listName,
        address account,
        bool add,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(PayloadType.RegistrarList, destinationChainId, destinationPeer, listName, account, add, messageId);
    }

    /// @notice Decodes Registrar list update payload.
    /// @param  payload   The payload to decode.
    /// @return listName  The name of the list.
    /// @return account   The address of the account.
    /// @return add       Indicates whether the account was added or removed from the list.
    /// @return messageId The message ID.
    function decodeRegistrarList(bytes memory payload)
        internal
        pure
        returns (bytes32 listName, address account, bool add, bytes32 messageId)
    {
        uint256 offset = HEADER_LENGTH;

        (listName, offset) = payload.asBytes32Unchecked(offset);
        (account, offset) = payload.asAddressUnchecked(offset);
        (add, offset) = payload.asBoolUnchecked(offset);
        (messageId, offset) = payload.asBytes32Unchecked(offset);

        payload.checkLength(offset);
    }

    /// @notice Encodes OrderBook fill report payload.
    /// @param destinationChainId The destination chain ID.
    /// @param destinationPeer    The address of the peer bridge adapter on the destination chain.
    /// @param orderId            The ID of the order being reported.
    /// @param amountInToRelease  The amount of input token to release to the filler on the source chain.
    /// @param amountOutFilled    The amount of output tokens filled.
    /// @param originRecipient    The address on the origin chain that should receive released funds.
    /// @param tokenIn            The address of the input token on the origin chain.
    /// @param messageId          The message ID.
    function encodeFillReport(
        uint32 destinationChainId,
        bytes32 destinationPeer,
        bytes32 orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 tokenIn,
        bytes32 messageId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            PayloadType.FillReport,
            destinationChainId,
            destinationPeer,
            orderId,
            amountInToRelease,
            amountOutFilled,
            originRecipient,
            tokenIn,
            messageId
        );
    }

    /// @notice Decodes a fill report payload.
    /// @param  payload           The payload to decode.
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
        uint256 offset = HEADER_LENGTH;

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
            return encodeTokenTransfer(0, bytes32(0), 0, bytes32(0), address(0), bytes32(0), 0, bytes32(0));
        } else if (payloadType == PayloadType.Index) {
            return encodeIndex(0, bytes32(0), 0, bytes32(0));
        } else if (payloadType == PayloadType.RegistrarKey) {
            return encodeRegistrarKey(0, bytes32(0), bytes32(0), bytes32(0), bytes32(0));
        } else if (payloadType == PayloadType.RegistrarList) {
            return encodeRegistrarList(0, bytes32(0), bytes32(0), address(0), false, bytes32(0));
        } else if (payloadType == PayloadType.FillReport) {
            return encodeFillReport(0, bytes32(0), bytes32(0), 0, 0, bytes32(0), bytes32(0), bytes32(0));
        } else if (payloadType == PayloadType.EarnerMerkleRoot) {
            return encodeEarnerMerkleRoot(0, bytes32(0), bytes32(0));
        }

        revert InvalidPayloadType(uint8(payloadType));
    }
}
