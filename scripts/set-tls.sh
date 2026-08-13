#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# set-tls.sh — TLS را روشن یا خاموش می‌کند.
#
# جانشین enable-tls.sh است و کار بسیار کمتری می‌کند، چون حالا خود فایل‌ها
# پارامتریک‌اند:
#
#   docker-compose.yml   TLS_ENABLED=${NETWORK_TLS} می‌خواند و پوشه
#                        گواهی هر نود را همیشه mount می‌کند
#   network.sh           گواهی همه نودها را همیشه می‌سازد
#
# پس تنها چیزی که می‌ماند: یک خط در .env، فلگ دستورهای CLI، و متغیر
# سرویس داشبورد.
#
#   ./set-tls.sh on
#   ./set-tls.sh off
# ══════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT_DIR="${ROOT_DIR:-/root/6g-network-raft}"
CONFIG="$ROOT_DIR/config"
SCRIPTS="$ROOT_DIR/scripts"
MODE="${1:-on}"
C_TLS_PEER="/etc/hyperledger/fabric/tls"
# مسیر گواهی ریشه orderer **از دید کانتینر peer**.
#
# دستورهای peer داخل کانتینر peer اجرا می‌شوند، نه orderer. مسیر
# /var/hyperledger/orderer/tls فقط داخل خود orderer وجود دارد، پس
# --cafile با آن مسیر شکست می‌خورد:
#
#     unable to load orderer.tls.rootcert.file: no such file or directory
#
# docker-compose همان پوشه را با نام دیگری در peer ها هم mount می‌کند.
ORD_CA="/etc/hyperledger/fabric/orderer-tls/ca.crt"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok()  { echo -e "  ${GREEN}✓${NC} $*"; }
die() { echo -e "  ${RED}✗${NC} $*"; exit 1; }

case "$MODE" in on|off) ;; *) die "حالت باید on یا off باشد" ;; esac
# .env اگر نبود ساخته می‌شود. network.sh پوشه config را بازسازی می‌کند و
# آن را با خود می‌برد، پس مردن اینجا یعنی راه‌اندازی از صفر همیشه در گام
# سوم متوقف شود — در حالی که تنها کار لازم نوشتن یک خط است.
[ -d "$CONFIG" ] || die "$CONFIG نیست — اول network.sh را اجرا کنید"
if [ ! -f "$CONFIG/.env" ]; then
    printf '# پیکربندی شبکه — docker-compose از اینجا می‌خواند\nNETWORK_TLS=false\n' \
        > "$CONFIG/.env"
    ok ".env ساخته شد"
fi

echo ""
echo "$([ "$MODE" = on ] && echo روشن || echo خاموش) کردن TLS"
echo "────────────────────────────────────────────"

# ── ۱) .env ──
VAL=$([ "$MODE" = on ] && echo true || echo false)
if grep -q "^NETWORK_TLS=" "$CONFIG/.env"; then
    sed -i "s/^NETWORK_TLS=.*/NETWORK_TLS=$VAL/" "$CONFIG/.env"
else
    echo "NETWORK_TLS=$VAL" >> "$CONFIG/.env"
fi
ok ".env → NETWORK_TLS=$VAL"

# ── ۲) فلگ دستورهای CLI ──
# دو دسته با دو نیاز متفاوت: آنهایی که با orderer حرف می‌زنند گواهی
# اوردرر می‌خواهند، آنهایی که فقط با peer کار دارند ریشه اعتماد peer.
for f in deploy_functions.sh deploy-staged.sh seed-network.sh upgrade-spatial.sh; do
    p="$SCRIPTS/$f"
    [ -f "$p" ] || continue
    sed -i "s| --tls --cafile [^ ]*||g" "$p"
    sed -i "/^ *-e CORE_PEER_TLS_ROOTCERT_FILE=[^ ]* \\\\$/d" "$p"
    sed -i "s|-e CORE_PEER_TLS_ENABLED=true|-e CORE_PEER_TLS_ENABLED=false|g" "$p"
    if [ "$MODE" = "on" ]; then
        sed -i "s|\(peer channel create\)|\1 --tls --cafile $ORD_CA|g;
                s|\(peer channel update\)|\1 --tls --cafile $ORD_CA|g;
                s|\(chaincode approveformyorg\)|\1 --tls --cafile $ORD_CA|g;
                s|\(chaincode commit\)|\1 --tls --cafile $ORD_CA|g;
                s|\(peer chaincode invoke\)|\1 --tls --cafile $ORD_CA|g" "$p"
        sed -i "s|-e CORE_PEER_TLS_ENABLED=false|-e CORE_PEER_TLS_ENABLED=true|g" "$p"
        sed -i "s|^\( *\)\(-e CORE_PEER_ADDRESS=\)|\1-e CORE_PEER_TLS_ROOTCERT_FILE=$C_TLS_PEER/ca.crt \\\\\n\1\2|g" "$p"
    fi
    ok "$f"
done

# ── ۳) سرویس داشبورد ──
# config.js مقدار tlsEnabled را از این متغیر می‌خواند، و bench-runner و
# gen-caliper-network هر دو از config.js تبعیت می‌کنند.
UNIT="/etc/systemd/system/dashboard.service.d/tls.conf"
if [ "$MODE" = "on" ]; then
    mkdir -p "$(dirname "$UNIT")"
    printf '[Service]\nEnvironment=CORE_PEER_TLS_ENABLED=true\n' > "$UNIT"
else
    rm -f "$UNIT"
fi
systemctl daemon-reload 2>/dev/null
ok "سرویس داشبورد"

echo ""
echo -e "${GREEN}TLS $([ "$MODE" = on ] && echo روشن || echo خاموش) شد.${NC}"
cat <<NEXT

اعمال:
  cd $CONFIG && docker compose down && docker compose up -d
  systemctl restart dashboard
  cd $SCRIPTS && node gen-caliper-network.js && ./fix-tape-policy.sh

بررسی:
  docker exec peer0.org1.example.com env | grep TLS_ENABLED
NEXT
