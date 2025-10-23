// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

library TypeConverter {
    function toBytes32(address addressValue) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addressValue)));
    }

    function toAddress(bytes32 bytes32Value) internal pure returns (address) {
        return address(uint160(uint256(bytes32Value)));
    }
}
