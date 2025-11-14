// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.30;

import {
    AccessControlUpgradeable
} from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "../../../lib/common/lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IBridgeAdapter } from "../../interfaces/IBridgeAdapter.sol";
import { IPortal } from "../../interfaces/IPortal.sol";
import { IExecutor } from "./interfaces/IExecutor.sol";
import { ICoreBridge } from "./interfaces/ICoreBridge.sol";

contract WormholeBridgeAdapter {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable coreBridge;

    /// @inheritdoc IWormholeBridgeAdapter
    address public immutable executor;

    /// @inheritdoc IWormholeBridgeAdapter
    uint8 public immutable finality;

    constructor(address coreBridge_, address executor_, uint8 finality_) {
        _disableInitializers();

        if ((coreBridge = coreBridge_) == address(0)) revert ZeroCoreBridge();
        if ((executor = executor_) == address(0)) revert ZeroExecutor();
        finality = finality_;
    }

    function initialize(address initialAdmin, address initialOperator) external initializer {
        if (admin == address(0)) revert ZeroAdmin();
        if (operator == address(0)) revert ZeroOperator();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, operator);
    }
}



