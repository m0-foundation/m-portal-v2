// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";

import { SpokePortal } from "../../../src/SpokePortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MigrateSpokePortalBase } from "../../../script/migrate/MigrateSpokePortalBase.sol";
import { ISpokePortalV1 } from "../../../script/migrate/portalV1/ISpokePortalV1.sol";
import { BridgingPath } from "../../../script/migrate//storageCleaners/PortalV1StorageCleaner.sol";

contract MigrateSpokePortalTest is MigrateSpokePortalBase, Test {
    using TypeConverter for *;

    uint256 constant ARBITRUM_FORK_BLOCK = 412_451_880;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: ARBITRUM_FORK_BLOCK });

        vm.deal(OWNER_V1, 1 ether);
        vm.deal(PAUSER_V1, 1 ether);

        vm.prank(PAUSER_V1);
        ISpokePortalV1(PORTAL).pause();
    }

    function test_initialState() external {
        ISpokePortalV1 spokePortal = ISpokePortalV1(PORTAL);

        // Ownable state
        assertEq(spokePortal.owner(), OWNER_V1);

        // Pausable state
        assertTrue(spokePortal.isPaused());
        assertEq(spokePortal.pauser(), PAUSER_V1);

        // TransceiverRegistry state
        assertEq(spokePortal.getTransceivers().length, 1);

        // Supported bridging paths
        BridgingPath[] memory bridgingPaths = _getBridgingPaths();
        for (uint256 i = 0; i < bridgingPaths.length; i++) {
            BridgingPath memory path = bridgingPaths[i];
            assertTrue(spokePortal.supportedBridgingPath(path.sourceToken, path.destinationChainId, path.destinationToken));
        }

        // Message attestations
        bytes32[] memory digests = _getWormholeMessageDigests();
        for (uint256 i = 0; i < digests.length; i++) {
            assertTrue(spokePortal.isMessageExecuted(digests[i]));
        }
    }

    function test_upgradeToStorageCleanerImplementation() external {
        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner(WORMHOLE_ARBITRUM_CHAIN_ID);
        _clearStorage();

        vm.stopPrank();

        // Check the storage after clearing
        ISpokePortalV1 spokePortal = ISpokePortalV1(PORTAL);

        // Ownable state
        assertEq(spokePortal.owner(), address(0));

        // Pausable state
        assertFalse(spokePortal.isPaused());
        assertEq(spokePortal.pauser(), address(0));

        // TransceiverRegistry state
        assertEq(spokePortal.getTransceivers().length, 0);

        // All supported bridging paths are cleared
        BridgingPath[] memory bridgingPaths = _getBridgingPaths();
        for (uint256 i = 0; i < bridgingPaths.length; i++) {
            BridgingPath memory path = bridgingPaths[i];
            assertFalse(spokePortal.supportedBridgingPath(path.sourceToken, path.destinationChainId, path.destinationToken));
        }

        // All Wormhole message attestations are cleared
        bytes32[] memory digests = _getWormholeMessageDigests();
        for (uint256 i = 0; i < digests.length; i++) {
            assertFalse(spokePortal.isMessageExecuted(digests[i]));
        }
    }

    function test_upgradeToSpokePortalV2() external {
        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner(WORMHOLE_ARBITRUM_CHAIN_ID);
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopPrank();

        SpokePortal spokePortal = SpokePortal(PORTAL);

        // Check initial state
        assertTrue(spokePortal.hasRole(spokePortal.DEFAULT_ADMIN_ROLE(), ADMIN_V2));
        assertTrue(spokePortal.hasRole(spokePortal.PAUSER_ROLE(), PAUSER_V2));
        assertTrue(spokePortal.hasRole(spokePortal.OPERATOR_ROLE(), OPERATOR_V2));
    }

    /// @dev Hard-coded to reduce the number of RPC calls in tests.
    ///      Should be obtained from the events when running scripts in production.
    function _getBridgingPaths() internal override returns (BridgingPath[] memory bridgingPaths) {
        bridgingPaths = new BridgingPath[](12);

        bridgingPaths[0] = BridgingPath(M_TOKEN, WORMHOLE_ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[1] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[2] = BridgingPath(M_TOKEN, WORMHOLE_ETHEREUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[3] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_ETHEREUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[4] = BridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[5] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[6] = BridgingPath(M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[7] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_OPTIMISM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[8] = BridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[9] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, M_TOKEN.toBytes32());
        bridgingPaths[10] = BridgingPath(M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
        bridgingPaths[11] = BridgingPath(WRAPPED_M_TOKEN, WORMHOLE_BASE_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32());
    }

    /// @dev Hard-coded to reduce the number of RPC calls in tests.
    ///      Should be obtained from the events when running scripts in production.
    function _getWormholeMessageDigests() internal override returns (bytes32[] memory digests) {
        digests = new bytes32[](10);
        digests[0] = 0xb0ee889f86624985c9cf009b1a96db67af4826768d83728c7e7c5692d1338e2c;
        digests[1] = 0x93c285090c547e982c3faaff1cd35d53a6f5aa768cf5ed5263f4276baa4b45f8;
        digests[2] = 0x95f5f75f9aa40be7ec67e5d33024fbffbf887c594acb323b014fc62efe7a904c;
        digests[3] = 0x96be46be4ab899ffde9fb5ad3ed0e383c6c413dc79fa30482f7c8d4e6e956630;
        digests[4] = 0x77c173dbd64d4a59d9ebc1c5947d61c8aaeb561ab65524001b665cf0dcc51800;
        digests[5] = 0x5973174341c59df59154df8894c993175b33b85d6f991b3c246e58409a5bae16;
        digests[6] = 0xea024a126c981f945c54a497b80330c603d48e1972292adcde54b55527f32583;
        digests[7] = 0x1c01e6f7f14057bc308164011f34063cd0d5103795dcddd6829b863ff9f0d060;
        digests[8] = 0x948b1449fb032cd48c529c40df8301c42bbff7cf45feea20bc44b601f2b0cd20;
        digests[9] = 0x354953bf11f8d446143433a1f10e0fa0e98f6f5b6acfd5a4f3117ae457697b2a;
    }
}
