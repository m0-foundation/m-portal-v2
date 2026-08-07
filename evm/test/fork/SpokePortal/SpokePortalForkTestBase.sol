// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    ERC1967Proxy
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SpokePortal } from "../../../src/SpokePortal.sol";
import { HyperlaneBridgeAdapter } from "../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MigrateSpokePortalBase } from "../../../script/migrate/MigrateSpokePortalBase.sol";
import { PortalForkTestBase } from "../PortalForkTestBase.sol";

contract SpokePortalForkTestBase is MigrateSpokePortalBase, PortalForkTestBase {
    using TypeConverter for *;

    // Must be a block after both SpokePortal and Wrapped $M were upgraded to V2
    uint256 constant ARBITRUM_FORK_BLOCK = 491_860_000;

    // Live Portal V2 access control addresses
    address public constant ADMIN = 0x48670B46380FE1645f0E3e821a25162dB2589D19;
    address public constant OPERATOR = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    address public constant ARBITRUM_HYPERLANE_MAILBOX = 0x979Ca5202784112f4738403dBec5D0F3B9daabB9;
    address public constant TOKEN_HOLDER = 0x77BAB32F75996de8075eBA62aEa7b1205cf7E004;

    SpokePortal public spokePortal;
    HyperlaneBridgeAdapter public bridgeAdapter;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: ARBITRUM_FORK_BLOCK });

        vm.deal(TOKEN_HOLDER, 1 ether);
        vm.deal(OPERATOR, 1 ether);

        // SpokePortal is already migrated to V2
        spokePortal = SpokePortal(PORTAL);

        vm.startPrank(OPERATOR);

        // Deploy and register HyperlaneBridgeAdapter
        bytes memory initializeData = abi.encodeCall(HyperlaneBridgeAdapter.initialize, (ADMIN, OPERATOR));
        ERC1967Proxy proxy = new ERC1967Proxy(address(new HyperlaneBridgeAdapter(ARBITRUM_HYPERLANE_MAILBOX, PORTAL)), initializeData);
        bridgeAdapter = HyperlaneBridgeAdapter(address(proxy));

        // Configure Arbitrum SpokePortal V2
        spokePortal.setDefaultBridgeAdapter(ETHEREUM_CHAIN_ID, address(bridgeAdapter));

        spokePortal.setSupportedBridgingPath(M_TOKEN, ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32(), true);
        spokePortal.setSupportedBridgingPath(M_TOKEN, ETHEREUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32(), true);
        spokePortal.setSupportedBridgingPath(WRAPPED_M_TOKEN, ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32(), true);
        spokePortal.setSupportedBridgingPath(WRAPPED_M_TOKEN, ETHEREUM_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32(), true);

        spokePortal.setPayloadGasLimit(ETHEREUM_CHAIN_ID, PayloadType.TokenTransfer, TOKEN_TRANSFER_GAS_LIMIT);
        spokePortal.setPayloadGasLimit(ETHEREUM_CHAIN_ID, PayloadType.FillReport, FILL_REPORT_GAS_LIMIT);

        // Configure HyperlaneBridgeAdapter
        bridgeAdapter.setPeer(ETHEREUM_CHAIN_ID, address(bridgeAdapter).toBytes32());
        bridgeAdapter.setBridgeChainId(ETHEREUM_CHAIN_ID, ETHEREUM_HYPERLANE_DOMAIN);

        vm.stopPrank();
    }
}
