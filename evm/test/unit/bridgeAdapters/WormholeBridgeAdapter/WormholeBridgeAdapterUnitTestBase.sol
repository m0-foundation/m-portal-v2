// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "../../../../lib/forge-std/src/Test.sol";
import { ERC1967Proxy } from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { WormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/WormholeBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { MockPortal } from "../../../mocks/MockPortal.sol";
import { MockWormholeCoreBridge } from "../../../mocks/MockWormholeCoreBridge.sol";
import { MockWormholeExecutor } from "../../../mocks/MockWormholeExecutor.sol";

abstract contract WormholeBridgeAdapterUnitTestBase is Test {
    using TypeConverter for *;

    uint32 internal constant HUB_CHAIN_ID = 1;
    uint32 internal constant SPOKE_CHAIN_ID = 2;
    uint16 internal constant HUB_WORMHOLE_CHAIN_ID = 1000;
    uint16 internal constant SPOKE_WORMHOLE_CHAIN_ID = 2000;
    uint8 internal constant CONSISTENCY_LEVEL = 15;

    WormholeBridgeAdapter internal implementation;
    WormholeBridgeAdapter internal adapter;
    MockWormholeCoreBridge internal coreBridge;
    MockWormholeExecutor internal executor;
    MockPortal internal portal;

    bytes32 internal peerAdapterAddress = makeAddr("spokeAdapter").toBytes32();

    address internal admin = makeAddr("admin");
    address internal operator = makeAddr("operator");
    address internal user = makeAddr("user");

    function setUp() public virtual {
        // Set block.chainid to HUB_CHAIN_ID
        vm.chainId(HUB_CHAIN_ID);

        portal = new MockPortal(address(0));
        coreBridge = new MockWormholeCoreBridge();
        executor = new MockWormholeExecutor();

        // Deploy implementation
        implementation = new WormholeBridgeAdapter(
            address(coreBridge),
            address(executor),
            CONSISTENCY_LEVEL,
            HUB_WORMHOLE_CHAIN_ID,
            address(portal)
        );

        // Deploy UUPS proxy
        bytes memory initializeData = abi.encodeCall(WormholeBridgeAdapter.initialize, (admin, operator));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        adapter = WormholeBridgeAdapter(address(proxy));

        vm.startPrank(operator);
        // Configure peer and chain ID mapping
        adapter.setPeer(SPOKE_CHAIN_ID, peerAdapterAddress);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_WORMHOLE_CHAIN_ID);
        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(portal), 1 ether);
        vm.deal(address(coreBridge), 1 ether);
        vm.deal(address(executor), 1 ether);
    }
}