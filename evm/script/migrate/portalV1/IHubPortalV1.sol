// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IPortalV1 } from "./IPortalV1.sol";

interface IHubPortalV1 is IPortalV1 {
    function merkleTreeBuilder() external view returns (address);
    function wasEarningEnabled() external view returns (bool);
    function disableEarningIndex() external view returns (uint128);
}
