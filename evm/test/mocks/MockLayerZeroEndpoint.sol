// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import {
    Origin,
    MessagingFee,
    MessagingReceipt,
    MessagingParams,
    SetConfigParam
} from "../../src/bridgeAdapters/layerzero/interfaces/ILayerZeroTypes.sol";

/// @title  MockLayerZeroEndpoint
/// @notice Mock contract for testing LayerZero Endpoint V2 interactions.
/// @dev    Implements the essential functions needed for testing the LayerZero Bridge Adapter.
contract MockLayerZeroEndpoint {
    /// @notice Tracks the last sent message for verification in tests.
    struct SentMessage {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        uint256 nativeFee;
        address refundAddress;
    }

    /// @notice The last message sent via the endpoint.
    SentMessage public lastSentMessage;

    /// @notice Counter for generating unique nonces.
    uint64 public nonceCounter;

    /// @notice Configurable fee to return from quote().
    uint256 public quoteFee;

    /// @notice Array to track all sent messages.
    SentMessage[] public sentMessages;

    /// @notice Tracks skip calls for verification.
    struct SkipCall {
        address oapp;
        uint32 srcEid;
        bytes32 sender;
        uint64 nonce;
    }

    /// @notice The last skip call.
    SkipCall public lastSkipCall;

    /// @notice Tracks clear calls for verification.
    struct ClearCall {
        address oapp;
        Origin origin;
        bytes32 guid;
        bytes message;
    }

    /// @notice The last clear call.
    ClearCall public lastClearCall;

    /// @notice Tracks delegate set for each OApp.
    mapping(address oapp => address delegate) public delegates;

    /// @notice Tracks setConfig calls for verification.
    struct SetConfigCall {
        address oapp;
        address lib;
        SetConfigParam[] params;
    }

    /// @notice The last setConfig call.
    SetConfigCall public lastSetConfigCall;

    /// @notice Mock send library address.
    address public mockSendLibrary;

    /// @notice Mock receive library address.
    address public mockReceiveLibrary;

    /// @notice Allows the contract to receive ETH for fee handling.
    receive() external payable { }

    /// @notice Sets the fee to return from quote().
    /// @param  fee_ The fee to return.
    function setQuoteFee(uint256 fee_) external {
        quoteFee = fee_;
    }

    /// @notice Returns the fee required to send a message.
    /// @param  _params The messaging parameters.
    /// @param  _sender The sender address (OApp).
    /// @return fee The messaging fee (nativeFee and lzTokenFee).
    function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory fee) {
        // Silence unused parameter warnings
        _params;
        _sender;

        return MessagingFee({ nativeFee: quoteFee, lzTokenFee: 0 });
    }

    /// @notice Sends a message to the destination chain.
    /// @param  _params The messaging parameters.
    /// @param  _refundAddress The address to refund excess fees.
    /// @return receipt The messaging receipt.
    function send(MessagingParams calldata _params, address _refundAddress) external payable returns (MessagingReceipt memory receipt) {
        nonceCounter++;

        lastSentMessage = SentMessage({
            dstEid: _params.dstEid,
            receiver: _params.receiver,
            message: _params.message,
            options: _params.options,
            nativeFee: msg.value,
            refundAddress: _refundAddress
        });

        sentMessages.push(lastSentMessage);

        // Generate a deterministic guid based on inputs
        bytes32 guid = keccak256(abi.encodePacked(_params.dstEid, _params.receiver, _params.message, nonceCounter));

        receipt = MessagingReceipt({ guid: guid, nonce: nonceCounter, fee: MessagingFee(msg.value, 0) });

        // Refund excess if any (in real endpoint, this refunds actual excess)
        // For mock, we just keep the ETH
    }

    /// @notice Sets the delegate for an OApp.
    /// @param  _delegate The delegate address.
    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }

    /// @notice Skips a blocked inbound nonce.
    /// @param  _oapp The OApp address.
    /// @param  _srcEid The source endpoint ID.
    /// @param  _sender The sender address.
    /// @param  _nonce The nonce to skip.
    function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external {
        lastSkipCall = SkipCall({ oapp: _oapp, srcEid: _srcEid, sender: _sender, nonce: _nonce });
    }

    /// @notice Clears a stored payload hash.
    /// @param  _oapp The OApp address.
    /// @param  _origin The origin information.
    /// @param  _guid The global unique identifier.
    /// @param  _message The original message.
    function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external {
        lastClearCall = ClearCall({ oapp: _oapp, origin: _origin, guid: _guid, message: _message });
    }

    /// @notice Returns the number of messages sent.
    /// @return count The number of sent messages.
    function sentMessageCount() external view returns (uint256 count) {
        return sentMessages.length;
    }

    /// @notice Helper to get sent message at index.
    /// @param  index The index of the message.
    /// @return message The sent message.
    function getSentMessage(uint256 index) external view returns (SentMessage memory message) {
        return sentMessages[index];
    }

    /// @notice Sets the configuration for an OApp in a message library.
    /// @param  _oapp The OApp address.
    /// @param  _lib The message library address.
    /// @param  _params The configuration parameters.
    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external {
        // Store the call for verification
        delete lastSetConfigCall.params;
        lastSetConfigCall.oapp = _oapp;
        lastSetConfigCall.lib = _lib;
        for (uint256 i; i < _params.length; ++i) {
            lastSetConfigCall.params.push(_params[i]);
        }
    }

    /// @notice Sets the mock send library address.
    /// @param  _lib The library address.
    function setMockSendLibrary(address _lib) external {
        mockSendLibrary = _lib;
    }

    /// @notice Sets the mock receive library address.
    /// @param  _lib The library address.
    function setMockReceiveLibrary(address _lib) external {
        mockReceiveLibrary = _lib;
    }

    /// @notice Returns the send library for an OApp to a destination.
    /// @param  _sender The OApp address.
    /// @param  _dstEid The destination endpoint ID.
    /// @return lib The send library address.
    function getSendLibrary(address _sender, uint32 _dstEid) external view returns (address lib) {
        // Silence unused parameter warnings
        _sender;
        _dstEid;
        return mockSendLibrary;
    }

    /// @notice Returns the receive library for an OApp from a source.
    /// @param  _receiver The OApp address.
    /// @param  _srcEid The source endpoint ID.
    /// @return lib The receive library address.
    /// @return isDefault Whether it's the default library.
    function getReceiveLibrary(address _receiver, uint32 _srcEid) external view returns (address lib, bool isDefault) {
        // Silence unused parameter warnings
        _receiver;
        _srcEid;
        return (mockReceiveLibrary, true);
    }

    /// @notice Returns the last setConfig call's params length for verification.
    /// @return length The number of params in the last setConfig call.
    function lastSetConfigParamsLength() external view returns (uint256 length) {
        return lastSetConfigCall.params.length;
    }

    /// @notice Returns a specific param from the last setConfig call.
    /// @param  index The index of the param.
    /// @return param The SetConfigParam.
    function getLastSetConfigParam(uint256 index) external view returns (SetConfigParam memory param) {
        return lastSetConfigCall.params[index];
    }
}
