// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

/// @title  OptionsBuilder
/// @notice Library for building LayerZero execution options.
/// @dev    Simplified version of LayerZero's OptionsBuilder for the bridge adapter use case.
library OptionsBuilder {
    /// @notice Option type for executor options (lzReceive gas, native drop, etc).
    uint8 internal constant WORKER_ID_EXECUTOR = 1;

    /// @notice Option type for lzReceive gas configuration.
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;

    /// @notice Creates new TYPE_3 options bytes.
    /// @return options The initialized options bytes (just the type header).
    function newOptions() internal pure returns (bytes memory options) {
        // TYPE_3 options header: 0x0003
        return hex"0003";
    }

    /// @notice Adds executor lzReceive option to specify gas limit and msg.value for the destination execution.
    /// @param  _options The existing options bytes.
    /// @param  _gas The gas limit for lzReceive execution.
    /// @param  _value The msg.value to pass to lzReceive (typically 0).
    /// @return options The options with the lzReceive option appended.
    function addExecutorLzReceiveOption(bytes memory _options, uint128 _gas, uint128 _value) internal pure returns (bytes memory options) {
        // Format: workerID (1 byte) + optionLength (2 bytes) + optionType (1 byte) + gas (16 bytes) [+ value (16 bytes)]
        bytes memory option;
        if (_value == 0) {
            // Without value: optionType (1) + gas (16) = 17 bytes
            option = abi.encodePacked(
                WORKER_ID_EXECUTOR, // 1 byte
                uint16(17), // option length: 1 + 16
                OPTION_TYPE_LZRECEIVE, // 1 byte
                _gas // 16 bytes
            );
        } else {
            // With value: optionType (1) + gas (16) + value (16) = 33 bytes
            option = abi.encodePacked(
                WORKER_ID_EXECUTOR, // 1 byte
                uint16(33), // option length: 1 + 16 + 16
                OPTION_TYPE_LZRECEIVE, // 1 byte
                _gas, // 16 bytes
                _value // 16 bytes
            );
        }

        return abi.encodePacked(_options, option);
    }
}
