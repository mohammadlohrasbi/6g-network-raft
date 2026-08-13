#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# setup-raft.sh — سرویس ترتیب‌دهی را از solo به Raft تبدیل می‌کند.
#
# چرا این کار ارزش دارد
# ─────────────────────
# solo اصلاً اجماع نیست: یک نود ترتیب‌دهی بدون تکرار و بدون تحمل خطا.
# اگر آن کانتینر بیفتد، کل شبکه می‌ایستد. Raft اجماع واقعی است — رأی‌گیری،
# انتخاب رهبر، و تحمل خطا: خوشه‌ای با N نود، (N−1)/2 خرابی را تحمل می‌کند.
#
# و مهم‌تر برای پایان‌نامه: هزینه‌اش قابل اندازه‌گیری است. هر تراکنش باید
# پیش از کامیت در اکثریت نودها تکرار شود، پس تأخیر بالا می‌رود. آن عدد
# «بهای تحمل خطا» است و در ادبیات کمتر برای شبکه‌های 6G سنجیده شده.
#
# مسئله TLS و راه‌حلش
# ───────────────────
# مستندات فابریک صریح است: نودهای Raft یکدیگر را با TLS pinning شناسایی
# می‌کنند، پس اجرای Raft بدون TLS معتبر ممکن نیست.
#
# ولی شبکه شما TLS غیرفعال دارد و روشن کردنش کل پشته را می‌شکند: Gateway
# داشبورد، کانفیگ‌های Tape، پروفایل‌های Caliper، و همه دستورهای CLI.
#
# راه‌حل، همان چیزی است که فابریک برای این حالت پیش‌بینی کرده: **listener
# جداگانه برای خوشه**. سرویس Raft روی پورت و گواهی خودش اجرا می‌شود و
# رابط رو‌به‌کلاینت plaintext می‌ماند:
#
#     7050  →  رو‌به‌کلاینت، plaintext   ← دست‌نخورده
#     7053  →  خوشه Raft، فقط TLS       ← جدید
#
# پس هیچ‌کدام از اجزای موجود لمس نمی‌شوند.
#
# استفاده:
#   ./setup-raft.sh 3          # خوشه ۳ نودی (یک خرابی را تحمل می‌کند)
#   ./setup-raft.sh 5          # خوشه ۵ نودی (دو خرابی)
#   ./setup-raft.sh solo       # بازگشت به حالت قبل
#   DRY_RUN=1 ./setup-raft.sh 3
#
# ⚠ این اسکریپت پیکربندی را آماده می‌کند ولی شبکه را بازنمی‌سازد. تغییر
#   نوع سرویس ترتیب‌دهی، بلوک پیدایش را عوض می‌کند، پس کانال‌ها و قراردادها
#   باید از نو مستقر شوند. اسکریپت در پایان ترتیبش را می‌گوید.
# ══════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT_DIR="${ROOT_DIR:-/root/6g-network-raft}"
CONFIG_DIR="$ROOT_DIR/config"
# network.sh مواد رمزنگاری را داخل config/ می‌سازد، نه در ریشه پروژه.
CRYPTO="${CRYPTO_BASE:-$CONFIG_DIR/crypto-config}"
OORG="$CRYPTO/ordererOrganizations/example.com"
MODE="${1:-3}"
DRY_RUN="${DRY_RUN:-0}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; }

case "$MODE" in
    solo) NODES=1 ;;
    3|5|7) NODES="$MODE" ;;
    *) bad "حالت باید 3، 5، 7 یا solo باشد — دریافت شد: $MODE"; exit 1 ;;
esac

echo ""
if [ "$MODE" = "solo" ]; then
    echo "بازگشت سرویس ترتیب‌دهی به solo"
else
    echo "پیکربندی Raft با $NODES نود"
    echo "  تحمل خطا: $(( (NODES-1)/2 )) نود"
fi
[ "$DRY_RUN" = "1" ] && warn "حالت DRY_RUN — چیزی نوشته نمی‌شود"
echo "────────────────────────────────────────────"

# ── پیش‌نیازها ──
for f in "$CONFIG_DIR/configtx.yaml" "$CONFIG_DIR/docker-compose.yml"; do
    [ -f "$f" ] || { bad "$f نیست"; exit 1; }
