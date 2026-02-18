// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IMTokenLike } from "../../../src/interfaces/IMTokenLike.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract DisableEarningUnitTest is HubPortalUnitTestBase {
    function test_disableEarning() external {
        uint128 currentMIndex_ = 1_100_000_068_703;

        mToken.setCurrentIndex(currentMIndex_);

        // enable
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        // disable
        registrar.setListContains(EARNERS_LIST, address(hubPortal), false);

        vm.expectEmit();
        emit IHubPortal.EarningDisabled(currentMIndex_);

        vm.expectCall(address(mToken), abi.encodeCall(IMTokenLike.stopEarning, (address(hubPortal))));

        hubPortal.disableEarning();
    }

    function test_disableEarning_revertsIfEarningIsDisabled() external {
        vm.expectRevert(IHubPortal.EarningIsDisabled.selector);
        hubPortal.disableEarning();
    }
}
