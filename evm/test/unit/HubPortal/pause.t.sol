// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    IAccessControl
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { IPortal } from "../../../src/interfaces/IPortal.sol";

import { HubPortalUnitTestBase } from "./HubPortalUnitTestBase.sol";

contract PauseUnitTest is HubPortalUnitTestBase {
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ==================== pauseSend TESTS ====================

    function test_pauseSend() external {
        assertFalse(hubPortal.sendPaused());

        vm.expectEmit();
        emit IPortal.SendPaused();

        vm.prank(pauser);
        hubPortal.pauseSend();

        assertTrue(hubPortal.sendPaused());
    }

    function test_pauseSend_alreadyPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        assertTrue(hubPortal.sendPaused());

        // Should not emit event when already paused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.pauseSend();

        assertEq(vm.getRecordedLogs().length, 0);
        assertTrue(hubPortal.sendPaused());
    }

    function test_pauseSend_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.pauseSend();
    }

    function test_unpauseSend() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        assertTrue(hubPortal.sendPaused());

        vm.expectEmit();
        emit IPortal.SendUnpaused();

        vm.prank(pauser);
        hubPortal.unpauseSend();

        assertFalse(hubPortal.sendPaused());
    }

    function test_unpauseSend_alreadyUnpaused() external {
        assertFalse(hubPortal.sendPaused());

        // Should not emit event when already unpaused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.unpauseSend();

        assertEq(vm.getRecordedLogs().length, 0);
        assertFalse(hubPortal.sendPaused());
    }

    function test_unpauseSend_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.unpauseSend();
    }

    function test_pauseReceive() external {
        assertFalse(hubPortal.receivePaused());

        vm.expectEmit();
        emit IPortal.ReceivePaused();

        vm.prank(pauser);
        hubPortal.pauseReceive();

        assertTrue(hubPortal.receivePaused());
    }

    function test_pauseReceive_alreadyPaused() external {
        vm.prank(pauser);
        hubPortal.pauseReceive();

        assertTrue(hubPortal.receivePaused());

        // Should not emit event when already paused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.pauseReceive();

        assertEq(vm.getRecordedLogs().length, 0);
        assertTrue(hubPortal.receivePaused());
    }

    function test_pauseReceive_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.pauseReceive();
    }

    function test_unpauseReceive() external {
        vm.prank(pauser);
        hubPortal.pauseReceive();

        assertTrue(hubPortal.receivePaused());

        vm.expectEmit();
        emit IPortal.ReceiveUnpaused();

        vm.prank(pauser);
        hubPortal.unpauseReceive();

        assertFalse(hubPortal.receivePaused());
    }

    function test_unpauseReceive_alreadyUnpaused() external {
        assertFalse(hubPortal.receivePaused());

        // Should not emit event when already unpaused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.unpauseReceive();

        assertEq(vm.getRecordedLogs().length, 0);
        assertFalse(hubPortal.receivePaused());
    }

    function test_unpauseReceive_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.unpauseReceive();
    }

    function test_pauseAll() external {
        assertFalse(hubPortal.sendPaused());
        assertFalse(hubPortal.receivePaused());

        vm.expectEmit();
        emit IPortal.SendPaused();
        vm.expectEmit();
        emit IPortal.ReceivePaused();

        vm.prank(pauser);
        hubPortal.pauseAll();

        assertTrue(hubPortal.sendPaused());
        assertTrue(hubPortal.receivePaused());
    }

    function test_pauseAll_partiallyPaused() external {
        vm.prank(pauser);
        hubPortal.pauseSend();

        assertTrue(hubPortal.sendPaused());
        assertFalse(hubPortal.receivePaused());

        // Should only emit ReceivePaused since send is already paused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.pauseAll();

        // Only ReceivePaused should be emitted
        assertEq(vm.getRecordedLogs().length, 1);
        assertTrue(hubPortal.sendPaused());
        assertTrue(hubPortal.receivePaused());
    }

    function test_pauseAll_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.pauseAll();
    }

    function test_unpauseAll() external {
        vm.prank(pauser);
        hubPortal.pauseAll();

        assertTrue(hubPortal.sendPaused());
        assertTrue(hubPortal.receivePaused());

        vm.expectEmit();
        emit IPortal.SendUnpaused();
        vm.expectEmit();
        emit IPortal.ReceiveUnpaused();

        vm.prank(pauser);
        hubPortal.unpauseAll();

        assertFalse(hubPortal.sendPaused());
        assertFalse(hubPortal.receivePaused());
    }

    function test_unpauseAll_partiallyPaused() external {
        vm.prank(pauser);
        hubPortal.pauseReceive();

        assertFalse(hubPortal.sendPaused());
        assertTrue(hubPortal.receivePaused());

        // Should only emit ReceiveUnpaused since send is already unpaused
        vm.recordLogs();
        vm.prank(pauser);
        hubPortal.unpauseAll();

        // Only ReceiveUnpaused should be emitted
        assertEq(vm.getRecordedLogs().length, 1);
        assertFalse(hubPortal.sendPaused());
        assertFalse(hubPortal.receivePaused());
    }

    function test_unpauseAll_revertsIfNotPauser() external {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, PAUSER_ROLE));
        vm.prank(user);
        hubPortal.unpauseAll();
    }
}
