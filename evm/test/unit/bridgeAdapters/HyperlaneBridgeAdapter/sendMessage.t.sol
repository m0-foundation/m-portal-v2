// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IMailbox } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IMailbox.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract SendMessageUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    using TypeConverter for *;
    
    bytes32 hyperlaneMessageId = bytes32("hyperlaneMessageId");

    function test_sendMessage_dispatchesToMailbox() external {
        uint256 gasLimit = 250_000;
        bytes32 refundAddress = makeAddr("refund").toBytes32();
        bytes memory payload = "test payload";
        uint256 fee = 0.001 ether;

        vm.mockCall(
            address(mailbox),
            fee,
            abi.encodeWithSelector(IMailbox.dispatch.selector),
            abi.encode(hyperlaneMessageId)
        );

        // Expect the mailbox dispatch to be called with the fee
        vm.expectCall(address(mailbox), fee, abi.encodeWithSelector(IMailbox.dispatch.selector));

        vm.prank(address(portal));
        adapter.sendMessage{ value: fee }(SPOKE_CHAIN_ID, gasLimit, refundAddress, payload, "");
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

        // Set peer but not bridge chain ID
        vm.prank(operator);
        adapter.setPeer(newChainId, newPeer);

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, newChainId));

        vm.prank(address(portal));
        adapter.sendMessage{ value: 0.001 ether }(newChainId, 250_000, makeAddr("refund").toBytes32(), "test", "");
    }

    function test_sendMessage_revertsIfPeerNotSet() external {
        uint32 newChainId = 3;

        // Set bridge chain ID but not peer
        vm.prank(operator);
        adapter.setBridgeChainId(newChainId, 3000);

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, newChainId));

        vm.prank(address(portal));
        adapter.sendMessage{ value: 0.001 ether }(newChainId, 250_000, makeAddr("refund").toBytes32(), "test", "");
    }
}
