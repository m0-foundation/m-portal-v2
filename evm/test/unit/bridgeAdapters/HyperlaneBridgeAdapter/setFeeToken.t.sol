// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.34;

import { IMailbox } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IMailbox.sol";
import { IHyperlaneBridgeAdapter } from "../../../../src/bridgeAdapters/hyperlane/interfaces/IHyperlaneBridgeAdapter.sol";
import { HyperlaneBridgeAdapterStorageLayout } from "../../../../src/bridgeAdapters/hyperlane/HyperlaneBridgeAdapter.sol";
import { StandardHookMetadata } from "../../../../src/bridgeAdapters/hyperlane/libraries/StandardHookMetadata.sol";
import { TypeConverter } from "../../../../src/libraries/TypeConverter.sol";

import { HyperlaneBridgeAdapterUnitTestBase } from "./HyperlaneBridgeAdapterUnitTestBase.sol";

/// @dev Mock Seismic SRC20 fee token. Mirrors sUSDC: it does NOT implement the standard
///      approve(address,uint256); only the shielded approve(address,suint256) selector is handled.
///      `suint256` is a Seismic-only type, so the standalone (stock solc) test emulates the shielded
///      approve through the fallback keyed on the selector and records the resulting allowance.
contract MockShieldedFeeToken {
    bytes4 internal constant SHIELDED_APPROVE = bytes4(keccak256("approve(address,suint256)"));

    mapping(address => mapping(address => uint256)) public allowance;

    string public constant symbol = "sUSDC";
    uint8 public constant decimals = 6;

    bool public approveReturnsFalse;

    function setApproveReturnsFalse(bool value) external {
        approveReturnsFalse = value;
    }

    fallback(bytes calldata data) external returns (bytes memory) {
        require(bytes4(data) == SHIELDED_APPROVE, "unsupported selector");
        (address spender, uint256 amount) = abi.decode(data[4:], (address, uint256));
        allowance[msg.sender][spender] = amount;
        return abi.encode(!approveReturnsFalse);
    }
}

