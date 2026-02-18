// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { UUPSUpgradeable } from "../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { HubPortal } from "../../src/HubPortal.sol";

import { Mode } from "./portalV1/IPortalV1.sol";
import { IHubPortalV1 } from "./portalV1/IHubPortalV1.sol";
import { BridgingPath } from "./storageCleaners/PortalV1StorageCleaner.sol";
import { HubPortalV1StorageCleaner } from "./storageCleaners/HubPortalV1StorageCleaner.sol";

import { MigratePortalBase } from "./MigratePortalBase.sol";

abstract contract MigrateHubPortalBase is MigratePortalBase {
    uint256 internal constant HUB_PORTAL_DEPLOY_BLOCK = 21_881_736;

    /// @dev Returns the block number when HubPortal V1 was deployed. Used for event log queries
    function _portalDeployBlock() internal view override returns (uint256) {
        return HUB_PORTAL_DEPLOY_BLOCK;
    }

    /// @dev Upgrade HubPortal to a temporary Storage Cleaner implementation
    function _upgradeToStorageCleaner() internal virtual {
        address storageCleanerImplementation = address(new HubPortalV1StorageCleaner(M_TOKEN, Mode.LOCKING, WORMHOLE_ETHEREUM_CHAIN_ID));
        IHubPortalV1(PORTAL).upgrade(storageCleanerImplementation);
    }

    /// @dev Clear HubPortal V1 storage
    function _clearStorage() internal virtual {
        HubPortalV1StorageCleaner(PORTAL).clearStorage(_getBridgingPaths(), _getWormholeMessageDigests());
    }

    /// @dev Upgrade HubPortal to Portal V2 implementation AFTER storage has been cleared
    function _upgradeToPortalV2() internal virtual {
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (ADMIN_V2, PAUSER_V2, OPERATOR_V2));
        address hubPortalV2Implementation = address(new HubPortal(M_TOKEN, REGISTRAR, SWAP_FACILITY, ORDER_BOOK, MERKLE_TREE_BUILDER));
        UUPSUpgradeable(PORTAL).upgradeToAndCall(hubPortalV2Implementation, initializeData);
    }
}
