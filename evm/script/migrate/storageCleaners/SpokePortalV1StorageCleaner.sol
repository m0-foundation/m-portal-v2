// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { BridgingPath, PortalV1StorageCleaner } from "./PortalV1StorageCleaner.sol";

import { Mode } from "../portalV1/IPortalV1.sol";

/// @dev A temporary implementation used to clear ALL storage across the entire inheritance chain during an upgrade.
///      After calling clearAllStorage(), the contract should be upgraded to the new implementation.
contract SpokePortalV1StorageCleaner is PortalV1StorageCleaner {
    constructor(address token_, Mode mode_, uint16 chainId_) PortalV1StorageCleaner(token_, mode_, chainId_) { }
}
