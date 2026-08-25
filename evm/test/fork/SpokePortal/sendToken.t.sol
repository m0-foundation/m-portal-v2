// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IndexingMath } from "../../../lib/common/src/libs/IndexingMath.sol";

import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { SpokePortalForkTestBase } from "./SpokePortalForkTestBase.sol";

contract SendTokenForkTest is SpokePortalForkTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = TOKEN_HOLDER.toBytes32();
    bytes internal bridgeAdapterArgs = "";
    bytes32 internal recipient = TOKEN_HOLDER.toBytes32();
    uint256 internal amount = 1e6;

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

        // $M is burnt on SpokePortal when sent to another chain.
        // Total supply may deviate by up to index / EXP_SCALED_ONE + 1 wei due to principal
        // rounding in $M earner accounting when $M is transferred out of the earning Wrapped $M contract.
        assertApproxEqAbs(mTotalSupplyAfter, mTotalSupplyBefore - amount, _roundingTolerance());
        assertEq(userWrappedMBalanceAfter, userWrappedMBalanceBefore - amount);
    }

    /// @dev Maximum total supply deviation caused by $M earner principal rounding when $M
    ///      is transferred out of the earning Wrapped $M contract.
    function _roundingTolerance() internal view returns (uint256) {
        return spokePortal.currentIndex() / IndexingMath.EXP_SCALED_ONE + 1;
    }
}
