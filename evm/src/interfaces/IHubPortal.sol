// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IPortal } from "./IPortal.sol";

struct SpokeChainConfig {
    uint248 bridgedPrincipal;
    bool crossSpokeTokenTransferEnabled;
}

/// @title  HubPortal interface.
/// @author M0 Labs
interface IHubPortal is IPortal {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when earning is enabled for the Hub Portal.
    /// @param  index The index at which earning was enabled.
    event EarningEnabled(uint128 index);

    /// @notice Emitted when earning is disabled for the Hub Portal.
    /// @param  index The index at which earning was disabled.
    event EarningDisabled(uint128 index);

    /// @notice Emitted when the M token index is sent to a destination chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  index              The the M token index.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param  messageId          The unique ID of the sent message.
    event MTokenIndexSent(uint32 indexed destinationChainId, uint128 index, address bridgeAdapter, bytes32 messageId);

    /// @notice Emitted when the Registrar key is sent to a destination chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  key                The key that was sent.
    /// @param  value              The value that was sent.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param  messageId          The unique ID of the sent message.
    event RegistrarKeySent(uint32 indexed destinationChainId, bytes32 indexed key, bytes32 value, address bridgeAdapter, bytes32 messageId);

    /// @notice Emitted when the Registrar list status for an account is sent to a destination chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  listName           The name of the list.
    /// @param  account            The account.
    /// @param  status             The status of the account in the list.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @param  messageId          The unique ID of the sent message.
    event RegistrarListStatusSent(
        uint32 indexed destinationChainId,
        bytes32 indexed listName,
        address indexed account,
        bool status,
        address bridgeAdapter,
        bytes32 messageId
    );

    /// @notice Emitted when cross-Spoke token transfer is enabled for the Spoke chain.
    /// @param  spokeChainId     The EVM chain Id of the Spoke.
    /// @param  bridgedPrincipal The principal amount of M tokens bridged to the Spoke chain before the connection was enabled.
    event CrossSpokeTokenTransferEnabled(uint32 spokeChainId, uint248 bridgedPrincipal);

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when trying to enable earning after it has been explicitly disabled.
    error EarningCannotBeReenabled();

    /// @notice Thrown when performing an operation that is not allowed when earning is disabled.
    error EarningIsDisabled();

    /// @notice Thrown when performing an operation that is not allowed when earning is enabled.
    error EarningIsEnabled();

    /// @notice Thrown when trying to unlock more tokens than was locked.
    error InsufficientBridgedBalance();

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Indicates whether earning for HubPortal was ever enabled.
    function wasEarningEnabled() external view returns (bool);

    /// @notice Returns the value of M token index when earning for HubPortal was disabled.
    function disableEarningIndex() external view returns (uint128);

    /// @notice Returns the principal amount of M tokens bridged to a specified Spoke chain.
    /// @dev    Only applicable to isolated Spokes (i.e., `crossSpokeTokenTransferEnabled` == false).
    function bridgedPrincipal(uint32 spokeChainId) external view returns (uint248);

    /// @notice Returns whether cross-Spoke token transfer is enabled for a specified Spoke chain.
    function crossSpokeTokenTransferEnabled(uint32 spokeChainId) external view returns (bool);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sends the $M token index to the destination chain using the default bridge adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @return messageId          The ID uniquely identifying the message.
    function sendMTokenIndex(uint32 destinationChainId, bytes32 refundAddress) external payable returns (bytes32 messageId);

    /// @notice Sends the $M token index to the destination chain using the specified bridge adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @return messageId          The ID uniquely identifying the message.
    function sendMTokenIndex(
        uint32 destinationChainId,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the Registrar key to the destination chain using the default bridge adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  key                The key to send.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @return messageId          The ID uniquely identifying the message.
    function sendRegistrarKey(uint32 destinationChainId, bytes32 key, bytes32 refundAddress) external payable returns (bytes32 messageId);

    /// @notice Sends the Registrar key to the destination chain the specified bridge adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  key                The key to send.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @return messageId          The ID uniquely identifying the message.
    function sendRegistrarKey(
        uint32 destinationChainId,
        bytes32 key,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the Registrar list status for an account to the destination chain using the default bridge adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  listName           The name of the list.
    /// @param  account            The account.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @return messageId          The ID uniquely identifying the message.
    function sendRegistrarListStatus(
        uint32 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress
    ) external payable returns (bytes32 messageId);

    /// @notice Sends the Registrar list status for an account to the destination chain using the default specified adapter.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  listName           The name of the list.
    /// @param  account            The account.
    /// @param  refundAddress      The refund address to receive excess native gas.
    /// @param  bridgeAdapter      The address of the bridge adapter used to send the message.
    /// @return messageId          The ID uniquely identifying the message.
    function sendRegistrarListStatus(
        uint32 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress,
        address bridgeAdapter
    ) external payable returns (bytes32 messageId);

    /// @notice Enables earning for the Hub Portal if allowed by TTG.
    function enableEarning() external;

    /// @notice Disables earning for the Hub Portal if disallowed by TTG.
    function disableEarning() external;

    /// @notice Enables cross-Spoke token transfer for a specified Spoke chain.
    function enableCrossSpokeTokenTransfer(uint32 spokeChainId) external;
}
