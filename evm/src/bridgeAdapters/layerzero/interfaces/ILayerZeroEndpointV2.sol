// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}

/// @title  ILayerZeroEndpointV2
/// @author LayerZero Labs
/// @notice Minimal interface for LayerZero V2 Endpoint used by LayerZeroBridgeAdapter.
/// @dev    See full version at:
///         https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol
interface ILayerZeroEndpointV2 {
    /// @notice Estimates the fee for sending a cross-chain message.
    /// @param  params The messaging parameters (destination, receiver, message, options).
    /// @param  sender The address of the sender.
    /// @return fee    The estimated native and LZ token fees.
    function quote(MessagingParams calldata params, address sender) external view returns (MessagingFee memory fee);

    /// @notice Sends a cross-chain message to the specified destination.
    /// @param  params        The messaging parameters (destination, receiver, message, options).
    /// @param  refundAddress The address to receive excess fee refunds.
    /// @return receipt       The messaging receipt containing guid, nonce, and actual fee.
    function send(MessagingParams calldata params, address refundAddress) external payable returns (MessagingReceipt memory receipt);

    /// @notice Delivers a received message to the specified receiver.
    /// @param  origin    The origin information (source endpoint ID, sender, nonce).
    /// @param  receiver  The address of the receiver contract.
    /// @param  guid      The globally unique identifier of the message.
    /// @param  message   The message payload.
    /// @param  extraData Additional data provided by the executor.
    function lzReceive(
        Origin calldata origin,
        address receiver,
        bytes32 guid,
        bytes calldata message,
        bytes calldata extraData
    ) external payable;

    /// @notice Sets the delegate address authorized to configure LayerZero settings.
    /// @param  delegate The address to grant delegate permissions.
    function setDelegate(address delegate) external;
}
