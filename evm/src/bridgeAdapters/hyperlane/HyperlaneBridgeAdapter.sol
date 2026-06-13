// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IMailbox } from "./interfaces/IMailbox.sol";
import { IMessageRecipient } from "./interfaces/IMessageRecipient.sol";
import { IHyperlaneBridgeAdapter } from "./interfaces/IHyperlaneBridgeAdapter.sol";
import { StandardHookMetadata } from "./libraries/StandardHookMetadata.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";

abstract contract HyperlaneBridgeAdapterStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.HyperlaneBridgeAdapter
    struct HyperlaneBridgeAdapterStorageStruct {
        /// @notice ERC20 used to pay dispatch fees; 0x0 means fees are paid in native value.
        address feeToken;
        /// @notice IGP approved to pull `feeToken` payments at dispatch time.
        address interchainGasPaymaster;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.HyperlaneBridgeAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant HYPERLANE_BRIDGE_ADAPTER_STORAGE_LOCATION = 0x158a023759c3908307e29f8c383800a2a933ca03be7b8c6947e01b3ed187ec00;

    function _getHyperlaneBridgeAdapterStorageLocation() internal pure returns (HyperlaneBridgeAdapterStorageStruct storage $) {
        assembly {
            $.slot := HYPERLANE_BRIDGE_ADAPTER_STORAGE_LOCATION
        }
    }
}

/// @title  HyperLane Bridge Adapter
/// @author M0 Labs
/// @notice Sends and receives messages to and from remote chains using Hyperlane protocol
contract HyperlaneBridgeAdapter is BridgeAdapter, HyperlaneBridgeAdapterStorageLayout, IHyperlaneBridgeAdapter {
    using TypeConverter for *;
    using SafeERC20 for IERC20;

    /// @inheritdoc IHyperlaneBridgeAdapter
    address public immutable mailbox;

    /// @notice Constructs Hyperlane Bridge Adapter Implementation contract
    /// @param mailbox_ The address of the Hyperlane Mailbox.
    /// @param portal_  The address of the Portal on the current chain.
    constructor(address mailbox_, address portal_) BridgeAdapter(portal_) {
        if ((mailbox = mailbox_) == address(0)) revert ZeroMailbox();
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address admin, address operator) external initializer {
        _initialize(admin, operator);
    }

    /// @inheritdoc IHyperlaneBridgeAdapter
    function setFeeToken(address feeToken_, address interchainGasPaymaster_) external onlyRole(OPERATOR_ROLE) {
        if (feeToken_ == address(0)) {
            interchainGasPaymaster_ = address(0);
        } else if (interchainGasPaymaster_ == address(0)) {
            revert ZeroInterchainGasPaymaster();
        }

        HyperlaneBridgeAdapterStorageStruct storage $ = _getHyperlaneBridgeAdapterStorageLocation();

        $.feeToken = feeToken_;
        $.interchainGasPaymaster = interchainGasPaymaster_;

        emit FeeTokenSet(feeToken_, interchainGasPaymaster_);
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee) {
        // In fee token mode the adapter pays the dispatch fee in the fee token, so callers attach no native value.
        if (_getHyperlaneBridgeAdapterStorageLocation().feeToken != address(0)) return 0;

        return _quoteDispatch(destinationChainId, StandardHookMetadata.overrideGasLimit(gasLimit), payload);
    }

    /// @inheritdoc IHyperlaneBridgeAdapter
    function quoteFeeToken(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256) {
        address feeToken_ = _getHyperlaneBridgeAdapterStorageLocation().feeToken;
        if (feeToken_ == address(0)) return 0;

        return _quoteDispatch(destinationChainId, StandardHookMetadata.formatWithFeeToken(0, gasLimit, msg.sender, feeToken_), payload);
    }

    /// @inheritdoc IHyperlaneBridgeAdapter
    function feeToken() external view returns (address) {
        return _getHyperlaneBridgeAdapterStorageLocation().feeToken;
    }

    /// @inheritdoc IHyperlaneBridgeAdapter
    function interchainGasPaymaster() external view returns (address) {
        return _getHyperlaneBridgeAdapterStorageLocation().interchainGasPaymaster;
    }

    /// @dev Returns zero address, so Mailbox will use the default ISM
    function interchainSecurityModule() external pure returns (address) {
        return address(0);
    }

    /// @inheritdoc IBridgeAdapter
    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata /* extraArguments */
    ) external payable {
        _revertIfNotPortal();

        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint32 destinationDomain = _getHyperlaneDomainOrRevert(destinationChainId);

        HyperlaneBridgeAdapterStorageStruct storage $ = _getHyperlaneBridgeAdapterStorageLocation();
        address feeToken_ = $.feeToken;

        if (feeToken_ == address(0)) {
            bytes memory metadata = StandardHookMetadata.formatMetadata(0, gasLimit, refundAddress.toAddress(), "");

            // NOTE: The transaction reverts if msg.value isn't enough to cover the fee.
            //       If msg.value is greater than the required fee, the excess is sent to the refund address.
            IMailbox(mailbox).dispatch{ value: msg.value }(destinationDomain, destinationPeer, payload, metadata);
        } else {
            // Fee token mode (e.g. Seismic, where value-bearing transactions are not mined):
            // the adapter holds the fee token and the IGP pulls the quoted fee via transferFrom.
            // The IGP reverts if native value is sent alongside an ERC20 fee.
            if (msg.value != 0) revert UnexpectedNativeValue();

            bytes memory metadata = StandardHookMetadata.formatWithFeeToken(0, gasLimit, refundAddress.toAddress(), feeToken_);
            uint256 fee = IMailbox(mailbox).quoteDispatch(destinationDomain, destinationPeer, payload, metadata);

            IERC20(feeToken_).forceApprove($.interchainGasPaymaster, fee);

            IMailbox(mailbox).dispatch(destinationDomain, destinationPeer, payload, metadata);
        }
    }

    /// @inheritdoc IMessageRecipient
    function handle(uint32 sourceBridgeChainId, bytes32 sender, bytes calldata payload) external payable {
        if (msg.sender != mailbox) revert NotMailbox();
        // Convert Hyperlane domain to internal chain ID
        uint32 sourceChainId = _getChainIdOrRevert(sourceBridgeChainId);
        if (sender != _getPeerOrRevert(sourceChainId)) revert UnsupportedSender(sender);

        IPortal(portal).receiveMessage(sourceChainId, payload);
    }

    /// @notice Resolves the destination route and quotes the Hyperlane dispatch fee for the given metadata.
    /// @param  destinationChainId The M0 internal chain ID of the destination.
    /// @param  metadata           The standard hook metadata (native or fee-token variant).
    /// @param  payload            The message payload.
    /// @return The dispatch fee, denominated in native value or in the fee token per the metadata.
    function _quoteDispatch(uint32 destinationChainId, bytes memory metadata, bytes memory payload) private view returns (uint256) {
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint32 destinationDomain = _getHyperlaneDomainOrRevert(destinationChainId);

        return IMailbox(mailbox).quoteDispatch(destinationDomain, destinationPeer, payload, metadata);
    }

    /// @notice Returns Hyperlane domain by chain Id
    /// @dev    https://docs.hyperlane.xyz/docs/reference/domains
    function _getHyperlaneDomainOrRevert(uint32 chainId) private view returns (uint32) {
        return _getBridgeChainIdOrRevert(chainId).toUint32();
    }
}
