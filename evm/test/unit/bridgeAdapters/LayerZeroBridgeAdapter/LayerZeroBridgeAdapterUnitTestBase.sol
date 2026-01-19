// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "../../../../lib/forge-std/src/Test.sol";
import {
    ERC1967Proxy
} from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { LayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/LayerZeroBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { MockLayerZeroEndpoint } from "../../../mocks/MockLayerZeroEndpoint.sol";
import { MockPortal } from "../../../mocks/MockPortal.sol";

/// @title  LayerZeroBridgeAdapterUnitTestBase
/// @notice Base test contract for LayerZero Bridge Adapter unit tests.
/// @dev    Sets up a complete testing environment with mock contracts, proxy deployment, and configured peers.
abstract contract LayerZeroBridgeAdapterUnitTestBase is Test {
    using TypeConverter for *;

    /// @notice M0 Internal chain ID for hub (Ethereum).
    uint32 internal constant HUB_CHAIN_ID = 1;

    /// @notice M0 Internal chain ID for spoke (Arbitrum).
    uint32 internal constant SPOKE_CHAIN_ID = 42_161;

    /// @notice LayerZero EID for spoke (Arbitrum).
    uint32 internal constant SPOKE_LZ_EID = 30_110;

    /// @notice LayerZero EID for hub (Ethereum).
    uint32 internal constant HUB_LZ_EID = 30_101;

    /// @notice The LayerZero Bridge Adapter implementation.
    LayerZeroBridgeAdapter internal implementation;

    /// @notice The LayerZero Bridge Adapter proxy.
    LayerZeroBridgeAdapter internal adapter;

    /// @notice The mock LayerZero Endpoint.
    MockLayerZeroEndpoint internal lzEndpoint;

    /// @notice The mock Portal contract.
    MockPortal internal portal;

    /// @notice The peer adapter address on the spoke chain.
    bytes32 internal peerAdapterAddress = makeAddr("spokeAdapter").toBytes32();

    /// @notice Admin address with DEFAULT_ADMIN_ROLE.
    address internal admin = makeAddr("admin");

    /// @notice Operator address with OPERATOR_ROLE.
    address internal operator = makeAddr("operator");

    /// @notice Regular user address without any roles.
    address internal user = makeAddr("user");

    function setUp() public virtual {
        // Set block.chainid to HUB_CHAIN_ID
        vm.chainId(HUB_CHAIN_ID);

        // Deploy mock contracts
        portal = new MockPortal(address(0));
        lzEndpoint = new MockLayerZeroEndpoint();

        // Deploy implementation
        implementation = new LayerZeroBridgeAdapter(address(lzEndpoint), address(portal));

        // Deploy UUPS proxy with initialization
        bytes memory initializeData = abi.encodeCall(LayerZeroBridgeAdapter.initialize, (admin, operator));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        adapter = LayerZeroBridgeAdapter(address(proxy));

        // Configure peer and chain ID mapping
        vm.startPrank(operator);
        adapter.setPeer(SPOKE_CHAIN_ID, peerAdapterAddress);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_LZ_EID);
        vm.stopPrank();

        // Fund all accounts with 1 ether
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(portal), 1 ether);
        vm.deal(address(lzEndpoint), 1 ether);
    }
}
