// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { PayloadType } from "../libraries/PayloadEncoder.sol";

/// @title  IPortal interface
/// @author M0 Labs
/// @notice Subset of functions inherited by both IHubPortal and ISpokePortal.
interface IPortal {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when M token is sent to a destination chain.
    /// @param  sourceToken        The address of the token on the source chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  sender             The account initiated bridging of the M tokens via the Portal.
    /// @param  recipient          The account receiving tokens on destination chain.
    /// @param  amount             The amount of tokens.
    /// @param  index              The M token index.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param  messageId          The unique identifier for the sent message.
    event MTokenSent(
        address indexed sourceToken,
        uint256 destinationChainId,
        bytes32 destinationToken,
        address indexed sender,
        bytes32 indexed recipient,
        uint256 amount,
        uint128 index,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when M token is received from a source chain.
    /// @param  sourceChainId    The chain Id of the source chain.
    /// @param  destinationToken The address of the token on the destination chain.
    /// @param  sender           The account sending tokens.
    /// @param  recipient        The account receiving tokens.
    /// @param  amount           The amount of tokens.
    /// @param  index            The M token index
    /// @param  bridgeAdapter    The address of the bridge adapter used to deliver the message.
    /// @param  messageId        The unique identifier for the message.
    event MTokenReceived(
        uint256 sourceChainId,
        address indexed destinationToken,
        bytes32 indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when wrapping M token to the Extension token is failed on the destination.
    /// @param  destinationExtension The address of M Extension on the destination chain.
    /// @param  recipient            The account receiving tokens.
    /// @param  amount               The amount of tokens.
    event WrapFailed(address indexed destinationExtension, address indexed recipient, uint256 amount);

    /// @notice Emitted when a bridging path support status is updated.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  supported          `True` if the token is supported, `false` otherwise.
    event SupportedBridgingPathSet(
        address indexed sourceToken,
        uint256 indexed destinationChainId,
        bytes32 indexed destinationToken,
        bool supported
    );

    /// @notice Emitted when the gas limit for a payload type is updated.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  payloadType        The type of payload.
    /// @param  gasLimit           The gas limit.
    event PayloadGasLimitSet(uint256 indexed destinationChainId, PayloadType indexed payloadType, uint256 gasLimit);

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

    /// @notice Thrown when the Bridge address is 0x0.
    error ZeroBridge();

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

    /// @notice Thrown when `receiveMessage` function caller is not the bridge.
    error NotBridge();

    /// @notice Thrown in `transferMLikeToken` function when bridging path is not supported
    error UnsupportedBridgingPath(address sourceToken, uint256 destinationChainId, bytes32 destinationToken);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Wrapped M token.
    function wrappedMToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);

    /// @notice The address of the Swap Facility contract.
    function swapFacility() external view returns (address);

    /// @notice The address of the original caller of `transfer` and `transferMLikeToken` functions.
    function msgSender() external view returns (address);

    /// @notice Indicates whether the provided bridging path is supported.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The EVM chain Id of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @return supported          `True` if the token is supported, `false` otherwise.
    function supportedBridgingPath(
        address sourceToken,
        uint256 destinationChainId,
        bytes32 destinationToken
    ) external view returns (bool supported);

    /// @notice Returns the gas limit required to process a message
    ///         with the specified payload type on the destination chain.
    /// @param  destinationChainId The EVM chain Id of the destination chain.
    /// @param  payloadType        The type of payload.
    function payloadGasLimit(uint256 destinationChainId, PayloadType payloadType) external view returns (uint256);

    /// @notice Returns the delivery fee for token transfer.
    /// @dev    The fee must be passed as msg.value when calling any function that sends a cross-chain message (e.g. `transfer`).
    /// @param  destinationChainId The EVM chain Id of the destination chain.
    /// @param  payloadType        The payload type: TokenTransfer = 0, Index = 1, RegistrarKey = 2, RegistrarList = 3, FillReport = 4
    function quote(uint256 destinationChainId, PayloadType payloadType) external view returns (uint256);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Initializes the Proxy's storage
    /// @param  initialOwner  The address of the owner.
    /// @param  initialPauser The address of the pauser.
    function initialize(address initialOwner, address initialPauser) external;

    /// @notice Sets a bridging path support status.
    /// @param  sourceToken        The address of the token on the current chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  destinationToken   The address of the token on the destination chain.
    /// @param  supported          `True` if the token is supported, `false` otherwise.
    function setSupportedBridgingPath(
        address sourceToken,
        uint256 destinationChainId,
        bytes32 destinationToken,
        bool supported
    ) external;

    /// @notice Sets the gas limit required to process a message
    ///         with the specified payload type on the destination chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  payloadType        The payload type.
    /// @param  gasLimit           The gas limit required to process the message.
    function setPayloadGasLimit(uint256 destinationChainId, PayloadType payloadType, uint256 gasLimit) external;

    /// @notice Transfers $M Token or $M Extension to the destination chain.
    /// @dev    If wrapping on the destination fails, the recipient will receive $M token.
    /// @param  amount             The amount of tokens to transfer.
    /// @param  sourceToken        The address of the token (M or Wrapped M) on the source chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  destinationToken   The address of the token (M or Wrapped M) on the destination chain.
    /// @param  recipient          The account to receive tokens.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @return messageId          The unique identifier of the message sent.
    function transfer(
        uint256 amount,
        address sourceToken,
        uint256 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable returns (bytes32 messageId);

    /// @notice Transfers $M Token or $M Extension to the destination chain.
    /// @dev    If wrapping on the destination fails, the recipient will receive $M token.
    /// @param  amount             The amount of tokens to transfer.
    /// @param  sourceToken        The address of the token (M or Wrapped M) on the source chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  destinationToken   The address of the token (M or Wrapped M) on the destination chain.
    /// @param  recipient          The account to receive tokens.
    /// @param  refundAddress      The address to receive excess native gas on the source chain.
    /// @param  bridgeAdapter      The address of the bridge adapter to use for sending cross-chain message.
    /// @return messageId          The unique identifier of the message sent.
    function transfer(
        uint256 amount,
        address sourceToken,
        uint256 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable returns (bytes32 messageId);

    /// @notice Receives a message from the bridge.
    /// @param  sourceChainId The chain Id of the source chain.
    /// @param  payload       The message payload.
    function receiveMessage(uint256 sourceChainId, bytes calldata payload) external;
}
