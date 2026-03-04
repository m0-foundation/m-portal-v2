// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.34;

/// @title  ReentrancyLock contract.
/// @author Uniswap Labs. Modified from https://github.com/Uniswap/v4-periphery/blob/main/src/base/ReentrancyLock.sol
/// @notice A reentrancy lock, that stores the caller's address as the lock.
abstract contract ReentrancyLock {
    error ContractLocked();

    // keccak256(abi.encode(uint256(keccak256("M0.storage.ReentrancyLock")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant REENTRANCY_LOCK_STORAGE_LOCATION =
        0x157708201859ed3ceee295d1baf4381ae5b622de496b1cee3705ed07c6a50200;

    struct ReentrancyLockStorage {
        address _locker;
    }

    function _getReentrancyLockStorage() private pure returns (ReentrancyLockStorage storage $) {
        bytes32 position_ = REENTRANCY_LOCK_STORAGE_LOCATION;
        assembly {
            $.slot := position_
        }
    }

    modifier whenNotLocked() {
        ReentrancyLockStorage storage $ = _getReentrancyLockStorage();
        if ($._locker != address(0)) revert ContractLocked();
        $._locker = msg.sender;
        _;
        $._locker = address(0);
    }

    function _locker() internal view returns (address) {
        return _getReentrancyLockStorage()._locker;
    }
}
