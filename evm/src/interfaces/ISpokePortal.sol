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

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the chain ID of the Hub chain.
    function hubChainId() external view returns (uint32);
}
