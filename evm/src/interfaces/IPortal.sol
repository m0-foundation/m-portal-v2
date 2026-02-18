// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.33;

import { PayloadType } from "../libraries/PayloadEncoder.sol";
import { IOrderBookLike } from "./IOrderBookLike.sol";

/// @title  IPortal interface
/// @author M0 Labs
/// @notice Subset of functions inherited by both IHubPortal and ISpokePortal.
interface IPortal {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when token is sent to a destination chain.
    /// @param  sourceToken        The address of the token on the source chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  sender             The account initiated bridging of the M tokens via the Portal.
    /// @param  recipient          The account receiving tokens on destination chain.
    /// @param  amount             The amount of tokens.
    /// @param  index              The $M token index.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param  messageId          The unique ID for the sent message.
    event TokenSent(
        address indexed sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        address indexed sender,
        bytes32 indexed recipient,
        uint256 amount,
        uint128 index,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when token is received from a source chain.
    /// @param  sourceChainId    The ID of the source chain.
    /// @param  destinationToken The address of the token on the destination chain.
    /// @param  sender           The account sending tokens.
    /// @param  recipient        The account receiving tokens.
    /// @param  amount           The amount of tokens.
    /// @param  index            $M token index received from the source chain.
    /// @param  messageId        The unique ID of the message.
    event TokenReceived(
        uint32 sourceChainId,
        address indexed destinationToken,
        bytes32 indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index,
        bytes32 messageId
    );

    /// @notice Emitted when a fill report is sent to a origin chain.
    /// @param destinationChainId The ID of the destination chain.
    /// @param orderId            The ID of the order being reported
    /// @param amountInToRelease  The amount of input token to release to the filler on the origin chain
    /// @param amountOutFilled    The amount of output token that was filled on the destination chain
    /// @param originRecipient    The address on the origin chain that should receive released funds
    /// @param tokenIn            The address of the input token on the origin chain
    /// @param index              $M token index.
    /// @param bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param messageId          The unique identifier for the sent message.
    event FillReportSent(
        uint32 indexed destinationChainId,
        bytes32 indexed orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 tokenIn,
        uint128 index,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when a fill report is received from a source chain.
    /// @param sourceChainId      The ID of the source chain.
    /// @param orderId            The ID of the order being reported
    /// @param amountInToRelease  The amount of input token to release to the filler on the origin chain
    /// @param amountOutFilled    The amount of output token that was filled on the destination chain
    /// @param originRecipient    The address on the origin chain that should receive released funds
    /// @param tokenIn            The address of the input token on the origin chain
    /// @param index              $M token index received from the source chain.
    /// @param messageId          The unique identifier for the message.
    event FillReportReceived(
        uint32 indexed sourceChainId,
        bytes32 indexed orderId,
        uint128 amountInToRelease,
        uint128 amountOutFilled,
        bytes32 originRecipient,
        bytes32 tokenIn,
        uint128 index,
        bytes32 messageId
    );

    /// @notice Emitted when a cancel report is sent to a origin chain.
    /// @param destinationChainId The ID of the destination chain.
    /// @param orderId            The ID of the order being reported.
    /// @param originSender       The address on the origin chain that created the order.
    /// @param tokenIn            The address of the input token on the origin chain.
    /// @param amountInToRefund   The amount of input token to refund to the origin sender.
    /// @param index              $M token index.
    /// @param bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param messageId          The unique identifier for the sent message.
    event CancelReportSent(
        uint32 indexed destinationChainId,
        bytes32 indexed orderId,
        bytes32 originSender,
        bytes32 tokenIn,
        uint128 amountInToRefund,
        uint128 index,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when an order cancel report is received from a source chain.
    /// @param sourceChainId    The ID of the source chain.
    /// @param orderId          The ID of the order being reported.
    /// @param originSender     The address on the origin chain that created the order.
    /// @param tokenIn          The address of the input token on the origin chain.
    /// @param amountInToRefund The amount of input token to refund to the origin sender.
    /// @param index            $M token index received from the source chain.
    /// @param messageId        The unique identifier for the message.
    event CancelReportReceived(
        uint32 indexed sourceChainId,
        bytes32 indexed orderId,
        bytes32 originSender,
        bytes32 tokenIn,
        uint128 amountInToRefund,
        uint128 index,
        bytes32 messageId
    );

    /// @notice Emitted when wrapping M token to the Extension token is failed on the destination.
    /// @param  destinationExtension The address of M Extension on the destination chain.
    /// @param  recipient            The account receiving tokens.
    /// @param  amount               The amount of tokens.
    event WrapFailed(address indexed destinationExtension, address indexed recipient, uint256 amount);

    /// @notice Emitted when a bridging path support status is updated.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  supported          `True` if the token is supported, `false` otherwise.
    event SupportedBridgingPathSet(
        address indexed sourceToken, uint32 indexed destinationChainId, bytes32 indexed destinationToken, bool supported
    );

    /// @notice Emitted when the gas limit for a payload type is updated.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The type of payload.
    /// @param  gasLimit           The gas limit.
    event PayloadGasLimitSet(uint32 indexed destinationChainId, PayloadType indexed payloadType, uint256 gasLimit);

    /// @notice Emitted when the default bridge adapter for a destination chain is set.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  bridgeAdapter      The address of the bridge adapter.
    event DefaultBridgeAdapterSet(uint32 indexed destinationChainId, address indexed bridgeAdapter);

    /// @notice Emitted when a supported bridge adapter for a destination chain is set.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  bridgeAdapter      The address of the bridge adapter.
    /// @param  supported          `True` if the bridge adapter is supported, `false` otherwise.
    event SupportedBridgeAdapterSet(uint32 indexed destinationChainId, address indexed bridgeAdapter, bool supported);

    /// @notice Emitted when sending is paused.
    event SendPaused();

    /// @notice Emitted when sending is unpaused.
    event SendUnpaused();

    /// @notice Emitted when receiving is paused.
    event ReceivePaused();

    /// @notice Emitted when receiving is unpaused.
    event ReceiveUnpaused();

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the M token is 0x0.
    error ZeroMToken();

    /// @notice Thrown when the Wrapped M token is 0x0.
    error ZeroWrappedMToken();

    /// @notice Thrown when the Registrar address is 0x0.
    error ZeroRegistrar();

    /// @notice Thrown when the Swap Facility address is 0x0.
    error ZeroSwapFacility();

    /// @notice Thrown when the Order Book address is 0x0.
    error ZeroOrderBook();

    /// @notice Thrown when the admin address is 0x0.
    error ZeroAdmin();

    /// @notice Thrown when the pauser address is 0x0.
    error ZeroPauser();

    /// @notice Thrown when the operator address is 0x0.
    error ZeroOperator();

    /// @notice Thrown when the source token address is 0x0.
    error ZeroSourceToken();

    /// @notice Thrown when the destination token address is 0x0.
    error ZeroDestinationToken();

    /// @notice Thrown when the transfer amount is 0.
    error ZeroAmount();

    /// @notice Thrown when the refund address is 0x0.
    error ZeroRefundAddress();

    /// @notice Thrown when the recipient address is 0x0.
    error ZeroRecipient();

    /// @notice Thrown when the bridge adapter address is 0x0.
    error ZeroBridgeAdapter();

    /// @notice Thrown when the payload gas limit is 0.
    error ZeroPayloadGasLimit();

    /// @notice Thrown when `receiveMessage` function caller is not the bridge.
    error NotBridgeAdapter();

    /// @notice Thrown when `sendFillReport` function caller is not the Order Book.
    error NotOrderBook();

    /// @notice Thrown when the destination chain id is equal to the source one.
    error InvalidDestinationChain(uint32 destinationChainId);

    /// @notice Thrown in `sendToken` function when bridging path is not supported
    error UnsupportedBridgingPath(address sourceToken, uint32 destinationChainId, bytes32 destinationToken);

    /// @notice Thrown when the bridge adapter is not supported for the destination chain.
    error UnsupportedBridgeAdapter(uint32 destinationChainId, address bridgeAdapter);

    /// @notice Thrown in `sendToken` function when the actual amount received is less than the specified amount.
    error InsufficientAmountReceived(uint256 specifiedAmount, uint256 actualAmount);

    /// @notice Thrown when sending is paused.
    error SendingPaused();

    /// @notice Thrown when receiving is paused.
    error ReceivingPaused();

    /// @notice Thrown when a message with the given ID has already been processed.
    error MessageAlreadyProcessed(bytes32 messageId);

    /// @notice Thrown when the gas limit for the specified payload type is not configured.
    error PayloadGasLimitNotSet(uint32 destinationChainId, PayloadType payloadType);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);

    /// @notice The address of the Swap Facility contract.
    function swapFacility() external view returns (address);

    /// @notice The address of the Order Book contract.
    function orderBook() external view returns (address);

    /// @notice The ID of the chain on which the Portal contract is deployed.
    function currentChainId() external view returns (uint32);

    /// @notice Returns the current nonce used for generating unique message IDs.
    function getNonce() external view returns (uint256);

    /// @notice Returns the default bridge adapter for the given destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    function defaultBridgeAdapter(uint32 destinationChainId) external view returns (address);

    /// @notice Indicates whether the provided bridge adapter is supported for the destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  bridgingAdapter    The address of the bridge adapter.
    function supportedBridgeAdapter(uint32 destinationChainId, address bridgingAdapter) external view returns (bool);

    /// @notice Indicates whether the provided bridging path is supported.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    function supportedBridgingPath(address sourceToken, uint32 destinationChainId, bytes32 destinationToken) external view returns (bool);

    /// @notice Returns the gas limit required to process a message
    ///         with the specified payload type on the destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The type of payload.
    function payloadGasLimit(uint32 destinationChainId, PayloadType payloadType) external view returns (uint256);

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /// @notice The address of the original caller of `sendToken` function.
    function msgSender() external view returns (address);

    /// @notice Returns the fee for delivering a cross-chain message using the default bridge adapter.
    /// @dev    The fee must be passed as msg.value when calling any function that sends a cross-chain message (e.g. `sendToken`).
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The payload type: TokenTransfer = 0, Index = 1, RegistrarKey = 2, RegistrarList = 3, FillReport = 4, EarnerMerkleRoot = 5, CancelReport = 6
    function quote(uint32 destinationChainId, PayloadType payloadType) external view returns (uint256);

    /// @notice Returns the fee for delivering a cross-chain message using the specified bridge adapter.
    /// @dev    The fee must be passed as msg.value when calling any function that sends a cross-chain message (e.g. `sendToken`).
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The payload type: TokenTransfer = 0, Index = 1, RegistrarKey = 2, RegistrarList = 3, FillReport = 4, EarnerMerkleRoot = 5, CancelReport = 6
    /// @param  bridgeAdapter      The address of the bridge adapter.
    function quote(uint32 destinationChainId, PayloadType payloadType, address bridgeAdapter) external view returns (uint256);

    /// @notice Indicates whether sending cross-chain messages is paused.
    function sendPaused() external view returns (bool);

    /// @notice Indicates whether receiving cross-chain messages is paused.
    function receivePaused() external view returns (bool);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sets a bridging path support status.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  supported          `True` if the token is supported, `false` otherwise.
    function setSupportedBridgingPath(address sourceToken, uint32 destinationChainId, bytes32 destinationToken, bool supported) external;

    /// @notice Sets the gas limit required to process a message
    ///         with the specified payload type on the destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  payloadType        The payload type.
    /// @param  gasLimit           The gas limit required to process the message.
    function setPayloadGasLimit(uint32 destinationChainId, PayloadType payloadType, uint256 gasLimit) external;

    /// @notice Sets the default bridge adapter for a destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  bridgeAdapter      The address of the bridge adapter.
    function setDefaultBridgeAdapter(uint32 destinationChainId, address bridgeAdapter) external;

    /// @notice Sets a supported bridge adapter for a destination chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  bridgeAdapter      The address of the bridge adapter.
    /// @param  supported          `True` if the bridge adapter is supported, `false` otherwise.
    function setSupportedBridgeAdapter(uint32 destinationChainId, address bridgeAdapter, bool supported) external;

    /// @notice Transfers $M Token or $M Extension to the destination chain using the default bridge adapter.
    /// @dev    If wrapping on the destination fails, the recipient will receive $M token.
    /// @param  amount             The amount of tokens to transfer.
    /// @param  sourceToken        The address of the token ($M or $M Extension) on the source chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token ($M or $M Extension) on the destination chain.
    /// @param  recipient          The account to receive tokens.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The unique identifier of the message sent.
    function sendToken(
        uint256 amount,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Transfers $M Token or $M Extension to the destination chain using the specified bridge adapter.
    /// @dev    If wrapping on the destination fails, the recipient will receive $M token.
    /// @param  amount             The amount of tokens to transfer.
    /// @param  sourceToken        The address of the token ($M or $M Extension) on the source chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationToken   The address of the token ($M or $M Extension) on the destination chain.
    /// @param  recipient          The account to receive tokens.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapter      The address of the bridge adapter to use.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The unique identifier of the message sent.
    function sendToken(
        uint256 amount,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the fill report to the destination chain using the default bridge adapter.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  report             The OrderBook fill report to send.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The ID uniquely identifying the message.
    function sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the fill report to the destination chain using the specified bridge adapter.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  report             The OrderBook fill report to send.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapter      The address of the bridge adapter to use.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The ID uniquely identifying the message.
    function sendFillReport(
        uint32 destinationChainId,
        IOrderBookLike.FillReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the cancel report to the destination chain using the default bridge adapter.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  report             The OrderBook cancel report to send.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The ID uniquely identifying the message.
    function sendCancelReport(
        uint32 destinationChainId,
        IOrderBookLike.CancelReport calldata report,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the cancel report to the destination chain using the specified bridge adapter.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  report             The OrderBook cancel report to send.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapter      The address of the bridge adapter to use.
    /// @param  bridgeAdapterArgs  The optional bridge adapter arguments, could be empty.
    /// @return messageId          The ID uniquely identifying the message.
    function sendCancelReport(
        uint32 destinationChainId,
        IOrderBookLike.CancelReport calldata report,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Receives a message from the bridge.
    /// @param  sourceChainId The chain Id of the source chain.
    /// @param  payload       The message payload.
    function receiveMessage(uint32 sourceChainId, bytes calldata payload) external;

    /// @notice Pauses sending cross-chain messages.
    function pauseSend() external;

    /// @notice Unpauses sending cross-chain messages.
    function unpauseSend() external;

    /// @notice Pauses receiving cross-chain messages.
    function pauseReceive() external;

    /// @notice Unpauses receiving cross-chain messages.
    function unpauseReceive() external;

    /// @notice Pauses both sending and receiving cross-chain messages.
    function pauseAll() external;

    /// @notice Unpauses both sending and receiving cross-chain messages.
    function unpauseAll() external;
}
