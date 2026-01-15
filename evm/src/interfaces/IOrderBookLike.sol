// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

/// @title  IOrderBookLike interface
/// @author M0 Labs
/// @notice Subset of OrderBook interface required for Portal contracts.
interface IOrderBookLike {
    /// @notice Data reported from a destination chain back to the origin chain about a fill
    /// @dev    This struct is sent by the portal contract to report fills that occurred
    ///         on the destination chain back to the origin chain for refund processing.
    /// @param orderId The ID of the order being reported
    /// @param amountInToRelease The amount of input token to release to the filler on the origin chain
    /// @param amountOutFilled The amount of output token that was filled on the destination chain
    /// @param originRecipient The address on the origin chain that should receive released funds
    /// @param tokenIn The address of the input token on the origin chain
    ///                This is included for non-EVM chains to provide a way to resolve the account
    struct FillReport {
        bytes32 orderId;
        uint128 amountInToRelease;
        uint128 amountOutFilled;
        bytes32 originRecipient;
        bytes32 tokenIn;
    }

    /// @notice Data reported from a destination chain back to the origin chain about a cancelled order
    /// @dev    This struct is sent by the portal contract to report orders that were cancelled
    ///         on the destination chain back to the origin chain for cleanup processing.
    /// @param orderId The ID of the order being reported
    /// @param originSender The address on the origin chain that created the order
    /// @param tokenIn The address of the input token on the origin chain
    /// @param amountInToRefund The amount of input token to refund to the origin sender
    struct CancelReport {
        bytes32 orderId;
        bytes32 originSender;
        bytes32 tokenIn;
        uint128 amountInToRefund;
    }

    /**
     * @notice Report a fill that was made on another chain back to this chain as the origin chain
     * @dev    Must be called by the portal contract
     * @param sourceChainId The chain ID that the fill report was sent from
     * @param report Fill data sent from the destination chain
     */
    function reportFill(uint32 sourceChainId, FillReport calldata report) external;

    /**
     * @notice Report a cross-chain cancellation of an order.
     * @dev    Must be called by the portal contract
     * @param sourceChainId The chain ID that the cancel report was sent from
     * @param report Cancel data sent from the destination chain
     */
    function reportCancel(uint32 sourceChainId, CancelReport calldata report) external;
}
