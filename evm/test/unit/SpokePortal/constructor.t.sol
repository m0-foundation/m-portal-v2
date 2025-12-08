// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { SpokePortal } from "../../../src/SpokePortal.sol";

import { SpokePortalUnitTestBase } from "./SpokePortalUnitTestBase.sol";

contract ConstructorUnitTest is SpokePortalUnitTestBase {
    function test_constructor_initialState() external {
        assertEq(address(spokePortal.mToken()), address(mToken));
        assertEq(address(spokePortal.registrar()), address(registrar));
        assertEq(address(spokePortal.swapFacility()), address(swapFacility));
        assertEq(address(spokePortal.orderBook()), address(mockOrderBook));
    }

    function test_constructor_zeroMToken() external {
        vm.expectRevert(IPortal.ZeroMToken.selector);
        new SpokePortal(address(0), address(registrar), address(swapFacility), address(mockOrderBook));
    }

    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(IPortal.ZeroRegistrar.selector);
        new SpokePortal(address(mToken), address(0), address(swapFacility), address(mockOrderBook));
    }

    function test_constructor_zeroSwapFacility() external {
        vm.expectRevert(IPortal.ZeroSwapFacility.selector);
        new SpokePortal(address(mToken), address(registrar), address(0), address(mockOrderBook));
    }

    function test_constructor_zeroOrderBook() external {
        vm.expectRevert(IPortal.ZeroOrderBook.selector);
        new SpokePortal(address(mToken), address(registrar), address(swapFacility), address(0));
    }
}