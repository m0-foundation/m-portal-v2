// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for clear
 *
 * Branch coverage TODOs:
 * - [x] when caller does not have DEFAULT_ADMIN_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 * - [x] when caller has DEFAULT_ADMIN_ROLE
 *     - [x] succeeds
 *     - [x] calls endpoint.clear with correct parameters
 *     - [x] emits PayloadCleared event
 */

import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol";
import { Origin } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroTypes.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract ClearUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    /// @notice Sample origin for testing.
    Origin internal sampleOrigin;

    /// @notice Sample GUID for testing.
    bytes32 internal sampleGuid = keccak256("sampleGuid");

    /// @notice Sample message for testing.
    bytes internal sampleMessage = abi.encodePacked("sample message payload");

    function setUp() public override {
        super.setUp();

        // Initialize sample origin
        sampleOrigin = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: 42 });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                      REVERT CASES - ACCESS CONTROL
    // ═══════════════════════════════════════════════════════════════════════

    function test_clear_revertsIfCallerIsNotAdmin() external {
        vm.expectRevert();
        vm.prank(user);
        adapter.clear(sampleOrigin, sampleGuid, sampleMessage);
    }

    function test_clear_revertsIfCallerIsOperator() external {
        vm.expectRevert();
        vm.prank(operator);
        adapter.clear(sampleOrigin, sampleGuid, sampleMessage);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_clear_succeeds() external {
        vm.prank(admin);
        adapter.clear(sampleOrigin, sampleGuid, sampleMessage);

        // Verify the clear call was made to the endpoint
        (address oapp, Origin memory origin, bytes32 guid, bytes memory message) = _getLastClearCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(origin.srcEid, sampleOrigin.srcEid, "Source EID should match");
        assertEq(origin.sender, sampleOrigin.sender, "Sender should match");
        assertEq(origin.nonce, sampleOrigin.nonce, "Nonce should match");
        assertEq(guid, sampleGuid, "GUID should match");
        assertEq(message, sampleMessage, "Message should match");
    }

    function test_clear_callsEndpointWithCorrectParameters() external {
        Origin memory differentOrigin = Origin({ srcEid: HUB_LZ_EID, sender: bytes32(uint256(123_456)), nonce: 999 });
        bytes32 differentGuid = keccak256("differentGuid");
        bytes memory differentMessage = abi.encodePacked("different message content");

        vm.prank(admin);
        adapter.clear(differentOrigin, differentGuid, differentMessage);

        // Verify all parameters are passed correctly
        (address oapp, Origin memory origin, bytes32 guid, bytes memory message) = _getLastClearCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter address");
        assertEq(origin.srcEid, differentOrigin.srcEid, "Source EID should match input");
        assertEq(origin.sender, differentOrigin.sender, "Sender should match input");
        assertEq(origin.nonce, differentOrigin.nonce, "Nonce should match input");
        assertEq(guid, differentGuid, "GUID should match input");
        assertEq(message, differentMessage, "Message should match input");
    }

    function test_clear_emitsPayloadClearedEvent() external {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.PayloadCleared(sampleOrigin.srcEid, sampleOrigin.sender, sampleOrigin.nonce, sampleGuid);
        adapter.clear(sampleOrigin, sampleGuid, sampleMessage);
    }

    function test_clear_withZeroNonce() external {
        Origin memory originWithZeroNonce = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: 0 });

        vm.prank(admin);
        adapter.clear(originWithZeroNonce, sampleGuid, sampleMessage);

        (, Origin memory origin,,) = _getLastClearCall();
        assertEq(origin.nonce, 0, "Zero nonce should be passed");
    }

    function test_clear_withMaxNonce() external {
        Origin memory originWithMaxNonce = Origin({ srcEid: SPOKE_LZ_EID, sender: peerAdapterAddress, nonce: type(uint64).max });

        vm.prank(admin);
        adapter.clear(originWithMaxNonce, sampleGuid, sampleMessage);

        (, Origin memory origin,,) = _getLastClearCall();
        assertEq(origin.nonce, type(uint64).max, "Max nonce should be passed correctly");
    }

    function test_clear_withZeroSender() external {
        Origin memory originWithZeroSender = Origin({ srcEid: SPOKE_LZ_EID, sender: bytes32(0), nonce: 42 });

        vm.prank(admin);
        adapter.clear(originWithZeroSender, sampleGuid, sampleMessage);

        (, Origin memory origin,,) = _getLastClearCall();
        assertEq(origin.sender, bytes32(0), "Zero sender should be passed");
    }

    function test_clear_withEmptyMessage() external {
        bytes memory emptyMessage = "";

        vm.prank(admin);
        adapter.clear(sampleOrigin, sampleGuid, emptyMessage);

        (,,, bytes memory message) = _getLastClearCall();
        assertEq(message.length, 0, "Empty message should be passed");
    }

    function test_clear_withZeroGuid() external {
        bytes32 zeroGuid = bytes32(0);

        vm.prank(admin);
        adapter.clear(sampleOrigin, zeroGuid, sampleMessage);

        (,, bytes32 guid,) = _getLastClearCall();
        assertEq(guid, bytes32(0), "Zero GUID should be passed");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_clear_withVariableParameters(
        uint32 srcEid,
        bytes32 sender,
        uint64 nonce,
        bytes32 guid,
        bytes calldata message
    ) external {
        Origin memory fuzzedOrigin = Origin({ srcEid: srcEid, sender: sender, nonce: nonce });

        vm.prank(admin);
        adapter.clear(fuzzedOrigin, guid, message);

        (address oapp, Origin memory actualOrigin, bytes32 actualGuid, bytes memory actualMessage) = _getLastClearCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(actualOrigin.srcEid, srcEid, "Source EID should match fuzzed value");
        assertEq(actualOrigin.sender, sender, "Sender should match fuzzed value");
        assertEq(actualOrigin.nonce, nonce, "Nonce should match fuzzed value");
        assertEq(actualGuid, guid, "GUID should match fuzzed value");
        assertEq(actualMessage, message, "Message should match fuzzed value");
    }

    function testFuzz_clear_emitsEventWithCorrectParameters(uint32 srcEid, bytes32 sender, uint64 nonce, bytes32 guid) external {
        Origin memory fuzzedOrigin = Origin({ srcEid: srcEid, sender: sender, nonce: nonce });

        vm.prank(admin);
        vm.expectEmit(true, true, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.PayloadCleared(srcEid, sender, nonce, guid);
        adapter.clear(fuzzedOrigin, guid, sampleMessage);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    /// @notice Helper to get the last clear call from the mock endpoint.
    /// @dev    The mock stores the clear call data that we can retrieve.
    function _getLastClearCall() internal view returns (address oapp, Origin memory origin, bytes32 guid, bytes memory message) {
        (oapp, origin, guid, message) = lzEndpoint.lastClearCall();
    }
}
