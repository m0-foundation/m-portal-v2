// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { ISpokeMTokenLike } from "./interfaces/ISpokeMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";

abstract contract SpokePortalStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.SpokePortal
    struct SpokePortalStorageStruct {
        mapping(uint32 spokeChainId => bool) crossSpokeTokenTransferEnabled;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.SpokePortal")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant SPOKE_PORTAL_STORAGE_LOCATION = 0x69eb231f66ca36530ae1439a642c87296518bd9b871fe76efe7c4b78db4d2800;

    function _getSpokePortalStorageLocation() internal pure returns (SpokePortalStorageStruct storage $) {
        assembly {
            $.slot := SPOKE_PORTAL_STORAGE_LOCATION
        }
    }
}

/// @title  SpokePortal
/// @author M0 Labs
/// @notice Deployed on Spoke chains and responsible for sending and receiving M tokens
///         as well as updating M index and Registrar keys.
/// @dev    Tokens are bridged using mint-burn mechanism.
contract SpokePortal is SpokePortalStorageLayout, Portal, ISpokePortal {
    using PayloadEncoder for bytes;

    /// @inheritdoc ISpokePortal
    uint32 public immutable hubChainId;

    /// @notice Constructs SpokePortal Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  mToken_       The address of M token.
    /// @param  registrar_    The address of Registrar.
    /// @param  swapFacility_ The address of Swap Facility.
    /// @param  orderBook_    The address of Order Book.
    /// @param  hubChainId_   The chain ID of the Hub.
    constructor(
        address mToken_,
        address registrar_,
        address swapFacility_,
        address orderBook_,
        uint32 hubChainId_
    ) Portal(mToken_, registrar_, swapFacility_, orderBook_) {
        if ((hubChainId = hubChainId_) == 0) revert ZeroHubChain();
    }

    /// @inheritdoc ISpokePortal
    function initialize(address owner, address pauser, address operator, bool crossSpokeTransferEnabled) external initializer {
        _initialize(owner, pauser, operator);
        
        if (crossSpokeTransferEnabled) {
            _enableCrossSpokeTokenTransfer(currentChainId);
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          PRIVILEGED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc ISpokePortal
    function enableCrossSpokeTokenTransfer(uint32 spokeChainId) external onlyRole(OPERATOR_ROLE) {
        if (_getSpokePortalStorageLocation().crossSpokeTokenTransferEnabled[spokeChainId]) return;

        _enableCrossSpokeTokenTransfer(spokeChainId);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                      EXTERNAL VIEW/PURE FUNCTIONS                     //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc ISpokePortal
    function crossSpokeTokenTransferEnabled(uint32 spokeChainId) external view returns (bool) {
        return _getSpokePortalStorageLocation().crossSpokeTokenTransferEnabled[spokeChainId];
    }

    ///////////////////////////////////////////////////////////////////////////
    //                INTERNAL/PRIVATE INTERACTIVE FUNCTIONS                 //
    ///////////////////////////////////////////////////////////////////////////

    function _receiveCustomPayload(PayloadType payloadType, bytes memory payload) internal override {
        if (payloadType == PayloadType.Index) {
            _updateMTokenIndex(payload);
        } else if (payloadType == PayloadType.RegistrarKey) {
            _setRegistrarKey(payload);
        } else if (payloadType == PayloadType.RegistrarList) {
            _updateRegistrarList(payload);
        }
    }

    /// @notice Updates M Token index to the index received from the remote chain.
    function _updateMTokenIndex(bytes memory payload) private {
        (bytes32 messageId, uint128 index) = payload.decodeIndex();

        if (index > _currentIndex()) {
            ISpokeMTokenLike(mToken).updateIndex(index);
        }

        emit MTokenIndexReceived(index, messageId);
    }

    /// @notice Sets a Registrar key received from the Hub chain.
    function _setRegistrarKey(bytes memory payload_) private {
        (bytes32 messageId, bytes32 key, bytes32 value) = payload_.decodeRegistrarKey();

        IRegistrarLike(registrar).setKey(key, value);

        emit RegistrarKeyReceived(key, value, messageId);
    }

    /// @notice Adds or removes an account from the Registrar List based on the message from the Hub chain.
    function _updateRegistrarList(bytes memory payload_) private {
        (bytes32 messageId, bytes32 listName, address account, bool add) = payload_.decodeRegistrarList();

        emit RegistrarListUpdateReceived(listName, account, add, messageId);

        if (add) {
            IRegistrarLike(registrar).addToList(listName, account);
        } else {
            IRegistrarLike(registrar).removeFromList(listName, account);
        }
    }

    /// @dev Mints $M Token to the `recipient`.
    /// @param recipient The account to mint $M tokens to.
    /// @param amount    The amount of $M Token to mint to the recipient.
    /// @param index     The index from the source chain.
    function _mintOrUnlock(
        uint32, /* sourceChainId */
        address recipient,
        uint256 amount,
        uint128 index
    ) internal override {
        // Update M token index only if the index received from the remote chain is bigger
        if (index > _currentIndex()) {
            ISpokeMTokenLike(mToken).mint(recipient, amount, index);
        } else {
            ISpokeMTokenLike(mToken).mint(recipient, amount);
        }
    }

    /// @dev Burns $M Token.
    /// @param amount The amount of M Token to burn from the SpokePortal.
    function _burnOrLock(
        uint32, /* destinationChainId */
        uint256 amount
    ) internal override {
        ISpokeMTokenLike(mToken).burn(amount);
    }

    /// @dev Enables cross-Spoke token transfer for the specified Spoke.
    function _enableCrossSpokeTokenTransfer(uint32 spokeChainId) private {
        _getSpokePortalStorageLocation().crossSpokeTokenTransferEnabled[spokeChainId] = true;
        emit CrossSpokeTokenTransferEnabled(spokeChainId);
    }

    /// @dev Reverts if the destination chain is the Hub chain
    function _revertIfTokenTransferDisabled(uint32 destinationChainId) internal view override {
        // Always allow sending tokens to the Hub chain
        if (destinationChainId == hubChainId) return;

        SpokePortalStorageStruct storage $ = _getSpokePortalStorageLocation();

        // Current chain is isolated, disallow sending tokens to any other Spoke
        if (!$.crossSpokeTokenTransferEnabled[currentChainId]) revert CrossSpokeTokenTransferDisabled(currentChainId);

        // Destination chain is isolated, disallow sending tokens to that Spoke
        if (!$.crossSpokeTokenTransferEnabled[destinationChainId]) revert CrossSpokeTokenTransferDisabled(destinationChainId);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                      INTERNAL VIEW/PURE FUNCTIONS                     //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Returns the current M token index used by the Spoke Portal.
    function _currentIndex() internal view override returns (uint128) {
        return ISpokeMTokenLike(mToken).currentIndex();
    }
}
