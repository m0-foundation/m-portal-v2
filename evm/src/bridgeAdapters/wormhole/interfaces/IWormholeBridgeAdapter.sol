// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../interfaces/IBridgeAdapter.sol";
import { IVaaV1Receiver } from "./IVaaV1Receiver.sol";

interface IWormholeBridgeAdapter is IBridgeAdapter, IVaaV1Receiver {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when the address of Wormhole Bridge Adapter on the remote chain is set.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  peer               The address of the Bridge Adapter on the remote chain.
    event PeerSet(uint32 destinationChainId, bytes32 peer);

    /// @notice Emitted when the Wormhole finality is set.
    /// @param  finality The finality value.
    event FinalitySet(uint8 finality);

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the Wormhole Core address is 0x0.
    error ZeroWormholeCore();

    /// @notice Thrown when the Executor address is 0x0.
    error ZeroExecutorCore();

    /// @notice Thrown when the remote chain id is 0.
    error ZeroDestinationChain();

    /// @notice Thrown when the remote Bridge Adapter is 0x0.
    error ZeroPeer();

    /// @notice Thrown when the invalid VAA is received.
    error InvalidVaa(string reason);

    /// @notice Thrown when the destination chain isn't supported.
    error UnsupportedDestinationChain(uint32 destinationChainId);

    /// @notice Thrown when the source chain isn't supported or configured peer doesn't match the sender.
    error UnsupportedSender(bytes32 sender);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of Wormhole Core contract.
    function wormholeCore() external view returns (address);

    /// @notice Returns the address of Executor contract.
    function executor() external view returns (address);

    /// @notice Defines how long the Guardians should wait before signing a VAA.
    /// @dev    See https://wormhole.com/docs/products/reference/consistency-levels/ for more details.
    function finality() external view returns (uint8);

    /// @notice Returns the address of Wormhole Bridge Adapter contract on the remote chain.
    function peer(uint32 destinationChainId) external view returns (bytes32);

    ///////////////////////////////////////////////////////////////////////////
    //                     PRIVILEGED INTERACTIVE FUNCTIONS                  //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sets an address of Wormhole Bridge Adapter contract on the remote chain.
    /// @param  destinationChainId The EVM chain Id of the destination chain.
    /// @param  peer               The address of of the bridge contract on the remote chain.
    function setPeer(uint32 destinationChainId, bytes32 peer) external;

    /// @notice Set the Wormhole finality, which defines how long the Guardians should wait before signing a VAA.
    /// @dev    See https://wormhole.com/docs/products/reference/consistency-levels/ for more details.
    /// @param  finality The finality value.
    function setFinality(uint8 finality) external;
}