contract SetFeeTokenUnitTest is HyperlaneBridgeAdapterUnitTestBase, HyperlaneBridgeAdapterStorageLayout {
    using TypeConverter for *;

    MockShieldedFeeToken internal feeToken;
    address internal igp = makeAddr("igp");

    // Must match HyperlaneBridgeAdapter.SHIELDED_APPROVE_SELECTOR.
    bytes4 internal constant SHIELDED_APPROVE_SELECTOR = bytes4(keccak256("approve(address,suint256)"));

    function setUp() public override {
        super.setUp();

        feeToken = new MockShieldedFeeToken();
    }

    function _enableFeeToken() internal {
        vm.prank(operator);
        adapter.setFeeToken(address(feeToken), igp);
    }

    /* ============ storage location ============ */

    function test_storageLocation_matchesErc7201Formula() external pure {
        assertEq(
            HYPERLANE_BRIDGE_ADAPTER_STORAGE_LOCATION,
            keccak256(abi.encode(uint256(keccak256("M0.storage.HyperlaneBridgeAdapter")) - 1)) & ~bytes32(uint256(0xff))
        );
    }

    function test_shieldedApproveSelector_matchesSusdc() external pure {
        // sUSDC (Seismic testnet) exposes approve(address,suint256); the standard 0x095ea7b3 is absent.
        assertEq(SHIELDED_APPROVE_SELECTOR, bytes4(0x2e62b8c8));
    }

    /* ============ setFeeToken ============ */

    function test_setFeeToken_setsTokenAndPaymaster() external {
        vm.expectEmit(true, true, false, false);
        emit IHyperlaneBridgeAdapter.FeeTokenSet(address(feeToken), igp);

        _enableFeeToken();

        assertEq(adapter.feeToken(), address(feeToken));
        assertEq(adapter.interchainGasPaymaster(), igp);
    }

    function test_setFeeToken_clearsPaymasterWhenTokenCleared() external {
        _enableFeeToken();

        // Clearing the fee token also clears the paymaster, even if one is passed.
        vm.expectEmit(true, true, false, false);
        emit IHyperlaneBridgeAdapter.FeeTokenSet(address(0), address(0));

        vm.prank(operator);
        adapter.setFeeToken(address(0), igp);

        assertEq(adapter.feeToken(), address(0));
        assertEq(adapter.interchainGasPaymaster(), address(0));
    }

    function test_setFeeToken_revertsIfZeroPaymaster() external {
        vm.expectRevert(IHyperlaneBridgeAdapter.ZeroInterchainGasPaymaster.selector);

        vm.prank(operator);
        adapter.setFeeToken(address(feeToken), address(0));
    }

    function test_setFeeToken_revertsIfNotOperator() external {
        vm.expectRevert();

        vm.prank(user);
        adapter.setFeeToken(address(feeToken), igp);
    }

    /* ============ quote / quoteFeeToken ============ */

    function test_quote_returnsZeroInFeeTokenMode() external {
        _enableFeeToken();

        assertEq(adapter.quote(SPOKE_CHAIN_ID, 250_000, "test payload"), 0);
    }

    function test_quoteFeeToken_returnsZeroInNativeMode() external view {
        assertEq(adapter.quoteFeeToken(SPOKE_CHAIN_ID, 250_000, "test payload"), 0);
    }

    function test_quoteFeeToken_returnsMailboxQuoteInFeeTokenMode() external {
        _enableFeeToken();

        uint256 fee = 5e6;
        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.quoteDispatch.selector), abi.encode(fee));

        assertEq(adapter.quoteFeeToken(SPOKE_CHAIN_ID, 250_000, "test payload"), fee);
    }

    /* ============ sendMessage ============ */

    function test_sendMessage_feeTokenMode_approvesIgpAndDispatchesWithoutValue() external {
        _enableFeeToken();

        uint256 gasLimit = 250_000;
        address refundAddress = makeAddr("refund");
        bytes memory payload = "test payload";
        uint256 fee = 5e6;

        bytes memory expectedMetadata = StandardHookMetadata.formatWithFeeToken(0, gasLimit, refundAddress, address(feeToken));
        // variant(2) + msgValue(32) + gasLimit(32) + refundAddress(20) + feeToken(20)
        assertEq(expectedMetadata.length, 106);

        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.quoteDispatch.selector), abi.encode(fee));
        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.dispatch.selector), abi.encode(bytes32("id")));

        // The adapter must approve the IGP for the fee via the shielded approve(address,suint256) selector.
        vm.expectCall(address(feeToken), abi.encodeWithSelector(SHIELDED_APPROVE_SELECTOR, igp, fee));
        // The dispatch must carry the fee token metadata and ZERO native value.
        vm.expectCall(
            address(mailbox),
            0,
            abi.encodeWithSelector(IMailbox.dispatch.selector, SPOKE_HYPERLANE_DOMAIN, peerAdapterAddress, payload, expectedMetadata)
        );

        vm.prank(address(portal));
        adapter.sendMessage(SPOKE_CHAIN_ID, gasLimit, refundAddress.toBytes32(), payload, "");

        // The IGP pulls the fee via transferFrom; the adapter approves exactly the quoted amount.
        assertEq(feeToken.allowance(address(adapter), igp), fee);
    }

    function test_sendMessage_feeTokenMode_revertsIfApproveFails() external {
        _enableFeeToken();
        feeToken.setApproveReturnsFalse(true);

        vm.mockCall(address(mailbox), abi.encodeWithSelector(IMailbox.quoteDispatch.selector), abi.encode(uint256(5e6)));

        vm.expectRevert(IHyperlaneBridgeAdapter.FeeTokenApproveFailed.selector);

        vm.prank(address(portal));
        adapter.sendMessage(SPOKE_CHAIN_ID, 250_000, makeAddr("refund").toBytes32(), "test payload", "");
    }

    function test_sendMessage_feeTokenMode_revertsIfNativeValueSent() external {
        _enableFeeToken();

        vm.expectRevert(IHyperlaneBridgeAdapter.UnexpectedNativeValue.selector);

        vm.prank(address(portal));
        adapter.sendMessage{ value: 1 }(SPOKE_CHAIN_ID, 250_000, makeAddr("refund").toBytes32(), "test payload", "");
    }

    function test_sendMessage_nativeMode_unaffected() external {
        uint256 fee = 0.001 ether;

        vm.mockCall(address(mailbox), fee, abi.encodeWithSelector(IMailbox.dispatch.selector), abi.encode(bytes32("id")));
        vm.expectCall(address(mailbox), fee, abi.encodeWithSelector(IMailbox.dispatch.selector));

        vm.prank(address(portal));
        adapter.sendMessage{ value: fee }(SPOKE_CHAIN_ID, 250_000, makeAddr("refund").toBytes32(), "test payload", "");
    }
}
