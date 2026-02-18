// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalForkTestBase } from "./HubPortalForkTestBase.sol";

contract SendTokenForkTest is HubPortalForkTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = TOKEN_HOLDER.toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = TOKEN_HOLDER.toBytes32();
    uint256 internal amount = 1e6;

    uint256 internal constant MAX_ROUNDING_ERROR = 2;

    function test_sendToken_M() external {
        uint256 portalMBalanceBefore = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userMBalanceBefore = IERC20(M_TOKEN).balanceOf(TOKEN_HOLDER);
        uint256 fee = hubPortal.quote(BNB_CHAIN_ID, PayloadType.TokenTransfer);

        vm.startPrank(TOKEN_HOLDER);
        IERC20(M_TOKEN).approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(amount, M_TOKEN, BNB_CHAIN_ID, M_TOKEN.toBytes32(), recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        uint256 portalMBalanceAfter = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userMBalanceAfter = IERC20(M_TOKEN).balanceOf(TOKEN_HOLDER);

        assertEq(portalMBalanceAfter, portalMBalanceBefore + amount);
        assertEq(userMBalanceAfter, userMBalanceBefore - amount);
    }

    function test_sendToken_wM() external {
        uint256 portalMBalanceBefore = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userWrappedMBalanceBefore = IERC20(WRAPPED_M_TOKEN).balanceOf(TOKEN_HOLDER);
        uint256 fee = hubPortal.quote(BNB_CHAIN_ID, PayloadType.TokenTransfer);

        vm.startPrank(TOKEN_HOLDER);
        IERC20(WRAPPED_M_TOKEN).approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(
            amount, WRAPPED_M_TOKEN, BNB_CHAIN_ID, M_TOKEN.toBytes32(), recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();

        uint256 portalMBalanceAfter = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userWrappedMBalanceAfter = IERC20(WRAPPED_M_TOKEN).balanceOf(TOKEN_HOLDER);

        assertApproxEqAbs(portalMBalanceAfter, portalMBalanceBefore + amount, MAX_ROUNDING_ERROR);
        assertEq(userWrappedMBalanceAfter, userWrappedMBalanceBefore - amount);
    }

    function test_sendToken_mUSD() external {
        uint256 portalMBalanceBefore = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userWrappedMBalanceBefore = IERC20(MUSD).balanceOf(TOKEN_HOLDER);
        uint256 fee = hubPortal.quote(BNB_CHAIN_ID, PayloadType.TokenTransfer);

        vm.startPrank(TOKEN_HOLDER);
        IERC20(MUSD).approve(address(hubPortal), amount);
        hubPortal.sendToken{ value: fee }(amount, MUSD, BNB_CHAIN_ID, MUSD.toBytes32(), recipient, refundAddress, bridgeAdapterArgs);
        vm.stopPrank();

        uint256 portalMBalanceAfter = IERC20(M_TOKEN).balanceOf(address(hubPortal));
        uint256 userWrappedMBalanceAfter = IERC20(MUSD).balanceOf(TOKEN_HOLDER);

        assertEq(portalMBalanceAfter, portalMBalanceBefore + amount);
        assertEq(userWrappedMBalanceAfter, userWrappedMBalanceBefore - amount);
    }
}
