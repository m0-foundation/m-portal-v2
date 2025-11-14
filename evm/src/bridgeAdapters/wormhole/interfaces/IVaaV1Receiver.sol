// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title  IVaaV1Receiver
/// @notice Any contract that wishes to receive V1 VAAs from the Executor needs to implement `IVaaV1Receiver`.
/// @author Wormhole Labs. Copied from https://github.com/wormholelabs-xyz/example-messaging-executor/blob/main/evm/src/interfaces/IVaaV1Receiver.sol
interface IVaaV1Receiver {
    /// @notice Receive an attested message from the executor relayer.
    /// @param msg The attested message payload.
    function executeVAAv1(bytes memory msg) external payable;
}