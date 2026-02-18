// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.34;

contract MockWormholeExecutor {
    receive() external payable { }

    function requestExecution(uint16, bytes32, address, bytes calldata, bytes calldata, bytes calldata) external payable { }
}
