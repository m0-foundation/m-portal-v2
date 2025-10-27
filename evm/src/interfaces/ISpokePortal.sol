// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IPortal } from "./IPortal.sol";

/// @title  ISpokePortal interface.
/// @author M0 Labs
interface ISpokePortal is IPortal {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when M Token index is received from Mainnet.
    /// @param  index M token index.
    event MTokenIndexReceived(uint128 index);

    /// @notice Emitted when the Registrar key is received from Mainnet.
    /// @param  key   The Registrar key of some value.
    /// @param  value The value.
    event RegistrarKeyReceived(bytes32 indexed key, bytes32 value);

    /// @notice Emitted when the Registrar list status is received from the Hub.
    /// @param  listName The name of the list.
    /// @param  account  The account.
    /// @param  add      Indicates if the account is added or removed from the list.
    event RegistrarListUpdateReceived(bytes32 indexed listName, address indexed account, bool add);
}
