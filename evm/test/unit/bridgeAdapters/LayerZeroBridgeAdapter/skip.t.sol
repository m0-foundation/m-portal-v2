// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for skip
 *
 * Branch coverage TODOs:
 * - [x] when caller does not have DEFAULT_ADMIN_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 * - [x] when caller has DEFAULT_ADMIN_ROLE
 *     - [x] succeeds
 *     - [x] calls endpoint.skip with correct parameters
 *     - [x] emits NonceSkipped event
 */

import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract SkipUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    /// @notice Sample source endpoint ID for testing.
    uint32 internal sampleSrcEid = SPOKE_LZ_EID;

    /// @notice Sample sender address for testing.
    bytes32 internal sampleSender = peerAdapterAddress;

    /// @notice Sample nonce for testing.
    uint64 internal sampleNonce = 42;

    // ═══════════════════════════════════════════════════════════════════════
    //                      REVERT CASES - ACCESS CONTROL
    // ═══════════════════════════════════════════════════════════════════════

    function test_skip_revertsIfCallerIsNotAdmin() external {
        vm.expectRevert();
        vm.prank(user);
        adapter.skip(sampleSrcEid, sampleSender, sampleNonce);
    }

    function test_skip_revertsIfCallerIsOperator() external {
        vm.expectRevert();
        vm.prank(operator);
        adapter.skip(sampleSrcEid, sampleSender, sampleNonce);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_skip_succeeds() external {
        vm.prank(admin);
        adapter.skip(sampleSrcEid, sampleSender, sampleNonce);

        // Verify the skip call was made to the endpoint
        (address oapp, uint32 srcEid, bytes32 sender, uint64 nonce) = lzEndpoint.lastSkipCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(srcEid, sampleSrcEid, "Source EID should match");
        assertEq(sender, sampleSender, "Sender should match");
        assertEq(nonce, sampleNonce, "Nonce should match");
    }

    function test_skip_callsEndpointWithCorrectParameters() external {
        uint32 differentSrcEid = HUB_LZ_EID;
        bytes32 differentSender = bytes32(uint256(123_456));
        uint64 differentNonce = 999;

        vm.prank(admin);
        adapter.skip(differentSrcEid, differentSender, differentNonce);

        // Verify all parameters are passed correctly
        (address oapp, uint32 srcEid, bytes32 sender, uint64 nonce) = lzEndpoint.lastSkipCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter address");
        assertEq(srcEid, differentSrcEid, "Source EID should match input");
        assertEq(sender, differentSender, "Sender should match input");
        assertEq(nonce, differentNonce, "Nonce should match input");
    }

    function test_skip_emitsNonceSkippedEvent() external {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.NonceSkipped(sampleSrcEid, sampleSender, sampleNonce);
        adapter.skip(sampleSrcEid, sampleSender, sampleNonce);
    }

    function test_skip_withZeroNonce() external {
        uint64 zeroNonce = 0;

        vm.prank(admin);
        adapter.skip(sampleSrcEid, sampleSender, zeroNonce);

        (,, bytes32 sender, uint64 nonce) = lzEndpoint.lastSkipCall();
        assertEq(sender, sampleSender, "Sender should match");
        assertEq(nonce, zeroNonce, "Zero nonce should be passed");
    }

    function test_skip_withMaxNonce() external {
        uint64 maxNonce = type(uint64).max;

        vm.prank(admin);
        adapter.skip(sampleSrcEid, sampleSender, maxNonce);

        (,,, uint64 nonce) = lzEndpoint.lastSkipCall();
        assertEq(nonce, maxNonce, "Max nonce should be passed correctly");
    }

    function test_skip_withZeroSender() external {
        bytes32 zeroSender = bytes32(0);

        vm.prank(admin);
        adapter.skip(sampleSrcEid, zeroSender, sampleNonce);

        (,, bytes32 sender,) = lzEndpoint.lastSkipCall();
        assertEq(sender, zeroSender, "Zero sender should be passed");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_skip_withVariableParameters(uint32 srcEid, bytes32 sender, uint64 nonce) external {
        vm.prank(admin);
        adapter.skip(srcEid, sender, nonce);

        (address oapp, uint32 actualSrcEid, bytes32 actualSender, uint64 actualNonce) = lzEndpoint.lastSkipCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(actualSrcEid, srcEid, "Source EID should match fuzzed value");
        assertEq(actualSender, sender, "Sender should match fuzzed value");
        assertEq(actualNonce, nonce, "Nonce should match fuzzed value");
    }

    function testFuzz_skip_emitsEventWithCorrectParameters(uint32 srcEid, bytes32 sender, uint64 nonce) external {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.NonceSkipped(srcEid, sender, nonce);
        adapter.skip(srcEid, sender, nonce);
    }
}
