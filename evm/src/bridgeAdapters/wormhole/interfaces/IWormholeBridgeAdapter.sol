// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IVaaV1Receiver } from "./IVaaV1Receiver.sol";

/// @title  IWormholeBridgeAdapter interface.
/// @author M0 Labs
/// @notice Defines interface specific to Wormhole Bridge Adapter.
interface IWormholeBridgeAdapter is IBridgeAdapter, IVaaV1Receiver {
    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the Wormhole Core Bridge address is 0x0.
    error ZeroCoreBridge();

    /// @notice Thrown when the Executor address is 0x0.
    error ZeroExecutor();

    /// @notice Thrown when the invalid VAA is received.
    error InvalidVaa(string reason);

    /// @notice Thrown when the provided fee is insufficient to cover the Wormhole Core Bridge fee.
    error InsufficientFee();

    /// @notice Thrown when calling `quote` function.
    error OnChainQuoteNotSupported();

    /// @notice Thrown when a message with a given hash has already been consumed.
    error MessageAlreadyConsumed(bytes32 hash);

    /// @notice Thrown when the target chain ID does not match the current chain ID.
    error InvalidTargetChain(uint32 targetChainId);

    /// @notice Thrown when the target bridge adapter does not match the current adapter.
    error InvalidTargetBridgeAdapter(bytes32 targetBridgeAdapter);

    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when the sender peer for a remote chain is set.
    /// @param  chainId    The ID of the remote chain.
    /// @param  senderPeer The address of the peer that sends messages from the remote chain.
    event SenderPeerSet(uint32 chainId, bytes32 senderPeer);

    /// @notice Emitted when the msg value for a remote chain is set.
    /// @dev    Only relevant for SVM chains where msg value covers lamports for fees and rent.
    /// @param  chainId  The ID of the remote chain.
    /// @param  msgValue The msg value to include in relay instructions for the remote chain.
    event MsgValueSet(uint32 chainId, uint128 msgValue);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of Wormhole Core Bridge contract.
    function coreBridge() external view returns (address);

    /// @notice Returns the address of Executor contract.
    function executor() external view returns (address);

    /// @notice Defines how long the Guardians should wait before signing a VAA.
    /// @dev    See https://wormhole.com/docs/products/reference/consistency-levels/ for more details.
    function consistencyLevel() external view returns (uint8);

    /// @notice Returns the Wormhole chain ID of the current chain.
    function currentWormholeChainId() external view returns (uint16);

    /// @notice Returns whether a Wormhole message with a given hash has been consumed.
    /// @param  hash The Wormhole hash of the message.
    function messageConsumed(bytes32 hash) external view returns (bool);

    /// @notice Returns the address of the peer that sends messages from the remote chain.
    /// @param  chainId The ID of the remote chain.
    function getSenderPeer(uint32 chainId) external view returns (bytes32);

    /// @notice Returns the value to include in relay instructions for the remote chain.
    /// @param  chainId The ID of the remote chain.
    function getMsgValue(uint32 chainId) external view returns (uint128);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sets the peer address that sends messages from the remote chain.
    /// @dev    Required because Wormhole on SVM uses different addresses for sending (signer PDA)
    ///         vs receiving (program ID)
    /// @param  chainId    The ID of the remote chain.
    /// @param  senderPeer The address of the peer that sends messages from the remote chain.
    function setSenderPeer(uint32 chainId, bytes32 senderPeer) external;

    /// @notice Sets the msg value to include in relay instructions for the remote chain.
    /// @dev    Only required for SVM chains. Must cover lamports for transaction fees,
    ///         priority fees, and rent for new accounts.
    /// @param  chainId  The ID of the remote chain.
    /// @param  msgValue The msg value to include in relay instructions for the remote chain.
    function setMsgValue(uint32 chainId, uint128 msgValue) external;
}
