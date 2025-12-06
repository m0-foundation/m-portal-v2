// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import { ERC1967Proxy } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { HubPortal } from "../../../src/HubPortal.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal, ChainConfig } from "../../../src/interfaces/IPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MockMToken } from "../../mocks/MockMToken.sol";
import { MockWrappedMToken } from "../../mocks/MockWrappedMToken.sol";
import { MockHubRegistrar } from "../../mocks/MockHubRegistrar.sol";
import { MockSwapFacility } from "../../mocks/MockSwapFacility.sol";
import { MockOrderBook } from "../../mocks/MockOrderBook.sol";
import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";

abstract contract HubPortalUnitTestBase is Test {
    using TypeConverter for *;

    uint32 internal constant HUB_CHAIN_ID = 1;
    uint32 internal constant SPOKE_CHAIN_ID = 2;

    uint256 internal constant INDEX_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant KEY_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant LIST_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant FILL_REPORT_GAS_LIMIT = 150_000;
    uint256 internal constant TOKEN_TRANSFER_GAS_LIMIT = 250_000;

    /// @dev Registrar key of earners list.
    bytes32 internal constant EARNERS_LIST = "earners";

    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant EARNERS_LIST_IGNORED = "earners_list_ignored";

    HubPortal internal implementation;
    HubPortal internal hubPortal;
    MockMToken internal mToken;
    MockWrappedMToken internal wrappedMToken;
    MockHubRegistrar internal registrar;
    MockSwapFacility internal swapFacility;
    MockOrderBook internal mockOrderBook;
    MockBridgeAdapter internal bridgeAdapter;

    bytes32 internal spokeMToken = makeAddr("spokeMToken").toBytes32();
    bytes32 internal spokeWrappedMToken = makeAddr("spokeWrappedMToken").toBytes32();

    address internal admin = makeAddr("admin");
    address internal operator = makeAddr("operator");
    address internal pauser = makeAddr("pauser");
    address internal user = makeAddr("user");

    function setUp() public virtual {
        // Set block.chainid to HUB_CHAIN_ID
        vm.chainId(HUB_CHAIN_ID);

        mToken = new MockMToken();
        wrappedMToken = new MockWrappedMToken(address(mToken));

        registrar = new MockHubRegistrar();
        swapFacility = new MockSwapFacility(address(mToken));
        mockOrderBook = new MockOrderBook();
        bridgeAdapter = new MockBridgeAdapter();

        // Deploy implementation
        implementation = new HubPortal(
            address(mToken),
            address(registrar),
            address(swapFacility),
            address(mockOrderBook)
        );

        // Deploy UUPS proxy
        bytes memory initializeData = abi.encodeCall(HubPortal.initialize, (admin, pauser, operator));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        hubPortal = HubPortal(address(proxy));

        vm.startPrank(operator);

        // Configure
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID, address(bridgeAdapter));

        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID, spokeMToken, true);
        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID, spokeWrappedMToken, true);
        hubPortal.setSupportedBridgingPath(address(wrappedMToken), SPOKE_CHAIN_ID, spokeMToken, true);
        hubPortal.setSupportedBridgingPath(address(wrappedMToken), SPOKE_CHAIN_ID, spokeWrappedMToken, true);

        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, TOKEN_TRANSFER_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.Index, INDEX_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.RegistrarKey, KEY_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.RegistrarList, LIST_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.FillReport, FILL_REPORT_GAS_LIMIT);
        
        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(pauser, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(mockOrderBook), 1 ether);
    }

    function _getMessageId() internal returns (bytes32) {
        uint256 nonce = hubPortal.getNonce();
        return keccak256(abi.encode(HUB_CHAIN_ID, SPOKE_CHAIN_ID, nonce++));
    }
}
