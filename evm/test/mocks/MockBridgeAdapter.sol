// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.33;

import { IBridgeAdapter } from "../../src/interfaces/IBridgeAdapter.sol";

contract MockBridgeAdapter is IBridgeAdapter {
    address public portalAddress;
    bytes32 public messageId;
    uint256 public quoteValue;

    struct SendMessageCall {
        uint32 destinationChainId;
        uint256 gasLimit;
        bytes32 refundAddress;
        bytes payload;
        bytes extraArguments;
    }

    SendMessageCall[] public sendMessageCalls;

    function setPortal(address portal_) external {
        portalAddress = portal_;
    }

    function setMessageId(bytes32 messageId_) external {
        messageId = messageId_;
    }

    function setQuote(uint256 quote_) external {
        quoteValue = quote_;
    }

    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata extraArguments
    ) external payable {
        sendMessageCalls.push(SendMessageCall(destinationChainId, gasLimit, refundAddress, payload, extraArguments));
    }

    function getSendMessageCallCount() external view returns (uint256) {
        return sendMessageCalls.length;
    }

    function getLastSendMessageCall() external view returns (SendMessageCall memory) {
        require(sendMessageCalls.length > 0, "No sendMessage calls recorded");
        return sendMessageCalls[sendMessageCalls.length - 1];
    }

    function resetSendMessageCalls() external {
        delete sendMessageCalls;
    }

    function portal() external view returns (address) {
        return portalAddress;
    }

    function quote(uint32 destinationChainId, uint256 gasLimit, bytes memory payload) external view returns (uint256) {
        return quoteValue;
    }

    function getPeer(uint32 chainId) external pure returns (bytes32) {
        return bytes32(0);
    }

    function getBridgeChainId(uint32 chainId) external pure returns (uint256) {
        return 0;
    }

    function getChainId(uint256 bridgeChainId) external pure returns (uint32) {
        return 0;
    }

    function setPeer(uint32 destinationChainId, bytes32 destinationPeer) external {
        // Mock implementation
    }

    function setBridgeChainId(uint32 chainId, uint256 bridgeChainId) external {
        // Mock implementation
    }

    function initialize(address admin, address operator) external {
        // Mock implementation
    }
}
