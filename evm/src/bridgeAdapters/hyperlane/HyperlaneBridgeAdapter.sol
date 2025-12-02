// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IMailbox } from "./interfaces/IMailbox.sol";
import { IMessageRecipient } from "./interfaces/IMessageRecipient.sol";
import { IHyperlaneBridgeAdapter } from "./interfaces/IHyperlaneBridgeAdapter.sol";
import { StandardHookMetadata } from "./libs/StandardHookMetadata.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";

/// @title  HyperLane Bridge Adapter
/// @notice Sends and receives messages to and from remote chains using Hyperlane protocol
contract HyperlaneBridge is BridgeAdapter, IHyperlaneBridgeAdapter {
    using TypeConverter for *;

    /// @inheritdoc IHyperlaneBridgeAdapter
    address public immutable mailbox;

    /// @notice Constructs Hyperlane Bridge Adapter Implementation contract
    /// @param mailbox_ The address of the Hyperlane Mailbox.
    /// @param portal_  The address of the Portal on the current chain.
    constructor(address mailbox_, address portal_) BridgeAdapter(portal_) {
        if ((mailbox = mailbox_) == address(0)) revert ZeroMailbox();
    }

    function initialize(address owner, address operator) external initializer {
        _initialize(owner, operator);
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee) {
        bytes memory metadata = StandardHookMetadata.overrideGasLimit(gasLimit);
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint32 destinationDomain = _getHyperlaneDomainOrRevert(destinationChainId);

        return IMailbox(mailbox).quoteDispatch(destinationDomain, destinationPeer, payload, metadata);
    }

    /// @dev Returns zero address, so Mailbox will use the default ISM
    function interchainSecurityModule() external pure returns (address) {
        return address(0);
    }

    /// @inheritdoc IBridgeAdapter
    function sendMessage(uint32 destinationChainId, uint256 gasLimit, bytes32 refundAddress, bytes memory payload, bytes calldata) external payable {
        _revertIfNotPortal();

        IMailbox mailbox_ = IMailbox(mailbox);
        bytes memory metadata_ = StandardHookMetadata.formatMetadata(0, gasLimit, refundAddress.toAddress(), "");
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint32 destinationDomain = _getHyperlaneDomainOrRevert(destinationChainId);

        // NOTE: The transaction reverts if mgs.value isn't enough to cover the fee.
        //       If msg.value is greater than the required fee, the excess is sent to the refund address.
        mailbox_.dispatch{ value: msg.value }(destinationDomain, destinationPeer, payload, metadata_);
    }

    /// @inheritdoc IMessageRecipient
    function handle(uint32 sourceBridgeChainId, bytes32 sender, bytes calldata payload) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        // Covert Hyperlane domain to internal chain ID
        uint32 sourceChainId = _getChainIdOrRevert(sourceBridgeChainId);
        if (sender != _getPeer(sourceChainId)) revert UnsupportedSender(sender);

        IPortal(portal).receiveMessage(sourceChainId, payload);
    }

    /// @notice Returns Hyperlane domain by chain Id
    /// @dev    https://docs.hyperlane.xyz/docs/reference/domains
    function _getHyperlaneDomainOrRevert(uint32 chainId) private view returns (uint32) {
        return _getBridgeChainIdOrRevert(chainId).toUint32();
    }
}
