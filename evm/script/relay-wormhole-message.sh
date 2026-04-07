#!/usr/bin/env bash
# Manually relay a Wormhole bridge message that was not delivered by the relayer.
#
# Usage:
#   ./script/relay-wormhole-message.sh <wormhole-message-id> <destination-chain> [options]
#
# Arguments:
#   wormhole-message-id   Wormhole message ID in "chain/emitter/sequence" format
#                         Example: 2/000000000000000000000000abc.../12345
#   destination-chain     Target chain name: ethereum, arbitrum, base, sonic
#
# Options:
#   --testnet             Use testnet WormholeScan API and testnet RPC URLs
#   --gas-limit <limit>   Gas limit for the transaction (default: 500000)
#   --dry-run             Fetch and decode the VAA without sending the transaction
#
# Environment (resolved by op run from .env.op):
#   PRIVATE_KEY           Private key of the relayer wallet (required unless --dry-run)
#   ETHEREUM_RPC_URL      RPC URL for Ethereum mainnet
#   ARBITRUM_RPC_URL      RPC URL for Arbitrum mainnet
#   BASE_RPC_URL          RPC URL for Base mainnet
#   SONIC_RPC_URL         RPC URL for Sonic mainnet
#   SEPOLIA_RPC_URL       RPC URL for Sepolia testnet
#   ARBITRUM_SEPOLIA_RPC_URL
#   BASE_SEPOLIA_RPC_URL
#
# Examples:
#   # Relay a message to Arbitrum (secrets injected via 1Password)
#   op run --env-file=.env.op --account=mzerolabs.1password.com -- \
#     ./script/relay-wormhole-message.sh 2/000000...abc/42 arbitrum
#
#   # Dry run (no private key needed)
#   ./script/relay-wormhole-message.sh 2/000000...abc/42 arbitrum --dry-run

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────

WORMHOLESCAN_MAINNET="https://api.wormholescan.io/api/v1/vaas"
WORMHOLESCAN_TESTNET="https://api.testnet.wormholescan.io/api/v1/vaas"

# WormholeBridgeAdapter proxy — same CREATE2 address on all chains.
ADAPTER_ADDRESS="0xaCFfEC28C4eEE21c889A4e6C0704c540eD9D4FDd"

# 1Password account for op run
OP_ACCOUNT="mzerolabs.1password.com"

# ── Defaults ─────────────────────────────────────────────────────────────────

TESTNET=false
DRY_RUN=false
GAS_LIMIT=500000

# ── Parse arguments ──────────────────────────────────────────────────────────

usage() {
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

MSG_ID="$1"
DEST_CHAIN="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --testnet)
            TESTNET=true
            shift
            ;;
        --gas-limit)
            GAS_LIMIT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage
            ;;
    esac
done

# ── Resolve RPC URL for destination chain ────────────────────────────────────

resolve_rpc_url() {
    local chain="$1"
    local testnet="$2"
    local var_name

    if [[ "$testnet" == "true" ]]; then
        case "$chain" in
            ethereum) var_name="SEPOLIA_RPC_URL" ;;
            arbitrum) var_name="ARBITRUM_SEPOLIA_RPC_URL" ;;
            base)     var_name="BASE_SEPOLIA_RPC_URL" ;;
            *)
                echo "Error: Unsupported testnet chain '$chain'. Use: ethereum, arbitrum, base" >&2
                exit 1
                ;;
        esac
    else
        case "$chain" in
            ethereum) var_name="ETHEREUM_RPC_URL" ;;
            arbitrum) var_name="ARBITRUM_RPC_URL" ;;
            base)     var_name="BASE_RPC_URL" ;;
            sonic)    var_name="SONIC_RPC_URL" ;;
            *)
                echo "Error: Unsupported chain '$chain'. Use: ethereum, arbitrum, base, sonic" >&2
                exit 1
                ;;
        esac
    fi

    local url="${!var_name:-}"
    if [[ -z "$url" ]]; then
        echo "Error: $var_name is not set. Run with: op run --env-file=.env.op --account=$OP_ACCOUNT -- $0 ..." >&2
        exit 1
    fi
    echo "$url"
}

# ── Validate inputs ─────────────────────────────────────────────────────────

