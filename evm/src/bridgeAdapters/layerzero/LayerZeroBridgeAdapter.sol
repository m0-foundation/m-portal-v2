// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.30;

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { ILayerZeroBridgeAdapter } from "./interfaces/ILayerZeroBridgeAdapter.sol";
import { ILayerZeroReceiver } from "./interfaces/ILayerZeroReceiver.sol";
import { Origin, MessagingParams, MessagingFee, ILayerZeroEndpointV2 } from "./interfaces/ILayerZeroEndpointV2.sol";
import { OptionsBuilder } from "./libraries/OptionsBuilder.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";

/// @title  LayerZeroBridgeAdapter
/// @author M0 Labs
/// @notice Bridge adapter implementation for LayerZero V2.
contract LayerZeroBridgeAdapter is BridgeAdapter, ILayerZeroBridgeAdapter {
    using TypeConverter for *;
    using OptionsBuilder for bytes;

    /// @inheritdoc ILayerZeroBridgeAdapter
    address public immutable endpoint;

    /// @notice Constructs the LayerZeroBridgeAdapter.
    /// @dev    Sets immutable storage and disables initializers for the implementation contract.
    /// @param  endpoint_ The LayerZero Endpoint V2 address.
    /// @param  portal_   The Portal contract address.
    constructor(address endpoint_, address portal_) BridgeAdapter(portal_) {
        if (endpoint_ == address(0)) revert ZeroEndpoint();
        endpoint = endpoint_;
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address admin, address operator) external initializer {
        _initialize(admin, operator);

        // Sets the operator as a default delegate.
        // The delegate is authorized to configure LayerZero settings, clear, skip messages, etc.
        // by interacting directly with LayerZero Endpoint on behalf of this contract.
        ILayerZeroEndpointV2(endpoint).setDelegate(operator);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IBridgeAdapter
    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata /* extraArguments */
    ) external payable {
        _revertIfNotPortal();

        bytes memory options = _buildOptions(gasLimit);
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint32 destinationEid = _getLayerZeroEndpointIdOrRevert(destinationChainId);

        // NOTE: The transaction reverts if msg.value isn't enough to cover the fee.
        //       If msg.value is greater than the required fee, the excess is sent to the refund address.
        ILayerZeroEndpointV2(endpoint).send{ value: msg.value }(
            MessagingParams(destinationEid, destinationPeer, payload, options, false), refundAddress.toAddress()
        );
    }

    /// @inheritdoc ILayerZeroReceiver
    function lzReceive(
        Origin calldata origin,
        bytes32, /* LayerZero message guid */
        bytes calldata payload,
        address, /* executor */
        bytes calldata /* extraData */
    ) external payable {
        if (msg.sender != endpoint) revert NotEndpoint();
        // Convert LayerZero Endpoint ID to internal chain ID
        uint32 sourceChainId = _getChainIdOrRevert(origin.srcEid);
        if (origin.sender != _getPeerOrRevert(sourceChainId)) revert UnsupportedSender(origin.sender);

        IPortal(portal).receiveMessage(sourceChainId, payload);
    }

    /// @inheritdoc ILayerZeroBridgeAdapter
    function setDelegate(address delegate) external onlyRole(OPERATOR_ROLE) {
        ILayerZeroEndpointV2(endpoint).setDelegate(delegate);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                    EXTERNAL VIEW/PURE FUNCTIONS                       //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IBridgeAdapter
    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee) {
        bytes memory options = _buildOptions(gasLimit);
        uint32 destinationEid = _getLayerZeroEndpointIdOrRevert(destinationChainId);
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);

        MessagingFee memory messagingFee =
            ILayerZeroEndpointV2(endpoint).quote(MessagingParams(destinationEid, destinationPeer, payload, options, false), address(this));
        return messagingFee.nativeFee;
    }

    /// @inheritdoc ILayerZeroReceiver
    function allowInitializePath(Origin calldata origin) external view returns (bool) {
        // The path is assumed to be initialized if the peer was set.
        // The same logic is used in LayerZero OAppReceiver implementation:
        // https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oapp/OAppReceiver.sol#L63
        return _getPeer(_getChainId(origin.srcEid)) == origin.sender;
    }

    /// @inheritdoc ILayerZeroReceiver
    function nextNonce(uint32 /* srcEid */, bytes32 /* sender */) external pure returns (uint64) {
        // Hardcode to 0 for unordered execution.
        return 0;
    }

    ///////////////////////////////////////////////////////////////////////////
    //                      PRIVATE VIEW/PURE FUNCTIONS                      //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Builds LayerZero execution options with the specified gas limit.
    /// @param  gasLimit The gas limit for destination execution.
    /// @return options The encoded options bytes.
    function _buildOptions(uint256 gasLimit) internal pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit.toUint128(), 0);
    }

    /// @notice Returns LayerZero Endpoint Id by chain Id
    /// @dev    https://docs.layerzero.network/v2/deployments/deployed-contracts?stages=mainnet
    function _getLayerZeroEndpointIdOrRevert(uint32 chainId) private view returns (uint32) {
        return _getBridgeChainIdOrRevert(chainId).toUint32();
    }
}
