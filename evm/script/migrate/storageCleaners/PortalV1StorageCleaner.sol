// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { NttManagerPeer, AttestationInfo, Mode, Sequence, Threshold, TransceiverInfo } from "../portalV1/IPortalV1.sol";

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
    address public constant TRANSCEIVER = 0x0763196A091575adF99e2306E5e90E0Be5154841;

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
    //                                 IMPLEMENTATION                                  //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/Implementation.sol#L36
    bytes32 private constant MIGRATING_SLOT = bytes32(uint256(keccak256("ntt.migrating")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/libraries/Implementation.sol#L38
    bytes32 private constant MIGRATES_IMMUTABLES_SLOT = bytes32(uint256(keccak256("ntt.migratesImmutables")) - 1);

    struct _Migrating {
        bool isMigrating;
    }

    struct _Bool {
        bool value;
    }

    function _getMigratingStorage() private pure returns (_Migrating storage $) {
        uint256 slot = uint256(MIGRATING_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getMigratesImmutablesStorage() internal pure returns (_Bool storage $) {
        uint256 slot = uint256(MIGRATES_IMMUTABLES_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
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
    //                            TRANSCEIVER REGISTRY                                 //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/TransceiverRegistry.sol#L81
    bytes32 private constant TRANSCEIVER_INFOS_SLOT = bytes32(uint256(keccak256("ntt.transceiverInfos")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/TransceiverRegistry.sol#L84
    bytes32 private constant TRANSCEIVER_BITMAP_SLOT = bytes32(uint256(keccak256("ntt.transceiverBitmap")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/TransceiverRegistry.sol#L87
    bytes32 private constant ENABLED_TRANSCEIVERS_SLOT = bytes32(uint256(keccak256("ntt.enabledTransceivers")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/TransceiverRegistry.sol#L90
    bytes32 private constant REGISTERED_TRANSCEIVERS_SLOT = bytes32(uint256(keccak256("ntt.registeredTransceivers")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/TransceiverRegistry.sol#L93
    bytes32 private constant NUM_REGISTERED_TRANSCEIVERS_SLOT = bytes32(uint256(keccak256("ntt.numRegisteredTransceivers")) - 1);

    /// @dev Bitmap encoding the enabled transceivers.
    /// invariant: forall (i: uint8), enabledTransceiverBitmap & i == 1 <=> transceiverInfos[i].enabled
    struct _EnabledTransceiverBitmap {
        uint64 bitmap;
    }

    /// @dev Total number of registered transceivers. This number can only increase.
    /// invariant: numRegisteredTransceivers <= MAX_TRANSCEIVERS
    /// invariant: forall (i: uint8),
    ///   i < numRegisteredTransceivers <=> exists (a: address), transceiverInfos[a].index == i
    struct _NumTransceivers {
        uint8 registered;
        uint8 enabled;
    }

    function _getTransceiverInfosStorage() internal pure returns (mapping(address => TransceiverInfo) storage $) {
        uint256 slot = uint256(TRANSCEIVER_INFOS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getEnabledTransceiversStorage() internal pure returns (address[] storage $) {
        uint256 slot = uint256(ENABLED_TRANSCEIVERS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getTransceiverBitmapStorage() private pure returns (_EnabledTransceiverBitmap storage $) {
        uint256 slot = uint256(TRANSCEIVER_BITMAP_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getRegisteredTransceiversStorage() internal pure returns (address[] storage $) {
        uint256 slot = uint256(REGISTERED_TRANSCEIVERS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getNumTransceiversStorage() internal pure returns (_NumTransceivers storage $) {
        uint256 slot = uint256(NUM_REGISTERED_TRANSCEIVERS_SLOT);
        assembly ("memory-safe") {
            $.slot := slot
        }
    }

    function _getEnabledTransceiversBitmap() internal view virtual returns (uint64 bitmap) {
        return _getTransceiverBitmapStorage().bitmap;
    }

    function getTransceivers() external pure returns (address[] memory result) {
        result = _getEnabledTransceiversStorage();
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                                 MANAGER BASE                                    //
    /////////////////////////////////////////////////////////////////////////////////////

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/ManagerBase.sol#L61
    bytes32 private constant MESSAGE_ATTESTATIONS_SLOT = bytes32(uint256(keccak256("ntt.messageAttestations")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/ManagerBase.sol#L64
    bytes32 private constant MESSAGE_SEQUENCE_SLOT = bytes32(uint256(keccak256("ntt.messageSequence")) - 1);

    /// @dev https://github.com/m0-foundation/native-token-transfers/blob/main/evm/src/NttManager/ManagerBase.sol#L67
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

        // Clear Implementation storage
        delete _getMigratingStorage().isMigrating;
        delete _getMigratesImmutablesStorage().value;

        // Clear Ownable storage
        delete _getOwnableStorage()._owner;

        // Clear Pausable storage
        delete _getPauserStorage()._pauser;
        delete _getPauseStorage()._pauseFlag;

        // Only one transceiver is registered and enabled in PortalV1
        assert(_getNumTransceiversStorage().enabled == 1);
        assert(_getNumTransceiversStorage().registered == 1);

        // Clear TransceiverRegistry storage
        delete _getTransceiverInfosStorage()[TRANSCEIVER];
        _getEnabledTransceiversStorage().pop();
        _getRegisteredTransceiversStorage().pop();
        delete _getTransceiverBitmapStorage().bitmap;
        delete _getNumTransceiversStorage().enabled;
        delete _getNumTransceiversStorage().registered;

        // Clear ManagerBase storage
        delete _getThresholdStorage().num;
        delete _getMessageSequenceStorage().num;

        mapping(bytes32 => AttestationInfo) storage attestations = _getMessageAttestationsStorage();
        for (uint256 i = 0; i < digests.length; i++) {
            delete attestations[digests[i]];
        }

        mapping(uint16 => NttManagerPeer) storage peers = _getPeersStorage();

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
            if (peers[destinationChainId].peerAddress != bytes32(0)) {
                delete peers[destinationChainId];
            }
        }
    }
}
