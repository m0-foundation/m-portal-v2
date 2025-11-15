// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import { CoreBridgeLib } from "../../../lib/wormhole-solidity-sdk/src/libraries/CoreBridge.sol";

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { IExecutor } from "./interfaces/IExecutor.sol";
import { ICoreBridge } from "./interfaces/ICoreBridge.sol";
import { IWormholeBridgeAdapter } from "./interfaces/IWormholeBridgeAdapter.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";
import { RelayInstructions } from "./libraries/RelayInstructions.sol";
import { ExecutorMessages } from "./libraries/ExecutorMessages.sol";

contract WormholeBridgeAdapter is BridgeAdapter, IWormholeBridgeAdapter {
    using TypeConverter for *;

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable coreBridge;

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable executor;

    /// @inheritdoc IWormholeBridgeAdapter
    uint8 public immutable consistencyLevel;

    /// @inheritdoc IWormholeBridgeAdapter
    uint16 public immutable currentWormholeChainId;

    /// @notice Constructs Wormhole Bridge Adapter Implementation contract
    /// @param coreBridge_       The address of the Wormhole Core Bridge.
    /// @param executor_         The address of the Executor.
    /// @param consistencyLevel_ The consistency level.
    /// @param portal_           The address of the Portal.
    constructor(
        address coreBridge_,
        address executor_,
        uint8 consistencyLevel_,
        uint16 currentWormholeChainId_,
        address portal_
    ) BridgeAdapter(portal_) {
        _disableInitializers();

        if ((coreBridge = coreBridge_) == address(0)) revert ZeroCoreBridge();
        if ((executor = executor_) == address(0)) revert ZeroExecutor();
        consistencyLevel = consistencyLevel_;
        currentWormholeChainId = currentWormholeChainId_;
    }

    function initialize(address owner, address operator) external initializer {
        _initialize(owner, operator);
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint32, uint256, bytes memory) external pure returns (uint256 fee) {
        // NOTE: At the moment Wormhole doesn't provide a way to quote the fee on-chain.
        //       The signed quote must be provided by the Executor off-chain API.
        return 0;
    }

    /// @inheritdoc IBridgeAdapter
    function sendMessage(uint32 destinationChainId, uint256 gasLimit, bytes32 refundAddress, bytes memory payload) external payable {
        if (msg.sender != portal) revert NotPortal();

        uint256 coreBridgeFee = ICoreBridge(coreBridge).messageFee();
        if (msg.value < coreBridgeFee) revert InsufficientFee();

        // nonce is 0 in ICoreBridge.publishMessage as it's not used
        uint64 sequence = ICoreBridge(coreBridge).publishMessage{ value: coreBridgeFee }(0, payload, consistencyLevel);
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint16 destinationWormholeChainId = _getBridgeChainIdOrRevert(destinationChainId).toUint16();

        IExecutor(executor).requestExecution{ value: msg.value - coreBridgeFee }(
            destinationWormholeChainId,
            destinationPeer,
            refundAddress.toAddress(),
            "", //signedQuote,
            ExecutorMessages.makeVAAv1Request(currentWormholeChainId, address(this).toBytes32(), sequence),
            RelayInstructions.encodeGas(gasLimit.toUint128(), 0)
        );
    }

    function executeVAAv1(bytes calldata vaa) external payable {
        (,, uint16 sourceChainId, bytes32 sender,,, bytes calldata payload) = CoreBridgeLib.decodeAndVerifyVaaCd(coreBridge, vaa);
        
        // TODO: check that sender is a valid peer
        IPortal(portal).receiveMessage(sourceChainId, payload);
    }
}

