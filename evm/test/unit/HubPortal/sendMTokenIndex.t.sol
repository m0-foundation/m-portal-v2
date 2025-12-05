// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { PausableUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IHubPortal } from "../../../src/interfaces/IHubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { HubPortal } from "../../../src/HubPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendMTokenIndexUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";

    function test_sendMTokenIndex_withDefaultAdapter() external {
        uint128 index = 1_100000068703;
        uint256 fee = 1;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeIndex(index, messageId);
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        mToken.setCurrentIndex(index);
        registrar.setListContains(EARNERS_LIST, address(hubPortal), true);
        hubPortal.enableEarning();

        vm.expectCall(
            defaultBridgeAdapter, abi.encodeCall(IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, INDEX_UPDATE_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs))
        );
        vm.expectEmit();
        emit IHubPortal.MTokenIndexSent(SPOKE_CHAIN_ID, index, defaultBridgeAdapter, messageId);

        vm.prank(user);
        hubPortal.sendMTokenIndex{ value: fee }(SPOKE_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfPaused() external {
        vm.prank(pauser);
        hubPortal.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        hubPortal.sendMTokenIndex(SPOKE_CHAIN_ID, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfZeroRefundAddress() external {
        vm.expectRevert(IPortal.ZeroRefundAddress.selector);
        hubPortal.sendMTokenIndex(SPOKE_CHAIN_ID, bytes32(0), bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 3;

        vm.expectRevert(abi.encodeWithSelector(IPortal.UnsupportedDestinationChain.selector, unconfiguredChain));
        hubPortal.sendMTokenIndex(unconfiguredChain, refundAddress, bridgeAdapterArgs);
    }

    function test_sendMTokenIndex_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(
            abi.encodeWithSelector(
                IPortal.UnsupportedBridgeAdapter.selector,
                SPOKE_CHAIN_ID,
                unsupportedAdapter
            )
        );

        hubPortal.sendMTokenIndex(
            SPOKE_CHAIN_ID,
            refundAddress,
            unsupportedAdapter,
            bridgeAdapterArgs
        );
    }
}
