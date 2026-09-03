// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.26;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IMessageRecipient } from "./IMessageRecipient.sol";

/// @title  IHyperlaneBridgeAdapter interface.
/// @author M0 Labs
/// @notice Defines interface specific to Hyperlane Bridge Adapter.
interface IHyperlaneBridgeAdapter is IBridgeAdapter, IMessageRecipient {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when the dispatch fee token is set or cleared.
    /// @param  feeToken               The ERC20 used to pay dispatch fees, or 0x0 for native value.
    /// @param  interchainGasPaymaster The IGP approved to pull the fee, or 0x0 when feeToken is 0x0.
    event FeeTokenSet(address indexed feeToken, address indexed interchainGasPaymaster);

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the Hyperlane Mailbox address is 0x0.
    error ZeroMailbox();

    /// @notice Thrown when the caller is not the Hyperlane Mailbox.
    error NotMailbox();

    /// @notice Thrown when a fee token is set without an Interchain Gas Paymaster.
    error ZeroInterchainGasPaymaster();

    /// @notice Thrown when native value is sent while dispatch fees are paid in the fee token.
    error UnexpectedNativeValue();

    /// @notice Thrown when the fee token approval to the Interchain Gas Paymaster fails.
    error FeeTokenApproveFailed();

    ///////////////////////////////////////////////////////////////////////////
    //                          PRIVILEGED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sets the ERC20 used to pay Hyperlane dispatch fees instead of native value.
    /// @dev    Used on chains where value-bearing transactions are not supported (e.g. Seismic).
    ///         The adapter must hold a balance of `feeToken`; the IGP pulls the quoted fee from the
    ///         adapter via transferFrom at dispatch time. Set `feeToken` to 0x0 to restore native fees.
    /// @param  feeToken               The ERC20 fee token, or 0x0 for native value.
    /// @param  interchainGasPaymaster The IGP contract approved to pull the fee. Required when `feeToken` is non-zero.
    function setFeeToken(address feeToken, address interchainGasPaymaster) external;

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of Hyperlane Mailbox contract.
    function mailbox() external view returns (address);

    /// @notice Returns the ERC20 used to pay dispatch fees, or 0x0 when fees are paid in native value.
    function feeToken() external view returns (address);

    /// @notice Returns the Interchain Gas Paymaster approved to pull fee token payments.
    function interchainGasPaymaster() external view returns (address);

    /// @notice Returns the dispatch fee denominated in the fee token.
    /// @dev    Only meaningful when a fee token is configured; reverts route checks like `quote`.
    /// @param  destinationChainId The M0 internal chain ID of the destination.
    /// @param  gasLimit           The gas limit for execution on the destination.
    /// @param  payload            The message payload.
    function quoteFeeToken(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256);
}
