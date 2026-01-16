// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";
import { IERC20 } from "../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    AccessControlUpgradeable
} from "../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IBridgeAdapter } from "./interfaces/IBridgeAdapter.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { ISwapFacilityLike } from "./interfaces/ISwapFacilityLike.sol";
import { IOrderBookLike } from "./interfaces/IOrderBookLike.sol";
import { ReentrancyLock } from "./utils/ReentrancyLock.sol";
import { PayloadType, PayloadEncoder } from "./libraries/PayloadEncoder.sol";
import { TypeConverter } from "./libraries/TypeConverter.sol";

struct ChainConfig {
    /// @notice Default bridge adapter for each remote chain used if no bridge adapter is specified.
    address defaultBridgeAdapter;
    /// @notice Supported bridge adapters for each remote chain.
    mapping(address bridgeAdapter => bool supported) supportedBridgeAdapter;
    /// @notice Gas limit required to process different types of payload on destination chains.
    mapping(PayloadType payloadType => uint256 gasLimit) payloadGasLimit;
}

abstract contract PortalStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.Portal
    struct PortalStorageStruct {
        /// @notice Ensures the uniqueness of each cross-chain message.
        uint256 nonce;
        /// @notice Configuration required to send cross-chain messages to the remote chain.
        mapping(uint32 chainId => ChainConfig) remoteChainConfig;
        /// @notice Supported bridging paths for cross-chain transfers.
        mapping(address sourceToken => mapping(uint32 destinationChainId => mapping(bytes32 destinationToken => bool supported)))
            supportedBridgingPath;
        /// @notice Indicates whether a message with a given hash has been processed.
        mapping(bytes32 messageId => bool) processedMessages;
        /// @notice Indicates whether sending cross-chain messages is paused.
        bool sendPaused;
        /// @notice Indicates whether receiving cross-chain messages is paused.
        bool receivePaused;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.Portal")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant PORTAL_STORAGE_LOCATION = 0xc28186249f0e66be857064e66a873ce85cfd996b5352867e3f7c1d7931e67d00;

    function _getPortalStorageLocation() internal pure returns (PortalStorageStruct storage $) {
        assembly {
            $.slot := PORTAL_STORAGE_LOCATION
        }
    }
}

