// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IMailbox } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IMailbox.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

contract QuoteUnitTest is HyperlaneBridgeAdapterUnitTestBase {
    using TypeConverter for *;

    function test_quote_returnsMailboxQuote() external {
        uint256 gasLimit = 250_000;
        bytes memory payload = "test payload";
        uint256 expectedFee = 0.001 ether;

        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.quoteDispatch.selector), abi.encode(expectedFee));

        uint256 fee = adapter.quote(SPOKE_CHAIN_ID, gasLimit, payload);

        assertEq(fee, expectedFee);
    }

    function testFuzz_quote(uint256 expectedFee, uint256 gasLimit) external {
        vm.assume(expectedFee < 1 ether);
        vm.assume(gasLimit > 0 && gasLimit < 10_000_000);

        bytes memory payload = "test payload";

        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.quoteDispatch.selector), abi.encode(expectedFee));

        uint256 fee = adapter.quote(SPOKE_CHAIN_ID, gasLimit, payload);

        assertEq(fee, expectedFee);
    }

    function test_quote_revertsIfChainNotConfigured() external {
        uint32 unconfiguredChain = 999;
        uint256 gasLimit = 250_000;
        bytes memory payload = "test payload";

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, unconfiguredChain));

        adapter.quote(unconfiguredChain, gasLimit, payload);
    }

    function test_quote_revertsIfBridgeChainIdNotSet() external {
        uint32 newChainId = 3;
        bytes32 newPeer = makeAddr("newPeer").toBytes32();

        // Set peer but not bridge chain ID
        vm.prank(operator);
        adapter.setPeer(newChainId, newPeer);

        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, newChainId));

        adapter.quote(newChainId, 250_000, "test");
    }
}
