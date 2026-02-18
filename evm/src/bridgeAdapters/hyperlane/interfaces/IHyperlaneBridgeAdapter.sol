// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IMessageRecipient } from "./IMessageRecipient.sol";

/// @title  IHyperlaneBridgeAdapter interface.
/// @author M0 Labs
/// @notice Defines interface specific to Hyperlane Bridge Adapter.
interface IHyperlaneBridgeAdapter is IBridgeAdapter, IMessageRecipient {
    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the Hyperlane Mailbox address is 0x0.
    error ZeroMailbox();

    /// @notice Thrown when the caller is not the Hyperlane Mailbox.
    error NotMailbox();

    /// @notice Thrown when the source chain isn't supported or configured peer doesn't match the sender.
    error UnsupportedSender(bytes32 sender);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of Hyperlane Mailbox contract.
    function mailbox() external view returns (address);
}
