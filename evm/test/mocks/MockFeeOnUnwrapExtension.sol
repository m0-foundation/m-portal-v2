// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { MockERC20 } from "./MockERC20.sol";

contract MockFeeOnUnwrapExtension is MockERC20 {
    address public mToken;
    uint256 public feeRate; // 100 = 1%, 10000 = 100%
    address public feeRecipient;

    constructor(address mToken_, uint256 feeRate_, address feeRecipient_) MockERC20("Mock Wrapped M", "Wrapped M", 6) {
        mToken = mToken_;
        feeRate = feeRate_;
        feeRecipient = feeRecipient_;
    }

    function wrap(address recipient, uint256 amount) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount);
        _mint(recipient, amount);
    }

    function unwrap(address recipient, uint256 amount) external {
        _burn(msg.sender, amount);
        uint256 fee = (amount * feeRate) / 10_000;
        IERC20(mToken).transfer(recipient, amount - fee);
        if (fee > 0) IERC20(mToken).transfer(feeRecipient, fee);
    }
}
