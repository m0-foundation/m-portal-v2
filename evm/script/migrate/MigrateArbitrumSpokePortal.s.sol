// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { MigrateSpokePortalBase } from "./MigrateSpokePortalBase.sol";

contract MigrateArbitrumSpokePortal is MigrateSpokePortalBase {
    uint256 internal constant ARBITRUM_SPOKE_PORTAL_DEPLOY_BLOCK = 307_758_512;
    uint256 internal constant ARBITRUM_CHAIN_ID = 42_161;

    function _portalDeployBlock() internal view override returns (uint256) {
        return ARBITRUM_SPOKE_PORTAL_DEPLOY_BLOCK;
    }

    function run() external {
        assert(block.chainid == ARBITRUM_CHAIN_ID);

        address admin = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(admin);

        _upgradeToStorageCleaner(WORMHOLE_ARBITRUM_CHAIN_ID);
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopBroadcast();
    }
}
