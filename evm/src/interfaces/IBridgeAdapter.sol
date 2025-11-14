// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

struct AdapterConfig {
    /// @notice The provider-specific ID of the remote chain.
    uint256 bridgeChainId;
    /// @notice The address of the Bridge Adapter contract on the remote chain.
    bytes32 peer;
}

/// @title  IBridgeAdapter interface
/// @author M0 Labs
/// @notice Interface defining a bridge adapter for cross-chain messaging functionality.
interface IBridgeAdapter {
    ///////////////////////////////////////////////////////////////////////////
    //                                 EVENTS                                //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when the address of bridge adapter on the remote chain is set.
    /// @param  chainId The ID of the remote chain.
    /// @param  peer    The address of the bridge contract on the remote chain.
    event PeerSet(uint32 chainId, bytes32 peer);

    /// @notice Emitted when the provider-specific chain ID is set.
    /// @param  chainId       The ID of the chain.
    /// @param  bridgeChainId The provider-specific chain ID.
    event BridgeChainIdSet(uint32 chainId, uint256 bridgeChainId);

    ///////////////////////////////////////////////////////////////////////////
    //                             CUSTOM ERRORS                             //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when `sendMessage` function caller is not the portal.
    error NotPortal();

    /// @notice Thrown when the portal address is 0x0.
    error ZeroPortal();

    /// @notice Thrown when the admin address is 0x0.
    error ZeroAdmin();

    /// @notice Thrown when the operator address is 0x0.
    error ZeroOperator();

    /// @notice Thrown when the chain ID is 0.
    error ZeroChain();

    /// @notice Thrown when the provider-specific chain ID is 0.
    error ZeroBridgeChain();

    /// @notice Thrown when the remote bridge is 0x0.
    error ZeroPeer();

    /// @notice Thrown when the destination chain isn't supported.
    error UnsupportedChain(uint32 chainId);

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Returns the address of the portal.
    function portal() external view returns (address);

    /// @notice Returns the fee for sending a message to the remote chain
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  gasLimit           The gas limit to execute the message on the destination chain.
    /// @param  payload            The message payload to send.
    /// @return fee                The fee for sending a message.
    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256 fee);

    /// @notice Returns the address of Bridge Adapter contract on the remote chain.
    /// @param  chainId The ID of the remote chain.
    function getPeer(uint32 chainId) external view returns (bytes32);

    /// @notice Returns the provider-specific chain ID.
    /// @param  chainId The ID of the chain.
    function getBridgeChainId(uint32 chainId) external view returns (uint256);

    ///////////////////////////////////////////////////////////////////////////
    //                         INTERACTIVE FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Sends a message to the remote chain.
    /// @param  destinationChainId The chain Id of the destination chain.
    /// @param  gasLimit           The gas limit to execute the message on the destination chain.
    /// @param  refundAddress      The address to refund the fee to.
    /// @param  payload            The message payload to send.
    function sendMessage(uint32 destinationChainId, uint256 gasLimit, bytes32 refundAddress, bytes memory payload) external payable;

    /// @notice Sets an address of Bridge Adapter contract on the remote chain.
    /// @param  destinationChainId The ID of the destination chain.
    /// @param  destinationPeer    The address of of the Bridge Adapter contract on the destination chain.
    function setPeer(uint32 destinationChainId, bytes32 destinationPeer) external;

    /// @notice Sets the provider-specific chain ID.
    /// @param  chainId       The ID of the chain.
    /// @param  bridgeChainId The provider-specific chain ID.
    function setBridgeChainId(uint32 chainId, uint256 bridgeChainId) external;

    /// @notice Sets both the provider-specific chain ID and the remote Bridge Adapter address.
    /// @param  chainId       The ID of the chain.
    /// @param  bridgeChainId The provider-specific chain ID.
    /// @param  peer          The address of of the Bridge Adapter contract on the destination chain.
    function setConfig(uint32 chainId, uint256 bridgeChainId, bytes32 peer) external;
}
