// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract ConstructorUnitTest is HubPortalUnitTestBase {
    function test_constructor_initialState() external {
        assertEq(address(hubPortal.mToken()), address(mToken));
        assertEq(address(hubPortal.registrar()), address(registrar));
        assertEq(address(hubPortal.swapFacility()), address(swapFacility));
        assertEq(address(hubPortal.orderBook()), address(mockOrderBook));
    }

    function test_constructor_zeroMToken() external {
        vm.expectRevert(IPortal.ZeroMToken.selector);
        new HubPortal(address(0), address(registrar), address(swapFacility), address(mockOrderBook));
    }

    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(IPortal.ZeroRegistrar.selector);
        new HubPortal(address(mToken), address(0), address(swapFacility), address(mockOrderBook));
    }

    function test_constructor_zeroSwapFacility() external {
        vm.expectRevert(IPortal.ZeroSwapFacility.selector);
        new HubPortal(address(mToken), address(registrar), address(0), address(mockOrderBook));
    }

    function test_constructor_zeroOrderBook() external {
        vm.expectRevert(IPortal.ZeroOrderBook.selector);
        new HubPortal(address(mToken), address(registrar), address(swapFacility), address(0));
    }
}