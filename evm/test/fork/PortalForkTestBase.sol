// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "../../lib/forge-std/src/Test.sol";

abstract contract PortalForkTestBase is Test {
    uint32 ETHEREUM_CHAIN_ID = 1;
    uint32 ARBITRUM_CHAIN_ID = 42_161;
    uint32 BNB_CHAIN_ID = 56;

    uint32 ETHEREUM_HYPERLANE_DOMAIN = 1;
    uint32 ARBITRUM_HYPERLANE_DOMAIN = 42_161;
    uint32 BNB_HYPERLANE_DOMAIN = 56;

    uint256 internal constant INDEX_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant KEY_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant LIST_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant FILL_REPORT_GAS_LIMIT = 150_000;
    uint256 internal constant TOKEN_TRANSFER_GAS_LIMIT = 250_000;
    uint256 internal constant EARNER_MERKLE_ROOT_GAS_LIMIT = 100_000;
}
