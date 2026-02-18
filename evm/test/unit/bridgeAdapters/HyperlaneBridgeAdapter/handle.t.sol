// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IHyperlaneBridgeAdapter } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IHyperlaneBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract HandleUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_handle_forwardsToPortal() external {
        bytes memory payload = "test payload";

        vm.prank(address(mailbox));
        adapter.handle(SPOKE_HYPERLANE_DOMAIN, peerAdapterAddress, payload);

        // Verify portal.receiveMessage was called
        assertEq(portal.getReceiveMessageCallsCount(), 1);

        (uint32 sourceChainId, bytes memory receivedPayload) = portal.receiveMessageCalls(0);

        assertEq(sourceChainId, SPOKE_CHAIN_ID);
        assertEq(receivedPayload, payload);
    }

    function test_handle_revertsIfNotCalledByMailbox() external {
        bytes memory payload = "test payload";

        vm.expectRevert(IHyperlaneBridgeAdapter.NotMailbox.selector);

        vm.prank(user);
        adapter.handle(SPOKE_HYPERLANE_DOMAIN, peerAdapterAddress, payload);
    }

    function test_handle_revertsIfUnsupportedBridgeDomain() external {
        uint32 unsupportedDomain = 9999;
        bytes memory payload = "test payload";

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedBridgeChain.selector, unsupportedDomain));

        vm.prank(address(mailbox));
        adapter.handle(unsupportedDomain, peerAdapterAddress, payload);
    }

    function test_handle_revertsIfUnsupportedSender() external {
        bytes32 unsupportedSender = makeAddr("unsupported").toBytes32();
        bytes memory payload = "test payload";

        vm.expectRevert(abi.encodeWithSelector(IHyperlaneBridgeAdapter.UnsupportedSender.selector, unsupportedSender));

        vm.prank(address(mailbox));
        adapter.handle(SPOKE_HYPERLANE_DOMAIN, unsupportedSender, payload);
    }
}
