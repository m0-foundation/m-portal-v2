// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerZero/interfaces/ILayerZeroBridgeAdapter.sol";
import { Origin } from "../../../../src/bridgeAdapters/layerZero/interfaces/ILayerZeroEndpointV2.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract LzReceiveUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_lzReceive_forwardsToPortal() external {
        bytes memory payload = "test payload";
        Origin memory origin = Origin({ srcEid: SPOKE_LAYER_ZERO_EID, sender: peerAdapterAddress, nonce: 1 });

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, bytes32(0), payload, address(0), "");

        // Verify portal.receiveMessage was called
        assertEq(portal.getReceiveMessageCallsCount(), 1);

        (uint32 sourceChainId, bytes memory receivedPayload) = portal.receiveMessageCalls(0);

        assertEq(sourceChainId, SPOKE_CHAIN_ID);
        assertEq(receivedPayload, payload);
    }

    function test_lzReceive_revertsIfNotCalledByEndpoint() external {
        bytes memory payload = "test payload";
        Origin memory origin = Origin({ srcEid: SPOKE_LAYER_ZERO_EID, sender: peerAdapterAddress, nonce: 1 });

        vm.expectRevert(ILayerZeroBridgeAdapter.NotEndpoint.selector);

        vm.prank(user);
        adapter.lzReceive(origin, bytes32(0), payload, address(0), "");
    }

    function test_lzReceive_revertsIfUnsupportedEndpointId() external {
        uint32 unsupportedEid = 99_999;
        bytes memory payload = "test payload";
        Origin memory origin = Origin({ srcEid: unsupportedEid, sender: peerAdapterAddress, nonce: 1 });

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedBridgeChain.selector, unsupportedEid));

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, bytes32(0), payload, address(0), "");
    }

    function test_lzReceive_revertsIfPeerNotDefined() external {
        // Set up a chain ID mapping without a peer
        uint32 noPeerChainId = 3;
        uint32 noPeerEid = 30_103;

        vm.prank(operator);
        adapter.setBridgeChainId(noPeerChainId, noPeerEid);

        bytes memory payload = "test payload";
        Origin memory origin = Origin({ srcEid: noPeerEid, sender: peerAdapterAddress, nonce: 1 });

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, noPeerChainId));

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, bytes32(0), payload, address(0), "");
    }

    function test_lzReceive_revertsIfUnsupportedSender() external {
        bytes32 unsupportedSender = makeAddr("unsupported").toBytes32();
        bytes memory payload = "test payload";
        Origin memory origin = Origin({ srcEid: SPOKE_LAYER_ZERO_EID, sender: unsupportedSender, nonce: 1 });

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedSender.selector, unsupportedSender));

        vm.prank(address(lzEndpoint));
        adapter.lzReceive(origin, bytes32(0), payload, address(0), "");
    }
}
