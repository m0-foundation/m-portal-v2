// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

contract MockPortal {
    address public immutable mToken;

    struct ReceiveMessageCall {
        uint32 sourceChainId;
        bytes payload;
    }

    ReceiveMessageCall[] public receiveMessageCalls;

    constructor(address mToken_) {
        mToken = mToken_;
    }

    function currentChainId() external view returns (uint32) {
        return 0;
    }

    function receiveMessage(uint32 sourceChainId, bytes memory payload) external {
        receiveMessageCalls.push(ReceiveMessageCall({ sourceChainId: sourceChainId, payload: payload }));
    }

    function getReceiveMessageCallsCount() external view returns (uint256) {
        return receiveMessageCalls.length;
    }

    function resetReceiveMessageCalls() external {
        delete receiveMessageCalls;
    }
}
