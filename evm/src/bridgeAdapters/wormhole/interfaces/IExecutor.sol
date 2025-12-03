// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title  IExecutor
/// @notice Interface for the Executor contract responsible for handling execution requests on destination chains.
/// @author Wormhole Labs. Copied from
/// https://github.com/wormholelabs-xyz/example-messaging-executor/blob/main/evm/src/interfaces/IExecutor.sol
interface IExecutor {
    struct SignedQuoteHeader {
        bytes4 prefix;
        address quoterAddress;
        bytes32 payeeAddress;
        uint16 srcChain;
        uint16 dstChain;
        uint64 expiryTime;
    }

    /// @notice Emitted when an execution request is made.
    /// @param  quoterAddress     The address of the quoter.
    /// @param  amtPaid           The amount paid for the execution.
    /// @param  dstChain          The destination chain ID.
    /// @param  dstAddr           The address of the contract on the destination chain to execute the message.
    /// @param  refundAddr        The address to refund any excess payment to.
    /// @param  signedQuote       The signed quote for the execution.
    /// @param  requestBytes      The request payload to be executed on the destination chain.
    /// @param  relayInstructions The relay instructions for the execution.
    event RequestForExecution(
        address indexed quoterAddress,
        uint256 amtPaid,
        uint16 dstChain,
        bytes32 dstAddr,
        address refundAddr,
        bytes signedQuote,
        bytes requestBytes,
        bytes relayInstructions
    );

    /// @notice Requests execution of a message on a destination chain.
    /// @param  dstChain          The destination chain ID.
    /// @param  dstAddr           The address of the contract on the destination chain to execute the message.
    /// @param  refundAddr        The address to refund any excess payment to.
    /// @param  signedQuote       The signed quote for the execution.
    /// @param  requestBytes      The request payload to be executed on the destination chain.
    /// @param  relayInstructions The relay instructions for the execution.
    function requestExecution(
        uint16 dstChain,
        bytes32 dstAddr,
        address refundAddr,
        bytes calldata signedQuote,
        bytes calldata requestBytes,
        bytes calldata relayInstructions
    ) external payable;
}
