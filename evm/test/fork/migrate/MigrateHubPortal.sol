// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";
import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { HubPortal } from "../../../src/HubPortal.sol";

import { NttManagerPeer, Mode } from "../../../script/migrate/portalV1/IPortalV1.sol";
import { IHubPortalV1 } from "../../../script/migrate/portalV1/IHubPortalV1.sol";
import { BridgingPath } from "../../../script/migrate/PortalV1StorageCleaner.sol";
import { HubPortalV1StorageCleaner } from "../../../script/migrate/HubPortalV1StorageCleaner.sol";

contract MigrateHubPortal is Test {
    using TypeConverter for *;

    address constant HUB_PORTAL = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
    address constant OWNER = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;
    address constant PAUSER = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    address constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address constant REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address constant SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;
    // Dummy address as ORDER_BOOK isn't deployed yet
    address ORDER_BOOK = makeAddr("ORDER_BOOK");
    address constant WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    // HubPortalV2 initialization
    address constant ADMIN = OWNER;
    address constant OPERATOR = 0xb7A9B5f301eF3bAD36C2b4964E82931Dd7fb989C;

    uint256 constant ETHEREUM_FORK_BLOCK = 23_978_958;

    uint16 constant WORMHOLE_ETHEREUM_CHAIN_ID = 2;
    uint16 constant WORMHOLE_ARBITRUM_CHAIN_ID = 23;
    uint16 constant WORMHOLE_OPTIMISM_CHAIN_ID = 24;
    uint16 constant WORMHOLE_BASE_CHAIN_ID = 30;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: ETHEREUM_FORK_BLOCK });

        vm.deal(OWNER, 1 ether);
        vm.deal(PAUSER, 1 ether);

        vm.prank(PAUSER);
        IHubPortalV1(HUB_PORTAL).pause();
    }

    function test_initialState() external {
        IHubPortalV1 hubPortal = IHubPortalV1(HUB_PORTAL);

        // HubPortal state
        assertTrue(hubPortal.merkleTreeBuilder() != address(0));
        assertTrue(hubPortal.wasEarningEnabled());

        // Ownable state
        assertEq(hubPortal.owner(), OWNER);

        // Pausable state
        assertTrue(hubPortal.isPaused());
        assertEq(hubPortal.pauser(), PAUSER);

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
        vm.prank(OWNER);
        IHubPortalV1(HUB_PORTAL).upgrade(newImplementation);

        vm.prank(OWNER);
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
        // First upgrade to storage cleaner to clear storage
        address emptyImplementation = address(new HubPortalV1StorageCleaner(M_TOKEN, Mode.LOCKING, WORMHOLE_ETHEREUM_CHAIN_ID));
        vm.prank(OWNER);
        IHubPortalV1(HUB_PORTAL).upgrade(emptyImplementation);

        // Clear all storage
        vm.prank(OWNER);
        HubPortalV1StorageCleaner(HUB_PORTAL).clearStorage(_getBridgingPaths(), _getMessageDigests());

        // Upgrade to HubPortalV2
        vm.startPrank(OWNER);
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (ADMIN, PAUSER, OPERATOR));
        address hubPortalV2Implementation = address(new HubPortal(M_TOKEN, REGISTRAR, SWAP_FACILITY, ORDER_BOOK));
        UUPSUpgradeable(HUB_PORTAL).upgradeToAndCall(hubPortalV2Implementation, initializeData);

        HubPortal hubPortal = HubPortal(HUB_PORTAL);

        // Check initial state
        assertTrue(hubPortal.hasRole(hubPortal.DEFAULT_ADMIN_ROLE(), ADMIN));
        assertTrue(hubPortal.hasRole(hubPortal.PAUSER_ROLE(), PAUSER));
        assertTrue(hubPortal.hasRole(hubPortal.OPERATOR_ROLE(), OPERATOR));
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

