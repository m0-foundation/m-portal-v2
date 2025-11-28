// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IPortal } from "./IPortal.sol";

/// @title  ISpokePortal interface.
/// @author M0 Labs
interface ISpokePortal is IPortal {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when $M Token index is received from the Hub.
    /// @param  index     $M token index.
    /// @param  messageId The unique ID of the message.
    event MTokenIndexReceived(uint128 index, bytes32 messageId);

    /// @notice Emitted when the Registrar key is received from the Hub.
    /// @param  key       The Registrar key of some value.
    /// @param  value     The value.
    /// @param  messageId The unique ID of the message.
    event RegistrarKeyReceived(bytes32 indexed key, bytes32 value, bytes32 messageId);

    /// @notice Emitted when the Registrar list status is received from the Hub.
    /// @param  listName  The name of the list.
    /// @param  account   The account.
    /// @param  add       Indicates if the account is added or removed from the list.
    /// @param  messageId The unique ID of the message.
    event RegistrarListUpdateReceived(bytes32 indexed listName, address indexed account, bool add, bytes32 messageId);

    /// @notice Emitted when a token is sent via the Hub to another spoke or to the Hub itself.
    /// @param  sourceToken             The address of the source token on this spoke.
    /// @param  finalDestinationChainId The chain Id of the final destination.
    /// @param  recipient               The recipient on the final destination.
    /// @param  amount                  The amount of tokens sent.
    event TokenSentViaHub(address indexed sourceToken, uint32 indexed finalDestinationChainId, bytes32 indexed recipient, uint256 amount);
}
