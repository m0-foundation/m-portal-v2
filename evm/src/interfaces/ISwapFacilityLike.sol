// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

/// @title  ISwapFacilityLike interface.
/// @author M0 Labs
/// @notice Subset of SwapFacility interface required for Portal contracts.
interface ISwapFacilityLike {
    /// @notice Swaps $M token to $M Extension.
    /// @param  extensionOut The address of the M Extension to swap to.
    /// @param  amount       The amount of $M token to swap.
    /// @param  recipient    The address to receive the swapped $M Extension tokens.
    function swapInM(address extensionOut, uint256 amount, address recipient) external;

    /// @notice Swaps $M Extension to $M token.
    /// @param  extensionIn The address of the $M Extension to swap from.
    /// @param  amount      The amount of $M Extension tokens to swap.
    /// @param  recipient   The address to receive $M tokens.
    function swapOutM(address extensionIn, uint256 amount, address recipient) external;

    /// @notice Checks if the extension is permissioned.
    /// @param  extension The extension address to check.
    function isPermissionedExtension(address extension) external view returns (bool);
}
