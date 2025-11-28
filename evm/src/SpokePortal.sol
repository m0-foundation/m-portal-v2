// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ISpokeMTokenLike } from "./interfaces/ISpokeMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { ISwapFacilityLike } from "./interfaces/ISwapFacilityLike.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";

/// @title  SpokePortal
/// @author M0 Labs
/// @notice Deployed on Spoke chains and responsible for sending and receiving M tokens
///         as well as updating M index and Registrar keys.
/// @dev    Tokens are bridged using mint-burn mechanism.
contract SpokePortal is Portal, ISpokePortal {
    using PayloadEncoder for bytes;

    /// @inheritdoc ISpokePortal
    uint32 public immutable hubChainId;

    /// @notice Constructs SpokePortal Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  mToken_       The address of M token.
    /// @param  registrar_    The address of Registrar.
    /// @param  swapFacility_ The address of Swap Facility.
    /// @param  orderBook_    The address of Order Book.
    /// @param  hubChainId_   The chain ID of the Hub chain.
    constructor(
        address mToken_,
        address registrar_,
        address swapFacility_,
        address orderBook_,
        uint32 hubChainId_
    ) Portal(mToken_, registrar_, swapFacility_, orderBook_) {
        hubChainId = hubChainId_;
    }

    /// @inheritdoc IPortal
    function initialize(address owner, address pauser, address operator) external initializer {
        _initialize(owner, pauser, operator);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc ISpokePortal
    function sendTokenViaHub(
        uint256 amount,
        address sourceToken,
        uint32 finalDestinationChainId,
        bytes32 finalDestinationToken,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable whenNotPaused whenNotLocked returns (bytes32 messageId) {
        _revertIfZeroAmount(amount);
        _revertIfZeroRefundAddress(refundAddress);
        _revertIfZeroSourceToken(sourceToken);
        _revertIfZeroDestinationToken(finalDestinationToken);
        _revertIfZeroRecipient(recipient);

        uint128 index = _currentIndex();

        // Prevent stack too deep
        {
            uint256 startingBalance = _mBalanceOf(address(this));

            // Transfer source token from the sender
            IERC20(sourceToken).transferFrom(msg.sender, address(this), amount);

            // If the source token isn't $M token, unwrap it
            if (sourceToken != address(mToken)) {
                IERC20(sourceToken).approve(swapFacility, amount);
                ISwapFacilityLike(swapFacility).swapOutM(sourceToken, amount, address(this));
            }

            // Adjust amount based on actual received $M tokens for potential fee-on-transfer tokens
            amount = _getTransferAmount(startingBalance, amount);

            // Burn M tokens on Spoke
            _burnOrLock(hubChainId, amount);

            messageId = _getMessageId(hubChainId);
            bytes memory payload = PayloadEncoder.encodeTokenTransferViaHub(
                amount, finalDestinationToken, msg.sender, recipient, index, messageId, finalDestinationChainId
            );

            address bridgeAdapter = defaultBridgeAdapter(hubChainId);
            _revertIfZeroBridgeAdapter(hubChainId, bridgeAdapter);

            _sendMessage(hubChainId, PayloadType.TokenTransferViaHub, refundAddress, payload, bridgeAdapter);
        }

        emit TokenSentViaHub(sourceToken, finalDestinationChainId, recipient, amount);
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
    function _mintOrUnlock(uint32, address recipient, uint256 amount, uint128 index) internal override {
        // Update M token index only if the index received from the remote chain is bigger
        if (index > _currentIndex()) {
            ISpokeMTokenLike(mToken).mint(recipient, amount, index);
        } else {
            ISpokeMTokenLike(mToken).mint(recipient, amount);
        }
    }

    /// @dev Burns $M Token.
    /// @param amount The amount of M Token to burn from the SpokePortal.
    function _burnOrLock(uint32, uint256 amount) internal override {
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
