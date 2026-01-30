// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IBridgeAdapter } from "../../../../src/interfaces/IBridgeAdapter.sol";
import { IWormholeBridgeAdapter } from "../../../../src/bridgeAdapters/wormhole/interfaces/IWormholeBridgeAdapter.sol";

import { WormholeBridgeAdapterUnitTestBase } from "./WormholeBridgeAdapterUnitTestBase.sol";

contract SetMsgValueUnitTest is WormholeBridgeAdapterUnitTestBase {
    function test_setMsgValue() external {
        uint32 chainId = 3;
        uint128 msgValue = 1e9; // 1 SOL worth of lamports

        vm.expectEmit();
        emit IWormholeBridgeAdapter.MsgValueSet(chainId, msgValue);

        vm.prank(operator);
        adapter.setMsgValue(chainId, msgValue);

        assertEq(adapter.getMsgValue(chainId), msgValue);
    }

    function test_setMsgValue_zeroValueAllowed() external {
        uint32 chainId = 3;
        uint128 msgValue = 1e9;

        // First set a non-zero value
        vm.prank(operator);
        adapter.setMsgValue(chainId, msgValue);

        // Setting zero should be allowed (valid for EVM chains)
        vm.expectEmit();
        emit IWormholeBridgeAdapter.MsgValueSet(chainId, 0);

        vm.prank(operator);
        adapter.setMsgValue(chainId, 0);

        assertEq(adapter.getMsgValue(chainId), 0);
    }

    function test_setMsgValue_sameValueNoEvent() external {
        uint32 chainId = 3;
        uint128 msgValue = 1e9;

        // First set the msg value
        vm.prank(operator);
        adapter.setMsgValue(chainId, msgValue);

        // Setting the same value should not emit event
        vm.recordLogs();

        vm.prank(operator);
        adapter.setMsgValue(chainId, msgValue);

        // No events should be emitted
        assertEq(vm.getRecordedLogs().length, 0);
    }

    function test_setMsgValue_revertsIfCalledByNonOperator() external {
        uint128 msgValue = 1e9;

        vm.expectRevert();

        vm.prank(user);
        adapter.setMsgValue(SPOKE_CHAIN_ID, msgValue);
    }

    function test_setMsgValue_revertsIfZeroChain() external {
        uint128 msgValue = 1e9;

        vm.expectRevert(IBridgeAdapter.ZeroChain.selector);

        vm.prank(operator);
        adapter.setMsgValue(0, msgValue);
    }
}
