// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

/// @notice Origin struct for incoming LayerZero messages.
/// @param  srcEid The source endpoint ID.
/// @param  sender The sender address as bytes32.
/// @param  nonce  The message nonce.
struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

/// @notice MessagingFee struct for LayerZero fee handling.
/// @param  nativeFee Fee in native token.
/// @param  lzTokenFee Fee in LZ token (typically 0).
struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

/// @notice MessagingReceipt returned from send.
/// @param  guid Global unique identifier.
/// @param  nonce Assigned nonce.
/// @param  fee Actual fee charged.
struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

/// @notice MessagingParams for send function.
/// @param  dstEid Destination endpoint ID.
/// @param  receiver Receiver address as bytes32.
/// @param  message Message payload.
/// @param  options Execution options.
/// @param  payInLzToken Whether to pay in LZ token.
struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

/// @notice Parameters for setting configuration on a message library.
/// @param  eid The endpoint ID this config applies to.
/// @param  configType The configuration type (e.g., CONFIG_TYPE_ULN for DVN settings).
/// @param  config The encoded configuration bytes.
struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}
