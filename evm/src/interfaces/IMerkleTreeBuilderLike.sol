// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.33;

/// @title  IMerkleTreeBuilderLike interface
/// @author M0 Labs
/// @notice Subset of MerkleTreeBuilder interface required for Portal contracts.
interface IMerkleTreeBuilderLike {
    /// @notice Retrieves the root of the Merkle tree for a list.
    function getRoot(bytes32 list) external view returns (bytes32);
}
