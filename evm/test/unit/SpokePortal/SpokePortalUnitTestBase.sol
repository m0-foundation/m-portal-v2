// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import {
    ERC1967Proxy
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SpokePortal } from "../../../src/SpokePortal.sol";
import { ChainConfig } from "../../../src/interfaces/IPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MockSpokeMToken } from "../../mocks/MockSpokeMToken.sol";
import { MockWrappedMToken } from "../../mocks/MockWrappedMToken.sol";
import { MockSpokeRegistrar } from "../../mocks/MockSpokeRegistrar.sol";
import { MockSwapFacility } from "../../mocks/MockSwapFacility.sol";
import { MockOrderBook } from "../../mocks/MockOrderBook.sol";
import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";

abstract contract SpokePortalUnitTestBase is Test {
    using TypeConverter for *;

    uint32 internal constant HUB_CHAIN_ID = 1;
    uint32 internal constant SPOKE_CHAIN_ID = 2;

    uint256 internal constant FILL_REPORT_GAS_LIMIT = 150_000;
    uint256 internal constant TOKEN_TRANSFER_GAS_LIMIT = 250_000;

    /// @dev Registrar key of earners list.
    bytes32 internal constant EARNERS_LIST = "earners";

    /// @dev Registrar key holding value of whether the earners list can be ignored or not.
    bytes32 internal constant EARNERS_LIST_IGNORED = "earners_list_ignored";

    SpokePortal internal implementation;
    SpokePortal internal spokePortal;
    MockSpokeMToken internal mToken;
    MockWrappedMToken internal wrappedMToken;
    MockSpokeRegistrar internal registrar;
    MockSwapFacility internal swapFacility;
    MockOrderBook internal mockOrderBook;
    MockBridgeAdapter internal bridgeAdapter;

    bytes32 internal hubMToken = makeAddr("hubMToken").toBytes32();
    bytes32 internal hubWrappedMToken = makeAddr("hubWrappedMToken").toBytes32();
    bytes32 internal hubBridgeAdapter = makeAddr("hubBridgeAdapter").toBytes32();

    address internal admin = makeAddr("admin");
    address internal operator = makeAddr("operator");
    address internal pauser = makeAddr("pauser");
    address internal user = makeAddr("user");

    function setUp() public virtual {
        // Set block.chainid to SPOKE_CHAIN_ID
        vm.chainId(SPOKE_CHAIN_ID);

        mToken = new MockSpokeMToken();
        wrappedMToken = new MockWrappedMToken(address(mToken));

        registrar = new MockSpokeRegistrar();
        swapFacility = new MockSwapFacility(address(mToken));
        mockOrderBook = new MockOrderBook();
        bridgeAdapter = new MockBridgeAdapter();

        // Deploy implementation
        implementation = new SpokePortal(address(mToken), address(registrar), address(swapFacility), address(mockOrderBook));

        // Deploy UUPS proxy
        bytes memory initializeData = abi.encodeCall(SpokePortal.initialize, (admin, pauser, operator));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        spokePortal = SpokePortal(address(proxy));

        vm.startPrank(operator);

        // Configure
        spokePortal.setDefaultBridgeAdapter(HUB_CHAIN_ID, address(bridgeAdapter));

        spokePortal.setSupportedBridgingPath(address(mToken), HUB_CHAIN_ID, hubMToken, true);
        spokePortal.setSupportedBridgingPath(address(mToken), HUB_CHAIN_ID, hubWrappedMToken, true);
        spokePortal.setSupportedBridgingPath(address(wrappedMToken), HUB_CHAIN_ID, hubMToken, true);
        spokePortal.setSupportedBridgingPath(address(wrappedMToken), HUB_CHAIN_ID, hubWrappedMToken, true);

        spokePortal.setPayloadGasLimit(HUB_CHAIN_ID, PayloadType.TokenTransfer, TOKEN_TRANSFER_GAS_LIMIT);
        spokePortal.setPayloadGasLimit(HUB_CHAIN_ID, PayloadType.FillReport, FILL_REPORT_GAS_LIMIT);

        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(pauser, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(mockOrderBook), 1 ether);

        // Mock fetching peer bridge adapter
        vm.mockCall(address(bridgeAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (HUB_CHAIN_ID)), abi.encode(hubBridgeAdapter));
    }

    function _getMessageId() internal returns (bytes32) {
        uint256 nonce = spokePortal.getNonce();
        return keccak256(abi.encode(SPOKE_CHAIN_ID, HUB_CHAIN_ID, nonce++));
    }
}
