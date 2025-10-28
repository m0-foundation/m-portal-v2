// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { Ownable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { SafeCast } from
    "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IMailbox } from "./interfaces/IMailbox.sol";
import { IMessageRecipient } from "./interfaces/IMessageRecipient.sol";
import { IHyperlaneBridgeAdapter } from "./interfaces/IHyperlaneBridgeAdapter.sol";
import { StandardHookMetadata } from "./libs/StandardHookMetadata.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";

/// @title  HyperLane Bridge
/// @notice Sends and receives messages to and from remote chains using Hyperlane protocol
contract HyperlaneBridge is Ownable, IHyperlaneBridgeAdapter {
    using TypeConverter for *;
    using SafeCast for uint256;

    /// @inheritdoc IHyperlaneBridgeAdapter
    address public immutable mailbox;

    /// @inheritdoc IBridgeAdapter
    address public immutable portal;

    /// @inheritdoc IHyperlaneBridgeAdapter
    mapping(uint256 destinationChainId => bytes32 destinationPeer) public peer;

    /// @notice Constructs Hyperlane Bridge
    /// @param mailbox_ The address of the Hyperlane Mailbox.
    /// @param portal_  The address of the Portal on the current chain.
    constructor(address mailbox_, address portal_, address initialOwner_) Ownable(initialOwner_) {
        if ((mailbox = mailbox_) == address(0)) revert ZeroMailbox();
        if ((portal = portal_) == address(0)) revert ZeroPortal();
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint256 destinationChainId_, uint256 gasLimit_, bytes memory payload_) external view returns (uint256 fee_) {
        bytes memory metadata_ = StandardHookMetadata.overrideGasLimit(gasLimit_);
        bytes32 peer_ = _getPeer(destinationChainId_);
        uint32 destinationDomain_ = _getHyperlaneDomain(destinationChainId_);

        fee_ = IMailbox(mailbox).quoteDispatch(destinationDomain_, peer_, payload_, metadata_);
    }

    /// @dev Returns zero address, so Mailbox will use the default ISM
    function interchainSecurityModule() external pure returns (address) {
        return address(0);
    }

    /// @inheritdoc IBridgeAdapter
    function sendMessage(uint256 destinationChainId, uint256 gasLimit, bytes32 refundAddress, bytes memory payload) external payable {
        if (msg.sender != portal) revert NotPortal();

        IMailbox mailbox_ = IMailbox(mailbox);
        bytes memory metadata_ = StandardHookMetadata.formatMetadata(0, gasLimit, refundAddress.toAddress(), "");
        bytes32 destinationPeer = _getPeer(destinationChainId);
        uint32 destinationDomain = _getHyperlaneDomain(destinationChainId);

        // NOTE: The transaction reverts if mgs.value isn't enough to cover the fee.
        //       If msg.value is greater than the required fee, the excess is sent to the refund address.
        mailbox_.dispatch{ value: msg.value }(destinationDomain, destinationPeer, payload, metadata_);
    }

    /// @inheritdoc IMessageRecipient
    function handle(uint32 sourceChainId, bytes32 sender, bytes calldata payload) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        if (sender != peer[sourceChainId]) revert UnsupportedSender(sender);
        IPortal(portal).receiveMessage(sourceChainId, payload);
    }

    /// @inheritdoc IHyperlaneBridgeAdapter
    function setPeer(uint256 destinationChainId, bytes32 destinationPeer) external onlyOwner {
        if (destinationChainId == 0) revert ZeroDestinationChain();
        if (destinationPeer == bytes32(0)) revert ZeroPeer();

        peer[destinationChainId] = destinationPeer;
        emit PeerSet(destinationChainId, destinationPeer);
    }

    /// @notice Returns the address of Hyperlane bridge on the destination chain.
    /// @param  destinationChainId The EVM chain id of the destination chain.
    function _getPeer(uint256 destinationChainId) private view returns (bytes32) {
        bytes32 destinationPeer = peer[destinationChainId];
        if (destinationPeer == bytes32(0)) revert UnsupportedDestinationChain(destinationChainId);
        return destinationPeer;
    }

    /// @notice Returns Hyperlane domain by chain Id
    /// @dev    For EVM chains Hyperlane domain IDs match EVM chain IDs, but uses `uint32` type
    ///         https://docs.hyperlane.xyz/docs/reference/domains
    /// @param  chainId The EVM chain Id.
    function _getHyperlaneDomain(uint256 chainId) private pure returns (uint32) {
        // TODO: Add non-EVM chains conversion
        return chainId.toUint32();
    }
}
