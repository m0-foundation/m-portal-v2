// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { ILayerZeroBridgeAdapter } from "./interfaces/ILayerZeroBridgeAdapter.sol";
import { ILayerZeroEndpointV2 } from "./interfaces/ILayerZeroEndpointV2.sol";
import { Origin, MessagingFee, MessagingReceipt, SetConfigParam } from "./interfaces/ILayerZeroTypes.sol";
import { OAppReceiver } from "./oapp/OAppReceiver.sol";
import { OptionsBuilder } from "./libraries/OptionsBuilder.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";

/// @title  LayerZeroBridgeAdapter
/// @author M0 Labs
/// @notice Bridge adapter implementation for LayerZero V2.
/// @dev    Inherits from BridgeAdapter for common adapter functionality and OAppReceiver for LayerZero receive callbacks.
contract LayerZeroBridgeAdapter is BridgeAdapter, OAppReceiver, ILayerZeroBridgeAdapter {
    using TypeConverter for *;
    using OptionsBuilder for bytes;

    // ═══════════════════════════════════════════════════════════════════════
    //                              IMMUTABLES
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc ILayerZeroBridgeAdapter
    address public immutable endpoint;

    // ═══════════════════════════════════════════════════════════════════════
    //                             CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Constructs the LayerZeroBridgeAdapter.
    /// @dev    Sets immutable storage and disables initializers for the implementation contract.
    /// @param  endpoint_ The LayerZero Endpoint V2 address.
    /// @param  portal_   The Portal contract address.
    constructor(address endpoint_, address portal_) BridgeAdapter(portal_) OAppReceiver(endpoint_) {
        if (endpoint_ == address(0)) revert ZeroEndpoint();
        endpoint = endpoint_;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         INITIALIZER FUNCTION
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Initializes the adapter proxy.
    /// @param  admin_    The admin address with DEFAULT_ADMIN_ROLE.
    /// @param  operator_ The operator address with OPERATOR_ROLE.
    function initialize(address admin_, address operator_) external initializer {
        _initialize(admin_, operator_);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          VIEW/PURE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Returns the peer address for the given LayerZero endpoint ID.
    /// @dev    Provides OApp-compatible peer query. Maps EID to internal chain ID first.
    /// @param  eid The LayerZero endpoint ID.
    /// @return peer The peer address as bytes32 (zero if not configured).
    function peers(uint32 eid) external view returns (bytes32 peer) {
        return _getPeerForEid(eid);
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee) {
        // Build options with the same logic as sendMessage
        bytes memory options = _buildOptions(gasLimit);

        // Convert internal chain ID to LayerZero EID
        uint32 dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32();

        // Verify peer is configured (validates chain is supported)
        _getPeerOrRevert(destinationChainId);

        // Get quote from endpoint
        MessagingFee memory messagingFee = _quote(dstEid, payload, options, false);
        return messagingFee.nativeFee;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                         INTERACTIVE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Sends a message to the destination chain via LayerZero.
    /// @param  destinationChainId The M0 internal chain ID of the destination.
    /// @param  gasLimit The gas limit for execution on the destination.
    /// @param  refundAddress The address to refund excess fees (as bytes32).
    /// @param  payload The message payload.
    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata /* extraArguments */
    ) external payable {
        _revertIfNotPortal();

        // Get peer and verify chain is configured
        _getPeerOrRevert(destinationChainId);

        // Convert internal chain ID to LayerZero EID
        uint32 dstEid = _getBridgeChainIdOrRevert(destinationChainId).toUint32();

        // Build execution options
        bytes memory options = _buildOptions(gasLimit);

        // Send via LayerZero - excess fees are refunded to refundAddress
        _lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), refundAddress.toAddress());
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          PRIVILEGED FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @inheritdoc ILayerZeroBridgeAdapter
    function skip(uint32 srcEid, bytes32 sender, uint64 nonce) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ILayerZeroEndpointV2(endpoint).skip(address(this), srcEid, sender, nonce);
        emit NonceSkipped(srcEid, sender, nonce);
    }

    /// @inheritdoc ILayerZeroBridgeAdapter
    function clear(Origin calldata origin, bytes32 guid, bytes calldata message) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ILayerZeroEndpointV2(endpoint).clear(address(this), origin, guid, message);
        emit PayloadCleared(origin.srcEid, origin.sender, origin.nonce, guid);
    }

    /// @inheritdoc ILayerZeroBridgeAdapter
    function setDVNConfig(address lib, SetConfigParam[] calldata params) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ILayerZeroEndpointV2(endpoint).setConfig(address(this), lib, params);
        emit DVNConfigSet(lib, params);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                          INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Handles incoming LayerZero messages.
    /// @dev    Called by OAppReceiver.lzReceive after endpoint validation.
    /// @param  _origin The origin information (srcEid, sender, nonce).
    /// @param  _message The message payload.
    function _lzReceive(
        Origin calldata _origin,
        bytes32,
        /* _guid */
        bytes calldata _message,
        address,
        /* _executor */
        bytes calldata /* _extraData */
    ) internal override {
        // Convert LayerZero EID to internal chain ID
        uint32 sourceChainId = _getChainIdOrRevert(_origin.srcEid);

        // Verify sender is the configured peer for this source chain
        if (_origin.sender != _getPeer(sourceChainId)) revert InvalidPeer(_origin.sender);

        // Forward message to Portal
        IPortal(portal).receiveMessage(sourceChainId, _message);
    }

    /// @notice Returns the peer address for the given LayerZero endpoint ID.
    /// @dev    Implements OAppCore._getPeerForEid by mapping EID to internal chain ID first.
    /// @param  _eid The LayerZero endpoint ID.
    /// @return peer The peer address as bytes32.
    function _getPeerForEid(uint32 _eid) internal view override returns (bytes32 peer) {
        // Convert LayerZero EID to internal chain ID, then get peer
        uint32 chainId = _getChainId(_eid);
        if (chainId == 0) return bytes32(0);
        return _getPeer(chainId);
    }

    /// @notice Builds LayerZero execution options with the specified gas limit.
    /// @param  gasLimit The gas limit for destination execution.
    /// @return options The encoded options bytes.
    function _buildOptions(uint256 gasLimit) internal pure returns (bytes memory options) {
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(gasLimit), 0);
    }
}
