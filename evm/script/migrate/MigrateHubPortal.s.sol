// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MigrateHubPortalBase } from "./MigrateHubPortalBase.sol";

contract MigrateHubPortal is MigrateHubPortalBase {
    function run() external {
        address admin = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        vm.startBroadcast(admin);

        _upgradeToStorageCleaner();
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopBroadcast();
    }
}
