// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// NTT Manager Structs
struct RateLimitParams {
    uint72 limit;
    uint72 currentCapacity;
    uint64 lastTxTimestamp;
}

struct InboundQueuedTransfer {
    uint72 amount;
    uint64 txTimestamp;
    address recipient;
}

struct OutboundQueuedTransfer {
    bytes32 recipient;
    bytes32 refundAddress;
    uint72 amount;
    uint64 txTimestamp;
    uint16 recipientChain;
    address sender;
    bytes transceiverInstructions;
}

struct NttManagerPeer {
    bytes32 peerAddress;
    uint8 tokenDecimals;
}

struct TransceiverInfo {
    bool registered;
    bool enabled;
    uint8 index;
}

/// @notice Information about attestations for a given message.
/// @dev The fields are as follows:
///      - executed: whether the message has been executed.
///      - attested: bitmap of transceivers that have attested to this message.
///                  (NOTE: might contain disabled transceivers)
struct AttestationInfo {
    bool executed;
    uint64 attestedTransceivers;
}

struct Sequence {
    uint64 num;
}

struct Threshold {
    uint8 num;
}

enum Mode {
    LOCKING,
    BURNING
}

/// @dev View and pure functions common to HubPortalV1 and SpokePortalV1
interface IPortalV1 {
    // Constants/Immutables
    function NTT_MANAGER_VERSION() external view returns (string memory);
    function chainId() external view returns (uint16);
    function getMode() external view returns (uint8);
    function mode() external view returns (uint8);
    function rateLimitDuration() external view returns (uint64);

    // Ownable
    function owner() external view returns (address);

    // Pauseable
    function pauser() external view returns (address);
    function isPaused() external view returns (bool);
    function pause() external;

    // Implementation
    function getMigratesImmutables() external view returns (bool);

    // RateLimiter - ALL STORAGE IS ALREADY EMPTY as Portal derives from NttManagerNoRateLimiting
    function getCurrentInboundCapacity(uint16) external pure returns (uint256);
    function getCurrentOutboundCapacity() external pure returns (uint256);
    function getInboundLimitParams(uint16) external pure returns (RateLimitParams memory);
    function getOutboundLimitParams() external pure returns (RateLimitParams memory);
    function getInboundQueuedTransfer(bytes32) external pure returns (InboundQueuedTransfer memory);
    function getOutboundQueuedTransfer(uint64) external pure returns (OutboundQueuedTransfer memory);

    // TransceiverRegistry
    function getTransceiverInfo() external view returns (TransceiverInfo[] memory);
    function getTransceivers() external pure returns (address[] memory result);

    // ManagerBase
    event MessageAttestedTo(bytes32 digest, address transceiver, uint8 index);

    function token() external view returns (address);
    function messageAttestations(bytes32 digest) external view returns (uint8 count);
    function nextMessageSequence() external view returns (uint64);
    function getThreshold() external view returns (uint8);
    function transceiverAttestedToMessage(bytes32 digest, uint8 index) external view returns (bool);
    function isMessageExecuted(bytes32 digest) external view returns (bool);

    function upgrade(address newImplementation) external;

    // NttManager
    function tokenDecimals() external view returns (uint8);
    function getPeer(uint16 chainId) external view returns (NttManagerPeer memory);

    // Portal
    event SupportedBridgingPathSet(
        address indexed sourceToken, uint16 indexed destinationChainId, bytes32 indexed destinationToken, bool supported
    );

    function currentIndex() external view returns (uint128);
    function destinationMToken(uint16 destinationChainId) external view returns (bytes32 mToken);
    function mToken() external view returns (address);
    function registrar() external view returns (address);
    function supportedBridgingPath(
        address sourceToken,
        uint16 destinationChainId,
        bytes32 destinationToken
    ) external view returns (bool supported);
    function swapFacility() external view returns (address);
}
