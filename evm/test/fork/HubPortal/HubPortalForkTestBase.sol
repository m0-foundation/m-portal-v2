// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
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

    uint256 constant ETHEREUM_FORK_BLOCK = 24_171_707;

    address SWAP_FACILITY_ADMIN = 0xb7A9B5f301eF3bAD36C2b4964E82931Dd7fb989C;

    address public constant HYPERLANE_MAILBOX = 0xc005dc82818d67AF737725bD4bf75435d065D239;
    address public constant TOKEN_HOLDER = 0x77BAB32F75996de8075eBA62aEa7b1205cf7E004;
    address public constant MUSD = 0xacA92E438df0B2401fF60dA7E4337B687a2435DA;

    HubPortal public hubPortal;
    HyperlaneBridgeAdapter public bridgeAdapter;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "ethereum", blockNumber: ETHEREUM_FORK_BLOCK });

        vm.deal(OWNER_V1, 1 ether);
        vm.deal(TOKEN_HOLDER, 1 ether);
        vm.deal(OPERATOR_V2, 1 ether);

        // Migrate HubPortal
        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner();
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopPrank();

        hubPortal = HubPortal(PORTAL);
        hubPortal.enableEarning();

        vm.startPrank(OPERATOR_V2);

        // Deploy and register HyperlaneBridgeAdapter
        bytes memory initializeData = abi.encodeCall(HyperlaneBridgeAdapter.initialize, (ADMIN_V2, OPERATOR_V2));
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

        // Allow Portal to swap MUSD in SwapFacility
        vm.prank(SWAP_FACILITY_ADMIN);
        SWAP_FACILITY.call(abi.encodeWithSignature("setPermissionedMSwapper(address,address,bool)", MUSD, address(hubPortal), true));
    }
}
