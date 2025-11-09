// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";
import { AccessControlUpgradeable } from
    "../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IBridgeAdapter } from "./interfaces/IBridgeAdapter.sol";
import { IMTokenLike } from "./interfaces/IMTokenLike.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { ISwapFacilityLike } from "./interfaces/ISwapFacilityLike.sol";
import { IOrderBookLike } from "./interfaces/IOrderBookLike.sol";
import { ReentrancyLock } from "./utils/ReentrancyLock.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";
import { TypeConverter } from "./libraries/TypeConverter.sol";

abstract contract PortalStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.Portal
    struct PortalStorageStruct {
        /// @notice Ensures the uniqueness of each cross-chain message.
        uint256 nonce;
        /// @notice Default bridge adapter for each remote chain set by the admin.
        mapping(uint32 remoteChainId => address bridgeAdapter) defaultBridgeAdapter;
        /// @notice Supported bridging paths for cross-chain transfers.
        mapping(address sourceToken => mapping(uint32 destinationChainId => mapping(bytes32 destinationToken => bool supported)))
            supportedBridgingPath;
        /// @notice Gas limit required to process different types of payload on destination chains.
        mapping(uint32 destinationChainId => mapping(PayloadType payloadType => uint256 gasLimit)) payloadGasLimit;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.Portal")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant PORTAL_STORAGE_LOCATION = 0xc28186249f0e66be857064e66a873ce85cfd996b5352867e3f7c1d7931e67d00;

    function _getPortalStorageLocation() internal pure returns (PortalStorageStruct storage $) {
        assembly {
            $.slot := PORTAL_STORAGE_LOCATION
        }
    }
}

