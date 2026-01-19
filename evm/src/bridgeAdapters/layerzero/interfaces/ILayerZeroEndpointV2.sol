// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Origin, MessagingFee, MessagingParams, MessagingReceipt, SetConfigParam } from "./ILayerZeroTypes.sol";

/// @title  ILayerZeroEndpointV2
/// @notice Interface for LayerZero Endpoint V2 contract.
/// @dev    Minimal interface with only the functions needed by the bridge adapter.
interface ILayerZeroEndpointV2 {
    /// @notice Sends a message to the specified destination.
    /// @param  _params The messaging parameters.
    /// @param  _refundAddress The address to refund excess fees.
    /// @return receipt The messaging receipt containing guid, nonce, and fee.
    function send(MessagingParams calldata _params, address _refundAddress) external payable returns (MessagingReceipt memory receipt);

    /// @notice Quotes the fee required to send a message.
    /// @param  _params The messaging parameters.
    /// @param  _sender The sender address (OApp).
    /// @return fee The messaging fee (nativeFee and lzTokenFee).
    function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory fee);

    /// @notice Sets the delegate for the calling OApp.
    /// @param  _delegate The delegate address.
    function setDelegate(address _delegate) external;

    /// @notice Skips a blocked inbound nonce to unblock subsequent messages.
    /// @param  _oapp The OApp address.
    /// @param  _srcEid The source endpoint ID.
    /// @param  _sender The sender address (bytes32).
    /// @param  _nonce The nonce to skip.
    function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external;

    /// @notice Clears a stored payload hash that failed execution.
    /// @param  _oapp The OApp address.
    /// @param  _origin The origin information.
    /// @param  _guid The global unique identifier.
    /// @param  _message The original message bytes.
    function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external;

    /// @notice Sets configuration for the OApp in the specified message library.
    /// @param  _oapp The OApp address.
    /// @param  _lib The message library address.
    /// @param  _params The configuration parameters.
    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;

    /// @notice Returns the send library address for the OApp to a specific destination EID.
    /// @param  _sender The OApp address.
    /// @param  _dstEid The destination endpoint ID.
    /// @return lib The send library address.
    function getSendLibrary(address _sender, uint32 _dstEid) external view returns (address lib);

    /// @notice Returns the receive library address for the OApp from a specific source EID.
    /// @param  _receiver The OApp address.
    /// @param  _srcEid The source endpoint ID.
    /// @return lib The receive library address.
    /// @return isDefault Whether it is the default library.
    function getReceiveLibrary(address _receiver, uint32 _srcEid) external view returns (address lib, bool isDefault);
}
