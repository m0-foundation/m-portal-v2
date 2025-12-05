// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

struct GuardianSignature {
    bytes32 r;
    bytes32 s;
    uint8 v;
    uint8 guardianIndex;
}

/// @dev VM = Verified Message - legacy struct of the CoreBridge contains fields that are not relevant to the integrator:
///      - version - always 1 regardless
///      - signatures/guardianSetIndex - only the CoreBridge itself cares (for verification)
///      - hash - NOT the VAA hash, but the hash of the hash! see warning at the top of VaaLib.sol!
///      _finalized_ VAAs should use the unique (emitterChainId, emitterAddress, sequence) triple
///      for cheaper replay protection, see SequenceReplayProtectionLib
struct CoreBridgeVM {
    uint8 version;
    uint32 timestamp;
    uint32 nonce;
    uint16 emitterChainId;
    bytes32 emitterAddress;
    uint64 sequence;
    uint8 consistencyLevel;
    bytes payload;
    uint32 guardianSetIndex;
    GuardianSignature[] signatures;
    bytes32 hash; //see comment above
}

/// @title  ICoreBridge
/// @notice Interface of the Wormhole Core Bridge contract
/// @author Wormhole Labs. Modified from
/// https://github.com/wormhole-foundation/wormhole-solidity-sdk/blob/main/src/interfaces/ICoreBridge.sol
interface ICoreBridge {
    /// @notice Returns the fee required to publish a message
    function messageFee() external view returns (uint256);

    /// @notice Publishes a message to Wormhole Core Bridge
    function publishMessage(uint32 nonce, bytes memory payload, uint8 consistencyLevel) external payable returns (uint64 sequence);

    /// @notice Parses and verifies a Wormhole VAA.
    /// @dev Consider using `VaaLib` and `CoreBridgeLib` instead to save on gas (though at the expense of some code size)
    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (CoreBridgeVM memory vm, bool valid, string memory reason);
}
