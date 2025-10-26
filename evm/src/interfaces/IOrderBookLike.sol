// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

/// @title  IOrderBookLike interface
/// @author M0 Labs
/// @notice Subset of OrderBook interface required for Portal contracts.
interface IOrderBookLike {
    /// @notice Data reported from a destination chain back to the origin chain about a fill
    /// @dev    This struct is sent by the messenger contract to report fills that occurred
    ///         on the destination chain back to the origin chain for refund processing.
    /// @param orderId The ID of the order being reported
    /// @param amountInToRelease The amount of input token to release to the filler on the origin chain
    /// @param amountOutFilled The amount of output token that was filled on the destination chain
    /// @param originRecipient The address on the origin chain that should receive released funds
    struct FillReport {
        bytes32 orderId;
        uint128 amountInToRelease;
        uint128 amountOutFilled;
        bytes32 originRecipient;
    }

    /// @notice Report a fill that was made on another chain back to this chain as the origin chain
    /// @dev    Must be called by the messenger contract
    /// @param report Fill data sent from the destination chain
    function reportFill(FillReport calldata report) external;
}