abstract contract Portal is PortalStorageLayout, AccessControlUpgradeable, PausableUpgradeable, ReentrancyLock, UUPSUpgradeable, IPortal {
    using TypeConverter for *;
    using PayloadEncoder for bytes;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @inheritdoc IPortal
    address public immutable mToken;

    /// @inheritdoc IPortal
    address public immutable registrar;

    /// @inheritdoc IPortal
    address public immutable swapFacility;

    /// @inheritdoc IPortal
    address public immutable orderBook;

    /// @inheritdoc IPortal
    uint32 public immutable currentChainId;

    /// @notice Constructs the Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  mToken_         The address of M token.
    /// @param  registrar_      The address of Registrar.
    /// @param  swapFacility_   The address of Swap Facility.
    /// @param  orderBook_      The address of Order Book.
    constructor(address mToken_, address registrar_, address swapFacility_, address orderBook_) {
        _disableInitializers();

        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
        if ((swapFacility = swapFacility_) == address(0)) revert ZeroSwapFacility();
        if ((orderBook = orderBook_) == address(0)) revert ZeroOrderBook();

        // NOTE: For most EVM chains, ID fits into uint32
        currentChainId = block.chainid.toUint32();
    }

    /// @notice Initializes the Proxy's storage
    /// @param  admin  The address of the admin.
    /// @param  pauser The address of the pauser.
    function _initialize(address admin, address pauser) internal onlyInitializing {
        if (admin == address(0)) revert ZeroAdmin();
        if (pauser == address(0)) revert ZeroPauser();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPortal
    function sendToken(
        uint256 amount,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable whenNotPaused whenNotLocked returns (bytes32 messageId) {
        _revertIfZeroAmount(amount);
        _revertIfZeroRefundAddress(refundAddress);
        if (destinationToken == bytes32(0)) revert ZeroDestinationToken();
        if (recipient == bytes32(0)) revert ZeroRecipient();

        PortalStorageStruct storage $ = _getPortalStorageLocation();

        if (!$.supportedBridgingPath[sourceToken][destinationChainId][destinationToken]) {
            revert UnsupportedBridgingPath(sourceToken, destinationChainId, destinationToken);
        }

        address bridgeAdapter = $.defaultBridgeAdapter[destinationChainId];
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

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

        // Burn M tokens on Spoke.
        // In case of Hub, only update the bridged principal amount as tokens already transferred.
        _burnOrLock(amount);

        uint128 index = _currentIndex();
        messageId = _getMessageId(destinationChainId, $.nonce++);
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(amount, destinationToken, msg.sender, recipient, index, messageId);
        IBridgeAdapter(bridgeAdapter).sendMessage{ value: msg.value }(
            destinationChainId, $.payloadGasLimit[destinationChainId][PayloadType.TokenTransfer], refundAddress, payload
        );

        // Prevent stack too deep
        uint256 transferAmount = amount;

        emit TokenSent(
            sourceToken, destinationChainId, destinationToken, msg.sender, recipient, transferAmount, index, bridgeAdapter, messageId
        );
    }

    /// @inheritdoc IPortal
    function sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress
    ) external payable whenNotPaused whenNotLocked returns (bytes32 messageId) {
        if (msg.sender != orderBook) revert NotOrderBook();
        _revertIfZeroRefundAddress(refundAddress);

        PortalStorageStruct storage $ = _getPortalStorageLocation();

        address bridgeAdapter = $.defaultBridgeAdapter[destinationChainId];
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        uint256 gasLimit = $.payloadGasLimit[destinationChainId][PayloadType.FillReport];
        bytes32 orderId = report.orderId;
        uint128 amountInToRelease = report.amountInToRelease;
        uint128 amountOutFilled = report.amountOutFilled;
        bytes32 originRecipient = report.originRecipient;
        messageId = _getMessageId(destinationChainId, $.nonce++);
        bytes memory payload = PayloadEncoder.encodeFillReport(orderId, amountInToRelease, amountOutFilled, originRecipient, messageId);

        IBridgeAdapter(bridgeAdapter).sendMessage{ value: msg.value }(destinationChainId, gasLimit, refundAddress, payload);

        emit FillReportSent(destinationChainId, orderId, amountInToRelease, amountOutFilled, originRecipient, bridgeAdapter, messageId);
    }

    /// @inheritdoc IPortal
    function receiveMessage(uint32 sourceChainId, bytes calldata payload) external {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        address bridgeAdapter = $.defaultBridgeAdapter[sourceChainId];

        if (msg.sender != bridgeAdapter) revert NotBridgeAdapter();

        PayloadType payloadType = payload.getPayloadType();

        if (payloadType == PayloadType.TokenTransfer) {
            _receiveToken(sourceChainId, payload);
            return;
        }

        if (payloadType == PayloadType.FillReport) {
            _receiveFillReport(sourceChainId, payload);
            return;
        }

        // Index, Registrar Key, or Registrar List Update on Spoke chains
        _receiveCustomPayload(payloadType, payload);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                        ACCESS CONTROL FUNCTIONS                       //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPortal
    function setDefaultBridgeAdapter(uint32 destinationChainId, address bridgeAdapter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();

        if ($.defaultBridgeAdapter[destinationChainId] == bridgeAdapter) return;

        $.defaultBridgeAdapter[destinationChainId] = bridgeAdapter;
        emit BridgeAdapterSet(destinationChainId, bridgeAdapter);
    }

    /// @inheritdoc IPortal
    function setSupportedBridgingPath(
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bool supported
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (sourceToken == address(0)) revert ZeroSourceToken();
        if (destinationChainId == currentChainId) revert InvalidDestinationChain(destinationChainId);
        if (destinationToken == bytes32(0)) revert ZeroDestinationToken();

        PortalStorageStruct storage $ = _getPortalStorageLocation();

        if ($.supportedBridgingPath[sourceToken][destinationChainId][destinationToken] == supported) return;

        $.supportedBridgingPath[sourceToken][destinationChainId][destinationToken] = supported;
        emit SupportedBridgingPathSet(sourceToken, destinationChainId, destinationToken, supported);
    }

    /// @inheritdoc IPortal
    function setPayloadGasLimit(
        uint32 destinationChainId,
        PayloadType payloadType,
        uint256 gasLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();

        if ($.payloadGasLimit[destinationChainId][payloadType] == gasLimit) return;

        $.payloadGasLimit[destinationChainId][payloadType] = gasLimit;
        emit PayloadGasLimitSet(destinationChainId, payloadType, gasLimit);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

    /// @inheritdoc IPortal
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc IPortal
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL VIEW/PURE FUNCTIONS                      //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPortal
    function getNonce() external view returns (uint256) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.nonce;
    }

    /// @inheritdoc IPortal
    function defaultBridgeAdapter(uint32 destinationChainId) external view returns (address) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.defaultBridgeAdapter[destinationChainId];
    }

    /// @inheritdoc IPortal
    function supportedBridgingPath(
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken
    ) external view returns (bool) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.supportedBridgingPath[sourceToken][destinationChainId][destinationToken];
    }

    /// @inheritdoc IPortal
    function payloadGasLimit(uint32 destinationChainId, PayloadType payloadType) external view returns (uint256) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.payloadGasLimit[destinationChainId][payloadType];
    }

    /// @inheritdoc IPortal
    function currentIndex() external view returns (uint128) {
        return _currentIndex();
    }

    /// @inheritdoc IPortal
    function msgSender() public view returns (address) {
        return _locker;
    }

    /// @inheritdoc IPortal
    function quote(uint32 destinationChainId, PayloadType payloadType) external view returns (uint256) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();

        uint256 gasLimit = $.payloadGasLimit[destinationChainId][payloadType];
        address bridgeAdapter = $.defaultBridgeAdapter[destinationChainId];
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        // NOTE: For quoting delivery fee, the content of the message doesn’t matter,
        //       only the destination chain, gas limit required to process the message on the destination
        //       and, for some protocols, payload size are relevant.
        bytes memory payload = PayloadEncoder.generateEmptyPayload(payloadType);

        return IBridgeAdapter(bridgeAdapter).quote(destinationChainId, gasLimit, payload);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     INTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev   Handles token transfer message on the destination.
    /// @param sourceChainId The ID of the source chain.
    /// @param payload       The message payload.
    function _receiveToken(uint32 sourceChainId, bytes memory payload) private {
        (uint256 amount, address destinationToken, bytes32 sender, address recipient, uint128 index, bytes32 messageId) =
            payload.decodeTokenTransfer();

        emit TokenReceived(sourceChainId, destinationToken, sender, recipient, amount, index, messageId);

        if (destinationToken == mToken) {
            // mints or unlocks $M Token to the recipient
            _mintOrUnlock(recipient, amount, index);
        } else {
            // mints or unlocks $M Token to the Portal
            _mintOrUnlock(address(this), amount, index);

            // wraps $M token and transfers it to the recipient
            _wrap(destinationToken, recipient, amount);
        }
    }

    /// @dev   Wraps $M token to the token specified by `destinationToken`.
    ///        If wrapping fails transfers $M token to `recipient_`.
    /// @param destinationToken The address of the Extension token.
    /// @param recipient        The account to receive wrapped token.
    /// @param amount           The amount to wrap.
    function _wrap(address destinationToken, address recipient, uint256 amount) private {
        IERC20(mToken).approve(swapFacility, amount);

        // Attempt to wrap $M token
        // NOTE: the call might fail with out-of-gas exception
        //       even if the destination token is the valid wrapped M token.
        //       Recipients must support both $M and wrapped $M transfers.
        (bool success,) = swapFacility.call(abi.encodeCall(ISwapFacilityLike.swapInM, (destinationToken, amount, recipient)));

        if (!success) {
            emit WrapFailed(destinationToken, recipient, amount);
            // Reset approval to prevent a potential double-spend attack
            IERC20(mToken).approve(swapFacility, 0);
            // Transfer $M token to the recipient
            IERC20(mToken).transfer(recipient, amount);
        }
    }

    /// @dev   Handles fill report message on the destination.
    /// @param sourceChainId The ID of the source chain.
    /// @param payload       The message payload.
    function _receiveFillReport(uint32 sourceChainId, bytes memory payload) private {
        (bytes32 orderId, uint128 amountInToRelease, uint128 amountOutFilled, bytes32 originRecipient, bytes32 messageId) =
            payload.decodeFillReport();

        IOrderBookLike(orderBook).reportFill(
            IOrderBookLike.FillReport({
                orderId: orderId,
                amountInToRelease: amountInToRelease,
                amountOutFilled: amountOutFilled,
                originRecipient: originRecipient
            })
        );

        emit FillReportReceived(sourceChainId, orderId, amountInToRelease, amountOutFilled, originRecipient, messageId);
    }

    /// @dev Generates a unique across all chains message ID.
    /// @param destinationChainId The ID of the destination chain.
    /// @param nonce              A unique nonce for the message.
    function _getMessageId(uint32 destinationChainId, uint256 nonce) internal view returns (bytes32) {
        return keccak256(abi.encode(currentChainId, destinationChainId, nonce));
    }

    /// @dev   Overridden in SpokePortal to handle custom payload messages.
    /// @param payloadType The type of the payload (Index, RegistrarKey, or RegistrarList).
    /// @param payload     The message payload to process.
    function _receiveCustomPayload(PayloadType payloadType, bytes memory payload) internal virtual { }

    /// @dev   HubPortal:   unlocks and transfers `amount` $M tokens to `recipient`.
    ///        SpokePortal: mints `amount` $M tokens to `recipient`.
    /// @param recipient The account receiving $M tokens.
    /// @param amount    The amount of $M tokens to unlock/mint.
    /// @param index     The index from the source chain.
    function _mintOrUnlock(address recipient, uint256 amount, uint128 index) internal virtual { }

    /// @dev   HubPortal:   locks `amount` $M tokens.
    ///        SpokePortal: burns `amount` $M tokens.
    /// @param amount The amount of $M tokens to lock/burn.
    function _burnOrLock(uint256 amount) internal virtual { }

    ///////////////////////////////////////////////////////////////////////////
    //                 INTERNAL/PRIVATE VIEW/PURE FUNCTIONS                  //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev  Returns the adjusted transfer amount accounting for potential fee-on-transfer tokens.
    /// @param startingBalance The starting $M token balance of the Portal.
    /// @param specifiedAmount The transfer amount specified by the sender.
    function _getTransferAmount(uint256 startingBalance, uint256 specifiedAmount) internal view returns (uint256) {
        // The actual amount of $M tokens that Portal received from the sender.
        // Accounts for potential rounding errors when transferring between earners and non-earners,
        // as well as potential fee-on-transfer functionality in the source token.
        uint256 actualAmount = _mBalanceOf(address(this)) - startingBalance;

        if (specifiedAmount > actualAmount) {
            unchecked {
                // If the difference between the specified transfer amount and the actual amount exceeds
                // the maximum acceptable rounding error (e.g., due to fee-on-transfer in an extension token)
                // transfer the actual amount, not the specified.

                // Otherwise, the specified amount will be transferred and the deficit caused by rounding error will
                // be covered from the yield earned by HubPortal.
                if (specifiedAmount - actualAmount > _getMaxRoundingError()) {
                    // Ensure that updated transfer amount is greater than 0
                    _revertIfZeroAmount(actualAmount);
                    return actualAmount;
                }
            }
        }
        return specifiedAmount;
    }

    /// @dev Reverts if `amount` is zero.
    function _revertIfZeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }

    /// @dev Reverts if `refundAddress` is zero address.
    function _revertIfZeroRefundAddress(bytes32 refundAddress) internal pure {
        if (refundAddress == bytes32(0)) revert ZeroRefundAddress();
    }

    /// @dev Reverts if `bridgeAdapter` is zero address.
    function _revertIfZeroBridgeAdapter(uint32 destinationChainId, address bridgeAdapter) internal pure {
        if (bridgeAdapter == address(0)) revert UnsupportedDestinationChain(destinationChainId);
    }

    /// @dev Returns the current M token index used by the Portal.
    function _currentIndex() internal view virtual returns (uint128) { }

    /// @dev Returns the maximum rounding error that can occur when transferring M tokens to the Portal
    function _getMaxRoundingError() private view returns (uint256) {
        return _currentIndex() / IndexingMath.EXP_SCALED_ONE + 1;
    }

    /// @dev Returns the M Token balance of `account`.
    function _mBalanceOf(address account) internal view returns (uint256) {
        return IERC20(mToken).balanceOf(account);
    }
}
