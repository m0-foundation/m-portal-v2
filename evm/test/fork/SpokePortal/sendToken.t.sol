// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { SpokePortalForkTestBase } from "./SpokePortalForkTestBase.sol";

contract SendTokenForkTest is SpokePortalForkTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = TOKEN_HOLDER.toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = TOKEN_HOLDER.toBytes32();
    uint256 internal amount = 1e6;

    uint256 internal constant MAX_ROUNDING_ERROR = 2;

    function test_sendToken_M() external {
        uint256 mTotalSupplyBefore = IERC20(M_TOKEN).totalSupply();
        uint256 userMBalanceBefore = IERC20(M_TOKEN).balanceOf(TOKEN_HOLDER);
        uint256 fee = spokePortal.quote(ETHEREUM_CHAIN_ID, PayloadType.TokenTransfer);

        vm.startPrank(TOKEN_HOLDER);
        IERC20(M_TOKEN).approve(address(spokePortal), amount);
        spokePortal.sendToken{ value: fee }(
            amount, M_TOKEN, ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32(), recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();

        uint256 mTotalSupplyAfter = IERC20(M_TOKEN).totalSupply();
        uint256 userMBalanceAfter = IERC20(M_TOKEN).balanceOf(TOKEN_HOLDER);

        // $M is burnt on SpokePortal when sent to another chain
        assertEq(mTotalSupplyAfter, mTotalSupplyBefore - amount);
        assertEq(userMBalanceAfter, userMBalanceBefore - amount);
    }

    function test_sendToken_wM() external {
        // Ensure SpokePortal has some $M to cover rounding errors when unwrapping Wrapped $M V1
        assertGt(IERC20(M_TOKEN).balanceOf(address(spokePortal)), MAX_ROUNDING_ERROR);

        uint256 mTotalSupplyBefore = IERC20(M_TOKEN).totalSupply();
        uint256 userWrappedMBalanceBefore = IERC20(WRAPPED_M_TOKEN).balanceOf(TOKEN_HOLDER);
        uint256 fee = spokePortal.quote(ETHEREUM_CHAIN_ID, PayloadType.TokenTransfer);

        vm.startPrank(TOKEN_HOLDER);
        IERC20(WRAPPED_M_TOKEN).approve(address(spokePortal), amount);
        spokePortal.sendToken{ value: fee }(
            amount, WRAPPED_M_TOKEN, ETHEREUM_CHAIN_ID, M_TOKEN.toBytes32(), recipient, refundAddress, bridgeAdapterArgs
        );
        vm.stopPrank();

        uint256 mTotalSupplyAfter = IERC20(M_TOKEN).totalSupply();
        uint256 userWrappedMBalanceAfter = IERC20(WRAPPED_M_TOKEN).balanceOf(TOKEN_HOLDER);

        // $M is burnt on SpokePortal when sent to another chain
        assertApproxEqAbs(mTotalSupplyAfter, mTotalSupplyBefore - amount, MAX_ROUNDING_ERROR);
        assertEq(userWrappedMBalanceAfter, userWrappedMBalanceBefore - amount);
    }
}
