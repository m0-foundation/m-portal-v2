// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { OAppCore } from "./OAppCore.sol";
import { Origin } from "../interfaces/ILayerZeroTypes.sol";

/// @title  OAppReceiver
/// @notice Abstract contract for receiving LayerZero V2 messages.
/// @dev    This is a minimal implementation tailored for the LayerZeroBridgeAdapter.
abstract contract OAppReceiver is OAppCore {
    /// @notice The receiver version for LayerZero compatibility.
    uint64 public constant RECEIVER_VERSION = 2;

    /// @notice Thrown when the caller is not the LayerZero Endpoint.
    error OnlyEndpoint(address caller);

    /// @notice Constructs the OAppReceiver.
    /// @param  _endpoint The LayerZero Endpoint V2 address.
    constructor(address _endpoint) OAppCore(_endpoint) { }

    /// @notice Returns the OApp version (sender and receiver versions).
    /// @dev    Sender version is 0 since this adapter doesn't use OAppSender directly.
    /// @return senderVersion The sender version (0 for receive-only).
    /// @return receiverVersion The receiver version.
    function oAppVersion() public pure virtual returns (uint64 senderVersion, uint64 receiverVersion) {
        return (0, RECEIVER_VERSION);
    }

    /// @notice Checks if initialization is allowed for the given path.
    /// @dev    Returns true if the peer is set for the source endpoint ID.
    /// @param  _origin The origin information.
    /// @return Whether initialization is allowed.
    function allowInitializePath(Origin calldata _origin) public view virtual returns (bool) {
        return _getPeerForEid(_origin.srcEid) != bytes32(0);
    }

    /// @notice Returns the next nonce for the given source endpoint and sender.
    /// @dev    Returns 0 to indicate unordered delivery (no nonce enforcement).
    /// @param  _srcEid The source endpoint ID.
    /// @param  _sender The sender address.
    /// @return nonce The next nonce (0 for unordered).
    function nextNonce(uint32 _srcEid, bytes32 _sender) public view virtual returns (uint64 nonce) {
        // Silence unused parameter warnings
        _srcEid;
        _sender;
        // Return 0 for unordered execution
        return 0;
    }

    /// @notice Entry point for receiving LayerZero messages.
    /// @dev    Only callable by the LayerZero Endpoint. Validates endpoint and delegates to _lzReceive.
    /// @param  _origin The origin information (srcEid, sender, nonce).
    /// @param  _guid The global unique identifier.
    /// @param  _message The message payload.
    /// @param  _executor The executor address.
    /// @param  _extraData Additional data.
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable virtual {
        // Verify caller is the LayerZero Endpoint
        if (msg.sender != address(lzEndpoint)) revert OnlyEndpoint(msg.sender);

        // Delegate to internal implementation
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /// @notice Internal function to handle received messages.
    /// @dev    Must be implemented by the inheriting contract.
    /// @param  _origin The origin information.
    /// @param  _guid The global unique identifier.
    /// @param  _message The message payload.
    /// @param  _executor The executor address.
    /// @param  _extraData Additional data.
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual;
}
