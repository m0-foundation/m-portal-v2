// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ICoreBridge, CoreBridgeVM, GuardianSignature } from "../../../../src/bridgeAdapters/wormhole/interfaces/ICoreBridge.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract ReplayAttackTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    /// @notice Demonstrates that the same VAA can be executed multiple times
    /// @dev If replay protection is implemented, this test should fail.
    function test_executeVAAv1_replayAttack_sameVaaCanBeExecutedTwice() external {
        bytes memory payload = "token_transfer_payload";
        bytes memory encodedMessage = "encoded_vaa_bytes";

        // Create a valid VAA with a specific sequence number
        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: peerAdapterAddress,
            sequence: 12345, // Unique sequence number
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        // Mock the CoreBridge to return valid VAA
        vm.mockCall(
            address(coreBridge),
            abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector),
            abi.encode(mockVM, true, "")
        );

        // Verify portal starts with 0 received messages
        assertEq(portal.getReceiveMessageCallsCount(), 0, "Portal should start with 0 messages");

        // First execution - should succeed
        adapter.executeVAAv1(encodedMessage);
        assertEq(portal.getReceiveMessageCallsCount(), 1, "Portal should have received 1 message");

        // Second execution with SAME VAA - currently succeeds (vulnerability!)
        // If replay protection existed, this would revert
        adapter.executeVAAv1(encodedMessage);
        assertEq(portal.getReceiveMessageCallsCount(), 2, "Portal received message TWICE - replay attack succeeded!");

        // Third execution - still works
        adapter.executeVAAv1(encodedMessage);
        assertEq(portal.getReceiveMessageCallsCount(), 3, "Portal received message THREE times!");

        // Verify all calls had the same payload (same message replayed)
        (uint32 chainId1, bytes memory payload1) = portal.receiveMessageCalls(0);
        (uint32 chainId2, bytes memory payload2) = portal.receiveMessageCalls(1);
        (uint32 chainId3, bytes memory payload3) = portal.receiveMessageCalls(2);

        assertEq(chainId1, SPOKE_CHAIN_ID);
        assertEq(chainId2, SPOKE_CHAIN_ID);
        assertEq(chainId3, SPOKE_CHAIN_ID);
        assertEq(keccak256(payload1), keccak256(payload));
        assertEq(keccak256(payload2), keccak256(payload));
        assertEq(keccak256(payload3), keccak256(payload));
    }
}
