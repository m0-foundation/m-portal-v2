// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
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

    uint256 constant ARBITRUM_FORK_BLOCK = 418_948_002;

    address public constant ARBITRUM_HYPERLANE_MAILBOX = 0x979Ca5202784112f4738403dBec5D0F3B9daabB9;
    address public constant TOKEN_HOLDER = 0x77BAB32F75996de8075eBA62aEa7b1205cf7E004;
    SpokePortal public spokePortal;
    HyperlaneBridgeAdapter public bridgeAdapter;

    function setUp() external {
        vm.createSelectFork({ urlOrAlias: "arbitrum", blockNumber: ARBITRUM_FORK_BLOCK });

        vm.deal(OWNER_V1, 1 ether);
        vm.deal(TOKEN_HOLDER, 1 ether);
        vm.deal(OPERATOR_V2, 1 ether);

        // Migrate Arbitrum SpokePortal
        vm.startPrank(OWNER_V1);

        _upgradeToStorageCleaner(WORMHOLE_ARBITRUM_CHAIN_ID);
        _clearStorage();
        _upgradeToPortalV2();

        vm.stopPrank();

        spokePortal = SpokePortal(PORTAL);

        vm.startPrank(OPERATOR_V2);

        // Deploy and register HyperlaneBridgeAdapter
        bytes memory initializeData = abi.encodeCall(HyperlaneBridgeAdapter.initialize, (ADMIN_V2, OPERATOR_V2));
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
