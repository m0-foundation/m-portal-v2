// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

import { Test } from "../../../lib/forge-std/src/Test.sol";
import {
    ERC1967Proxy
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { HubPortal } from "../../../src/HubPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";

import { MockMToken } from "../../mocks/MockMToken.sol";
import { MockWrappedMToken } from "../../mocks/MockWrappedMToken.sol";
import { MockHubRegistrar } from "../../mocks/MockHubRegistrar.sol";
import { MockSwapFacility } from "../../mocks/MockSwapFacility.sol";
import { MockOrderBook } from "../../mocks/MockOrderBook.sol";
import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { MockMerkleTreeBuilder } from "../../mocks/MockMerkleTreeBuilder.sol";

abstract contract HubPortalUnitTestBase is Test {
    using TypeConverter for *;

    uint32 internal constant HUB_CHAIN_ID = 1;
    uint32 internal constant SPOKE_CHAIN_ID = 2;
    uint32 internal constant SPOKE_CHAIN_ID_2 = 3;

    uint256 internal constant INDEX_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant KEY_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant LIST_UPDATE_GAS_LIMIT = 100_000;
    uint256 internal constant FILL_REPORT_GAS_LIMIT = 150_000;
    uint256 internal constant CANCEL_REPORT_GAS_LIMIT = 150_000;
    uint256 internal constant TOKEN_TRANSFER_GAS_LIMIT = 250_000;
    uint256 internal constant EARNER_MERKLE_ROOT_GAS_LIMIT = 100_000;

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
    MockMerkleTreeBuilder internal merkleTreeBuilder;

    bytes32 internal spokeMToken = makeAddr("spokeMToken").toBytes32();
    bytes32 internal spokeWrappedMToken = makeAddr("spokeWrappedMToken").toBytes32();
    bytes32 internal spokeBridgeAdapter = makeAddr("spokeBridgeAdapter").toBytes32();

    bytes32 internal spoke2MToken = makeAddr("spoke2MToken").toBytes32();
    bytes32 internal spoke2WrappedMToken = makeAddr("spoke2WrappedMToken").toBytes32();
    bytes32 internal spoke2BridgeAdapter = makeAddr("spoke2BridgeAdapter").toBytes32();

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
        merkleTreeBuilder = new MockMerkleTreeBuilder();

        // Deploy implementation
        implementation =
            new HubPortal(address(mToken), address(registrar), address(swapFacility), address(mockOrderBook), address(merkleTreeBuilder));

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
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.CancelReport, CANCEL_REPORT_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID, PayloadType.EarnerMerkleRoot, EARNER_MERKLE_ROOT_GAS_LIMIT);

        // Configure second spoke
        hubPortal.setDefaultBridgeAdapter(SPOKE_CHAIN_ID_2, address(bridgeAdapter));

        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID_2, spoke2MToken, true);
        hubPortal.setSupportedBridgingPath(address(mToken), SPOKE_CHAIN_ID_2, spoke2WrappedMToken, true);
        hubPortal.setSupportedBridgingPath(address(wrappedMToken), SPOKE_CHAIN_ID_2, spoke2MToken, true);
        hubPortal.setSupportedBridgingPath(address(wrappedMToken), SPOKE_CHAIN_ID_2, spoke2WrappedMToken, true);

        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.TokenTransfer, TOKEN_TRANSFER_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.Index, INDEX_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.RegistrarKey, KEY_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.RegistrarList, LIST_UPDATE_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.FillReport, FILL_REPORT_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.CancelReport, CANCEL_REPORT_GAS_LIMIT);
        hubPortal.setPayloadGasLimit(SPOKE_CHAIN_ID_2, PayloadType.EarnerMerkleRoot, EARNER_MERKLE_ROOT_GAS_LIMIT);

        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(pauser, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(mockOrderBook), 1 ether);

        // Mock fetching peer bridge adapter
        vm.mockCall(address(bridgeAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));
        vm.mockCall(address(bridgeAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID_2)), abi.encode(spoke2BridgeAdapter));
    }

    function _getMessageId() internal returns (bytes32) {
        uint256 nonce = hubPortal.getNonce();
        return keccak256(abi.encode(HUB_CHAIN_ID, SPOKE_CHAIN_ID, nonce++));
    }

    function _enableEarningWithIndex(uint128 _index) internal {
        mToken.setCurrentIndex(_index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();
    }
}
