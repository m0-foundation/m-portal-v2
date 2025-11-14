// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import {
    AccessControlUpgradeable
} from "../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IBridgeAdapter, AdapterConfig } from "../interfaces/IBridgeAdapter.sol";
import { IPortal } from "../interfaces/IPortal.sol";

abstract contract BridgeAdapterLayout {
    /// @custom:storage-location erc7201:M0.storage.BridgeAdapter
    struct BridgeAdapterStorageStruct {
        mapping(uint32 chainId => AdapterConfig) config;
    }

    // keccak256(abi.encode(uint256(keccak256("M0.storage.BridgeAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 constant BRIDGE_ADAPTER_STORAGE_LOCATION = 0xd75c6d13973e9e8153b1592a6580d542ea215862c7c5b523d53847b2e2d63d00;

    function _getBridgeAdapterStorageLocation() internal pure returns (BridgeAdapterStorageStruct storage $) {
        assembly {
            $.slot := BRIDGE_ADAPTER_STORAGE_LOCATION
        }
    }
}

abstract contract BridgeAdapter is IBridgeAdapter, BridgeAdapterLayout, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @inheritdoc IBridgeAdapter
    address public immutable portal;

    /// @notice Constructs the Implementation contract
    /// @dev    Sets immutable storage.
    /// @param  portal_ The address of Portal.
    constructor(address portal_) {
        _disableInitializers();

        if ((portal = portal_) == address(0)) revert ZeroPortal();
    }

    /// @notice Initializes the Proxy's storage
    /// @param  admin    The address of the admin.
    /// @param  operator The address of the operator.
    function _initialize(address admin, address operator) internal onlyInitializing {
        if (admin == address(0)) revert ZeroAdmin();
        if (operator == address(0)) revert ZeroOperator();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, operator);
    }

    ///////////////////////////////////////////////////////////////////////////
    //                          PRIVILEGED FUNCTIONS                         //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IBridgeAdapter
    function setPeer(uint32 chainId, bytes32 peer) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroChain(chainId);
        _revertIfZeroPeer(peer);

        BridgeAdapterStorageStruct storage $ = _getBridgeAdapterStorageLocation();

        if ($.config[chainId].peer == peer) return;

        $.config[chainId].peer = peer;
        emit PeerSet(chainId, peer);
    }

    /// @inheritdoc IBridgeAdapter
    function setBridgeChainId(uint32 chainId, uint256 bridgeChainId) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroChain(chainId);
        _revertIfZeroBridgeChain(bridgeChainId);

        BridgeAdapterStorageStruct storage $ = _getBridgeAdapterStorageLocation();

        if ($.config[chainId].bridgeChainId == bridgeChainId) return;

        $.config[chainId].bridgeChainId = bridgeChainId;
        emit BridgeChainIdSet(chainId, bridgeChainId);
    }

    /// @inheritdoc IBridgeAdapter
    function setConfig(uint32 chainId, uint256 bridgeChainId, bytes32 peer) external onlyRole(OPERATOR_ROLE) {
        _revertIfZeroChain(chainId);
        _revertIfZeroBridgeChain(bridgeChainId);
        _revertIfZeroPeer(peer);

        BridgeAdapterStorageStruct storage $ = _getBridgeAdapterStorageLocation();

        if ($.config[chainId].bridgeChainId != bridgeChainId) {
            $.config[chainId].bridgeChainId = bridgeChainId;
            emit BridgeChainIdSet(chainId, bridgeChainId);
        }

        if ($.config[chainId].peer != peer) {
            $.config[chainId].peer = peer;
            emit PeerSet(chainId, peer);
        }
    }

    /// @dev Reverts if `msg.sender` is not authorized to upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

    ///////////////////////////////////////////////////////////////////////////
    //                          VIEW/PURE FUNCTIONS                          //
    ///////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IBridgeAdapter
    function getPeer(uint32 chainId) external view returns (bytes32) {
        return _getPeer(chainId);
    }

    /// @inheritdoc IBridgeAdapter
    function getBridgeChainId(uint32 chainId) public view returns (uint256) {
        return _getBridgeChainId(chainId);
    }

    function _getPeer(uint32 chainId) public view returns (bytes32) {
        return _getBridgeAdapterStorageLocation().config[chainId].peer;
    }

    function _getBridgeChainId(uint32 chainId) public view returns (uint256) {
        return _getBridgeAdapterStorageLocation().config[chainId].bridgeChainId;
    }

    function _getPeerOrRevert(uint32 chainId) internal view returns (bytes32) {
        bytes32 peer = _getPeer(chainId);
        if (peer == bytes32(0)) revert UnsupportedChain(chainId);
        return peer;
    }

    function _getBridgeChainIdOrRevert(uint32 chainId) internal view returns (uint256) {
        uint256 bridgeChainId = _getBridgeChainId(chainId);
        if (bridgeChainId == 0) revert UnsupportedChain(chainId);
        return bridgeChainId;
    }

    function _revertIfZeroChain(uint32 chainId) internal pure {
        if (chainId == 0) revert ZeroChain();
    }

    function _revertIfZeroBridgeChain(uint256 bridgeChainId) internal pure {
        if (bridgeChainId == 0) revert ZeroBridgeChain();
    }

    function _revertIfZeroPeer(bytes32 peer) internal pure {
        if (peer == bytes32(0)) revert ZeroPeer();
    }
}

