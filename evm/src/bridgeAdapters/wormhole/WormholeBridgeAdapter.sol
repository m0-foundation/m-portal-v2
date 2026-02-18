// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import { BridgeAdapter } from "../BridgeAdapter.sol";
import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { IExecutor } from "./interfaces/IExecutor.sol";
import { ICoreBridge, CoreBridgeVM } from "./interfaces/ICoreBridge.sol";
import { IWormholeBridgeAdapter } from "./interfaces/IWormholeBridgeAdapter.sol";
import { IVaaV1Receiver } from "./interfaces/IVaaV1Receiver.sol";
import { TypeConverter } from "../../libraries/TypeConverter.sol";
import { PayloadEncoder } from "../../libraries/PayloadEncoder.sol";
import { RelayInstructions } from "./libraries/RelayInstructions.sol";
import { ExecutorMessages } from "./libraries/ExecutorMessages.sol";

abstract contract WormholeBridgeAdapterStorageLayout {
    /// @custom:storage-location erc7201:M0.storage.WormholeBridgeAdapter
    struct WormholeBridgeAdapterStorageStruct {
        /// @notice Indicates whether a message with a given hash has been consumed.
        mapping(bytes32 hash => bool) consumedMessages;
        /// @notice Maps chain IDs to the peer addresses that send cross-chain messages.
        /// @dev    On SVM, Wormhole uses different addresses for sending (signer PDA) vs receiving (program ID).
        ///         This mapping stores sender addresses (signer PDA) for incoming message verification,
        ///         while `remotePeer` stores destination addresses (program ID) for outgoing messages.
        ///         On EVM chains, both mappings contain the same addresses.
        mapping(uint32 internalChainId => bytes32 peer) remoteSenderPeer;
        /// @notice Maps chain IDs to the msg values to include in relay instructions.
        /// @dev    Zero for EVM chains. For SVM chains, must cover lamports for transaction fees,
        ///         priority fees, and rent for new accounts.
        mapping(uint32 internalChainId => uint128 value) remoteMsgValue;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.WormholeBridgeAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant WORMHOLE_BRIDGE_ADAPTER_STORAGE_LOCATION = 0xc36ee3b8df5129da97f3c315d577051673b9e7cc93523a4006aae68954f30900;

    function _getWormholeBridgeAdapterStorageLocation() internal pure returns (WormholeBridgeAdapterStorageStruct storage $) {
        assembly {
            $.slot := WORMHOLE_BRIDGE_ADAPTER_STORAGE_LOCATION
        }
    }
}

/// @title  Wormhole Bridge Adapter
/// @author M0 Labs
/// @notice Sends and receives messages to and from remote chains using Wormhole protocol
contract WormholeBridgeAdapter is WormholeBridgeAdapterStorageLayout, BridgeAdapter, IWormholeBridgeAdapter {
    using TypeConverter for *;
    using PayloadEncoder for bytes;

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable coreBridge;

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable executor;

    /// @inheritdoc IWormholeBridgeAdapter
    uint8 public immutable consistencyLevel;

    /// @inheritdoc IWormholeBridgeAdapter
    uint16 public immutable currentWormholeChainId;

    /// @notice Constructs Wormhole Bridge Adapter Implementation contract
    /// @param coreBridge_             The address of the Wormhole Core Bridge.
    /// @param executor_               The address of the Executor.
    /// @param consistencyLevel_       The consistency level.
    /// @param portal_                 The address of the Portal.
    constructor(address coreBridge_, address executor_, uint8 consistencyLevel_, address portal_) BridgeAdapter(portal_) {
        if ((coreBridge = coreBridge_) == address(0)) revert ZeroCoreBridge();
        if ((executor = executor_) == address(0)) revert ZeroExecutor();

        consistencyLevel = consistencyLevel_;
        currentWormholeChainId = ICoreBridge(coreBridge_).chainId();
    }

    /// @inheritdoc IBridgeAdapter
    function initialize(address admin, address operator) external initializer {
        _initialize(admin, operator);
    }

    /// @inheritdoc IBridgeAdapter
    function quote(uint32, uint256, bytes memory) external pure returns (uint256) {
        // NOTE: At the moment Wormhole doesn't provide a way to quote the fee on-chain.
        //       The signed quote must be provided by the Executor off-chain API.
        revert OnChainQuoteNotSupported();
    }

    /// @inheritdoc IWormholeBridgeAdapter
    function messageConsumed(bytes32 hash) external view returns (bool) {
        return _getWormholeBridgeAdapterStorageLocation().consumedMessages[hash];
    }

    /// @inheritdoc IWormholeBridgeAdapter
    function getSenderPeer(uint32 chainId) external view returns (bytes32) {
        return _getWormholeBridgeAdapterStorageLocation().remoteSenderPeer[chainId];
    }

    /// @inheritdoc IWormholeBridgeAdapter
    function getMsgValue(uint32 chainId) external view returns (uint128) {
        return _getWormholeBridgeAdapterStorageLocation().remoteMsgValue[chainId];
    }

    /// @inheritdoc IBridgeAdapter
    function sendMessage(
        uint32 destinationChainId,
        uint256 gasLimit,
        bytes32 refundAddress,
        bytes memory payload,
        bytes calldata signedQuote
    ) external payable {
        _revertIfNotPortal();

        uint256 coreBridgeFee = ICoreBridge(coreBridge).messageFee();
        if (msg.value < coreBridgeFee) revert InsufficientFee();

        // nonce is 0 in ICoreBridge.publishMessage as it's not used
        uint64 sequence = ICoreBridge(coreBridge).publishMessage{ value: coreBridgeFee }(0, payload, consistencyLevel);
        bytes32 destinationPeer = _getPeerOrRevert(destinationChainId);
        uint16 destinationWormholeChainId = _getBridgeChainIdOrRevert(destinationChainId).toUint16();
        uint128 msgValue = _getWormholeBridgeAdapterStorageLocation().remoteMsgValue[destinationChainId];
        bytes memory relayInstructions = RelayInstructions.encodeGas(gasLimit.toUint128(), msgValue);

        IExecutor(executor).requestExecution{ value: msg.value - coreBridgeFee }(
            destinationWormholeChainId,
            destinationPeer,
            refundAddress.toAddress(),
            signedQuote,
            ExecutorMessages.makeVAAv1Request(currentWormholeChainId, address(this).toBytes32(), sequence),
            relayInstructions
        );
    }

    /// @inheritdoc IVaaV1Receiver
    function executeVAAv1(bytes calldata encodedMessage) external payable {
        // Verify VAA against Wormhole Core Bridge contract
        (CoreBridgeVM memory vm, bool valid, string memory reason) = ICoreBridge(coreBridge).parseAndVerifyVM(encodedMessage);

        // Ensure that the VAA is valid
        if (!valid) revert InvalidVaa(reason);

        // Wormhole VAAs are multicast by default. There is no default target chain for a given message.
        // Ensure that payload is intended for this chain and Bridge Adapter
        (uint32 targetChainId, bytes32 targetBridgeAdapter) = vm.payload.decodeDestinationChainIdAndPeer();
        if (targetChainId != IPortal(portal).currentChainId()) revert InvalidTargetChain(targetChainId);
        if (targetBridgeAdapter.toAddress() != address(this)) revert InvalidTargetBridgeAdapter(targetBridgeAdapter);

        // Replay protection: ensure the message hasn't been consumed yet
        WormholeBridgeAdapterStorageStruct storage $ = _getWormholeBridgeAdapterStorageLocation();
        if ($.consumedMessages[vm.hash]) revert MessageAlreadyConsumed(vm.hash);
        $.consumedMessages[vm.hash] = true;

        // Convert Wormhole chain ID to internal chain ID
        uint32 sourceChainId = _getChainIdOrRevert(vm.emitterChainId);
        if (vm.emitterAddress != $.remoteSenderPeer[sourceChainId]) revert UnsupportedSender(vm.emitterAddress);

        IPortal(portal).receiveMessage(sourceChainId, vm.payload);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          PRIVILEGED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IWormholeBridgeAdapter
    function setSenderPeer(uint32 chainId, bytes32 senderPeer) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroChain(chainId);

        WormholeBridgeAdapterStorageStruct storage $ = _getWormholeBridgeAdapterStorageLocation();

        if ($.remoteSenderPeer[chainId] == senderPeer) return;

        $.remoteSenderPeer[chainId] = senderPeer;
        emit SenderPeerSet(chainId, senderPeer);
    }

    /// @inheritdoc IWormholeBridgeAdapter
    function setMsgValue(uint32 chainId, uint128 msgValue) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroChain(chainId);

        WormholeBridgeAdapterStorageStruct storage $ = _getWormholeBridgeAdapterStorageLocation();

        if ($.remoteMsgValue[chainId] == msgValue) return;

        $.remoteMsgValue[chainId] = msgValue;
        emit MsgValueSet(chainId, msgValue);
    }
}

