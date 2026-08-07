#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# upgrade-spatial.sh — installs the regenerated location-aware contracts.
#
# The 34 spatial contracts now select their own serving cell, compute SINR
# and enforce admission control, so their code and their signatures have
# both changed. Fabric versions chaincode per channel, so each one has to
# be packaged, installed on all eight peers, approved and committed at a
# new sequence number.
#
# The channel definitions, the genesis block and the other 52 contracts are
# untouched — this is a chaincode upgrade, not a network rebuild.
#
# Usage:
#   ./upgrade-spatial.sh              # upgrade everything that changed
#   ./upgrade-spatial.sh datachannel  # just one channel
#   DRY_RUN=1 ./upgrade-spatial.sh    # show the plan and stop
# ══════════════════════════════════════════════════════════════════════
set -e

ROOT_DIR="${ROOT_DIR:-/root/6g-network}"
CC_VERSION="${CC_VERSION:-v2}"
DRY_RUN="${DRY_RUN:-0}"
ONLY_CHANNEL="${1:-}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

cd "$ROOT_DIR"

# channel:contract pairs for every regenerated contract. Four of them sit on
# two channels and must be upgraded separately on each — the state spaces
# are independent.
PAIRS=(
    "managementchannel:LocationBasedAntennaConfig"
    "managementchannel:LocationBasedPowerManagement"
    "managementchannel:LocationBasedChannelAllocation"
    "datachannel:LocationBasedAssignment"
    "datachannel:LocationBasedBandwidth"
    "datachannel:LocationBasedSignalStrength"
    "datachannel:LocationBasedSignalQuality"
    "connectivitychannel:LocationBasedConnection"
    "connectivitychannel:LocationBasedRoaming"
    "iotchannel:LocationBasedIoTConnection"
    "iotchannel:LocationBasedIoTBandwidth"
    "iotchannel:LocationBasedIoTStatus"
    "iotchannel:LocationBasedIoTFault"
    "iotchannel:LocationBasedIoTSession"
    "analyticschannel:LocationBasedQoS"
    "analyticschannel:LocationBasedCoverage"
    "analyticschannel:LocationBasedEnergy"
    "networkchannel:LocationBasedNetworkLoad"
    "networkchannel:LocationBasedNetworkHealth"
    "resourcechannel:LocationBasedResourceAllocation"
    "resourcechannel:LocationBasedIoTResource"
    "performancechannel:LocationBasedLatency"
    "authchannel:LocationBasedIoTAuthentication"
    "sessionchannel:LocationBasedSessionManagement"
    "sessionchannel:LocationBasedIoTSession"
    "monitoringchannel:LocationBasedStatus"
    "optimizationchannel:LocationBasedDynamicRouting"
    "faultchannel:LocationBasedFault"
    "faultchannel:LocationBasedIoTFault"
    "trafficchannel:LocationBasedTraffic"
    "trafficchannel:LocationBasedCongestion"
    "accesschannel:LocationBasedIoTRegistration"
    "accesschannel:LocationBasedIoTRevocation"
    "compliancechannel:LocationBasedPriority"
    "integrationchannel:LocationBasedInterference"
    "integrationchannel:LocationBasedSignalStrength"
    "integrationchannel:LocationBasedUserActivity"
)

