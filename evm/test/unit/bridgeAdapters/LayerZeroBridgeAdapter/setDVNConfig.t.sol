// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

/**
 * @notice Unit tests for setDVNConfig
 *
 * Branch coverage TODOs:
 * - [x] when caller does not have DEFAULT_ADMIN_ROLE
 *     - [x] reverts with AccessControlUnauthorizedAccount
 * - [x] when caller has DEFAULT_ADMIN_ROLE
 *     - [x] succeeds
 *     - [x] calls endpoint.setConfig with correct parameters
 *     - [x] emits DVNConfigSet event
 */

import { ILayerZeroBridgeAdapter } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroBridgeAdapter.sol";
import { SetConfigParam } from "../../../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroTypes.sol";

import { LayerZeroBridgeAdapterUnitTestBase } from "./LayerZeroBridgeAdapterUnitTestBase.sol";

contract SetDVNConfigUnitTest is LayerZeroBridgeAdapterUnitTestBase {
    /// @notice Sample library address for testing.
    address internal sampleLib = makeAddr("messageLib");

    /// @notice Sample config type constant (ULN config type from LayerZero).
    uint32 internal constant CONFIG_TYPE_ULN = 2;

    // ═══════════════════════════════════════════════════════════════════════
    //                      REVERT CASES - ACCESS CONTROL
    // ═══════════════════════════════════════════════════════════════════════

    function test_setDVNConfig_revertsIfCallerIsNotAdmin() external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.expectRevert();
        vm.prank(user);
        adapter.setDVNConfig(sampleLib, params);
    }

    function test_setDVNConfig_revertsIfCallerIsOperator() external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.expectRevert();
        vm.prank(operator);
        adapter.setDVNConfig(sampleLib, params);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                           SUCCESS CASES
    // ═══════════════════════════════════════════════════════════════════════

    function test_setDVNConfig_succeeds() external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.prank(admin);
        adapter.setDVNConfig(sampleLib, params);

        // Verify the setConfig call was made to the endpoint
        (address oapp, address lib) = lzEndpoint.lastSetConfigCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(lib, sampleLib, "Library should match");
    }

    function test_setDVNConfig_callsEndpointWithCorrectParameters() external {
        SetConfigParam[] memory params = new SetConfigParam[](2);
        params[0] = SetConfigParam({ eid: SPOKE_LZ_EID, configType: CONFIG_TYPE_ULN, config: abi.encode(uint64(1), uint8(2)) });
        params[1] = SetConfigParam({ eid: HUB_LZ_EID, configType: CONFIG_TYPE_ULN, config: abi.encode(uint64(15), uint8(1)) });

        vm.prank(admin);
        adapter.setDVNConfig(sampleLib, params);

        // Verify parameters are passed correctly
        (address oapp, address lib) = lzEndpoint.lastSetConfigCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter address");
        assertEq(lib, sampleLib, "Library should match input");

        // Verify params length
        uint256 paramsLength = lzEndpoint.lastSetConfigParamsLength();
        assertEq(paramsLength, 2, "Should have 2 params");

        // Verify first param
        SetConfigParam memory param0 = lzEndpoint.getLastSetConfigParam(0);
        assertEq(param0.eid, SPOKE_LZ_EID, "First param EID should match");
        assertEq(param0.configType, CONFIG_TYPE_ULN, "First param config type should match");

        // Verify second param
        SetConfigParam memory param1 = lzEndpoint.getLastSetConfigParam(1);
        assertEq(param1.eid, HUB_LZ_EID, "Second param EID should match");
        assertEq(param1.configType, CONFIG_TYPE_ULN, "Second param config type should match");
    }

    function test_setDVNConfig_emitsDVNConfigSetEvent() external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.DVNConfigSet(sampleLib, params);
        adapter.setDVNConfig(sampleLib, params);
    }

    function test_setDVNConfig_withEmptyParams() external {
        SetConfigParam[] memory params = new SetConfigParam[](0);

        vm.prank(admin);
        adapter.setDVNConfig(sampleLib, params);

        // Verify the call was made even with empty params
        (address oapp, address lib) = lzEndpoint.lastSetConfigCall();
        assertEq(oapp, address(adapter), "OApp should be the adapter");
        assertEq(lib, sampleLib, "Library should match");
        assertEq(lzEndpoint.lastSetConfigParamsLength(), 0, "Params should be empty");
    }

    function test_setDVNConfig_withSingleParam() external {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({ eid: SPOKE_LZ_EID, configType: CONFIG_TYPE_ULN, config: hex"1234" });

        vm.prank(admin);
        adapter.setDVNConfig(sampleLib, params);

        uint256 paramsLength = lzEndpoint.lastSetConfigParamsLength();
        assertEq(paramsLength, 1, "Should have 1 param");

        SetConfigParam memory param = lzEndpoint.getLastSetConfigParam(0);
        assertEq(param.eid, SPOKE_LZ_EID, "EID should match");
        assertEq(param.config, hex"1234", "Config should match");
    }

    function test_setDVNConfig_withZeroLibAddress() external {
        SetConfigParam[] memory params = _createSampleParams();

        // Zero lib address is allowed - endpoint handles validation
        vm.prank(admin);
        adapter.setDVNConfig(address(0), params);

        (, address lib) = lzEndpoint.lastSetConfigCall();
        assertEq(lib, address(0), "Library should be zero address");
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             FUZZ TESTS
    // ═══════════════════════════════════════════════════════════════════════

    function testFuzz_setDVNConfig_withVariableLibAddress(address lib) external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.prank(admin);
        adapter.setDVNConfig(lib, params);

        (, address actualLib) = lzEndpoint.lastSetConfigCall();
        assertEq(actualLib, lib, "Library should match fuzzed value");
    }

    function testFuzz_setDVNConfig_withVariableEidAndConfigType(uint32 eid, uint32 configType) external {
        SetConfigParam[] memory params = new SetConfigParam[](1);
        params[0] = SetConfigParam({ eid: eid, configType: configType, config: hex"abcd" });

        vm.prank(admin);
        adapter.setDVNConfig(sampleLib, params);

        SetConfigParam memory param = lzEndpoint.getLastSetConfigParam(0);
        assertEq(param.eid, eid, "EID should match fuzzed value");
        assertEq(param.configType, configType, "Config type should match fuzzed value");
    }

    function testFuzz_setDVNConfig_emitsEventWithCorrectParameters(address lib) external {
        SetConfigParam[] memory params = _createSampleParams();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true, address(adapter));
        emit ILayerZeroBridgeAdapter.DVNConfigSet(lib, params);
        adapter.setDVNConfig(lib, params);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //                             HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    function _createSampleParams() internal view returns (SetConfigParam[] memory params) {
        params = new SetConfigParam[](1);
        params[0] = SetConfigParam({ eid: SPOKE_LZ_EID, configType: CONFIG_TYPE_ULN, config: abi.encode(uint64(15), uint8(1)) });
    }
}
