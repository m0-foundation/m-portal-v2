// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.33;

import { Test } from "../../../../lib/forge-std/src/Test.sol";
import {
    ERC1967Proxy
} from "../../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { HyperlaneBridgeAdapter } from "../../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { MockHyperlaneMailbox } from "../../../mocks/MockHyperlaneMailbox.sol";
import { MockPortal } from "../../../mocks/MockPortal.sol";

abstract contract HyperlaneBridgeAdapterUnitTestBase is Test {
    using TypeConverter for *;

    uint32 internal constant HUB_CHAIN_ID = 1;
    uint32 internal constant SPOKE_CHAIN_ID = 2;
    uint32 internal constant SPOKE_HYPERLANE_DOMAIN = 2000;

    HyperlaneBridgeAdapter internal implementation;
    HyperlaneBridgeAdapter internal adapter;
    MockHyperlaneMailbox internal mailbox;
    MockPortal internal portal;

    bytes32 internal peerAdapterAddress = makeAddr("spokeAdapter").toBytes32();

    address internal admin = makeAddr("admin");
    address internal operator = makeAddr("operator");
    address internal user = makeAddr("user");

    function setUp() public virtual {
        // Set block.chainid to HUB_CHAIN_ID
        vm.chainId(HUB_CHAIN_ID);

        portal = new MockPortal(address(0));
        mailbox = new MockHyperlaneMailbox();

        // Deploy implementation
        implementation = new HyperlaneBridgeAdapter(address(mailbox), address(portal));

        // Deploy UUPS proxy
        bytes memory initializeData = abi.encodeCall(HyperlaneBridgeAdapter.initialize, (admin, operator));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initializeData);
        adapter = HyperlaneBridgeAdapter(address(proxy));

        vm.startPrank(operator);
        // Configure peer and chain ID mapping
        adapter.setPeer(SPOKE_CHAIN_ID, peerAdapterAddress);
        adapter.setBridgeChainId(SPOKE_CHAIN_ID, SPOKE_HYPERLANE_DOMAIN);
        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 1 ether);
        vm.deal(operator, 1 ether);
        vm.deal(user, 1 ether);
        vm.deal(address(portal), 1 ether);
        vm.deal(address(mailbox), 1 ether);
    }
}
