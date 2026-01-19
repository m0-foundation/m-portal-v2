// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for lzReceive (via _lzReceive)
 *
 * Branch coverage TODOs:
 * - [x] when caller is not endpoint
 *     - [x] reverts (enforced by OAppReceiver base)
 * - [x] when source EID is not configured
 *     - [x] reverts with UnsupportedBridgeChain
 * - [x] when sender does not match peer for source chain
 *     - [x] reverts with InvalidPeer
 * - [x] when sender matches configured peer
 *     - [x] succeeds
 *     - [x] calls portal.receiveMessage with correct source chain ID
 *     - [x] calls portal.receiveMessage with correct payload
 */

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol";
import { OAppReceiver } from "../../../../src/bridgeAdapters/layerzero/oapp/OAppReceiver.sol";
import { Origin } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroTypes.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract LzReceiveUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    /// @notice Sample payload for testing.
    bytes internal samplePayload = abi.encode("test message from remote");

    /// @notice Sample GUID for testing.
    bytes32 internal sampleGuid = keccak256("sample-guid");

    /// @notice Sample nonce for testing.
    uint64 internal sampleNonce = 1;

    /// @notice Empty extra data for testing.
    bytes internal emptyExtraData = "";

    // ═══════════════════════════════════════════════════════════════════════
    //                  REVERT CASES - CALLER NOT ENDPOINT
    // ═══════════════════════════════════════════════════════════════════════

    function test_lzReceive_revertsIfCallerIsNotEndpoint() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OAppReceiver.OnlyEndpoint.selector, user));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfCallerIsAdmin() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(OAppReceiver.OnlyEndpoint.selector, admin));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfCallerIsOperator() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(OAppReceiver.OnlyEndpoint.selector, operator));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfCallerIsPortal() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(portal));
        vm.expectRevert(abi.encodeWithSelector(OAppReceiver.OnlyEndpoint.selector, address(portal)));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                REVERT CASES - SOURCE EID NOT CONFIGURED
    // ═══════════════════════════════════════════════════════════════════════

    function test_lzReceive_revertsIfSourceEidNotConfigured() external {
        uint32 unconfiguredEid = 99_999;
        Origin memory origin = Origin({ srcEid: unconfiguredEid, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedBridgeChain.selector, unconfiguredEid));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfSourceEidIsZero() external {
        Origin memory origin = Origin({ srcEid: 0, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedBridgeChain.selector, 0));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //              REVERT CASES - SENDER DOES NOT MATCH PEER
    // ═══════════════════════════════════════════════════════════════════════

    function test_lzReceive_revertsIfSenderDoesNotMatchPeer() external {
        bytes32 wrongSender = makeAddr("wrongSender").toBytes32();
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: wrongSender, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(ILayerZeroBridgeAdapter.InvalidPeer.selector, wrongSender));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfSenderIsZero() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: bytes32(0), nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(ILayerZeroBridgeAdapter.InvalidPeer.selector, bytes32(0)));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    function test_lzReceive_revertsIfSenderIsSlightlyDifferent() external {
        // Test with a sender that is very close to the peer address but different
        bytes32 slightlyDifferentSender = bytes32(uint256(peerAdapterAddress) + 1);
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: slightlyDifferentSender, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(ILayerZeroBridgeAdapter.InvalidPeer.selector, slightlyDifferentSender));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_lzReceive_succeeds() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);

        // Verify portal.receiveMessage was called
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function test_lzReceive_callsPortalWithCorrectSourceChainId() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);

        // Check the source chain ID in the portal call
        (uint32 sourceChainId,) = portal.receiveMessageCalls(0);
        assertEq(sourceChainId, SPOKE_CHAIN_ID, "Source chain ID should be converted from LZ EID to internal chain ID");
    }

    function test_lzReceive_callsPortalWithCorrectPayload() external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);

        // Check the payload in the portal call
        (, bytes memory payload) = portal.receiveMessageCalls(0);
        assertEq(payload, samplePayload, "Payload should match the message sent");
    }

    function test_lzReceive_withEmptyPayload() external {
        bytes memory emptyPayload = "";
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, emptyPayload, address(0), emptyExtraData);

        (, bytes memory payload) = portal.receiveMessageCalls(0);
        assertEq(payload.length, 0, "Payload should be empty");
    }

    function test_lzReceive_withLargePayload() external {
        // Create a large payload (1KB)
        bytes memory largePayload = new bytes(1024);
        for (uint256 i = 0; i < 1024; i++) {
            largePayload[i] = bytes1(uint8(i % 256));
        }

        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, largePayload, address(0), emptyExtraData);

        (, bytes memory payload) = portal.receiveMessageCalls(0);
        assertEq(payload, largePayload, "Large payload should be forwarded correctly");
    }

    function test_lzReceive_withNonZeroExecutor() external {
        address executor = makeAddr("executor");
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, executor, emptyExtraData);

        // Should succeed regardless of executor address
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function test_lzReceive_withNonEmptyExtraData() external {
        bytes memory extraData = abi.encode("extra data");
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), extraData);

        // Should succeed regardless of extra data
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function test_lzReceive_withDifferentGuid() external {
        bytes32 differentGuid = keccak256("different-guid");
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, differentGuid, samplePayload, address(0), emptyExtraData);

        // Should succeed regardless of GUID
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function test_lzReceive_withDifferentNonce() external {
        uint64 differentNonce = 12_345;
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: differentNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);

        // Should succeed regardless of nonce value (unordered execution)
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function test_lzReceive_multipleMessages() external {
        Origin memory origin1 = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: 1 });
        Origin memory origin2 = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: 2 });
        Origin memory origin3 = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: 3 });

        bytes memory payload1 = abi.encode("message 1");
        bytes memory payload2 = abi.encode("message 2");
        bytes memory payload3 = abi.encode("message 3");

        vm.startPrank(address(lzEndpoint));
        adapter.lzReceive(origin1, keccak256("guid1"), payload1, address(0), emptyExtraData);
        adapter.lzReceive(origin2, keccak256("guid2"), payload2, address(0), emptyExtraData);
        adapter.lzReceive(origin3, keccak256("guid3"), payload3, address(0), emptyExtraData);
        vm.stopPrank();

        assertEq(portal.getReceiveMessageCallsCount(), 3, "Portal should have received three messages");

        // Verify each message
        (, bytes memory p1) = portal.receiveMessageCalls(0);
        (, bytes memory p2) = portal.receiveMessageCalls(1);
        (, bytes memory p3) = portal.receiveMessageCalls(2);

        assertEq(p1, payload1, "First payload should match");
        assertEq(p2, payload2, "Second payload should match");
        assertEq(p3, payload3, "Third payload should match");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_lzReceive_withVariablePayload(bytes memory payload) external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, payload, address(0), emptyExtraData);

        (, bytes memory receivedPayload) = portal.receiveMessageCalls(0);
        assertEq(receivedPayload, payload, "Payload should be forwarded correctly");
    }

    function testFuzz_lzReceive_withVariableNonce(uint64 nonce) external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: nonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);

        // Should succeed regardless of nonce value
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function testFuzz_lzReceive_withVariableGuid(bytes32 guid) external {
        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, guid, samplePayload, address(0), emptyExtraData);

        // Should succeed regardless of GUID
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received one message");
    }

    function testFuzz_lzReceive_revertsWithRandomSender(bytes32 randomSender) external {
        vm.assume(randomSender != peerAdapterAddress);

        Origin memory origin = Origin({ srcEid: SPOKE_LZ_EID, sender: randomSender, nonce: sampleNonce });

        vm.prank(address(lzEndpoint));
        vm.expectRevert(abi.encodeWithSelector(ILayerZeroBridgeAdapter.InvalidPeer.selector, randomSender));
        adapter.lzReceive(origin, sampleGuid, samplePayload, address(0), emptyExtraData);
    }
}
