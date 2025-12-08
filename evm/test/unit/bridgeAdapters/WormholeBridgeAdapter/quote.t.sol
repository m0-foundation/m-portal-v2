// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract QuoteUnitTest is WormholeBridgeAdapterUnitTestBase {
    function test_quote_revertsWithOnChainQuoteNotSupported() external {
        uint256 gasLimit = 250_000;
        bytes memory payload = "test payload";

        vm.expectRevert(IWormholeBridgeAdapter.OnChainQuoteNotSupported.selector);
        adapter.quote(SPOKE_CHAIN_ID, gasLimit, payload);
    }
}
