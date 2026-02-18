// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { MigrateSpokePortalBase } from "./MigrateSpokePortalBase.sol";

contract MigrateOptimismSpokePortal is MigrateSpokePortalBase {
    uint256 internal constant OPTIMISM_SPOKE_PORTAL_DEPLOY_BLOCK = 132_194_411;
    uint256 internal constant OPTIMISM_CHAIN_ID = 10;

    function _portalDeployBlock() internal view override returns (uint256) {
        return OPTIMISM_SPOKE_PORTAL_DEPLOY_BLOCK;
    }

    function run() external {
        assert(block.chainid == OPTIMISM_CHAIN_ID);

        address admin = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(admin);

        _upgradeToStorageCleaner(WORMHOLE_OPTIMISM_CHAIN_ID);
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopBroadcast();
    }
}
