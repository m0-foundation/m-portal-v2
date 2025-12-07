// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract CurrentIndexUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    function test_currentIndex_whenEarningEnabled() external {
        uint128 expectedIndex = 1_100000068703;
        mToken.setCurrentIndex(expectedIndex);

        // Enable earning so the portal returns mToken's index
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        uint128 index = hubPortal.currentIndex();

        assertEq(index, expectedIndex);
    }

    function test_currentIndex_whenEarningDisabled() external {
        // When earning is disabled, it returns disableEarningIndex (which is EXP_SCALED_ONE by default)
        uint128 index = hubPortal.currentIndex();

        // Default disableEarningIndex is 1e12 (EXP_SCALED_ONE)
        assertEq(index, 1_000000000000);
    }
}
