// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

/// @title  LayerZeroBridgeAdapterSetupTest
/// @notice Tests that the test base contract sets up correctly.
contract LayerZeroBridgeAdapterSetupTest is LayerZeroBridgeAdapterUnitTestBase {
    function test_setUp_deploysContracts() external view {
        assertNotEq(address(adapter), address(0), "Adapter should be deployed");
        assertNotEq(address(lzEndpoint), address(0), "Endpoint should be deployed");
        assertNotEq(address(portal), address(0), "Portal should be deployed");
    }

    function test_setUp_configuresEndpoint() external view {
        assertEq(adapter.endpoint(), address(lzEndpoint), "Endpoint should be configured correctly");
    }

    function test_setUp_configuresPortal() external view {
        assertEq(adapter.portal(), address(portal), "Portal should be configured correctly");
    }

    function test_setUp_configuresPeer() external view {
        assertEq(adapter.getPeer(SPOKE_CHAIN_ID), peerAdapterAddress, "Peer should be configured for spoke chain");
    }

    function test_setUp_configuresBridgeChainId() external view {
        assertEq(adapter.getBridgeChainId(SPOKE_CHAIN_ID), SPOKE_LZ_EID, "Bridge chain ID should map to LZ EID");
    }

    function test_setUp_fundsAccounts() external view {
        assertEq(admin.balance, 1 ether, "Admin should have 1 ether");
        assertEq(operator.balance, 1 ether, "Operator should have 1 ether");
        assertEq(user.balance, 1 ether, "User should have 1 ether");
        assertEq(address(portal).balance, 1 ether, "Portal should have 1 ether");
        assertEq(address(lzEndpoint).balance, 1 ether, "Endpoint should have 1 ether");
    }

    function test_setUp_grantsRoles() external view {
        assertTrue(adapter.hasRole(adapter.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE");
        assertTrue(adapter.hasRole(adapter.OPERATOR_ROLE(), operator), "Operator should have OPERATOR_ROLE");
    }
}