done
ok "فایل‌های پیکربندی یافت شدند"

if [ "$MODE" != "solo" ] && [ ! -d "$OORG/orderers/orderer.example.com/msp" ]; then
    bad "مواد رمزنگاری orderer اصلی نیست — اول network.sh را اجرا کنید"
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CONFIG_DIR/.raft-backup-$STAMP"

backup() {
    [ "$DRY_RUN" = "1" ] && return
    mkdir -p "$BACKUP"
    cp "$CONFIG_DIR/configtx.yaml" "$CONFIG_DIR/docker-compose.yml" "$BACKUP/"
}

# ══ ۱) هویت نودهای جدید ══════════════════════════════════════════════
# فقط MSP. گواهی TLS کار network.sh است — اگر هر دو اسکریپت گواهی
# بسازند، نیمی از خوشه گواهی CA و نیمی خودامضا می‌گیرد و Raft که با
# pinning کار می‌کند نودها را نمی‌پذیرد. یک تولیدکننده، یک زنجیره اعتماد.
make_orderer_msp() {
    local n="$1"
    local name="orderer${n}.example.com"
    local dir="$OORG/orderers/$name"
    local src="$OORG/orderers/orderer.example.com"

    if [ -d "$dir/msp" ]; then
        ok "$name — MSP از قبل هست"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        echo "  → ساخت MSP برای $name"
        return 0
    fi
    mkdir -p "$dir/msp"
    cp -r "$src/msp/." "$dir/msp/"
    ok "$name — MSP ساخته شد"
}

if [ "$MODE" != "solo" ]; then
    echo ""
    echo "هویت نودهای خوشه"
    echo "────────────────────────────────────────────"
    for i in $(seq 2 "$NODES"); do
        make_orderer_msp "$i" || exit 1
    done
    warn "این نودها هنوز گواهی TLS ندارند"
    echo "     network.sh با ORDERER_NODES=$NODES آنها را می‌سازد؛ اگر پیش از"
    echo "     این اسکریپت اجرا شده، دوباره بزنید:"
    echo "       NETWORK_TLS=true ORDERER_NODES=$NODES ./network.sh"
fi

# ══ ۲) configtx.yaml ═════════════════════════════════════════════════
echo ""
echo "پیکربندی کانال"
echo "────────────────────────────────────────────"
backup

build_orderer_block() {
    if [ "$MODE" = "solo" ]; then
        cat <<'SOLO'
Orderer: &OrdererDefaults
  OrdererType: solo
  Addresses:
    - orderer.example.com:7050
SOLO
        return
    fi

    echo "Orderer: &OrdererDefaults"
    echo "  OrdererType: etcdraft"
    echo "  Addresses:"
    echo "    - orderer.example.com:7050"
    for i in $(seq 2 "$NODES"); do
        echo "    - orderer${i}.example.com:$((7050 + (i-1)*1000)):"
    done | sed 's/:$//'
    # مسیرها نسبی‌اند، دقیقاً مثل MSPDir در همین فایل. configtxgen روی
    # هاست اجرا می‌شود و نه داخل کانتینر، پس مسیر داخل‌کانتینری /crypto
    # برایش وجود ندارد و بلوک پیدایش ساخته نمی‌شود.
    echo "  EtcdRaft:"
    echo "    Consenters:"
    # نود اول
    echo "      - Host: orderer.example.com"
    echo "        Port: 7053"
    echo "        ClientTLSCert: ./crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/client.crt"
    echo "        ServerTLSCert: ./crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt"
    for i in $(seq 2 "$NODES"); do
        echo "      - Host: orderer${i}.example.com"
        echo "        Port: 7053"
        echo "        ClientTLSCert: ./crypto-config/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/client.crt"
        echo "        ServerTLSCert: ./crypto-config/ordererOrganizations/example.com/orderers/orderer${i}.example.com/tls/server.crt"
    done
    cat <<'RAFTOPTS'
    Options:
      TickInterval: 500ms
      ElectionTick: 10
      HeartbeatTick: 1
      MaxInflightBlocks: 5
      SnapshotIntervalSize: 16 MB
RAFTOPTS
}

