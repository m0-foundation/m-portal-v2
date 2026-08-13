// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import {
    IERC20
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    UUPSUpgradeable
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { console } from "../../../lib/forge-std/src/console.sol";

import { HubPortal } from "../../../src/HubPortal.sol";
import { IPortal } from "../../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../../src/libraries/TypeConverter.sol";
import { PayloadType } from "../../../src/libraries/PayloadEncoder.sol";

import { HubPortalForkTestBase } from "./HubPortalForkTestBase.sol";

/// @dev Demonstrates that removing the rounding tolerance from `Portal._transferAndUnwrap` breaks
///      `HubPortal.sendToken` for a large fraction of amounts.
///
///      HubPortal is an $M earner. $M credits an earning recipient with principal rounded down, and
///      `balanceOf` is the present value of that principal rounded down, so the Portal's measured
///      balance delta after receiving `amount` can fall short of `amount` by up to
///      `index / 1e12 + 1` wei (1-2 wei at the current index). With the strict
///      `actualAmount < specifiedAmount` check, every such send reverts with
///      `InsufficientAmountReceived`. This is independent of the Wrapped $M version - it fires on
///      the plain $M path where no extension is involved at all.
///
///      IMPORTANT: `HubPortalForkTestBase.setUp` no longer upgrades the proxy to the locally
///      compiled implementation, so the regular fork tests exercise the currently deployed
///      bytecode (which still carries the tolerance) rather than this branch's source. Each test
///      below first re-applies the local build to the proxy so the sweep runs against this
///      branch's `Portal.sol`.
///
///      These tests are written as the regression tests the fix should satisfy: they sweep
///      consecutive amounts and assert every send succeeds. On this branch they FAIL (6 of 30
///      amounts revert at the pinned block); once a rounding tolerance is restored they pass.
///      Run with:
///          forge test --match-path test/fork/HubPortal/earnerRoundingRevert.t.sol -vv
contract EarnerRoundingRevertForkTest is HubPortalForkTestBase {
    using TypeConverter for address;

    bytes32 internal refundAddress = TOKEN_HOLDER.toBytes32();
    bytes32 internal recipient = TOKEN_HOLDER.toBytes32();

    uint256 internal constant SWEEP_START = 1;
    uint256 internal constant SWEEP_END = 30;

    /// @dev Upgrades the live proxy to the implementation compiled from this branch's source,
    ///      mirroring what `_upgradeToPortalV2` did before the fork test bases were re-pointed
    ///      at live state. The proxy is already initialized on-chain, so no call data is needed.
    function _upgradeToLocalImplementation() internal {
        address implementation = address(new HubPortal(M_TOKEN, REGISTRAR, SWAP_FACILITY, ORDER_BOOK, MERKLE_TREE_BUILDER));
        vm.prank(ADMIN);
        UUPSUpgradeable(PORTAL).upgradeToAndCall(implementation, "");
    }

    function test_sendToken_M_allAmountsBridgeable() external {
        _upgradeToLocalImplementation();
        _sweep(M_TOKEN, M_TOKEN.toBytes32());
    }

    function test_sendToken_wM_allAmountsBridgeable() external {
        _upgradeToLocalImplementation();
        _sweep(WRAPPED_M_TOKEN, M_TOKEN.toBytes32());
    }

    function test_sendToken_mUSD_allAmountsBridgeable() external {
        _upgradeToLocalImplementation();
        _sweep(MUSD, MUSD.toBytes32());
    }

    function _sweep(address sourceToken, bytes32 destinationToken) internal {
        uint256 fee = hubPortal.quote(BNB_CHAIN_ID, PayloadType.TokenTransfer);
        uint256 failures;

        vm.startPrank(TOKEN_HOLDER);
        IERC20(sourceToken).approve(address(hubPortal), type(uint256).max);

        for (uint256 amount = SWEEP_START; amount <= SWEEP_END; ++amount) {
            try hubPortal.sendToken{ value: fee }(
                amount, sourceToken, BNB_CHAIN_ID, destinationToken, recipient, refundAddress, ""
            ) { } catch (bytes memory reason) {
                failures++;
                _logFailure(amount, reason);
            }
        }

        vm.stopPrank();

        assertEq(failures, 0, "sendToken reverted for amounts short 1 wei due to $M earner principal rounding");
    }

    function _logFailure(uint256 amount, bytes memory reason) internal pure {
        if (bytes4(reason) == IPortal.InsufficientAmountReceived.selector) {
            (uint256 specified, uint256 actual) = abi.decode(_slice(reason, 4), (uint256, uint256));
            console.log("amount %s reverted: InsufficientAmountReceived(specified %s, actual %s)", amount, specified, actual);
        } else {
            console.log("amount %s reverted with unexpected error:", amount);
            console.logBytes(reason);
        }
    }

    function _slice(bytes memory data, uint256 offset) internal pure returns (bytes memory result) {
        result = new bytes(data.length - offset);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[i + offset];
        }
    }
}
