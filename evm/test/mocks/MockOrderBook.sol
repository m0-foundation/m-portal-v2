// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { IOrderBookLike } from "../../src/interfaces/IOrderBookLike.sol";

contract MockOrderBook is IOrderBookLike {
    FillReport public lastReport;

    function reportFill(FillReport calldata report) external {
        lastReport = report;
    }
}
