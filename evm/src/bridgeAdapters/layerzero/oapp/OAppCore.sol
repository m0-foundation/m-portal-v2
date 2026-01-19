// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ILayerZeroEndpointV2 } from "../interfaces/ILayerZeroEndpointV2.sol";
import { MessagingFee, MessagingParams, MessagingReceipt } from "../interfaces/ILayerZeroTypes.sol";

/// @title  OAppCore
/// @notice Abstract contract providing core OApp functionality for LayerZero V2.
/// @dev    This is a minimal implementation tailored for the LayerZeroBridgeAdapter.
///         Unlike the standard OApp, peer management is handled by BridgeAdapter base contract.
abstract contract OAppCore {
    /// @notice The LayerZero Endpoint V2 contract.
    ILayerZeroEndpointV2 public immutable lzEndpoint;

    /// @notice Constructs the OAppCore.
    /// @param  _endpoint The LayerZero Endpoint V2 address.
    constructor(address _endpoint) {
        lzEndpoint = ILayerZeroEndpointV2(_endpoint);
    }

    /// @notice Internal function to send a message via LayerZero.
    /// @param  _dstEid The destination endpoint ID.
    /// @param  _message The message payload.
    /// @param  _options The execution options.
    /// @param  _fee The messaging fee.
    /// @param  _refundAddress The address to refund excess fees.
    /// @return receipt The messaging receipt.
    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal virtual returns (MessagingReceipt memory receipt) {
        // Get peer from the inheriting contract (BridgeAdapter provides this via _getPeerForEid)
        bytes32 peer = _getPeerForEid(_dstEid);

        receipt = lzEndpoint.send{ value: _fee.nativeFee }(MessagingParams(_dstEid, peer, _message, _options, false), _refundAddress);
    }

    /// @notice Internal function to quote the fee for sending a message.
    /// @param  _dstEid The destination endpoint ID.
    /// @param  _message The message payload.
    /// @param  _options The execution options.
    /// @param  _payInLzToken Whether to pay in LZ token.
    /// @return fee The messaging fee.
    function _quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) internal view virtual returns (MessagingFee memory fee) {
        bytes32 peer = _getPeerForEid(_dstEid);

        return lzEndpoint.quote(MessagingParams(_dstEid, peer, _message, _options, _payInLzToken), address(this));
    }

    /// @notice Returns the peer address for the given endpoint ID.
    /// @dev    Must be implemented by the inheriting contract (BridgeAdapter).
    /// @param  _eid The endpoint ID.
    /// @return peer The peer address as bytes32.
    function _getPeerForEid(uint32 _eid) internal view virtual returns (bytes32 peer);
}
