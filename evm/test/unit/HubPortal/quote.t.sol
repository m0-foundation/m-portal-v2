// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BridgeAdapterStatus, IPortal } from "../../../src/interfaces/IPortal.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract QuoteUnitTest is HubPortalUnitTestBase {
    function test_quote_withDefaultAdapter() external {
        uint256 expectedFee = 0.001 ether;
        bridgeAdapter.setQuote(expectedFee);

        uint256 fee = hubPortal.quote(SPOKE_CHAIN_ID, PayloadType.TokenTransfer);

        assertEq(fee, expectedFee);
    }

    function test_quote_withSpecificAdapter() external {
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        uint256 expectedFee = 0.002 ether;
        customAdapter.setQuote(expectedFee);

        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(SPOKE_CHAIN_ID, address(customAdapter), BridgeAdapterStatus.Enabled);

        uint256 fee = hubPortal.quote(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, address(customAdapter));

        assertEq(fee, expectedFee);
    }

    function testFuzz_quote(uint256 expectedFee, uint8 payloadType) external {
        vm.assume(expectedFee < 1 ether);
        vm.assume(payloadType <= uint8(type(PayloadType).max));
        bridgeAdapter.setQuote(expectedFee);

        // Test all payload types
        assertEq(hubPortal.quote(SPOKE_CHAIN_ID, PayloadType(payloadType)), expectedFee);
    }

    function test_quote_revertsIfNoBridgeAdapterSet() external {
        uint32 unconfiguredChain = 999;

        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, unconfiguredChain, address(0)));
        hubPortal.quote(unconfiguredChain, PayloadType.TokenTransfer);
    }

    function test_quote_revertsIfUnsupportedBridgeAdapter() external {
        address unsupportedAdapter = makeAddr("unsupported");

        vm.expectRevert(abi.encodeWithSelector(IPortal.BridgeAdapterSendDisabled.selector, SPOKE_CHAIN_ID, unsupportedAdapter));
        hubPortal.quote(SPOKE_CHAIN_ID, PayloadType.TokenTransfer, unsupportedAdapter);
    }

    function test_quote_revertsIfPayloadGasLimitNotSet() external {
        uint32 newChainId = 999;

        // Set up bridge adapter but NOT the gas limit
        vm.prank(operator);
        hubPortal.setDefaultBridgeAdapter(newChainId, address(bridgeAdapter));

        vm.expectRevert(abi.encodeWithSelector(IPortal.PayloadGasLimitNotSet.selector, newChainId, PayloadType.TokenTransfer));
        hubPortal.quote(newChainId, PayloadType.TokenTransfer);
    }

    function test_quote_withSpecificAdapter_revertsIfPayloadGasLimitNotSet() external {
        uint32 newChainId = 999;

        // Set up bridge adapter but NOT the gas limit
        vm.prank(operator);
        hubPortal.setBridgeAdapterStatus(newChainId, address(bridgeAdapter), BridgeAdapterStatus.Enabled);

        vm.expectRevert(abi.encodeWithSelector(IPortal.PayloadGasLimitNotSet.selector, newChainId, PayloadType.TokenTransfer));
        hubPortal.quote(newChainId, PayloadType.TokenTransfer, address(bridgeAdapter));
    }
}
