// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";
import { IPortal } from "../../../../src/interfaces/IPortal.sol";
import { ICoreBridge, CoreBridgeVM, GuardianSignature } from "../../../../src/bridgeAdapters/wormhole/interfaces/ICoreBridge.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../../src/libraries/PayloadEncoder.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract ExecuteVAAv1UnitTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    bytes32 constant MESSAGE_ID = bytes32("message id");
    uint128 constant INDEX = 1.1e12;

    function test_executeVAAv1_forwardsToPortal() external {
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(adapter).toBytes32(), MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: peerAdapterAddress,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        // Expect portal.receiveMessage to be called with correct parameters
        vm.expectCall(address(portal), abi.encodeWithSelector(IPortal.receiveMessage.selector, SPOKE_CHAIN_ID, payload));

        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsIfInvalidVaa() external {
        bytes memory encodedMessage = "encoded_vaa";
        string memory reason = "Invalid signatures";

        CoreBridgeVM memory mockVM;

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, false, reason));

        vm.expectRevert(abi.encodeWithSelector(IWormholeBridgeAdapter.InvalidVaa.selector, reason));
        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsIfUnsupportedSender() external {
        bytes32 unsupportedSender = makeAddr("unsupported").toBytes32();
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(adapter).toBytes32(), MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: unsupportedSender,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        vm.expectRevert(abi.encodeWithSelector(IWormholeBridgeAdapter.UnsupportedSender.selector, unsupportedSender));
        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsIfUnsupportedChain() external {
        uint16 unsupportedChain = 9999;
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(adapter).toBytes32(), MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: unsupportedChain,
            emitterAddress: peerAdapterAddress,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedBridgeChain.selector, unsupportedChain));
        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsOnReplayAttack() external {
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, address(adapter).toBytes32(), MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";
        bytes32 messageHash = keccak256("unique_message_hash");

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: peerAdapterAddress,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: messageHash
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        // First execution should succeed
        vm.expectCall(address(portal), abi.encodeWithSelector(IPortal.receiveMessage.selector, SPOKE_CHAIN_ID, payload));
        adapter.executeVAAv1(encodedMessage);

        // Second execution with the same message hash should revert
        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));
        vm.expectRevert(abi.encodeWithSelector(IWormholeBridgeAdapter.MessageAlreadyConsumed.selector, messageHash));
        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsIfInvalidTargetChain() external {
        uint32 wrongTargetChainId = 999;
        bytes memory payload = PayloadEncoder.encodeIndex(wrongTargetChainId, address(adapter).toBytes32(), MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: peerAdapterAddress,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        vm.expectRevert(abi.encodeWithSelector(IWormholeBridgeAdapter.InvalidTargetChain.selector, wrongTargetChainId));
        adapter.executeVAAv1(encodedMessage);
    }

    function test_executeVAAv1_revertsIfInvalidTargetBridgeAdapter() external {
        bytes32 wrongTargetAdapter = makeAddr("wrongAdapter").toBytes32();
        bytes memory payload = PayloadEncoder.encodeIndex(HUB_CHAIN_ID, wrongTargetAdapter, MESSAGE_ID, INDEX);
        bytes memory encodedMessage = "encoded_vaa";

        CoreBridgeVM memory mockVM = CoreBridgeVM({
            version: 1,
            timestamp: uint32(block.timestamp),
            nonce: 0,
            emitterChainId: SPOKE_WORMHOLE_CHAIN_ID,
            emitterAddress: peerAdapterAddress,
            sequence: 1,
            consistencyLevel: CONSISTENCY_LEVEL,
            payload: payload,
            guardianSetIndex: 0,
            signatures: new GuardianSignature[](0),
            hash: bytes32(0)
        });

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.parseAndVerifyVM.selector), abi.encode(mockVM, true, ""));

        vm.expectRevert(abi.encodeWithSelector(IWormholeBridgeAdapter.InvalidTargetBridgeAdapter.selector, wrongTargetAdapter));
        adapter.executeVAAv1(encodedMessage);
    }
}
