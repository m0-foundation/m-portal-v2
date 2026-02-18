// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { UUPSUpgradeable } from "../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { SpokePortal } from "../../src/SpokePortal.sol";

import { Mode } from "./portalV1/IPortalV1.sol";
import { ISpokePortalV1 } from "./portalV1/ISpokePortalV1.sol";
import { BridgingPath } from "./storageCleaners/PortalV1StorageCleaner.sol";
import { SpokePortalV1StorageCleaner } from "./storageCleaners/SpokePortalV1StorageCleaner.sol";

import { MigratePortalBase } from "./MigratePortalBase.sol";

abstract contract MigrateSpokePortalBase is MigratePortalBase {
    /// @dev Upgrade SpokePortal to a temporary Storage Cleaner implementation
    function _upgradeToStorageCleaner(uint16 wormholeChainId) internal virtual {
        address storageCleanerImplementation = address(new SpokePortalV1StorageCleaner(M_TOKEN, Mode.BURNING, wormholeChainId));
        ISpokePortalV1(PORTAL).upgrade(storageCleanerImplementation);
    }

    /// @dev Clear SpokePortal V1 storage
    function _clearStorage() internal virtual {
        SpokePortalV1StorageCleaner(PORTAL).clearStorage(_getBridgingPaths(), _getWormholeMessageDigests());
    }

    /// @dev Upgrade SpokePortal to Portal V2 implementation AFTER storage has been cleared
    function _upgradeToPortalV2() internal virtual {
        uint32 HUB_CHAIN_ID = 1; // Ethereum Mainnet
        bool crossSpokeTransferEnabled = false; // default is false
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (ADMIN_V2, PAUSER_V2, OPERATOR_V2, crossSpokeTransferEnabled));
        address spokePortalV2Implementation = address(new SpokePortal(M_TOKEN, REGISTRAR, SWAP_FACILITY, ORDER_BOOK, HUB_CHAIN_ID));
        UUPSUpgradeable(PORTAL).upgradeToAndCall(spokePortalV2Implementation, initializeData);
    }
}
