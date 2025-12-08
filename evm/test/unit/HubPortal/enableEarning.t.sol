// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IMTokenLike } from "../../../src/interfaces/IMTokenLike.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract EnableEarningUnitTest is HubPortalUnitTestBase {
    function test_enableEarning() external {
        uint128 currentMIndex = 1_100_000_068_703;

        mToken.setCurrentIndex(currentMIndex);
        registrar.set(EARNERS_LIST_IGNORED, bytes32("1"));

        vm.expectEmit();
        emit IHubPortal.EarningEnabled(currentMIndex);

        vm.expectCall(address(mToken), abi.encodeCall(IMTokenLike.startEarning, ()));
        hubPortal.enableEarning();
    }

    function test_enableEarning_revertsIfEarningIsEnabled() external {
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        vm.expectRevert(IHubPortal.EarningIsEnabled.selector);
        hubPortal.enableEarning();
    }

    function test_enableEarning_revertsWhenReenablingEarning() external {
        mToken.setCurrentIndex(1_100_000_068_703);

        // enable
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        // disable
        registrar.setListContains(EARNERS_LIST, address(hubPortal), false);
        hubPortal.disableEarning();

        // fail to re-enable
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        vm.expectRevert(IHubPortal.EarningCannotBeReenabled.selector);
        hubPortal.enableEarning();
    }
}
