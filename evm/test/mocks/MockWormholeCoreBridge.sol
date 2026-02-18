// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.33;

import { CoreBridgeVM } from "../../src/bridgeAdapters/wormhole/interfaces/ICoreBridge.sol";

contract MockWormholeCoreBridge {
    receive() external payable { }

    /// @notice Returns the fee required to publish a message
    function messageFee() external pure returns (uint256) {
        return 0;
    }

    /// @notice Publishes a message to Wormhole Core Bridge
    function publishMessage(uint32, bytes memory, uint8) external payable returns (uint64) {
        return 0;
    }

    /// @notice Parses and verifies a Wormhole VAA
    function parseAndVerifyVM(bytes calldata) external pure returns (CoreBridgeVM memory vm, bool valid, string memory reason) {
        return (vm, false, "");
    }

    /// @notice Returns the Wormhole chain ID of the current chain
    function chainId() external pure returns (uint16) {
        return 0;
    }
}
