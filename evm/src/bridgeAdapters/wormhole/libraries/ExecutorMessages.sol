// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title  ExecutorMessages
/// @author Wormhole Labs. Modified from
/// https://github.com/wormholelabs-xyz/example-messaging-executor/blob/main/evm/src/libraries/ExecutorMessages.sol
library ExecutorMessages {
    bytes4 private constant REQ_VAA_V1 = "ERV1";

    /// @notice Payload length will not fit in a uint32.
    /// @dev Selector: 492f620d.
    error PayloadTooLarge();

    /// @notice Encodes a version 1 VAA request payload.
    /// @param emitterChain The emitter chain from the VAA.
    /// @param emitterAddress The emitter address from the VAA.
    /// @param sequence The sequence number from the VAA.
    /// @return bytes The encoded request.
    function makeVAAv1Request(uint16 emitterChain, bytes32 emitterAddress, uint64 sequence) internal pure returns (bytes memory) {
        return abi.encodePacked(REQ_VAA_V1, emitterChain, emitterAddress, sequence);
    }
}
