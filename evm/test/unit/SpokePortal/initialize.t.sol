// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ERC1967Proxy
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { SpokePortal } from "../../../src/SpokePortal.sol";

import { SpokePortalUnitTestBase } from "./SpokePortalUnitTestBase.sol";

contract InitializeUnitTest is SpokePortalUnitTestBase {
    function test_initialize_initialState() external {
        assertTrue(spokePortal.hasRole(spokePortal.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(spokePortal.hasRole(spokePortal.PAUSER_ROLE(), pauser));
        assertTrue(spokePortal.hasRole(spokePortal.OPERATOR_ROLE(), operator));
    }

    function test_initialize_cannotReinitialize() external {
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (admin, pauser, operator, false));

        (bool success,) = address(spokePortal).call(initializeData);
        assertFalse(success);
    }

    function test_initialize_zeroAdmin() external {
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (address(0), pauser, operator, false));

        vm.expectRevert(IPortal.ZeroAdmin.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }

    function test_initialize_zeroPauser() external {
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (admin, address(0), operator, false));

        vm.expectRevert(IPortal.ZeroPauser.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }

    function test_initialize_zeroOperator() external {
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (admin, pauser, address(0), false));

        vm.expectRevert(IPortal.ZeroOperator.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }
}
