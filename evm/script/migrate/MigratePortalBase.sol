// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import { Script } from "../../lib/forge-std/src/Script.sol";
import { Vm } from "../../lib/forge-std/src/Vm.sol";

import { TypeConverter } from "../../src/libraries/TypeConverter.sol";

import { IPortalV1 } from "./portalV1/IPortalV1.sol";
import { BridgingPath } from "./storageCleaners/PortalV1StorageCleaner.sol";

abstract contract MigratePortalBase is Script {
    using TypeConverter for *;

    // Wormhole chain IDs
    uint16 internal constant WORMHOLE_ETHEREUM_CHAIN_ID = 2;
    uint16 internal constant WORMHOLE_ARBITRUM_CHAIN_ID = 23;
    uint16 internal constant WORMHOLE_OPTIMISM_CHAIN_ID = 24;
    uint16 internal constant WORMHOLE_BASE_CHAIN_ID = 30;

    // Portal V1 Access control addresses
    address constant OWNER_V1 = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;
    address constant PAUSER_V1 = 0xF2f1ACbe0BA726fEE8d75f3E32900526874740BB;

    // Existing contract addresses
    address constant PORTAL = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
    address constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address constant REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address constant SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;
    // Dummy address as ORDER_BOOK isn't deployed yet
    address ORDER_BOOK = makeAddr("ORDER_BOOK");
    address constant MERKLE_TREE_BUILDER = 0xCab755D715f312AD946d6982b8778BFAD7E322d7;
    address constant WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    // Portal V2 Access control addresses
    address constant ADMIN_V2 = OWNER_V1;
    address constant PAUSER_V2 = PAUSER_V1;
    address constant OPERATOR_V2 = 0xb7A9B5f301eF3bAD36C2b4964E82931Dd7fb989C;

    /// @notice Returns the block number when Portal V1 was deployed.
    /// @dev    Used for event log queries. Must be overridden in derived contracts.
    function _portalDeployBlock() internal view virtual returns (uint256) { }

    /// @notice Returns all configured bridging paths in Portal V1
    /// @dev    Must be obtained from `SupportedBridgingPathSet` events or hardcoded
    function _getBridgingPaths() internal virtual returns (BridgingPath[] memory bridgingPaths) {
        Vm.EthGetLogs[] memory logs = _getPortalLogs(IPortalV1.SupportedBridgingPathSet.selector, _portalDeployBlock());
        bridgingPaths = new BridgingPath[](logs.length);
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.EthGetLogs memory log = logs[i];
            bridgingPaths[i] = BridgingPath(log.topics[1].toAddress(), uint16(uint256(log.topics[2])), log.topics[3]);
        }
    }

    /// @notice Returns all received Wormhole Message Id (aka digests) in Portal V1
    /// @dev    Must be obtained from `MessageAttestedTo` events or hardcoded
    function _getWormholeMessageDigests() internal virtual returns (bytes32[] memory digests) {
        Vm.EthGetLogs[] memory logs = _getPortalLogs(IPortalV1.MessageAttestedTo.selector, _portalDeployBlock());
        digests = new bytes32[](logs.length);
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.EthGetLogs memory log = logs[i];
            (bytes32 digest,,) = abi.decode(log.data, (bytes32, address, uint8));
            digests[i] = digest;
        }
    }

    function _getPortalLogs(bytes32 topic, uint256 fromBlock) internal returns (Vm.EthGetLogs[] memory logs) {
        bytes32[] memory topics = new bytes32[](1);
        topics[0] = topic;
        logs = vm.eth_getLogs(fromBlock, block.number, PORTAL, topics);
    }
}
