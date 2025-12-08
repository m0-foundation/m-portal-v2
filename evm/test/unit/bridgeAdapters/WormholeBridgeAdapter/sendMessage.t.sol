// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";
import { ICoreBridge } from "../../../../src/bridgeAdapters/wormhole/interfaces/ICoreBridge.sol";
import { IExecutor } from "../../../../src/bridgeAdapters/wormhole/interfaces/IExecutor.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SendMessageUnitTest is WormholeBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_sendMessage_publishesAndRequestsExecution() external {
        uint256 gasLimit = 250_000;
        bytes32 refundAddress = makeAddr("refund").toBytes32();
        bytes memory payload = "test payload";
        uint256 coreBridgeFee = 0.001 ether;
        uint256 executorFee = 0.002 ether;
        uint256 totalFee = coreBridgeFee + executorFee;

        vm.mockCall(address(coreBridge), coreBridgeFee, abi.encodeWithSelector(ICoreBridge.publishMessage.selector), abi.encode(uint64(0)));

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.messageFee.selector), abi.encode(coreBridgeFee));

        vm.expectCall(
            address(coreBridge),
            coreBridgeFee,
            abi.encodeWithSelector(ICoreBridge.publishMessage.selector, uint32(0), payload, CONSISTENCY_LEVEL)
        );

        vm.expectCall(address(executor), executorFee, abi.encodeWithSelector(IExecutor.requestExecution.selector));

        vm.prank(address(portal));
        adapter.sendMessage{ value: totalFee }(SPOKE_CHAIN_ID, gasLimit, refundAddress, payload, "signed_quote");
    }

    function test_sendMessage_revertsIfNotCalledByPortal() external {
        uint256 gasLimit = 250_000;
        bytes32 refundAddress = makeAddr("refund").toBytes32();
        bytes memory payload = "test payload";

        vm.expectRevert(IBridgeAdapter.NotPortal.selector);

        vm.prank(user);
        adapter.sendMessage{ value: 0.001 ether }(SPOKE_CHAIN_ID, gasLimit, refundAddress, payload, "");
    }

    function test_sendMessage_revertsIfChainNotConfigured() external {
        uint32 unconfiguredChain = 999;
        uint256 gasLimit = 250_000;
        bytes32 refundAddress = makeAddr("refund").toBytes32();
        bytes memory payload = "test payload";

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, unconfiguredChain));

        vm.prank(address(portal));
        adapter.sendMessage{ value: 0.001 ether }(unconfiguredChain, gasLimit, refundAddress, payload, "");
    }

    function test_sendMessage_revertsIfBridgeChainIdNotSet() external {
        uint32 newChainId = 3;
        bytes32 newPeer = makeAddr("newPeer").toBytes32();

        vm.prank(operator);
        adapter.setPeer(newChainId, newPeer);

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, newChainId));

        vm.prank(address(portal));
        adapter.sendMessage{ value: 0.001 ether }(newChainId, 250_000, makeAddr("refund").toBytes32(), "test", "");
    }

    function test_sendMessage_revertsIfPeerNotSet() external {
        uint32 newChainId = 3;

        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, 3000);

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, newChainId));

        vm.prank(address(portal));
        adapter.sendMessage{ value: 0.001 ether }(newChainId, 250_000, makeAddr("refund").toBytes32(), "test", "");
    }

    function test_sendMessage_revertsIfInsufficientFee() external {
        uint256 gasLimit = 250_000;
        bytes32 refundAddress = makeAddr("refund").toBytes32();
        bytes memory payload = "test payload";
        uint256 coreBridgeFee = 0.001 ether;

        vm.mockCall(address(coreBridge), abi.encodeWithSelector(ICoreBridge.messageFee.selector), abi.encode(coreBridgeFee));

        vm.expectRevert(IWormholeBridgeAdapter.InsufficientFee.selector);

        vm.prank(address(portal));
        adapter.sendMessage{ value: coreBridgeFee - 1 }(SPOKE_CHAIN_ID, gasLimit, refundAddress, payload, "");
    }
}
