// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";

import { IBridgeAdapter } from "./interfaces/IBridgeAdapter.sol";
import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { IPortal, ChainConfig } from "./interfaces/IPortal.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";
import { TypeConverter } from "./libraries/TypeConverter.sol";

abstract contract HubPortalStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.Portal
    struct HubPortalStorageStruct {
        bool wasEarningEnabled;
        uint128 disableEarningIndex;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.HubPortal")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant HUB_PORTAL_STORAGE_LOCATION = 0xa5b90c3f089c3e60896514f7e936c66a2ae73f34e81023f4d0032218558d8b00;

    function _getHubPortalStorageLocation() internal pure returns (HubPortalStorageStruct storage $) {
        assembly {
            $.slot := HUB_PORTAL_STORAGE_LOCATION
        }
    }
}

/// @title  HubPortal
/// @author M0 Labs
/// @notice Deployed on Ethereum and responsible for sending and receiving M tokens
///         as well as propagating M token index, Registrar keys and list status to the Spoke chain.
/// @dev    Tokens are bridged using lock-release mechanism.
contract HubPortal is Portal, HubPortalStorageLayout, IHubPortal {
    using TypeConverter for uint256;

    /// @notice Constructs HubPortal Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  mToken_       The address of M token.
    /// @param  registrar_    The address of Registrar.
    /// @param  swapFacility_ The address of Swap Facility.
    /// @param  orderBook_    The address of Order Book.
    constructor(
        address mToken_,
        address registrar_,
        address swapFacility_,
        address orderBook_
    ) Portal(mToken_, registrar_, swapFacility_, orderBook_) { }

    /// @inheritdoc IPortal
    function initialize(address initialOwner, address initialPauser, address initialOperator) external initializer {
        _initialize(initialOwner, initialPauser, initialOperator);

        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        $.disableEarningIndex = IndexingMath.EXP_SCALED_ONE;
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IHubPortal
    function sendMTokenIndex(uint32 destinationChainId, bytes32 refundAddress) external payable whenNotPaused returns (bytes32 messageId) {
        address bridgeAdapter = defaultBridgeAdapter(destinationChainId);
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendMTokenIndex(destinationChainId, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function sendMTokenIndex(
        uint32 destinationChainId,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable whenNotPaused returns (bytes32 messageId) {
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendMTokenIndex(destinationChainId, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint32 destinationChainId,
        bytes32 key,
        bytes32 refundAddress
    ) external payable whenNotPaused returns (bytes32 messageId) {
        address bridgeAdapter = defaultBridgeAdapter(destinationChainId);
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendRegistrarKey(destinationChainId, key, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarKey(
        uint32 destinationChainId,
        bytes32 key,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable whenNotPaused returns (bytes32 messageId) {
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendRegistrarKey(destinationChainId, key, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint32 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress
    ) external payable whenNotPaused returns (bytes32 messageId) {
        address bridgeAdapter = defaultBridgeAdapter(destinationChainId);
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendRegistrarListStatus(destinationChainId, listName, account, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function sendRegistrarListStatus(
        uint32 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable whenNotPaused returns (bytes32 messageId) {
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        return _sendRegistrarListStatus(destinationChainId, listName, account, refundAddress, bridgeAdapter);
    }

    /// @inheritdoc IHubPortal
    function enableEarning() external {
        if (_isEarningEnabled()) revert EarningIsEnabled();

        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        if ($.wasEarningEnabled) revert EarningCannotBeReenabled();

        $.wasEarningEnabled = true;

        IMTokenLike(mToken).startEarning();

        emit EarningEnabled(IMTokenLike(mToken).currentIndex());
    }

    /// @inheritdoc IHubPortal
    function disableEarning() external {
        if (!_isEarningEnabled()) revert EarningIsDisabled();

        uint128 currentMIndex = IMTokenLike(mToken).currentIndex();

        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        $.disableEarningIndex = currentMIndex;

        IMTokenLike(mToken).stopEarning(address(this));

        emit EarningDisabled(currentMIndex);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL VIEW/PURE FUNCTIONS                      //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IHubPortal
    function wasEarningEnabled() public view returns (bool) {
        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        return $.wasEarningEnabled;
    }

    /// @inheritdoc IHubPortal
    function disableEarningIndex() public view returns (uint128) {
        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        return $.disableEarningIndex;
    }

    ///////////////////////////////////////////////////////////////////////////
    //                INTERNAL/PRIVATE INTERACTIVE FUNCTIONS                 //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Sends the M token index to the destination chain.
    function _sendMTokenIndex(uint32 destinationChainId, bytes32 refundAddress, address bridgeAdapter) private returns (bytes32 messageId) {
        _revertIfZeroRefundAddress(refundAddress);

        uint128 index = _currentIndex();
        messageId = _getMessageId(destinationChainId);
        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);

        _sendMessage(destinationChainId, PayloadType.Index, refundAddress, payload, bridgeAdapter);

        emit MTokenIndexSent(destinationChainId, index, bridgeAdapter, messageId);
    }

    /// @dev Sends the Registrar key to the destination chain.
    function _sendRegistrarKey(
        uint32 destinationChainId,
        bytes32 key,
        bytes32 refundAddress,
        address bridgeAdapter
    ) private returns (bytes32 messageId) {
        _revertIfZeroRefundAddress(refundAddress);

        bytes32 value = IRegistrarLike(registrar).get(key);
        messageId = _getMessageId(destinationChainId);
        bytes memory payload = PayloadEncoder.encodeRegistrarKey(key, value, messageId);

        _sendMessage(destinationChainId, PayloadType.RegistrarKey, refundAddress, payload, bridgeAdapter);

        emit RegistrarKeySent(destinationChainId, key, value, bridgeAdapter, messageId);
    }

    /// @dev Sends the Registrar list status for an account to the destination chain.
    function _sendRegistrarListStatus(
        uint32 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress,
        address bridgeAdapter
    ) private returns (bytes32 messageId) {
        _revertIfZeroRefundAddress(refundAddress);

        bool status = IRegistrarLike(registrar).listContains(listName, account);
        messageId = _getMessageId(destinationChainId);
        bytes memory payload = PayloadEncoder.encodeRegistrarList(listName, account, status, messageId);

        _sendMessage(destinationChainId, PayloadType.RegistrarList, refundAddress, payload, bridgeAdapter);

        emit RegistrarListStatusSent(destinationChainId, listName, account, status, bridgeAdapter, messageId);
    }

    /// @dev Unlocks M tokens to `recipient_`.
    /// @param recipient The account to unlock/transfer M tokens to.
    /// @param amount    The amount of M Token to unlock to the recipient.
    function _mintOrUnlock(address recipient, uint256 amount, uint128) internal override {
        if (recipient != address(this)) {
            IERC20(mToken).transfer(recipient, amount);
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    //                 INTERNAL/PRIVATE VIEW/PURE FUNCTIONS                  //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev If earning is enabled returns the current M token index,
    ///      otherwise, returns the index at the time when earning was disabled.
    function _currentIndex() internal view override returns (uint128) {
        return _isEarningEnabled() ? IMTokenLike(mToken).currentIndex() : disableEarningIndex();
    }

    /// @dev Returns whether earning was enabled for HubPortal or not.
    function _isEarningEnabled() internal view returns (bool) {
        return wasEarningEnabled() && disableEarningIndex() == IndexingMath.EXP_SCALED_ONE;
    }
}