abstract contract Portal is PortalStorageLayout, AccessControlUpgradeable, ReentrancyLock, UUPSUpgradeable, IPortal {
    using TypeConverter for *;
    using PayloadEncoder for bytes;
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @inheritdoc IPortal
    address public immutable mToken;

    /// @inheritdoc IPortal
    address public immutable registrar;

    /// @inheritdoc IPortal
    address public immutable swapFacility;

    /// @inheritdoc IPortal
    address public immutable orderBook;

    /// @dev Modifier to make a function callable only when sending messages is not paused.
    modifier whenSendNotPaused() {
        if (sendPaused()) revert SendingPaused();
        _;
    }

    /// @dev Modifier to make a function callable only when receiving messages is not paused.
    modifier whenReceiveNotPaused() {
        if (receivePaused()) revert ReceivingPaused();
        _;
    }

    /// @notice Constructs the Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  mToken_       The address of M token.
    /// @param  registrar_    The address of Registrar.
    /// @param  swapFacility_ The address of Swap Facility.
    /// @param  orderBook_    The address of Order Book.
    constructor(address mToken_, address registrar_, address swapFacility_, address orderBook_) {
        _disableInitializers();

        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
        if ((swapFacility = swapFacility_) == address(0)) revert ZeroSwapFacility();
        if ((orderBook = orderBook_) == address(0)) revert ZeroOrderBook();
    }

    /// @notice Initializes the Proxy's storage
    /// @param  admin    The address of the admin.
    /// @param  pauser   The address of the pauser.
    /// @param  operator The address of the operator.
    function _initialize(address admin, address pauser, address operator) internal onlyInitializing {
        if (admin == address(0)) revert ZeroAdmin();
        if (pauser == address(0)) revert ZeroPauser();
        if (operator == address(0)) revert ZeroOperator();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(OPERATOR_ROLE, operator);
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
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendToken(
            amount,
            sourceToken,
            destinationChainId,
            destinationToken,
            recipient,
            refundAddress,
            defaultBridgeAdapter(destinationChainId),
            bridgeAdapterArgs
        );
    }

    function sendToken(
        uint256 amount,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendToken(
            amount, sourceToken, destinationChainId, destinationToken, recipient, refundAddress, bridgeAdapter, bridgeAdapterArgs
        );
    }

    /// @inheritdoc IPortal
    function sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendFillReport(destinationChainId, report, refundAddress, defaultBridgeAdapter(destinationChainId), bridgeAdapterArgs);
    }

    /// @inheritdoc IPortal
    function sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendFillReport(destinationChainId, report, refundAddress, bridgeAdapter, bridgeAdapterArgs);
    }

    /// @inheritdoc IPortal
    function sendCancelReport(
        uint32 destinationChainId,
        IOrderBookLike.CancelReport calldata report,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendCancelReport(destinationChainId, report, refundAddress, defaultBridgeAdapter(destinationChainId), bridgeAdapterArgs);
    }

    /// @inheritdoc IPortal
    function sendCancelReport(
        uint32 destinationChainId,
        IOrderBookLike.CancelReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable whenSendNotPaused whenNotLocked returns (bytes32 messageId) {
        return _sendCancelReport(destinationChainId, report, refundAddress, bridgeAdapter, bridgeAdapterArgs);
    }

    /// @inheritdoc IPortal
    function receiveMessage(uint32 sourceChainId, bytes calldata payload) external whenReceiveNotPaused {
        _revertIfUnsupportedBridgeAdapter(sourceChainId, msg.sender);

        PayloadType payloadType = payload.decodePayloadType();
        bytes32 messageId = payload.decodeMessageId();
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if ($.processedMessages[messageId]) revert MessageAlreadyProcessed(messageId);

        $.processedMessages[messageId] = true;

        if (payloadType == PayloadType.TokenTransfer) {
            _receiveToken(sourceChainId, payload);
            return;
        }

        if (payloadType == PayloadType.FillReport) {
            _receiveFillReport(sourceChainId, payload);
            return;
        }

        if (payloadType == PayloadType.CancelReport) {
            _receiveCancelReport(sourceChainId, payload);
            return;
        }

        // Index, Registrar Key, or Registrar List Update on Spoke chains
        _receiveCustomPayload(payloadType, payload);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          PRIVILEGED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPortal
    function setDefaultBridgeAdapter(uint32 destinationChainId, address bridgeAdapter) external onlyRole(OPERATOR_ROLE) {
        _revertIfInvalidDestinationChain(destinationChainId);

        ChainConfig storage remoteChainConfig = _getPortalStorageLocation().remoteChainConfig[destinationChainId];

        // If the bridge adapter isn't already supported, add it to the supported adapters list
        if (!remoteChainConfig.supportedBridgeAdapter[bridgeAdapter]) {
            remoteChainConfig.supportedBridgeAdapter[bridgeAdapter] = true;
            emit SupportedBridgeAdapterSet(destinationChainId, bridgeAdapter, true);
        }

        if (remoteChainConfig.defaultBridgeAdapter == bridgeAdapter) return;

        remoteChainConfig.defaultBridgeAdapter = bridgeAdapter;
        emit DefaultBridgeAdapterSet(destinationChainId, bridgeAdapter);
    }

    /// @inheritdoc IPortal
    function setSupportedBridgeAdapter(uint32 destinationChainId, address bridgeAdapter, bool supported) external onlyRole(OPERATOR_ROLE) {
        _revertIfInvalidDestinationChain(destinationChainId);
        if (bridgeAdapter == address(0)) revert ZeroBridgeAdapter();

        ChainConfig storage remoteChainConfig = _getPortalStorageLocation().remoteChainConfig[destinationChainId];

        if (remoteChainConfig.supportedBridgeAdapter[bridgeAdapter] == supported) return;

        // If the bridge adapter being removed is currently set as the default, clear the default adapter
        if (!supported && remoteChainConfig.defaultBridgeAdapter == bridgeAdapter) {
            remoteChainConfig.defaultBridgeAdapter = address(0);
            emit DefaultBridgeAdapterSet(destinationChainId, address(0));
        }

        remoteChainConfig.supportedBridgeAdapter[bridgeAdapter] = supported;
        emit SupportedBridgeAdapterSet(destinationChainId, bridgeAdapter, supported);
    }

    /// @inheritdoc IPortal
    function setSupportedBridgingPath(
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bool supported
    ) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroSourceToken(sourceToken);
        _revertIfInvalidDestinationChain(destinationChainId);
        _revertIfZeroDestinationToken(destinationToken);

        PortalStorageStruct storage $ = _getPortalStorageLocation();

        if ($.supportedBridgingPath[sourceToken][destinationChainId][destinationToken] == supported) return;

        $.supportedBridgingPath[sourceToken][destinationChainId][destinationToken] = supported;
        emit SupportedBridgingPathSet(sourceToken, destinationChainId, destinationToken, supported);
    }

    /// @inheritdoc IPortal
    function setPayloadGasLimit(uint32 destinationChainId, PayloadType payloadType, uint256 gasLimit) external onlyRole(OPERATOR_ROLE) {
        _revertIfInvalidDestinationChain(destinationChainId);
        if (gasLimit == 0) revert ZeroPayloadGasLimit();
        ChainConfig storage remoteChainConfig = _getPortalStorageLocation().remoteChainConfig[destinationChainId];

        if (remoteChainConfig.payloadGasLimit[payloadType] == gasLimit) return;

        remoteChainConfig.payloadGasLimit[payloadType] = gasLimit;
        emit PayloadGasLimitSet(destinationChainId, payloadType, gasLimit);
    }

    /// @dev Reverts if `msg.sender` is not authorized to upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

    /// @inheritdoc IPortal
    function pauseSend() public onlyRole(PAUSER_ROLE) {
        _pauseSend();
    }

    /// @inheritdoc IPortal
    function unpauseSend() public onlyRole(PAUSER_ROLE) {
        _unpauseSend();
    }

    /// @inheritdoc IPortal
    function pauseReceive() public onlyRole(PAUSER_ROLE) {
        _pauseReceive();
    }

    /// @inheritdoc IPortal
    function unpauseReceive() public onlyRole(PAUSER_ROLE) {
        _unpauseReceive();
    }

    /// @inheritdoc IPortal
    function pauseAll() public onlyRole(PAUSER_ROLE) {
        _pauseSend();
        _pauseReceive();
    }

    /// @inheritdoc IPortal
    function unpauseAll() public onlyRole(PAUSER_ROLE) {
        _unpauseSend();
        _unpauseReceive();
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     EXTERNAL VIEW/PURE FUNCTIONS                      //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IPortal
    /// @dev Using block.chainid directly to prevent a replay attack if a chain undergoes a contentious hard fork.
    function currentChainId() public view returns (uint32) {
        // NOTE: For most EVM chains, ID fits into uint32
        return block.chainid.toUint32();
    }

    function getNonce() external view returns (uint256) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.nonce;
    }

    /// @inheritdoc IPortal
    function defaultBridgeAdapter(uint32 destinationChainId) public view returns (address) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.remoteChainConfig[destinationChainId].defaultBridgeAdapter;
    }

    /// @inheritdoc IPortal
    function supportedBridgeAdapter(uint32 destinationChainId, address bridgeAdapter) public view returns (bool) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.remoteChainConfig[destinationChainId].supportedBridgeAdapter[bridgeAdapter];
    }

    /// @inheritdoc IPortal
    function supportedBridgingPath(address sourceToken, uint32 destinationChainId, bytes32 destinationToken) external view returns (bool) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.supportedBridgingPath[sourceToken][destinationChainId][destinationToken];
    }

    /// @inheritdoc IPortal
    function payloadGasLimit(uint32 destinationChainId, PayloadType payloadType) public view returns (uint256) {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        return $.remoteChainConfig[destinationChainId].payloadGasLimit[payloadType];
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
        address bridgeAdapter = defaultBridgeAdapter(destinationChainId);
        _revertIfZeroBridgeAdapter(destinationChainId, bridgeAdapter);

        return _quote(destinationChainId, payloadType, bridgeAdapter);
    }

    /// @inheritdoc IPortal
    function quote(uint32 destinationChainId, PayloadType payloadType, address bridgeAdapter) external view returns (uint256) {
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        return _quote(destinationChainId, payloadType, bridgeAdapter);
    }

    /// @inheritdoc IPortal
    function sendPaused() public view returns (bool) {
        return _getPortalStorageLocation().sendPaused;
    }

    /// @inheritdoc IPortal
    function receivePaused() public view returns (bool) {
        return _getPortalStorageLocation().receivePaused;
    }

    ///////////////////////////////////////////////////////////////////////////
    //                     INTERNAL INTERACTIVE FUNCTIONS                    //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Sends the specified payload to the destination chain.
    function _sendMessage(
        uint32 destinationChainId,
        PayloadType payloadType,
        bytes32 refundAddress,
        bytes memory payload,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) internal {
        IBridgeAdapter(bridgeAdapter).sendMessage{ value: msg.value }(
            destinationChainId, _getPayloadGasLimitOrRevert(destinationChainId, payloadType), refundAddress, payload, bridgeAdapterArgs
        );
    }

    /// @dev Transfers $M Token or $M Extension to the destination chain.
    function _sendToken(
        uint256 amount,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) internal returns (bytes32 messageId) {
        _revertIfZeroAmount(amount);
        _revertIfZeroRefundAddress(refundAddress);
        _revertIfZeroSourceToken(sourceToken);
        _revertIfZeroDestinationToken(destinationToken);
        _revertIfZeroRecipient(recipient);
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);
        _revertIfUnsupportedBridgingPath(sourceToken, destinationChainId, destinationToken);
        _revertIfTokenTransferDisabled(destinationChainId);

        // Transfer and if the source token isn't $M token, unwrap it to $M token.
        _transferAndUnwrap(sourceToken, amount);

        // Burn $M tokens on Spoke.
        // In case of Hub, only update the bridged principal amount as tokens already transferred.
        _burnOrLock(destinationChainId, amount);

        bytes memory payload;
        uint128 index;
        // Prevent stack too deep error
        uint256 transferAmount = amount;
        (payload, messageId, index) =
            _createTokenTransferPayload(transferAmount, destinationChainId, destinationToken, msg.sender, recipient, bridgeAdapter);

        _sendMessage(destinationChainId, PayloadType.TokenTransfer, refundAddress, payload, bridgeAdapter, bridgeAdapterArgs);

        emit TokenSent(
            sourceToken, destinationChainId, destinationToken, msg.sender, recipient, transferAmount, index, bridgeAdapter, messageId
        );
    }

    /// @dev Transfers the specified amount of `sourceToken` from the sender to the Portal
    ///      If the source token is not $M token, it unwraps it to $M token.
    ///      Reverts if the actual amount received is less than the specified amount.
    /// @param sourceToken     The address of the source token.
    /// @param specifiedAmount The amount specified by the sender to transfer.
    function _transferAndUnwrap(address sourceToken, uint256 specifiedAmount) internal {
        uint256 mBalanceBefore = _mBalanceOf(address(this));
        uint256 sourceTokenBalanceBefore = _tokenBalanceOf(sourceToken, address(this));

        // Transfer source token from the sender
        IERC20(sourceToken).safeTransferFrom(msg.sender, address(this), specifiedAmount);
        uint256 actualAmount;

        // If the source token isn't $M token, unwrap it
        if (sourceToken != mToken) {
            // The actual amount of the source tokens that Portal received from the sender.
            actualAmount = _tokenBalanceOf(sourceToken, address(this)) - sourceTokenBalanceBefore;

            // NOTE: SwapFacility doesn't support fee-on-transfer tokens.
            // Revert if the actual amount received is less than the specified amount.
            if (actualAmount < specifiedAmount) revert InsufficientAmountReceived(specifiedAmount, actualAmount);

            IERC20(sourceToken).forceApprove(swapFacility, actualAmount);
            ISwapFacilityLike(swapFacility).swapOutM(sourceToken, actualAmount, address(this));
        }

        // The actual amount of $M tokens that Portal received from the SwapFacility.
        actualAmount = _mBalanceOf(address(this)) - mBalanceBefore;

        // NOTE: The actual amount received can be less than the specified amount due to:
        //       - rounding down when transferring between $M earners and non-earners in Wrapped $M V1;
        //       - fee on unwrap in the source $M extension token.
        if (specifiedAmount > actualAmount) {
            unchecked {
                // Revert if the difference between the specified transfer amount and
                // the actual amount exceeds the maximum acceptable rounding error.
                if (specifiedAmount - actualAmount > _getMaxRoundingError()) {
                    revert InsufficientAmountReceived(specifiedAmount, actualAmount);
                }
                // Otherwise, the specified amount will be transferred, and the deficit caused
                // by rounding down will be covered from the yield earned by HubPortal.
                // SpokePortal must be funded with $M to cover such deficits.
            }
        }
    }

    /// @dev Creates token transfer payload.
    /// @return payload   The encoded payload.
    /// @return messageId The message ID for the cross-chain transfer.
    /// @return index     The current $M token index.
    function _createTokenTransferPayload(
        uint256 transferAmount,
        uint32 destinationChainId,
        bytes32 destinationToken,
        address sender,
        bytes32 recipient,
        address bridgeAdapter
    ) internal returns (bytes memory payload, bytes32 messageId, uint128 index) {
        messageId = _getMessageId(destinationChainId);
        index = _currentIndex();
        bytes32 destinationPeer = IBridgeAdapter(bridgeAdapter).getPeer(destinationChainId);
        payload = PayloadEncoder.encodeTokenTransfer(
            destinationChainId, destinationPeer, messageId, index, transferAmount, destinationToken, sender, recipient
        );
    }

    /// @dev Sends the fill report to the destination chain.
    function _sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) private returns (bytes32 messageId) {
        if (msg.sender != orderBook) revert NotOrderBook();
        _revertIfZeroRefundAddress(refundAddress);
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        bytes memory payload;
        uint128 index;
        // Prevent stack too deep error
        (payload, messageId, index) = _createFillReportPayload(destinationChainId, report, bridgeAdapter);

        _sendMessage(destinationChainId, PayloadType.FillReport, refundAddress, payload, bridgeAdapter, bridgeAdapterArgs);

        emit FillReportSent(
            destinationChainId,
            report.orderId,
            report.amountInToRelease,
            report.amountOutFilled,
            report.originRecipient,
            report.tokenIn,
            index,
            bridgeAdapter,
            messageId
        );
    }

    /// @dev Creates fill report payload.
    /// @return payload   The encoded payload.
    /// @return messageId The message ID for the cross-chain fill report.
    /// @return index     The current $M token index.
    function _createFillReportPayload(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        address bridgeAdapter
    ) internal returns (bytes memory payload, bytes32 messageId, uint128 index) {
        messageId = _getMessageId(destinationChainId);
        index = _currentIndex();

        payload = PayloadEncoder.encodeFillReport(
            destinationChainId,
            IBridgeAdapter(bridgeAdapter).getPeer(destinationChainId),
            messageId,
            index,
            report.orderId,
            report.amountInToRelease,
            report.amountOutFilled,
            report.originRecipient,
            report.tokenIn
        );
    }

    function _sendCancelReport(
        uint32 destinationChainId,
        IOrderBookLike.CancelReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) private returns (bytes32 messageId) {
        if (msg.sender != orderBook) revert NotOrderBook();
        _revertIfZeroRefundAddress(refundAddress);
        _revertIfUnsupportedBridgeAdapter(destinationChainId, bridgeAdapter);

        uint128 index = _currentIndex();
        messageId = _getMessageId(destinationChainId);
        bytes memory payload = PayloadEncoder.encodeCancelReport(
            destinationChainId,
            IBridgeAdapter(bridgeAdapter).getPeer(destinationChainId),
            messageId,
            index,
            report.orderId,
            report.originSender,
            report.tokenIn,
            report.amountInToRefund
        );

        _sendMessage(destinationChainId, PayloadType.CancelReport, refundAddress, payload, bridgeAdapter, bridgeAdapterArgs);

        emit CancelReportSent(
            destinationChainId,
            report.orderId,
            report.originSender,
            report.tokenIn,
            report.amountInToRefund,
            index,
            bridgeAdapter,
            messageId
        );
    }

    /// @dev   Handles token transfer message on the destination.
    /// @param sourceChainId The ID of the source chain.
    /// @param payload       The message payload.
    function _receiveToken(uint32 sourceChainId, bytes memory payload) private {
        (bytes32 messageId, uint128 index, uint256 amount, address destinationToken, bytes32 sender, address recipient) =
            payload.decodeTokenTransfer();

        emit TokenReceived(sourceChainId, destinationToken, sender, recipient, amount, index, messageId);

        if (destinationToken == mToken) {
            // mints or unlocks $M Token to the recipient
            _mintOrUnlock(sourceChainId, recipient, amount, index);
        } else {
            // mints or unlocks $M Token to the Portal
            _mintOrUnlock(sourceChainId, address(this), amount, index);

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
        (
            bytes32 messageId,
            uint128 index,
            bytes32 orderId,
            uint128 amountInToRelease,
            uint128 amountOutFilled,
            bytes32 originRecipient,
            bytes32 tokenIn
        ) = payload.decodeFillReport();

        IOrderBookLike(orderBook)
            .reportFill(
                sourceChainId,
                IOrderBookLike.FillReport({
                    orderId: orderId,
                    amountInToRelease: amountInToRelease,
                    amountOutFilled: amountOutFilled,
                    originRecipient: originRecipient,
                    tokenIn: tokenIn
                })
            );

        _updateMTokenIndex(index);

        emit FillReportReceived(sourceChainId, orderId, amountInToRelease, amountOutFilled, originRecipient, tokenIn, index, messageId);
    }

    /// @dev   Handles cancel report message on the destination.
    /// @param sourceChainId The ID of the source chain.
    /// @param payload       The message payload.
    function _receiveCancelReport(uint32 sourceChainId, bytes memory payload) private {
        (bytes32 messageId, uint128 index, bytes32 orderId, bytes32 orderSender, bytes32 tokenIn, uint128 amountInToRefund) =
            payload.decodeCancelReport();

        IOrderBookLike(orderBook)
            .reportCancel(
                sourceChainId,
                IOrderBookLike.CancelReport({
                    orderId: orderId, originSender: orderSender, tokenIn: tokenIn, amountInToRefund: amountInToRefund
                })
            );
        _updateMTokenIndex(index);

        emit CancelReportReceived(sourceChainId, orderId, orderSender, tokenIn, amountInToRefund, index, messageId);
    }

    /// @dev Pauses sending cross-chain messages.
    function _pauseSend() private {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if ($.sendPaused) return;
        $.sendPaused = true;
        emit SendPaused();
    }

    /// @dev Unpauses sending cross-chain messages.
    function _unpauseSend() private {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if (!$.sendPaused) return;
        $.sendPaused = false;
        emit SendUnpaused();
    }

    /// @dev Pauses receiving cross-chain messages.
    function _pauseReceive() private {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if ($.receivePaused) return;
        $.receivePaused = true;
        emit ReceivePaused();
    }

    /// @dev Unpauses receiving cross-chain messages.
    function _unpauseReceive() private {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if (!$.receivePaused) return;
        $.receivePaused = false;
        emit ReceiveUnpaused();
    }

    /// @dev Generates a unique across all chains message ID.
    /// @param destinationChainId The ID of the destination chain.
    function _getMessageId(uint32 destinationChainId) internal returns (bytes32) {
        return keccak256(abi.encode(currentChainId(), destinationChainId, _getPortalStorageLocation().nonce++));
    }

    /// @dev   Overridden in SpokePortal to handle custom payload messages.
    /// @param payloadType The type of the payload (Index, RegistrarKey, or RegistrarList).
    /// @param payload     The message payload to process.
    function _receiveCustomPayload(PayloadType payloadType, bytes memory payload) internal virtual { }

    /// @dev   HubPortal:   unlocks and transfers `amount` $M tokens to `recipient`.
    ///        SpokePortal: mints `amount` $M tokens to `recipient`.
    /// @param sourceChainId The ID of the source chain.
    /// @param recipient     The account receiving $M tokens.
    /// @param amount        The amount of $M tokens to unlock/mint.
    /// @param index         The index from the source chain.
    function _mintOrUnlock(uint32 sourceChainId, address recipient, uint256 amount, uint128 index) internal virtual { }

    /// @dev   HubPortal:   locks `amount` $M tokens.
    ///        SpokePortal: burns `amount` $M tokens.
    /// @param destinationChainId The ID of the destination chain.
    /// @param amount             The amount of $M tokens to lock/burn.
    function _burnOrLock(uint32 destinationChainId, uint256 amount) internal virtual { }

    /// @dev Overridden in SpokePortal to update the $M token index.
    function _updateMTokenIndex(uint128 index) internal virtual { }

    ///////////////////////////////////////////////////////////////////////////
    //                 INTERNAL/PRIVATE VIEW/PURE FUNCTIONS                  //
    ///////////////////////////////////////////////////////////////////////////

    /// @dev Returns the fee for delivering a cross-chain message.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The payload type: TokenTransfer = 0, Index = 1, RegistrarKey = 2, RegistrarList = 3, FillReport = 4
    /// @param  bridgeAdapter      The address of the bridge adapter.
    function _quote(uint32 destinationChainId, PayloadType payloadType, address bridgeAdapter) private view returns (uint256) {
        uint256 gasLimit = _getPayloadGasLimitOrRevert(destinationChainId, payloadType);

        // NOTE: For quoting delivery fee, the content of the message doesn’t matter,
        //       only the destination chain, gas limit required to process the message on the destination
        //       and, for some protocols, payload size is relevant.
        bytes memory payload = PayloadEncoder.generateEmptyPayload(payloadType);

        return IBridgeAdapter(bridgeAdapter).quote(destinationChainId, gasLimit, payload);
    }

    /// @dev Returns the gas limit for the specified payload type on the destination chain.
    ///      Reverts if the gas limit is not set.
    function _getPayloadGasLimitOrRevert(uint32 destinationChainId, PayloadType payloadType) internal view returns (uint256) {
        uint256 gasLimit = payloadGasLimit(destinationChainId, payloadType);
        if (gasLimit == 0) revert PayloadGasLimitNotSet(destinationChainId, payloadType);
        return gasLimit;
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

    function _revertIfInvalidDestinationChain(uint32 destinationChainId) internal view {
        if (destinationChainId == currentChainId()) revert InvalidDestinationChain(destinationChainId);
    }

    function _revertIfZeroSourceToken(address sourceToken) internal pure {
        if (sourceToken == address(0)) revert ZeroSourceToken();
    }

    function _revertIfZeroDestinationToken(bytes32 destinationToken) internal pure {
        if (destinationToken == bytes32(0)) revert ZeroDestinationToken();
    }

    function _revertIfZeroRecipient(bytes32 recipient) internal pure {
        if (recipient == bytes32(0)) revert ZeroRecipient();
    }

    function _revertIfUnsupportedBridgeAdapter(uint32 chainId, address bridgeAdapter) internal view {
        if (!supportedBridgeAdapter(chainId, bridgeAdapter)) revert UnsupportedBridgeAdapter(chainId, bridgeAdapter);
    }

    /// @dev Overridden in SpokePortal to allow bridging only to the Hub chain for isolated Spokes.
    function _revertIfTokenTransferDisabled(uint32 chainId) internal view virtual { }

    function _revertIfUnsupportedBridgingPath(address sourceToken, uint32 destinationChainId, bytes32 destinationToken) internal view {
        PortalStorageStruct storage $ = _getPortalStorageLocation();
        if (!$.supportedBridgingPath[sourceToken][destinationChainId][destinationToken]) {
            revert UnsupportedBridgingPath(sourceToken, destinationChainId, destinationToken);
        }
    }

    /// @dev Returns the current M token index used by the Portal.
    function _currentIndex() internal view virtual returns (uint128) { }

    /// @dev Returns the maximum rounding error that can occur when transferring and unwrapping $M extensions.
    ///      This applies only to Wrapped $M V1 and should be removed once Wrapped $M is upgraded.
    function _getMaxRoundingError() private view returns (uint256) {
        return _currentIndex() / IndexingMath.EXP_SCALED_ONE + 1;
    }

    /// @dev Returns the M Token balance of `account`.
    function _mBalanceOf(address account) internal view returns (uint256) {
        return IERC20(mToken).balanceOf(account);
    }

    /// @dev Returns the `token` balance of `account`.
    function _tokenBalanceOf(address token, address account) internal view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}
