// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";
import { IERC20 } from "../../../lib/common/src/interfaces/IERC20.sol";

import { HubPortal } from "../../../src/HubPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MigrateHubPortalBase } from "../../../script/migrate/MigrateHubPortalBase.sol";
import { IHubPortalV1 } from "../../../script/migrate/portalV1/IHubPortalV1.sol";
import { BridgingPath } from "../../../script/migrate/storageCleaners/PortalV1StorageCleaner.sol";

contract MigrateHubPortalTest is MigrateHubPortalBase, Test {
    using TypeConverter for *;

    uint256 constant ETHEREUM_FORK_BLOCK = 24_050_400;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: ETHEREUM_FORK_BLOCK });

        vm.deal(OWNER_V1, 1 ether);
        vm.deal(PAUSER_V1, 1 ether);

        vm.prank(PAUSER_V1);
        IHubPortalV1(PORTAL).pause();
    }

    function test_initialState() external {
        IHubPortalV1 hubPortal = IHubPortalV1(PORTAL);

        // HubPortal state
        assertTrue(hubPortal.merkleTreeBuilder() != address(0));
        assertTrue(hubPortal.wasEarningEnabled());

        // Ownable state
        assertEq(hubPortal.owner(), OWNER_V1);

        // Pausable state
        assertTrue(hubPortal.isPaused());
        assertEq(hubPortal.pauser(), PAUSER_V1);

        // TransceiverRegistry state
        assertEq(hubPortal.getTransceivers().length, 1);

        // Supported bridging paths
        BridgingPath[] memory bridgingPaths = _getBridgingPaths();
        for (uint256 i = 0; i < bridgingPaths.length; i++) {
            BridgingPath memory path = bridgingPaths[i];
            assertTrue(hubPortal.supportedBridgingPath(path.sourceToken, path.destinationChainId, path.destinationToken));
        }

        // Wormhole message attestations
        bytes32[] memory digests = _getWormholeMessageDigests();
        for (uint256 i = 0; i < digests.length; i++) {
            assertTrue(hubPortal.isMessageExecuted(digests[i]));
        }
    }

    function test_upgradeToStorageCleanerImplementation() external {
        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner();
        _clearStorage();

        vm.stopPrank();

        // Check the storage after clearing
        IHubPortalV1 hubPortal = IHubPortalV1(PORTAL);

        // HubPortal state
        assertEq(hubPortal.merkleTreeBuilder(), address(0));
        assertFalse(hubPortal.wasEarningEnabled());

        // Ownable state
        assertEq(hubPortal.owner(), address(0));

        // Pausable state
        assertFalse(hubPortal.isPaused());
        assertEq(hubPortal.pauser(), address(0));

        // TransceiverRegistry state
        assertEq(hubPortal.getTransceivers().length, 0);

        // All supported bridging paths are cleared
        BridgingPath[] memory bridgingPaths = _getBridgingPaths();
        for (uint256 i = 0; i < bridgingPaths.length; i++) {
            BridgingPath memory path = bridgingPaths[i];
            assertFalse(hubPortal.supportedBridgingPath(path.sourceToken, path.destinationChainId, path.destinationToken));
        }

        // All Wormhole message attestations are cleared
        bytes32[] memory digests = _getWormholeMessageDigests();
        for (uint256 i = 0; i < digests.length; i++) {
            assertFalse(hubPortal.isMessageExecuted(digests[i]));
        }
    }

    function test_upgradeToHubPortalV2() external {
        uint256 balanceBefore = IERC20(M_TOKEN).balanceOf(PORTAL);
        uint128 indexBefore = IHubPortalV1(PORTAL).currentIndex();

        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner();
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopPrank();

        HubPortal hubPortal = HubPortal(PORTAL);

        // Check initial state
        assertTrue(hubPortal.hasRole(hubPortal.DEFAULT_ADMIN_ROLE(), ADMIN_V2));
        assertTrue(hubPortal.hasRole(hubPortal.PAUSER_ROLE(), PAUSER_V2));
        assertTrue(hubPortal.hasRole(hubPortal.OPERATOR_ROLE(), OPERATOR_V2));
        assertEq(hubPortal.disableEarningIndex(), IndexingMath.EXP_SCALED_ONE);
        assertFalse(hubPortal.wasEarningEnabled());

        // Enable earning after initialization
        hubPortal.enableEarning();
        assertTrue(hubPortal.wasEarningEnabled());

        uint256 balanceAfter = IERC20(M_TOKEN).balanceOf(PORTAL);
        uint128 indexAfter = hubPortal.currentIndex();

        // $M token balance and index should remain the same after migration
        assertEq(indexAfter, indexBefore);
        assertEq(balanceAfter, balanceBefore);
    }

    /// @dev Should be obtain from the events or configured
    function _getBridgingPaths() internal override returns (BridgingPath[] memory bridgingPaths) {
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

    /// @dev Hard-coded to reduce the number of RPC calls. Should be obtained from the events in production
    function _getWormholeMessageDigests() internal override returns (bytes32[] memory digests) {
        digests = new bytes32[](10);
        digests[0] = 0x1688ff6261ea539ea83ab3e3f1509b86245dcd1355c8a7ecb8632eda561ac7cb;
        digests[1] = 0xc8287bfd85f6d6566399f54ede0adcc263f8cbff4100d82a8ba8b178dc9653b3;
        digests[2] = 0xb08b8f5658ed9f874f42f5aa6d04c7a81710063a9124e3aa12ec63bac279ae0c;
        digests[3] = 0x60b3dd2a37e77b68c702aa5b88e9e32a99a54e01f12a7dfa39617a8d41bc7d30;
        digests[4] = 0xc864f7db839a5a0509998b2c4560e63406abea695fc19f3d101ee8d875c5b292;
        digests[5] = 0x8b8b4e07ab6338ae5f9bbc77ea965cf261be50a8cf46d9c3d1e4298cd0a43dbf;
        digests[6] = 0x44821bd7695e6dffc408cc2097233b78233c8c3f8468d08cab5aef0f6d5cb478;
        digests[7] = 0xd6c89de13e3285b2b79a96d56d297007cec424f0003de63f1bc69f068a601148;
        digests[8] = 0x073d6ace526b3599d08f1f148b1c42f22d23b6f1715085e7c6caf7cf85e2719b;
        digests[9] = 0x0964c4d46b8a671bcfedbad8c7e6c0bd83ec1314fe5c961429732af4d713b50c;
    }
}

