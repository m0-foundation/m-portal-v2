// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { Origin, SetConfigParam } from "./ILayerZeroTypes.sol";

/// @title  ILayerZeroBridgeAdapter interface.
/// @author M0 Labs
/// @notice Defines interface specific to LayerZero Bridge Adapter.
interface ILayerZeroBridgeAdapter is IBridgeAdapter {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a nonce is skipped for recovery.
    /// @param  srcEid The source endpoint ID.
    /// @param  sender The sender address (bytes32).
    /// @param  nonce  The skipped nonce.
    event NonceSkipped(uint32 indexed srcEid, bytes32 indexed sender, uint64 nonce);

    /// @notice Emitted when a payload is cleared for recovery.
    /// @param  srcEid The source endpoint ID.
    /// @param  sender The sender address (bytes32).
    /// @param  nonce  The nonce of the cleared payload.
    /// @param  guid   The global unique identifier of the message.
    event PayloadCleared(uint32 indexed srcEid, bytes32 indexed sender, uint64 nonce, bytes32 guid);

    /// @notice Emitted when DVN configuration is set for a message library.
    /// @param  lib The message library address.
    /// @param  params The configuration parameters that were set.
    event DVNConfigSet(address indexed lib, SetConfigParam[] params);

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the LayerZero Endpoint address is 0x0.
    error ZeroEndpoint();

    /// @notice Thrown when the message sender is not the expected peer.
    /// @param  sender The actual sender address.
    error InvalidPeer(bytes32 sender);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of the LayerZero Endpoint V2 contract.
    function endpoint() external view returns (address);

    /// @notice Returns the peer address for the given LayerZero endpoint ID.
    /// @dev    Provides OApp-compatible peer query. Maps EID to internal chain ID first.
    /// @param  eid The LayerZero endpoint ID.
    /// @return peer The peer address as bytes32 (zero if not configured).
    function peers(uint32 eid) external view returns (bytes32 peer);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Skips a blocked inbound nonce to unblock subsequent messages.
    /// @dev    Only callable by DEFAULT_ADMIN_ROLE.
    /// @param  srcEid The source endpoint ID.
    /// @param  sender The sender address (bytes32).
    /// @param  nonce  The nonce to skip.
    function skip(uint32 srcEid, bytes32 sender, uint64 nonce) external;

    /// @notice Clears a stored payload hash that failed execution.
    /// @dev    Only callable by DEFAULT_ADMIN_ROLE.
    /// @param  origin  The origin information (srcEid, sender, nonce).
    /// @param  guid    The global unique identifier.
    /// @param  message The original message bytes.
    function clear(Origin calldata origin, bytes32 guid, bytes calldata message) external;

    /// @notice Sets DVN configuration for a message library.
    /// @dev    Only callable by DEFAULT_ADMIN_ROLE. Calls through to LayerZero Endpoint's setConfig().
    /// @param  lib The message library address (send or receive library).
    /// @param  params The configuration parameters to set.
    function setDVNConfig(address lib, SetConfigParam[] calldata params) external;
}
