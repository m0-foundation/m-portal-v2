// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { ISpokeMTokenLike } from "./interfaces/ISpokeMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";
import { IPortal } from "./interfaces/IPortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";

/// @title  SpokePortal
/// @author M0 Labs
/// @notice Deployed on Spoke chains and responsible for sending and receiving M tokens
///         as well as updating M index and Registrar keys.
/// @dev    Tokens are bridged using mint-burn mechanism.
contract SpokePortal is Portal, ISpokePortal {
    using PayloadEncoder for bytes;

    /// @notice Constructs SpokePortal Implementation contract
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
    function initialize(address initialOwner, address initialPauser) external initializer {
        _initialize(initialOwner, initialPauser);
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
        (uint128 index, bytes32 messageId) = payload.decodeIndex();

        if (index > _currentIndex()) {
            ISpokeMTokenLike(mToken).updateIndex(index);
        }

        emit MTokenIndexReceived(index, messageId);
    }

    /// @notice Sets a Registrar key received from the Hub chain.
    function _setRegistrarKey(bytes memory payload_) private {
        (bytes32 key, bytes32 value, bytes32 messageId) = payload_.decodeRegistrarKey();

        IRegistrarLike(registrar).setKey(key, value);

        emit RegistrarKeyReceived(key, value, messageId);
    }

    /// @notice Adds or removes an account from the Registrar List based on the message from the Hub chain.
    function _updateRegistrarList(bytes memory payload_) private {
        (bytes32 listName, address account, bool add, bytes32 messageId) = payload_.decodeRegistrarList();

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
    function _mintOrUnlock(address recipient, uint256 amount, uint128 index) internal override {
        // Update M token index only if the index received from the remote chain is bigger
        if (index > _currentIndex()) {
            ISpokeMTokenLike(mToken).mint(recipient, amount, index);
        } else {
            ISpokeMTokenLike(mToken).mint(recipient, amount);
        }
    }

    /// @dev Burns $M Token.
    /// @param amount The amount of M Token to burn from the SpokePortal.
    function _burnOrLock(uint256 amount) internal override {
        ISpokeMTokenLike(mToken).burn(amount);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                      INTERNAL VIEW/PURE FUNCTIONS                     //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Returns the current M token index used by the Spoke Portal.
    function _currentIndex() internal view override returns (uint128) {
        return ISpokeMTokenLike(mToken).currentIndex();
    }
}
