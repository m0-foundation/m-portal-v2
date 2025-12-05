// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";
import { ERC1967Proxy } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract InitializeUnitTest is HubPortalUnitTestBase {
    function test_initialize_initialState() external {
        assertTrue(hubPortal.hasRole(hubPortal.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(hubPortal.hasRole(hubPortal.PAUSER_ROLE(), pauser));
        assertTrue(hubPortal.hasRole(hubPortal.OPERATOR_ROLE(), operator));
        assertEq(hubPortal.disableEarningIndex(), IndexingMath.EXP_SCALED_ONE);
        assertFalse(hubPortal.wasEarningEnabled());
    }

    function test_initialize_cannotReinitialize() external {
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (admin, pauser, operator));

        (bool success, ) = address(hubPortal).call(initializeData);
        assertFalse(success);
    }

    function test_initialize_zeroAdmin() external {
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (address(0), pauser, operator));

        vm.expectRevert(IPortal.ZeroAdmin.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }

    function test_initialize_zeroPauser() external {
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (admin, address(0), operator));

        vm.expectRevert(IPortal.ZeroPauser.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }

    function test_initialize_zeroOperator() external {
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (admin, pauser, address(0)));

        vm.expectRevert(IPortal.ZeroOperator.selector);
        new ERC1967Proxy(address(implementation), initializeData);
    }
}
