// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

import { IBridgeAdapter } from "../../../src/interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../../src/libraries/PayloadEncoder.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockBridgeAdapter } from "../../mocks/MockBridgeAdapter.sol";
import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract SendTokenWithPermitUnitTest is HubPortalUnitTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = makeAddr("refundAddress").toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = makeAddr("recipient").toBytes32();
    uint256 internal amount = 10e6;
    uint256 internal deadline;

    address internal signer;
    uint256 internal signerKey;

    function setUp() public override {
        super.setUp();

        (signer, signerKey) = makeAddrAndKey("signer");
        vm.deal(signer, 1 ether);
        deadline = block.timestamp + 1 hours;

        // Mint tokens to signer for testing
        mToken.mint(signer, 100e6);
        wrappedMToken.mint(signer, 100e6);

        // Fund wrappedMToken with M tokens for unwrapping
        mToken.mint(address(wrappedMToken), 100e6);
    }

    /* ============ Helpers ============ */

    function _signPermit(MockERC20 token, uint256 value) internal view returns (bytes memory signature) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(token.PERMIT_TYPEHASH(), signer, address(hubPortal), value, token.nonces(signer), deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    /* ============ Default bridge adapter ============ */

    function test_sendTokenWithPermit_withMToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, amount, spokeMToken, signer, recipient
        );
        address defaultBridgeAdapter = hubPortal.defaultBridgeAdapter(SPOKE_CHAIN_ID);

        _enableEarningWithIndex(index);

        bytes memory signature = _signPermit(mToken, amount);

        // NOTE: No prior approval — the allowance is granted via permit
        assertEq(mToken.allowance(signer, address(hubPortal)), 0);

        vm.expectCall(
            address(mToken),
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,bytes)", signer, address(hubPortal), amount, deadline, signature
            )
        );
        vm.expectCall(
            defaultBridgeAdapter,
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(mToken), SPOKE_CHAIN_ID, spokeMToken, signer, recipient, amount, index, defaultBridgeAdapter, messageId
        );

        vm.prank(signer);
        hubPortal.sendTokenWithPermit{ value: fee }(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs, deadline, signature
        );

        assertEq(mToken.balanceOf(address(hubPortal)), amount);
        assertEq(mToken.nonces(signer), 1);
        assertEq(mToken.allowance(signer, address(hubPortal)), 0);
    }

    function test_sendTokenWithPermit_withWrappedMToken() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        bytes memory signature = _signPermit(wrappedMToken, amount);

        uint256 signerWrappedMBalanceBefore = wrappedMToken.balanceOf(signer);
        uint256 portalMBalanceBefore = mToken.balanceOf(address(hubPortal));

        vm.prank(signer);
        hubPortal.sendTokenWithPermit{ value: fee }(
            amount,
            address(wrappedMToken),
            SPOKE_CHAIN_ID,
            spokeWrappedMToken,
            recipient,
            refundAddress,
            bridgeAdapterArgs,
            deadline,
            signature
        );

        // Wrapped $M is unwrapped, Portal receives $M
        assertEq(wrappedMToken.balanceOf(signer), signerWrappedMBalanceBefore - amount);
        assertEq(mToken.balanceOf(address(hubPortal)), portalMBalanceBefore + amount);
    }

    function test_sendTokenWithPermit_succeedsIfPermitFrontRun() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        bytes memory signature = _signPermit(mToken, amount);

        // Front-run the permit: the signature is consumed before `sendTokenWithPermit` is called
        mToken.permit(signer, address(hubPortal), amount, deadline, signature);
        assertEq(mToken.allowance(signer, address(hubPortal)), amount);

        // The consumed permit reverts inside `sendTokenWithPermit`, the error is ignored
        // and the transfer succeeds using the allowance set by the front-run permit
        vm.prank(signer);
        hubPortal.sendTokenWithPermit{ value: fee }(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs, deadline, signature
        );

        assertEq(mToken.balanceOf(address(hubPortal)), amount);
    }

    function test_sendTokenWithPermit_revertsIfInvalidSignatureAndNoAllowance() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;

        _enableEarningWithIndex(index);

        // Sign a permit for a different amount, making the signature invalid
        bytes memory signature = _signPermit(mToken, amount - 1);

        // The invalid permit is ignored and the transfer fails due to insufficient allowance
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(signer);
        hubPortal.sendTokenWithPermit{ value: fee }(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs, deadline, signature
        );
    }

    function test_sendTokenWithPermit_revertsIfPaused() external {
        bytes memory signature = _signPermit(mToken, amount);

        vm.prank(pauser);
        hubPortal.pauseSend();

        vm.expectRevert(IPortal.SendingPaused.selector);
        vm.prank(signer);
        hubPortal.sendTokenWithPermit(
            amount, address(mToken), SPOKE_CHAIN_ID, spokeMToken, recipient, refundAddress, bridgeAdapterArgs, deadline, signature
        );
    }

    /* ============ Specified bridge adapter ============ */

    function test_sendTokenWithPermit_withSpecificAdapter() external {
        uint256 fee = 1;
        uint128 index = 1_100_000_068_703;
        bytes32 messageId = _getMessageId();
        bytes memory payload = PayloadEncoder.encodeTokenTransfer(
            SPOKE_CHAIN_ID, spokeBridgeAdapter, messageId, index, amount, spokeMToken, signer, recipient
        );

        // Deploy a new mock adapter
        MockBridgeAdapter customAdapter = new MockBridgeAdapter();
        customAdapter.setPortal(address(hubPortal));

        // Mock fetching peer bridge adapter
        vm.mockCall(address(customAdapter), abi.encodeCall(MockBridgeAdapter.getPeer, (SPOKE_CHAIN_ID)), abi.encode(spokeBridgeAdapter));

        _enableEarningWithIndex(index);

        vm.prank(operator);
        hubPortal.setSupportedBridgeAdapter(SPOKE_CHAIN_ID, address(customAdapter), true);

        bytes memory signature = _signPermit(mToken, amount);

        vm.expectCall(
            address(mToken),
            abi.encodeWithSignature(
                "permit(address,address,uint256,uint256,bytes)", signer, address(hubPortal), amount, deadline, signature
            )
        );
        vm.expectCall(
            address(customAdapter),
            abi.encodeCall(
                IBridgeAdapter.sendMessage, (SPOKE_CHAIN_ID, TOKEN_TRANSFER_GAS_LIMIT, refundAddress, payload, bridgeAdapterArgs)
            )
        );
        vm.expectEmit();
        emit IPortal.TokenSent(
            address(mToken), SPOKE_CHAIN_ID, spokeMToken, signer, recipient, amount, index, address(customAdapter), messageId
        );

        vm.prank(signer);
        hubPortal.sendTokenWithPermit{ value: fee }(
            amount,
            address(mToken),
            SPOKE_CHAIN_ID,
            spokeMToken,
            recipient,
            refundAddress,
            address(customAdapter),
            bridgeAdapterArgs,
            deadline,
            signature
        );

        assertEq(mToken.balanceOf(address(hubPortal)), amount);
        assertEq(mToken.nonces(signer), 1);
    }
}
