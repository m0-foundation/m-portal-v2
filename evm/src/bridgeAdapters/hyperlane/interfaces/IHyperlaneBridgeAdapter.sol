// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IMessageRecipient } from "./IMessageRecipient.sol";

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
