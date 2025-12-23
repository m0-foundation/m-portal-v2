// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { IOrderBookLike } from "../../src/interfaces/IOrderBookLike.sol";

contract MockOrderBook is IOrderBookLike {
    FillReport public lastFillReport;
    CancelReport public lastCancelReport;

    function reportFill(FillReport calldata report) external {
        lastFillReport = report;
    }

    function reportCancel(CancelReport calldata report) external {
        lastCancelReport = report;
    }
}
