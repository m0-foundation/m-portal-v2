// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { HyperlaneBridge } from "../../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IHyperlaneBridgeAdapter } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IHyperlaneBridgeAdapter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract ConstructorUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    function test_constructor_initialState() external view {
        assertEq(implementation.portal(), address(portal));
        assertEq(implementation.mailbox(), address(mailbox));
    }

    function test_constructor_zeroPortal() external {
        vm.expectRevert(IBridgeAdapter.ZeroPortal.selector);
        new HyperlaneBridge(address(mailbox), address(0));
    }

    function test_constructor_zeroMailbox() external {
        vm.expectRevert(IHyperlaneBridgeAdapter.ZeroMailbox.selector);
        new HyperlaneBridge(address(0), address(portal));
    }
}