if [ -n "$ONLY_CHANNEL" ]; then
    FILTERED=()
    for p in "${PAIRS[@]}"; do
        [ "${p%%:*}" = "$ONLY_CHANNEL" ] && FILTERED+=("$p")
    done
    PAIRS=("${FILTERED[@]}")
    if [ ${#PAIRS[@]} -eq 0 ]; then
        echo -e "${RED}No regenerated contracts on channel $ONLY_CHANNEL${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}Upgrading ${#PAIRS[@]} chaincodes to ${CC_VERSION}${NC}"
if [ "$DRY_RUN" = "1" ]; then
    printf '  %s\n' "${PAIRS[@]}"
    echo "DRY_RUN set — nothing was changed."
    exit 0
fi

# ── environment ──
# Matched to deploy-staged.sh / deploy_functions.sh: eight peers reached over
# plaintext gRPC through docker exec, one signature enough to commit.
declare -A ORG_PORTS=(
  [1]=7051 [2]=8051 [3]=9051 [4]=10051
  [5]=11051 [6]=12051 [7]=13051 [8]=14051
)
CC_POLICY="${CC_POLICY:-OR('org1MSP.member','org2MSP.member','org3MSP.member','org4MSP.member','org5MSP.member','org6MSP.member','org7MSP.member','org8MSP.member')}"
CHAINCODE_DIR="${CHAINCODE_DIR:-${ROOT_DIR}/chaincode}"

peer_exec() {
    local i="$1"; shift
    docker exec \
      -e CORE_PEER_LOCALMSPID="org${i}MSP" \
      -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/admin-msp \
      -e CORE_PEER_ADDRESS="peer0.org${i}.example.com:${ORG_PORTS[$i]}" \
      -e CORE_PEER_TLS_ENABLED=false \
      "peer0.org${i}.example.com" "$@"
}

# ── verify the contracts were regenerated before anything is committed ──
MISSING=()
for pair in "${PAIRS[@]}"; do
    CC="${pair##*:}"
    if ! grep -q "func (s \*${CC}) SeedNetwork(" "${CHAINCODE_DIR}/${CC}/chaincode.go" 2>/dev/null; then
        MISSING+=("$CC")
    fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${RED}These contracts have not been regenerated:${NC}"
    printf '  %s\n' "${MISSING[@]}"
    echo "Run: ./scripts/generateChaincodes_spatial.sh"
    exit 1
fi

# ── package and install, once per contract ──
LABEL="_${CC_VERSION}"
declare -A PKGID
BUILT=""
for pair in "${PAIRS[@]}"; do
    CC="${pair##*:}"
    case " $BUILT " in *" $CC "*) continue ;; esac
    BUILT="$BUILT $CC"

    echo -e "\n${YELLOW}▶ packaging ${CC}${NC}"
    DIR="${CHAINCODE_DIR}/${CC}"
    TAR="/tmp/${CC}${LABEL}.tar.gz"

    (cd "$DIR" && go mod tidy >/dev/null 2>&1 && go mod vendor >/dev/null 2>&1)
    rm -f "$TAR"
    docker run --rm \
      -v "$DIR":/chaincode/input:ro -v /tmp:/hosttmp \
      hyperledger/fabric-tools:2.5 \
      peer lifecycle chaincode package "/hosttmp/${CC}${LABEL}.tar.gz" \
        --path /chaincode/input --lang golang --label "${CC}${LABEL}" \
      || { echo -e "${RED}packaging ${CC} failed — it probably does not compile${NC}"; exit 1; }

    [ ! -f "$TAR" ] && { echo -e "${RED}no package produced for ${CC}${NC}"; exit 1; }

    for i in {1..8}; do
        docker cp "$TAR" "peer0.org${i}.example.com:/tmp/${CC}${LABEL}.tar.gz" >/dev/null
        peer_exec "$i" peer lifecycle chaincode install "/tmp/${CC}${LABEL}.tar.gz" >/dev/null 2>&1 &
    done
    wait

    PKGID[$CC]=$(peer_exec 1 peer lifecycle chaincode queryinstalled 2>/dev/null \
                 | grep -oP "Package ID: \K[^,]*${CC}${LABEL}[^,]*" | head -1)
    if [ -z "${PKGID[$CC]}" ]; then
        echo -e "${RED}could not read the package id for ${CC}${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓ installed on 8 peers${NC}"
done

# ── approve and commit, once per channel ──
OK=0; FAILED=()
for pair in "${PAIRS[@]}"; do
    CHANNEL="${pair%%:*}"
    CC="${pair##*:}"
    echo -e "\n${YELLOW}▶ ${CC} on ${CHANNEL}${NC}"

    # The sequence must advance from whatever is committed now; a fresh
    # channel has none, in which case it starts at 1.
    SEQ=$(peer_exec 1 peer lifecycle chaincode querycommitted \
            --channelID "$CHANNEL" --name "$CC" 2>/dev/null \
          | grep -oP 'Sequence: \K[0-9]+' | head -1)
    NEXT=$(( ${SEQ:-0} + 1 ))
    echo "  sequence ${SEQ:-none} → ${NEXT}"

    for i in {1..8}; do
        peer_exec "$i" peer lifecycle chaincode approveformyorg \
          -o orderer.example.com:7050 \
          --channelID "$CHANNEL" --name "$CC" --version "$CC_VERSION" \
          --package-id "${PKGID[$CC]}" --sequence "$NEXT" \
          --signature-policy "$CC_POLICY" >/dev/null 2>&1 &
    done
    wait

    PEER_ARGS=""
    for i in {1..8}; do
        PEER_ARGS="$PEER_ARGS --peerAddresses peer0.org${i}.example.com:${ORG_PORTS[$i]}"
    done

    if peer_exec 1 peer lifecycle chaincode commit \
         -o orderer.example.com:7050 \
         --channelID "$CHANNEL" --name "$CC" --version "$CC_VERSION" \
         --sequence "$NEXT" --signature-policy "$CC_POLICY" \
         $PEER_ARGS >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ committed${NC}"
        OK=$((OK+1))
    else
        echo -e "  ${RED}✗ commit failed${NC}"
        FAILED+=("$pair")
    fi

    # Old dev containers keep memory that this host does not have spare.
    ids=$(docker ps -aq --filter "name=dev-peer.*-${CC}_" 2>/dev/null | head -20)
    [ -n "$ids" ] && docker rm -f $ids >/dev/null 2>&1 || true
done

echo -e "\n${GREEN}Upgraded ${OK}/${#PAIRS[@]}${NC}"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}Failed:${NC}"
    printf '  %s\n' "${FAILED[@]}"
    exit 1
fi

echo ""
echo "Next: seed the antenna layout before benchmarking —"
echo "  ./scripts/seed-network.sh"
echo "Nothing spatial will accept a write until that has run."
