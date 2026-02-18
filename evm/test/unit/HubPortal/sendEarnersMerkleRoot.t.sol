// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { PausableUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";
import { IMerkleTreeBuilderLike } from "../../../src/interfaces/IMerkleTreeBuilderLike.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendEarnersMerkleRootUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";

    function test_sendEarnersMerkleRoot_withDefaultAdapter() external {
        uint128 index = 1_100_000_068_703;
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes32 earnerMerkleRoot = bytes32(uint256(0x123456));
        bytes memory payload = PayloadEncoder.encodeEarnerMerkleRoot(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, earnerMerkleRoot);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        // Mock the merkle tree builder to return the expected root
        vm.mockCall(
            address(merkleTreeBuilder),
            abi.encodeCall(IMerkleTreeBuilderLike.getRoot, (hubPortal.SVM_EARNER_LIST())),
            abi.encode(earnerMerkleRoot)
        );

        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, EARNER_MERKLE_ROOT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IHubPortal.EarnerMerkleRootSent(SPOKE_CHAIN_ID, index, earnerMerkleRoot, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendEarnersMerkleRoot{ value: fee }(SPOKE_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }

    function test_sendEarnersMerkleRoot_withSpecificAdapter() external {
        uint128 index = 1_100_000_068_703;
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes32 earnerMerkleRoot = bytes32(uint256(0x789abc));
        bytes memory payload = PayloadEncoder.encodeEarnerMerkleRoot(SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, earnerMerkleRoot);

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        // Mock the merkle tree builder to return the expected root
        vm.mockCall(
            address(merkleTreeBuilder),
            abi.encodeCall(IMerkleTreeBuilderLike.getRoot, (hubPortal.SVM_EARNER_LIST())),
            abi.encode(earnerMerkleRoot)
        );

        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, EARNER_MERKLE_ROOT_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IHubPortal.EarnerMerkleRootSent(SPOKE_CHAIN_ID, index, earnerMerkleRoot, address(customAdapter), messageId);

        vm.prank(user);
        hubPortal.sendEarnersMerkleRoot{ value: fee }(SPOKE_CHAIN_ID, refundAddress, address(customAdapter), bridgeAdapterArgs);
    }

    function test_sendEarnersMerkleRoot_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        hubPortal.sendEarnersMerkleRoot(SPOKE_CHAIN_ID, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendEarnersMerkleRoot_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, unconfiguredChain, address(0)));
        hubPortal.sendEarnersMerkleRoot(unconfiguredChain, refundAddress, bridgeAdapterArgs);
    }

    function test_sendEarnersMerkleRoot_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, SPOKE_CHAIN_ID, unsupportedAdapter));
        hubPortal.sendEarnersMerkleRoot(SPOKE_CHAIN_ID, refundAddress, unsupportedAdapter, bridgeAdapterArgs);
    }

    function test_sendEarnersMerkleRoot_revertsIfSendToSelf() external {
        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedBridgeAdapter.selector, HUB_CHAIN_ID, address(0)));
        hubPortal.sendEarnersMerkleRoot(HUB_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }
}
