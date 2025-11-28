// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";

import { IBridgeAdapter } from "./interfaces/IBridgeAdapter.sol";
import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { IPortal, ChainConfig } from "./interfaces/IPortal.sol";
import { IHubPortal, SpokeChainConfig } from "./interfaces/IHubPortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";
import { TypeConverter } from "./libraries/TypeConverter.sol";

abstract contract HubPortalStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.HubPortal
    struct HubPortalStorageStruct {
        bool wasEarningEnabled;
        uint128 disableEarningIndex;
        mapping(uint32 spokeChainId => SpokeChainConfig) spokeConfig;
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
    using TypeConverter for *;

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
    function initialize(address owner, address pauser, address operator) external initializer {
        _initialize(owner, pauser, operator);

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

    /// @inheritdoc IHubPortal
    function bridgedPrincipal(uint32 spokeChainId) external view returns (uint248) {
        HubPortalStorageStruct storage $ = _getHubPortalStorageLocation();
        return $.spokeConfig[spokeChainId].bridgedPrincipal;
    }

    /// @inheritdoc IHubPortal
    function treasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
    // TODO: Confirm if OZ UUPS contains receive function as that'll take precedence over this one

    ///////////////////////////////////////////////////////////////////////////
    //                          RECEIVE FUNCTIONS                            //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Allows funding the Hub treasury for bridge fees.
    receive() external payable {
        emit TreasuryFunded(msg.sender, msg.value);
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

    /// @dev Unlocks M tokens to `recipient`.
    /// @param sourceChainId The ID of the source chain.
    /// @param recipient     The account to unlock/transfer M tokens to.
    /// @param amount        The amount of M Token to unlock to the recipient.
    function _mintOrUnlock(uint32 sourceChainId, address recipient, uint256 amount, uint128) internal override {
        _decreaseBridgedPrincipal(sourceChainId, amount);
        if (recipient != address(this)) {
            IERC20(mToken).transfer(recipient, amount);
        }
    }

    /// @dev Updates bridged principal when tokens are locked for a destination spoke.
    /// @param destinationChainId The ID of the destination chain.
    /// @param amount             The amount of M Token to lock.
    function _burnOrLock(uint32 destinationChainId, uint256 amount) internal override {
        _increaseBridgedPrincipal(destinationChainId, amount);
    }

    /// @dev Increases the principal amount bridged to a spoke chain.
    /// @param spokeChainId The ID of the spoke chain.
    /// @param amount       The amount of M Token being bridged.
    function _increaseBridgedPrincipal(uint32 spokeChainId, uint256 amount) private {
        SpokeChainConfig storage config = _getHubPortalStorageLocation().spokeConfig[spokeChainId];

        // Won't overflow since `getPrincipalAmountRoundedDown` returns uint112
        unchecked {
            config.bridgedPrincipal += IndexingMath.getPrincipalAmountRoundedDown(uint240(amount), _currentIndex());
        }
    }

    /// @dev Decreases the principal amount bridged to a spoke chain.
    /// @param spokeChainId The ID of the spoke chain.
    /// @param amount       The amount of M Token being unlocked.
    function _decreaseBridgedPrincipal(uint32 spokeChainId, uint256 amount) private {
        SpokeChainConfig storage config = _getHubPortalStorageLocation().spokeConfig[spokeChainId];
        uint248 principal = IndexingMath.getPrincipalAmountRoundedDown(uint240(amount), _currentIndex());

        // Prevents unlocking more than was bridged to the Spoke
        if (principal > config.bridgedPrincipal) revert InsufficientBridgedBalance();

        unchecked {
            config.bridgedPrincipal -= principal;
        }
    }

    /// @dev Receives and routes token transfers via Hub.
    /// @param sourceChainId The ID of the source spoke chain.
    /// @param payload       The message payload.
    function _receiveTokenViaHub(uint32 sourceChainId, bytes memory payload) internal override {
        (
            uint256 amount,
            bytes32 finalDestinationToken,
            bytes32 sender,
            address recipient,
            uint128 index,
            bytes32 messageId,
            uint32 finalDestinationChainId
        ) = PayloadEncoder.decodeTokenTransferViaHub(payload);

        // Decrement source spoke's balance
        _decreaseBridgedPrincipal(sourceChainId, amount);

        if (finalDestinationChainId == currentChainId) {
            // Spoke→Hub: reuse _receiveToken logic for wrapping/unwrapping
            bytes memory tokenPayload = PayloadEncoder.encodeTokenTransfer(
                amount, finalDestinationToken, sender.toAddress(), recipient.toBytes32(), index, messageId
            );
            _receiveToken(sourceChainId, tokenPayload);
        } else {
            // Spoke→Spoke: forward to final destination
            _increaseBridgedPrincipal(finalDestinationChainId, amount);
            _forwardToSpoke(finalDestinationChainId, finalDestinationToken, sender, recipient, amount, index);
            emit TokenForwarded(sourceChainId, finalDestinationChainId, recipient, amount);
        }
    }

    /// @dev Forwards tokens to final spoke destination (Hub pays bridge fee).
    /// @param finalDestinationChainId The chain ID of the final spoke destination.
    /// @param finalDestinationToken   The token address on the final destination.
    /// @param sender                  The original sender from the source spoke.
    /// @param recipient               The recipient on the final destination.
    /// @param amount                  The amount of tokens to forward.
    /// @param index                   The M token index.
    function _forwardToSpoke(
        uint32 finalDestinationChainId,
        bytes32 finalDestinationToken,
        bytes32 sender,
        address recipient,
        uint256 amount,
        uint128 index
    ) private {
        bytes32 messageId = _getMessageId(finalDestinationChainId);
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            amount, finalDestinationToken, sender.toAddress(), recipient.toBytes32(), index, messageId
        );

        address bridgeAdapter = defaultBridgeAdapter(finalDestinationChainId);
        uint256 gasLimit = payloadGasLimit(finalDestinationChainId, PayloadType.TokenTransfer);

        // Quote delivery fee
        bytes memory emptyPayload = PayloadEncoder.generateEmptyPayload(PayloadType.TokenTransfer);
        uint256 fee = IBridgeAdapter(bridgeAdapter).quote(finalDestinationChainId, gasLimit, emptyPayload);

        // Hub pays for this leg from treasury
        IBridgeAdapter(bridgeAdapter).sendMessage{ value: fee }(
            finalDestinationChainId, gasLimit, address(this).toBytes32(), payload
        );
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
