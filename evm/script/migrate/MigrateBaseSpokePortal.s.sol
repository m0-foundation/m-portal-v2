// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MigrateSpokePortalBase } from "./MigrateSpokePortalBase.sol";

contract MigrateBaseSpokePortal is MigrateSpokePortalBase {
    uint256 internal constant BASE_SPOKE_PORTAL_DEPLOY_BLOCK = 37_549_707;
    uint256 internal constant BASE_CHAIN_ID = 8453;

    function _portalDeployBlock() internal view override returns (uint256) {
        return BASE_SPOKE_PORTAL_DEPLOY_BLOCK;
    }

    function run() external {
        assert(block.chainid == BASE_CHAIN_ID);

        address admin = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(admin);

        _upgradeToStorageCleaner(WORMHOLE_BASE_CHAIN_ID);
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopBroadcast();
    }
}