if [ "$DRY_RUN" = "1" ]; then
    echo "  → جایگزینی بلوک Orderer در configtx.yaml با:"
    build_orderer_block | sed 's/^/      /'
else
    python3 - "$CONFIG_DIR/configtx.yaml" <<PYEOF
import re, sys
path = sys.argv[1]
s = open(path).read()
new = """$(build_orderer_block)"""
# بلوک از "Orderer: &OrdererDefaults" تا خط "  BatchTimeout" را عوض می‌کنیم؛
# باقی بلوک (BatchSize، Policies، Capabilities) دست‌نخورده می‌ماند.
pat = re.compile(r'^Orderer: &OrdererDefaults\n(?:.*\n)*?(?=  BatchTimeout)', re.M)
if not pat.search(s):
    print("بلوک Orderer پیدا نشد — فایل دستی عوض شده؟", file=sys.stderr)
    sys.exit(1)
s = pat.sub(new.rstrip() + "\n", s)
open(path, 'w').write(s)
PYEOF
    if [ $? -ne 0 ]; then bad "ویرایش configtx.yaml ناموفق"; exit 1; fi
    ok "configtx.yaml — نوع سرویس ترتیب‌دهی به $([ "$MODE" = solo ] && echo solo || echo "etcdraft با $NODES نود") تغییر کرد"
fi

# ══ ۳) docker-compose ════════════════════════════════════════════════
# هیچ کاری لازم نیست.
#
# نسخه اول این اسکریپت سرویس‌های orderer را خودش به فایل تزریق می‌کرد. ولی
# docker-compose.yml حالا پارامتریک است و اوردررهای ۲ تا ۵ را با
# compose profiles از قبل دارد:
#
#     orderer2, orderer3  →  profiles: ["raft", "raft5"]
#     orderer4, orderer5  →  profiles: ["raft5"]
#
# یعنی دو سازوکار موازی وجود داشت و تداخلشان همان چیزی بود که با
# «refers to undefined network» ظاهر می‌شد. حالا فقط یکی هست: profile.
echo ""
echo "کانتینرها"
echo "────────────────────────────────────────────"
if [ "$MODE" = "solo" ]; then
    ok "profile لازم نیست — docker compose up -d کافی است"
else
    PROFILE=$([ "$NODES" -gt 3 ] && echo raft5 || echo raft)
    ok "docker-compose از قبل $NODES اوردرر را با profile دارد"
    echo "     هنگام بالا آوردن: docker compose --profile $PROFILE up -d"
fi

# ══ خلاصه ════════════════════════════════════════════════════════════
echo ""
echo "────────────────────────────────────────────"
[ "$DRY_RUN" = "1" ] && { echo "DRY_RUN — برای اجرای واقعی بدون DRY_RUN بزنید"; exit 0; }
[ -d "$BACKUP" ] && echo "پشتیبان: $BACKUP"

if [ "$MODE" = "solo" ]; then
    echo -e "${GREEN}پیکربندی به solo برگشت.${NC}"
else
    echo -e "${GREEN}پیکربندی Raft با $NODES نود آماده شد.${NC}"
fi

cat <<'NEXT'

⚠ تغییر نوع سرویس ترتیب‌دهی، بلوک پیدایش را عوض می‌کند — پس شبکه باید از
  نو ساخته شود. ترتیب کامل:

    cd /root/6g-network-raft/config
    docker compose down              # بدون -v اگر می‌خواهید دفتر بماند
    docker volume ls | grep orderer  # اگر Raft جدید است، volume های
                                     # orderer باید پاک شوند

    cd ../scripts
    ./deploy-staged.sh artifacts     # بلوک پیدایش جدید
    cd ../config && docker compose up -d
    cd ../scripts
    ./deploy-staged.sh channel datachannel
    ./deploy-staged.sh list          # باید 4/4 بدهد
    ./seed-network.sh datachannel

  بررسی سلامت خوشه پس از بالا آمدن:

    docker logs orderer.example.com 2>&1 | grep -i "raft\|leader" | tail -5

  انتظار: خطی که می‌گوید کدام نود رهبر شده.
NEXT
