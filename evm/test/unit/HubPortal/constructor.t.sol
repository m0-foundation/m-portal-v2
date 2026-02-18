// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract ConstructorUnitTest is HubPortalUnitTestBase {
    function test_constructor_initialState() external {
        assertEq(address(hubPortal.mToken()), address(mToken));
        assertEq(address(hubPortal.registrar()), address(registrar));
        assertEq(address(hubPortal.swapFacility()), address(swapFacility));
        assertEq(address(hubPortal.orderBook()), address(mockOrderBook));
        assertEq(address(hubPortal.merkleTreeBuilder()), address(merkleTreeBuilder));
    }

    function test_constructor_zeroMToken() external {
        vm.expectRevert(IPortal.ZeroMToken.selector);
        new HubPortal(address(0), address(registrar), address(swapFacility), address(mockOrderBook), address(merkleTreeBuilder));
    }

    function test_constructor_zeroRegistrar() external {
        vm.expectRevert(IPortal.ZeroRegistrar.selector);
        new HubPortal(address(mToken), address(0), address(swapFacility), address(mockOrderBook), address(merkleTreeBuilder));
    }

    function test_constructor_zeroSwapFacility() external {
        vm.expectRevert(IPortal.ZeroSwapFacility.selector);
        new HubPortal(address(mToken), address(registrar), address(0), address(mockOrderBook), address(merkleTreeBuilder));
    }

    function test_constructor_zeroOrderBook() external {
        vm.expectRevert(IPortal.ZeroOrderBook.selector);
        new HubPortal(address(mToken), address(registrar), address(swapFacility), address(0), address(merkleTreeBuilder));
    }

    function test_constructor_zeroMerkleTreeBuilder() external {
        vm.expectRevert(IHubPortal.ZeroMerkleTreeBuilder.selector);
        new HubPortal(address(mToken), address(registrar), address(swapFacility), address(mockOrderBook), address(0));
    }
}
