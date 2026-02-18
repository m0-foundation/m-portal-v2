// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.33;

import { IERC20 } from "../../lib/common/src/interfaces/IERC20.sol";

import { MockERC20 } from "./MockERC20.sol";

contract MockFeeOnTransferExtension is MockERC20 {
    address public mToken;
    uint256 public feeRate; // 100 = 1%, 10000 = 100%
    address public feeRecipient;

    constructor(address mToken_, uint256 feeRate_, address feeRecipient_) MockERC20("Mock Wrapped M", "Wrapped M", 6) {
        mToken = mToken_;
        feeRate = feeRate_;
        feeRecipient = feeRecipient_;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * feeRate) / 10_000;
        uint256 amountAfterFee = amount - fee;

        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amountAfterFee;
            balanceOf[feeRecipient] += fee;
        }

        emit Transfer(msg.sender, to, amountAfterFee);
        if (fee > 0) emit Transfer(msg.sender, feeRecipient, fee);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * feeRate) / 10_000;
        uint256 amountAfterFee = amount - fee;

        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amountAfterFee;
            balanceOf[feeRecipient] += fee;
        }

        emit Transfer(from, to, amountAfterFee);
        if (fee > 0) emit Transfer(from, feeRecipient, fee);

        return true;
    }

    function wrap(address recipient, uint256 amount) external {
        IERC20(mToken).transferFrom(msg.sender, address(this), amount);
        _mint(recipient, amount);
    }

    function unwrap(address recipient, uint256 amount) external {
        _burn(msg.sender, amount);
        IERC20(mToken).transfer(recipient, amount);
    }
}
