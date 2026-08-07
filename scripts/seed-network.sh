#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# seed-network.sh — lays out the antenna grid in every spatial contract.
#
# Each chaincode in Fabric owns an isolated state space, so a contract
# cannot see antennas registered by another one. Every location-aware
# contract therefore keeps its own registry, and each has to be seeded
# separately — 37 calls for 34 contracts, because three of them sit on two
# channels and the two copies do not share state.
#
# Placement is pseudo-random but derived entirely from the seed, so the
# same seed reproduces the same network everywhere. Use one fixed seed
# across a comparison so the layout is not a second variable; vary it
# deliberately when the question is how sensitive the results are to
# topology.
#
# Usage:
#   ./seed-network.sh                      # seed 42, 8 antennas, 10 km
#   SEED=7 ./seed-network.sh               # a different layout
#   ANTENNAS=16 GRID=20000 ./seed-network.sh
#   CAPACITY=200 ./seed-network.sh         # low cap, for admission studies
#   ./seed-network.sh datachannel          # one channel only
#   VERIFY_ONLY=1 ./seed-network.sh        # report what is seeded, change nothing
# ══════════════════════════════════════════════════════════════════════
set -e

ROOT_DIR="${ROOT_DIR:-/root/6g-network}"
SEED="${SEED:-42}"
ANTENNAS="${ANTENNAS:-8}"
GRID="${GRID:-10000}"
CAPACITY="${CAPACITY:-}"          # empty accepts the contract default
ONLY_CHANNEL="${1:-}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

declare -A ORG_PORTS=(
  [1]=7051 [2]=8051 [3]=9051 [4]=10051
  [5]=11051 [6]=12051 [7]=13051 [8]=14051
)

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
    [ ${#PAIRS[@]} -eq 0 ] && { echo -e "${RED}No spatial contracts on $ONLY_CHANNEL${NC}"; exit 1; }
fi

peer_exec() {
    local i="$1"; shift
    docker exec \
      -e CORE_PEER_LOCALMSPID="org${i}MSP" \
      -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/admin-msp \
      -e CORE_PEER_ADDRESS="peer0.org${i}.example.com:${ORG_PORTS[$i]}" \
      -e CORE_PEER_TLS_ENABLED=false \
      "peer0.org${i}.example.com" "$@"
}

PEER_ARGS=""
for i in {1..8}; do
    PEER_ARGS="$PEER_ARGS --peerAddresses peer0.org${i}.example.com:${ORG_PORTS[$i]}"
done

# ── verify mode: read the layout without touching it ──
if [ "$VERIFY_ONLY" = "1" ]; then
    echo -e "${YELLOW}Checking the antenna layout in ${#PAIRS[@]} contracts${NC}\n"
    SEEDED=0; UNSEEDED=()
    for pair in "${PAIRS[@]}"; do
        CHANNEL="${pair%%:*}"; CC="${pair##*:}"
        OUT=$(peer_exec 1 peer chaincode query -C "$CHANNEL" -n "$CC" \
                -c '{"function":"NetworkStatus","Args":[]}' 2>&1 || true)
        COUNT=$(echo "$OUT" | grep -o '"antennaID"' | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            printf "  %-22s %-34s ${GREEN}%s antennas${NC}\n" "$CHANNEL" "$CC" "$COUNT"
            SEEDED=$((SEEDED+1))
        else
            printf "  %-22s %-34s ${RED}not seeded${NC}\n" "$CHANNEL" "$CC"
            UNSEEDED+=("$pair")
        fi
    done
    echo -e "\n${SEEDED}/${#PAIRS[@]} seeded"
    [ ${#UNSEEDED[@]} -gt 0 ] && exit 1
    exit 0
fi

echo -e "${YELLOW}Seeding ${#PAIRS[@]} contracts${NC}"
echo "  seed:      $SEED"
echo "  antennas:  $ANTENNAS"
echo "  grid:      ${GRID} m"
echo "  capacity:  ${CAPACITY:-contract default}"
echo ""

OK=0; FAILED=()
for pair in "${PAIRS[@]}"; do
    CHANNEL="${pair%%:*}"
    CC="${pair##*:}"
    printf "  %-22s %-34s " "$CHANNEL" "$CC"

    ARGS="[\"${SEED}\",\"${ANTENNAS}\",\"${GRID}\",\"${CAPACITY}\"]"
    if peer_exec 1 peer chaincode invoke \
         -o orderer.example.com:7050 \
         -C "$CHANNEL" -n "$CC" \
         -c "{\"function\":\"SeedNetwork\",\"Args\":${ARGS}}" \
         $PEER_ARGS >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        OK=$((OK+1))
    else
        echo -e "${RED}✗${NC}"
        FAILED+=("$pair")
    fi
    # Serialised on purpose: eight peers on a 4 GB host will not survive
    # 37 concurrent chaincode invocations.
    sleep 0.3
done

echo -e "\n${GREEN}Seeded ${OK}/${#PAIRS[@]}${NC}"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}Failed:${NC}"
    printf '  %s\n' "${FAILED[@]}"
    echo ""
    echo "A failure here usually means the upgrade did not land on that"
    echo "channel — SeedNetwork only exists in the regenerated contracts."
    echo "Check with: ./scripts/upgrade-spatial.sh $CHANNEL"
    exit 1
fi

echo ""
echo "Layout in place. Confirm it with:"
echo "  VERIFY_ONLY=1 ./scripts/seed-network.sh"
echo ""
echo "Benchmarks must use the same seed (${SEED}); the contracts reject a"
echo "write whose seed does not match the layout they were given."
