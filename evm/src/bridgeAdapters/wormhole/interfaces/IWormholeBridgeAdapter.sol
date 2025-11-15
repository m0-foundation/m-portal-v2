// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IVaaV1Receiver } from "./IVaaV1Receiver.sol";

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

    /// @notice Thrown when the source chain isn't supported or configured peer doesn't match the sender.
    error UnsupportedSender(bytes32 sender);

    error InsufficientFee();

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
}
