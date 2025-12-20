// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { NttManagerPeer, AttestationInfo, Mode, Sequence, Threshold } from "../portalV1/IPortalV1.sol";

struct BridgingPath {
    address sourceToken;
    uint16 destinationChainId;
    bytes32 destinationToken;
}

/// @dev A temporary implementation used to clear ALL storage across the entire inheritance chain during an upgrade.
///      After calling clearAllStorage(), the contract should be upgraded to the new implementation.
abstract contract PortalV1StorageCleaner is UUPSUpgradeable {
    /// @dev The current owner of the Portal contract
    address public constant MIGRATOR = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;
    address public constant PORTAL = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;

    error Unauthorized();
    error OnlyDelegateCall();

    modifier onlyDelegateCall() {
        if (address(this) != PORTAL) revert OnlyDelegateCall();
        _;
    }

    modifier onlyMigrator() {
        if (msg.sender != MIGRATOR) revert Unauthorized();
        _;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //       TEMPORARY FUNCTIONS AND IMMUTABLES REQUIRED TO MIGRATE FROM PORTAL V1     //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev Immutable variables stored in the implementation, not the Proxy
    //       Required as current Wormhole implementation checks them during the upgrade
    address public immutable token;
    Mode public immutable mode;
    uint16 public immutable chainId;
    uint64 public immutable rateLimitDuration;

    constructor(address token_, Mode mode_, uint16 chainId_) {
        token = token_;
        mode = mode_;
        chainId = chainId_;
        rateLimitDuration = 0;
    }

    function migrate() external {
        // Do nothing here, as we need to pass parameters to clear the storage
    }

    function getMigratesImmutables() public view returns (bool) {
        return false;
    }

    /// @dev Reverts if `msg.sender` is not authorized to upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyMigrator { }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                   INITIALIZABLE                                 //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/external/Initializable.sol#L80
    bytes32 private constant INITIALIZABLE_SLOT = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function _getInitializableStorageSlot() private pure returns (UUPSUpgradeable.InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_SLOT
        }
    }

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                 REENTRANCY GUARD                                //
    /////////////////////////////////////////////////////////////////////////////////////

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                     OWNABLE                                     //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/external/OwnableUpgradeable.sol#L32
    bytes32 private constant OWNER_SLOT = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    struct OwnableStorage {
        address _owner;
    }

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OWNER_SLOT
        }
    }

    function owner() external view returns (address) {
        return _getOwnableStorage()._owner;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                    PAUSABLE                                     //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/PausableUpgradeable.sol#L54
    bytes32 private constant PAUSE_SLOT = bytes32(uint256(keccak256("Pause.pauseFlag")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/PausableUpgradeable.sol#L55
    bytes32 private constant PAUSER_ROLE_SLOT = bytes32(uint256(keccak256("Pause.pauseRole")) - 1);

    struct PauserStorage {
        address _pauser;
    }

    struct PauseStorage {
        uint256 _pauseFlag;
    }

    function _getPauserStorage() internal pure returns (PauserStorage storage $) {
        uint256 slot = uint256(PAUSER_ROLE_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getPauseStorage() private pure returns (PauseStorage storage $) {
        uint256 slot = uint256(PAUSE_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function pauser() public view returns (address) {
        return _getPauserStorage()._pauser;
    }

    function isPaused() public view returns (bool) {
        PauseStorage storage $ = _getPauseStorage();
        return $._pauseFlag == 2;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                 MANAGER BASE                                    //
    /////////////////////////////////////////////////////////////////////////////////////

    bytes32 private constant MESSAGE_ATTESTATIONS_SLOT = bytes32(uint256(keccak256("ntt.messageAttestations")) - 1);

    bytes32 private constant MESSAGE_SEQUENCE_SLOT = bytes32(uint256(keccak256("ntt.messageSequence")) - 1);

    bytes32 private constant THRESHOLD_SLOT = bytes32(uint256(keccak256("ntt.threshold")) - 1);

    function _getThresholdStorage() private pure returns (Threshold storage $) {
        uint256 slot = uint256(THRESHOLD_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getMessageAttestationsStorage() internal pure returns (mapping(bytes32 => AttestationInfo) storage $) {
        uint256 slot = uint256(MESSAGE_ATTESTATIONS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getMessageSequenceStorage() internal pure returns (Sequence storage $) {
        uint256 slot = uint256(MESSAGE_SEQUENCE_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function isMessageExecuted(bytes32 digest) public view returns (bool) {
        return _getMessageAttestationsStorage()[digest].executed;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                  NTT MANAGER                                    //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/NttManager.sol#L77
    bytes32 private constant PEERS_SLOT = bytes32(uint256(keccak256("ntt.peers")) - 1);

    function _getPeersStorage() internal pure returns (mapping(uint16 => NttManagerPeer) storage $) {
        uint256 slot = uint256(PEERS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function getPeer(uint16 chainId) external view returns (NttManagerPeer memory) {
        return _getPeersStorage()[chainId];
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                     PORTAL                                      //
    /////////////////////////////////////////////////////////////////////////////////////

    mapping(address sourceToken => mapping(uint16 destinationChainId => mapping(bytes32 destinationToken => bool supported))) public
        supportedBridgingPath;

    mapping(uint16 destinationChainId => bytes32 mToken) public destinationMToken;

    /////////////////////////////////////////////////////////////////////////////////////
    //                                CLEAR STORAGE                                    //
    /////////////////////////////////////////////////////////////////////////////////////

    function clearStorage(BridgingPath[] memory bridgingPaths, bytes32[] memory digests) external onlyMigrator onlyDelegateCall {
        _clearStorage(bridgingPaths, digests);
    }

    function _clearStorage(BridgingPath[] memory bridgingPaths, bytes32[] memory digests) internal virtual {
        // Clear ReentrancyGuard storage
        delete _getReentrancyGuardStorage()._status;

        // Clear Initializable storage
        delete _getInitializableStorageSlot()._initialized;
        delete _getInitializableStorageSlot()._initializing;

        // Clear Ownable storage
        delete _getOwnableStorage()._owner;

        // Clear Pausable storage
        delete _getPauserStorage()._pauser;
        delete _getPauseStorage()._pauseFlag;

        // Clear ManagerBase storage
        delete _getThresholdStorage().num;
        delete _getMessageSequenceStorage().num;

        mapping(bytes32 => AttestationInfo) storage attestations = _getMessageAttestationsStorage();
        for (uint256 i = 0; i < digests.length; i++) {
            delete attestations[digests[i]];
        }

        // Clear Portal and NttManager storage
        for (uint256 i = 0; i < bridgingPaths.length; i++) {
            BridgingPath memory path = bridgingPaths[i];
            uint16 destinationChainId = path.destinationChainId;

            // Clear supportedBridgingPath
            delete supportedBridgingPath[path.sourceToken][destinationChainId][path.destinationToken];

            // Clear destinationMToken
            if (destinationMToken[destinationChainId] != bytes32(0)) {
                delete destinationMToken[destinationChainId];
            }

            // Clear NttManagerPeer
            mapping(uint16 => NttManagerPeer) storage peers = _getPeersStorage();
            if (peers[destinationChainId].peerAddress != bytes32(0)) {
                delete peers[destinationChainId];
            }
        }
    }
}
