// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";
import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { NttManagerPeer, Mode } from "../../../script/migrate/portalV1/IPortalV1.sol";
import { ISpokePortalV1 } from "../../../script/migrate/portalV1/ISpokePortalV1.sol";
import { BridgingPath } from "../../../script/migrate//storageCleaners/PortalV1StorageCleaner.sol";
import { SpokePortalV1StorageCleaner } from "../../../script/migrate/storageCleaners/SpokePortalV1StorageCleaner.sol";

contract MigrateSpokePortalTest is Test {
    using TypeConverter for *;
}