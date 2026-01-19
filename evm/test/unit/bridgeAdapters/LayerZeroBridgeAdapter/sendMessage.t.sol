// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for sendMessage
 *
 * Branch coverage TODOs:
 * - [x] when caller is not portal
 *     - [x] reverts with NotPortal
 * - [x] when peer is not configured
 *     - [x] reverts with UnsupportedChain
 * - [x] when bridge chain ID is not configured
 *     - [x] reverts with UnsupportedChain
 * - [x] when all parameters are valid
 *     - [x] succeeds
 *     - [x] calls endpoint send with correct destination EID
 *     - [x] calls endpoint send with correct payload
 *     - [x] calls endpoint send with correct options
 *     - [x] passes msg.value to endpoint
 *     - [x] uses refundAddress for excess fee refund
 */

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { OptionsBuilder } from "../../../../src/bridgeAdapters/layerzero/libraries/OptionsBuilder.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract SendMessageUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    using OptionsBuilder for bytes;
    using TypeConverter for *;

    /// @notice Sample payload for testing.
    bytes internal samplePayload = abi.encode("test message");

    /// @notice Sample gas limit for testing.
    uint256 internal sampleGasLimit = 200_000;

    /// @notice Sample refund address for testing.
    bytes32 internal sampleRefundAddress;

    /// @notice Fee to send with message.
    uint256 internal messageFee = 0.01 ether;

    function setUp() public override {
        super.setUp();

        // Configure refund address
        sampleRefundAddress = user.toBytes32();

        // Configure the mock endpoint to return a specific fee
        lzEndpoint.setQuoteFee(messageFee);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      REVERT CASES - NOT PORTAL
    // ═══════════════════════════════════════════════════════════════════════

    function test_sendMessage_revertsIfCallerIsNotPortal() external {
        vm.prank(user);
        vm.expectRevert(IBridgeAdapter.NotPortal.selector);
        adapter.sendMessage(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");
    }

    function test_sendMessage_revertsIfCallerIsAdmin() external {
        vm.prank(admin);
        vm.expectRevert(IBridgeAdapter.NotPortal.selector);
        adapter.sendMessage(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");
    }

    function test_sendMessage_revertsIfCallerIsOperator() external {
        vm.prank(operator);
        vm.expectRevert(IBridgeAdapter.NotPortal.selector);
        adapter.sendMessage(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      REVERT CASES - NO PEER
    // ═══════════════════════════════════════════════════════════════════════

    function test_sendMessage_revertsIfPeerNotConfigured() external {
        // Use an unconfigured chain ID (no peer set)
        uint32 unconfiguredChainId = 999;

        vm.prank(address(portal));
        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, unconfiguredChainId));
        adapter.sendMessage{ value: messageFee }(unconfiguredChainId, sampleGasLimit, sampleRefundAddress, samplePayload, "");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                   REVERT CASES - NO BRIDGE CHAIN ID
    // ═══════════════════════════════════════════════════════════════════════

    function test_sendMessage_revertsIfBridgeChainIdNotConfigured() external {
        // Set peer but not bridge chain ID for a new chain
        uint32 chainIdWithPeerOnly = 10;
        bytes32 peerAddress = makeAddr("peer").toBytes32();

        vm.prank(operator);
        adapter.setPeer(chainIdWithPeerOnly, peerAddress);

        // Should revert because bridge chain ID is not configured
        vm.prank(address(portal));
        vm.expectRevert(abi.encodeWithSelector(IBridgeAdapter.UnsupportedChain.selector, chainIdWithPeerOnly));
        adapter.sendMessage{ value: messageFee }(chainIdWithPeerOnly, sampleGasLimit, sampleRefundAddress, samplePayload, "");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_sendMessage_succeeds() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Verify message was sent
        assertEq(lzEndpoint.sentMessageCount(), 1, "Should have sent one message");
    }

    function test_sendMessage_callsEndpointWithCorrectDestinationEid() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Check the destination EID in the sent message
        (uint32 dstEid,,,,,) = lzEndpoint.lastSentMessage();
        assertEq(dstEid, SPOKE_LZ_EID, "Destination EID should match configured LayerZero EID");
    }

    function test_sendMessage_callsEndpointWithCorrectPayload() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Check the payload in the sent message
        (,, bytes memory message,,,) = lzEndpoint.lastSentMessage();
        assertEq(message, samplePayload, "Payload should match input payload");
    }

    function test_sendMessage_callsEndpointWithCorrectOptions() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Build the expected options the same way as the adapter does internally
        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(sampleGasLimit), 0);

        // Check the options in the sent message
        (,,, bytes memory options,,) = lzEndpoint.lastSentMessage();
        assertEq(options, expectedOptions, "Options should match expected encoding");
    }

    function test_sendMessage_passesMsgValueToEndpoint() external {
        uint256 sentValue = 0.05 ether;

        vm.prank(address(portal));
        adapter.sendMessage{ value: sentValue }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Check the native fee in the sent message
        (,,,, uint256 nativeFee,) = lzEndpoint.lastSentMessage();
        assertEq(nativeFee, sentValue, "Native fee should match msg.value");
    }

    function test_sendMessage_usesRefundAddressForExcessFeeRefund() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        // Check the refund address in the sent message
        (,,,,, address refundAddr) = lzEndpoint.lastSentMessage();
        assertEq(refundAddr, sampleRefundAddress.toAddress(), "Refund address should match converted bytes32");
    }

    function test_sendMessage_withDifferentRefundAddress() external {
        bytes32 differentRefundAddress = admin.toBytes32();

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, differentRefundAddress, samplePayload, "");

        // Check the refund address in the sent message
        (,,,,, address refundAddr) = lzEndpoint.lastSentMessage();
        assertEq(refundAddr, admin, "Refund address should be admin");
    }

    function test_sendMessage_extraArgumentsAreIgnored() external {
        bytes memory extraArgs = abi.encode("some extra data", 123);

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, extraArgs);

        // Should succeed and send message normally
        assertEq(lzEndpoint.sentMessageCount(), 1, "Should have sent one message");

        // Check the payload is unchanged (extraArgs are ignored)
        (,, bytes memory message,,,) = lzEndpoint.lastSentMessage();
        assertEq(message, samplePayload, "Payload should not include extra arguments");
    }

    function test_sendMessage_withZeroGasLimit() external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, 0, sampleRefundAddress, samplePayload, "");

        // Build expected options with zero gas
        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(0, 0);

        (,,, bytes memory options,,) = lzEndpoint.lastSentMessage();
        assertEq(options, expectedOptions, "Options should encode zero gas limit");
    }

    function test_sendMessage_withMaxGasLimit() external {
        uint256 maxGasLimit = type(uint128).max;

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, maxGasLimit, sampleRefundAddress, samplePayload, "");

        // Build expected options with max gas
        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(uint128(maxGasLimit), 0);

        (,,, bytes memory options,,) = lzEndpoint.lastSentMessage();
        assertEq(options, expectedOptions, "Options should encode max gas limit");
    }

    function test_sendMessage_withEmptyPayload() external {
        bytes memory emptyPayload = "";

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, emptyPayload, "");

        (,, bytes memory message,,,) = lzEndpoint.lastSentMessage();
        assertEq(message.length, 0, "Payload should be empty");
    }

    function test_sendMessage_withLargePayload() external {
        // Create a large payload (1KB)
        bytes memory largePayload = new bytes(1024);
        for (uint256 i = 0; i < 1024; i++) {
            largePayload[i] = bytes1(uint8(i % 256));
        }

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, largePayload, "");

        (,, bytes memory message,,,) = lzEndpoint.lastSentMessage();
        assertEq(message, largePayload, "Large payload should be sent correctly");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_sendMessage_withVariableGasLimit(uint128 gasLimit) external {
        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, gasLimit, sampleRefundAddress, samplePayload, "");

        // Build expected options with fuzzed gas limit
        bytes memory expectedOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit, 0);

        (,,, bytes memory options,,) = lzEndpoint.lastSentMessage();
        assertEq(options, expectedOptions, "Options should encode fuzzed gas limit correctly");
    }

    function testFuzz_sendMessage_withVariableValue(uint96 value) external {
        vm.deal(address(portal), uint256(value) + 1 ether);

        vm.prank(address(portal));
        adapter.sendMessage{ value: value }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, samplePayload, "");

        (,,,, uint256 nativeFee,) = lzEndpoint.lastSentMessage();
        assertEq(nativeFee, value, "Native fee should match fuzzed value");
    }

    function testFuzz_sendMessage_withVariablePayloadLength(uint8 payloadLength) external {
        bytes memory payload = new bytes(payloadLength);
        for (uint256 i = 0; i < payloadLength; i++) {
            payload[i] = bytes1(uint8(i % 256));
        }

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, sampleRefundAddress, payload, "");

        (,, bytes memory message,,,) = lzEndpoint.lastSentMessage();
        assertEq(message, payload, "Payload should match fuzzed payload");
    }

    function testFuzz_sendMessage_withVariableRefundAddress(address refundAddr) external {
        vm.assume(refundAddr != address(0));
        bytes32 refundAddrBytes32 = refundAddr.toBytes32();

        vm.prank(address(portal));
        adapter.sendMessage{ value: messageFee }(SPOKE_CHAIN_ID, sampleGasLimit, refundAddrBytes32, samplePayload, "");

        (,,,,, address actualRefundAddr) = lzEndpoint.lastSentMessage();
        assertEq(actualRefundAddr, refundAddr, "Refund address should match fuzzed address");
    }
}
