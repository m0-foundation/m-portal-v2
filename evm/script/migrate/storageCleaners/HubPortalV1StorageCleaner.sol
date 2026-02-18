// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

import { BridgingPath, PortalV1StorageCleaner } from "./PortalV1StorageCleaner.sol";

import { Mode } from "../portalV1/IPortalV1.sol";

/// @dev A temporary implementation used to clear ALL storage across the entire inheritance chain during an upgrade.
///      After calling clearAllStorage(), the contract should be upgraded to the new implementation.
contract HubPortalV1StorageCleaner is PortalV1StorageCleaner {
    bool public wasEarningEnabled;
    uint128 public disableEarningIndex;
    address public merkleTreeBuilder;

    constructor(address token_, Mode mode_, uint16 chainId_) PortalV1StorageCleaner(token_, mode_, chainId_) { }

    function _clearStorage(BridgingPath[] memory bridgingPaths, bytes32[] memory digests) internal virtual override {
        super._clearStorage(bridgingPaths, digests);

        // Clear HubPortalV1 specific storage
        delete wasEarningEnabled;
        delete disableEarningIndex;
        delete merkleTreeBuilder;
    }
}