# Validate message ID format: chain/emitter/sequence
if [[ ! "$MSG_ID" =~ ^[0-9]+/[0-9a-fA-Fx]+/[0-9]+$ ]]; then
    echo "Error: Invalid wormhole message ID format. Expected: chain/emitter/sequence" >&2
    echo "  Example: 2/000000000000000000000000abcdef1234567890abcdef1234567890abcdef12/42" >&2
    exit 1
fi

RPC_URL=$(resolve_rpc_url "$DEST_CHAIN" "$TESTNET")

if [[ "$DRY_RUN" == "false" && -z "${PRIVATE_KEY:-}" ]]; then
    echo "Error: PRIVATE_KEY is not set. Run with: op run --env-file=.env.op --account=$OP_ACCOUNT -- $0 ..." >&2
    exit 1
fi

# ── Fetch VAA from WormholeScan ──────────────────────────────────────────────

if [[ "$TESTNET" == "true" ]]; then
    API_URL="$WORMHOLESCAN_TESTNET/$MSG_ID"
else
    API_URL="$WORMHOLESCAN_MAINNET/$MSG_ID"
fi

echo "Fetching VAA from WormholeScan..."
echo "  URL: $API_URL"

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL")
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -1)
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "Error: WormholeScan API returned HTTP $HTTP_STATUS" >&2
    echo "$HTTP_BODY" | jq -r '.message // .' 2>/dev/null || echo "$HTTP_BODY" >&2
    exit 1
fi

# Extract base64-encoded VAA from response
VAA_BASE64=$(echo "$HTTP_BODY" | jq -r '.data.vaa // empty')

if [[ -z "$VAA_BASE64" ]]; then
    echo "Error: No VAA found in API response. The message may not be signed yet." >&2
    echo "  Guardian signatures take ~15 minutes after emission." >&2
    exit 1
fi

# Decode base64 VAA to hex
VAA_HEX="0x$(echo "$VAA_BASE64" | base64 -d | xxd -p -c 0)"

echo "VAA fetched successfully."
echo "  VAA size: $(( (${#VAA_HEX} - 2) / 2 )) bytes"

# ── Decode and display VAA header ────────────────────────────────────────────

# VAA format: version(1) | guardianSetIndex(4) | numSignatures(1) | signatures(66*n) | body...
VAA_BYTES="${VAA_HEX#0x}"
VERSION="${VAA_BYTES:0:2}"
GUARDIAN_SET_INDEX=$(printf "%d" "0x${VAA_BYTES:2:8}")
NUM_SIGNATURES=$(printf "%d" "0x${VAA_BYTES:10:2}")
SIGS_LENGTH=$((NUM_SIGNATURES * 66 * 2)) # 66 bytes per sig, 2 hex chars per byte
BODY_OFFSET=$((12 + SIGS_LENGTH))

# Body: timestamp(4) | nonce(4) | emitterChain(2) | emitterAddress(32) | sequence(8) | consistencyLevel(1) | payload
BODY="${VAA_BYTES:$BODY_OFFSET}"
TIMESTAMP=$(printf "%d" "0x${BODY:0:8}")
EMITTER_CHAIN=$(printf "%d" "0x${BODY:16:4}")
EMITTER_ADDRESS="0x${BODY:20:64}"
SEQUENCE=$(printf "%d" "0x${BODY:84:16}")

echo ""
echo "VAA Details:"
echo "  Version:            $VERSION"
echo "  Guardian Set Index: $GUARDIAN_SET_INDEX"
echo "  Num Signatures:     $NUM_SIGNATURES"
echo "  Timestamp:          $TIMESTAMP ($(date -r "$TIMESTAMP" 2>/dev/null || echo 'N/A'))"
echo "  Emitter Chain:      $EMITTER_CHAIN"
echo "  Emitter Address:    $EMITTER_ADDRESS"
echo "  Sequence:           $SEQUENCE"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "Dry run complete. VAA hex:"
    echo "  $VAA_HEX"
    exit 0
fi

# ── Send transaction ─────────────────────────────────────────────────────────

echo ""
echo "Sending executeVAAv1 transaction..."
echo "  Chain:     $DEST_CHAIN"
echo "  Adapter:   $ADAPTER_ADDRESS"
echo "  Gas Limit: $GAS_LIMIT"

cast send \
    "$ADAPTER_ADDRESS" \
    "executeVAAv1(bytes)" \
    "$VAA_HEX" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --gas-limit "$GAS_LIMIT"

echo ""
echo "Message relayed successfully."
