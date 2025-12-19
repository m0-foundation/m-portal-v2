// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";
import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { MigratePortalBase } from "../../../script/migrate/MigratePortalBase.sol";

import { NttManagerPeer, Mode } from "../../../script/migrate/portalV1/IPortalV1.sol";
import { IHubPortalV1 } from "../../../script/migrate/portalV1/IHubPortalV1.sol";
import { BridgingPath } from "../../../script/migrate/storageCleaners/PortalV1StorageCleaner.sol";
import { HubPortalV1StorageCleaner } from "../../../script/migrate/storageCleaners/HubPortalV1StorageCleaner.sol";

contract MigrateHubPortalTest is MigratePortalBase, Test {
    using TypeConverter for *;

    uint256 constant ETHEREUM_FORK_BLOCK = 23_978_958;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: ETHEREUM_FORK_BLOCK });

        vm.deal(OWNER_V1, 1 ether);
        vm.deal(PAUSER_V1, 1 ether);

        vm.prank(PAUSER_V1);
        IHubPortalV1(HUB_PORTAL).pause();
    }

    function test_initialState() external {
        IHubPortalV1 hubPortal = IHubPortalV1(HUB_PORTAL);

        // HubPortal state
        assertTrue(hubPortal.merkleTreeBuilder() != address(0));
        assertTrue(hubPortal.wasEarningEnabled());

        // Ownable state
        assertEq(hubPortal.owner(), OWNER_V1);

        // Pausable state
        assertTrue(hubPortal.isPaused());
        assertEq(hubPortal.pauser(), PAUSER_V1);

        // Supported bridging paths
        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));

        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));

        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertTrue(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
    }

    function test_upgradeToStorageCleanerImplementation() external {
        address newImplementation = address(new HubPortalV1StorageCleaner(M_TOKEN, Mode.LOCKING, WORMHOLE_ETHEREUM_CHAIN_ID));
        vm.prank(OWNER_V1);
        IHubPortalV1(HUB_PORTAL).upgrade(newImplementation);

        vm.prank(OWNER_V1);
        HubPortalV1StorageCleaner(HUB_PORTAL).clearStorage(_getBridgingPaths(), _getMessageDigests());

        IHubPortalV1 hubPortal = IHubPortalV1(HUB_PORTAL);

        // HubPortal state
        assertEq(hubPortal.merkleTreeBuilder(), address(0));
        assertFalse(hubPortal.wasEarningEnabled());

        // Ownable state
        assertEq(hubPortal.owner(), address(0));

        // Pausable state
        assertFalse(hubPortal.isPaused());
        assertEq(hubPortal.pauser(), address(0));

        // All supported bridging paths are cleared
        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));

        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));

        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
        assertFalse(hubPortal.supportedBridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32()));
    }

    function test_upgradeToHubPortalV2() external {
        vm.startPrank(OWNER_V1);
        // First upgrade to storage cleaner to clear storage
        address emptyImplementation = address(new HubPortalV1StorageCleaner(M_TOKEN, Mode.LOCKING, WORMHOLE_ETHEREUM_CHAIN_ID));
        IHubPortalV1(HUB_PORTAL).upgrade(emptyImplementation);

        // Clear all storage
        HubPortalV1StorageCleaner(HUB_PORTAL).clearStorage(_getBridgingPaths(), _getMessageDigests());

        // Upgrade to HubPortalV2
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (ADMIN_V2, PAUSER_V2, OPERATOR_V2));
        address hubPortalV2Implementation = address(new HubPortal(M_TOKEN, REGISTRAR, SWAP_FACILITY, ORDER_BOOK, MERKLE_TREE_BUILDER));
        UUPSUpgradeable(HUB_PORTAL).upgradeToAndCall(hubPortalV2Implementation, initializeData);

        HubPortal hubPortal = HubPortal(HUB_PORTAL);

        // Check initial state
        assertTrue(hubPortal.hasRole(hubPortal.DEFAULT_ADMIN_ROLE(), ADMIN_V2));
        assertTrue(hubPortal.hasRole(hubPortal.PAUSER_ROLE(), PAUSER_V2));
        assertTrue(hubPortal.hasRole(hubPortal.OPERATOR_ROLE(), OPERATOR_V2));
        assertEq(hubPortal.disableEarningIndex(), IndexingMath.EXP_SCALED_ONE);
        assertFalse(hubPortal.wasEarningEnabled());

        // Enable earning after initialization
        hubPortal.enableEarning();
        assertTrue(hubPortal.wasEarningEnabled());
    }

    /// @dev Should be obtain from the events or configured
    function _getBridgingPaths() internal pure returns (BridgingPath[] memory bridgingPaths) {
        bridgingPaths = new BridgingPath[](12);

        bridgingPaths[0] = BridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[1] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[2] = BridgingPath(M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[3] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ARBITRUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[4] = BridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[5] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[6] = BridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[7] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[8] = BridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[9] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[10] = BridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[11] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
    }

    /// @dev Should be obtain from the events
    function _getMessageDigests() internal pure returns (bytes32[] memory digests) {
        digests = new bytes32[](0);
    }
}

