// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    ERC1967Proxy
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { HubPortal } from "../../../src/HubPortal.sol";
import { HyperlaneBridgeAdapter } from "../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MigrateHubPortalBase } from "../../../script/migrate/MigrateHubPortalBase.sol";
import { PortalForkTestBase } from "../PortalForkTestBase.sol";

contract HubPortalForkTestBase is MigrateHubPortalBase, PortalForkTestBase {
    using TypeConverter for *;

    // Must be a block after both HubPortal and Wrapped $M were upgraded to V2
    uint256 constant ETHEREUM_FORK_BLOCK = 25_699_000;

    // Live Portal V2 access control addresses
    address public constant ADMIN = 0x48670B46380FE1645f0E3e821a25162dB2589D19;
    address public constant OPERATOR = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    address public constant HYPERLANE_MAILBOX = 0xc005dc82818d67AF737725bD4bf75435d065D239;
    address public constant TOKEN_HOLDER = 0x77BAB32F75996de8075eBA62aEa7b1205cf7E004;
    address public constant MUSD = 0xacA92E438df0B2401fF60dA7E4337B687a2435DA;

    HubPortal public hubPortal;
    HyperlaneBridgeAdapter public bridgeAdapter;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: ETHEREUM_FORK_BLOCK });

        vm.deal(TOKEN_HOLDER, 1 ether);
        vm.deal(OPERATOR, 1 ether);

        // HubPortal is already migrated to V2 with earning enabled
        // and permissioned to swap MUSD in SwapFacility
        hubPortal = HubPortal(PORTAL);

        vm.startPrank(OPERATOR);

        // Deploy and register HyperlaneBridgeAdapter
        bytes memory initializeData = abi.encodeCall(HyperlaneBridgeAdapter.initialize, (ADMIN, OPERATOR));
        ERC1967Proxy proxy = new ERC1967Proxy(address(new HyperlaneBridgeAdapter(HYPERLANE_MAILBOX, PORTAL)), initializeData);
        bridgeAdapter = HyperlaneBridgeAdapter(address(proxy));

        // Configure HubPortal V2
        hubPortal.setDefaultBridgeAdapter(BNB_CHAIN_ID, address(bridgeAdapter));

        hubPortal.setSupportedBridgingPath(M_TOKEN, BNB_CHAIN_ID, M_TOKEN.toBytes32(), true);
        hubPortal.setSupportedBridgingPath(M_TOKEN, BNB_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32(), true);
        hubPortal.setSupportedBridgingPath(WRAPPED_M_TOKEN, BNB_CHAIN_ID, M_TOKEN.toBytes32(), true);
        hubPortal.setSupportedBridgingPath(WRAPPED_M_TOKEN, BNB_CHAIN_ID, WRAPPED_M_TOKEN.toBytes32(), true);
        hubPortal.setSupportedBridgingPath(MUSD, BNB_CHAIN_ID, MUSD.toBytes32(), true);

        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.TokenTransfer, TOKEN_TRANSFER_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.Index, INDEX_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.RegistrarKey, KEY_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.RegistrarList, LIST_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.FillReport, FILL_REPORT_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(BNB_CHAIN_ID, PayloadType.EarnerMerkleRoot, EARNER_MERKLE_ROOT_GAS_LIMIT);

        // Configure HyperlaneBridgeAdapter
        bridgeAdapter.setPeer(BNB_CHAIN_ID, address(bridgeAdapter).toBytes32());
        bridgeAdapter.setBridgeChainId(BNB_CHAIN_ID, BNB_HYPERLANE_DOMAIN);

        vm.stopPrank();
    }
}
