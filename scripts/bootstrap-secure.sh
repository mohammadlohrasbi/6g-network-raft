#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# bootstrap-secure.sh — راه‌اندازی شبکه از صفر با TLS کامل و Raft.
#
# چرا این اسکریپت وجود دارد
# ─────────────────────────
# سه قطعه باید به ترتیب درست اجرا شوند، وگرنه بی‌صدا شکست می‌خورند:
#
#   network.sh    مواد رمزنگاری و MSP می‌سازد
#   setup-raft.sh نودهای اضافی و configtx را می‌سازد
#   set-tls.sh گواهی TLS همه نودها را صادر می‌کند
#
# ترتیب اهمیت دارد چون setup-raft پوشه نودهای جدید را می‌سازد و set-tls
# باید بعد از آن بیاید تا گواهی همه‌شان را از یک CA صادر کند. اگر برعکس
# شود، نودهای جدید گواهی ندارند و Raft — که با pinning کار می‌کند —
# آنها را نمی‌پذیرد.
#
# و بلوک پیدایش باید پس از هر دو ساخته شود، چون هم نوع سرویس ترتیب‌دهی و
# هم مسیر گواهی consenter ها را در خود دارد.
#
# استفاده:
#   ./bootstrap-secure.sh              # ۳ نود Raft، TLS کامل، datachannel
#   NODES=5 ./bootstrap-secure.sh
#   CHANNELS="datachannel auditchannel" ./bootstrap-secure.sh
#   CHANNELS=all ./bootstrap-secure.sh          # هر ۲۰ کانال (طولانی)
#   SKIP_NETWORK=1 ./bootstrap-secure.sh        # اگر crypto از قبل هست
#   DRY_RUN=1 ./bootstrap-secure.sh
#
# ⚠ این اسکریپت شبکه موجود را پاک می‌کند. دفتر فعلی از بین می‌رود.
# ══════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT_DIR="${ROOT_DIR:-/root/6g-network-raft}"
SCRIPTS="$ROOT_DIR/scripts"
CONFIG="$ROOT_DIR/config"
NODES="${NODES:-3}"
CHANNELS="${CHANNELS:-datachannel}"
DRY_RUN="${DRY_RUN:-0}"
SKIP_NETWORK="${SKIP_NETWORK:-0}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step()  { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }
ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
warn()  { echo -e "  ${YELLOW}!${NC} $*"; }
die()   { echo -e "  ${RED}✗${NC} $*"; exit 1; }
run()   { if [ "$DRY_RUN" = "1" ]; then echo "    \$ $*"; else "$@"; fi; }

echo ""
echo "════════════════════════════════════════════"
echo " راه‌اندازی شبکه 6G از صفر"
echo "   Raft با $NODES نود | TLS کامل"
echo "   کانال‌ها: $CHANNELS"
echo "════════════════════════════════════════════"
[ "$DRY_RUN" = "1" ] && warn "DRY_RUN — فقط دستورها نشان داده می‌شوند"

# ── پیش‌نیازها ──
step "بررسی پیش‌نیازها"
for s in network.sh setup-raft.sh set-tls.sh deploy-staged.sh seed-network.sh; do
    [ -f "$SCRIPTS/$s" ] || die "$s نیست"
done
ok "اسکریپت‌ها"
for t in docker go node openssl; do
    command -v "$t" >/dev/null 2>&1 || die "$t نصب نیست"
done
ok "ابزارها"
docker compose version >/dev/null 2>&1 || die "docker compose v2 لازم است"
ok "docker compose v2"

FREE_MB=$(free -m | awk '/^Mem:/{print $7}')
NEEDED=$((1200 + NODES * 200))
if [ "$FREE_MB" -lt "$NEEDED" ]; then
    warn "حافظه آزاد ${FREE_MB}MB — برای $NODES نود حدود ${NEEDED}MB توصیه می‌شود"
    warn "اگر OOM دیدید، NODES=3 را امتحان کنید"
else
    ok "حافظه: ${FREE_MB}MB آزاد"
fi

# ── هشدار پاک شدن ──
if [ "$DRY_RUN" != "1" ] && [ "$SKIP_NETWORK" != "1" ]; then
    echo ""
    warn "این کار شبکه فعلی و کل دفتر را پاک می‌کند."
    warn "نتایج بنچمارک در test-tools/bench-runs دست‌نخورده می‌مانند."
    read -r -p "  ادامه؟ (بنویسید yes) " reply
    [ "$reply" = "yes" ] || { echo "لغو شد."; exit 0; }
fi

cd "$SCRIPTS" || die "به $SCRIPTS نمی‌رود"

# ── ۰) هم‌راستاسازی مسیرها ──
# چند اسکریپت مخزن مسیر پروژه را ثابت در خود دارند. اگر پروژه جای دیگری
# باشد، آنها به فایلی اشاره می‌کنند که وجود ندارد — یا بدتر، به نسخه
# قدیمی پروژه در مسیر اصلی.
if [ -f "$SCRIPTS/fix-paths.sh" ]; then
    step "۰/۷  هم‌راستاسازی مسیرها"
    if [ "$DRY_RUN" = "1" ]; then
        DRY_RUN=1 bash "$SCRIPTS/fix-paths.sh" "$ROOT_DIR" 2>&1 | tail -4
    else
        bash "$SCRIPTS/fix-paths.sh" "$ROOT_DIR" 2>&1 | grep -E "✓|✗|اصلاح‌شده" || true
    fi
fi

# ── ۱) شبکه پایه ──
step "۱/۷  مواد رمزنگاری و شبکه پایه"
if [ "$SKIP_NETWORK" = "1" ]; then
    warn "رد شد (SKIP_NETWORK=1)"
else
    # NETWORK_TLS=true باعث می‌شود tlscacerts در MSP قرار بگیرد — بدون آن
    # Gateway ریشه اعتماد ندارد و set-tls بعداً باید خودش اضافه کند.
    # ORDERER_NODES هم لازم است: بدون آن network.sh فقط برای یک orderer
    # هویت و گواهی می‌سازد و خوشه Raft بعداً دو نود بی‌گواهی خواهد داشت.
    run env NETWORK_TLS=true ORDERER_NODES="$NODES" ./network.sh || die "network.sh شکست خورد"
    ok "شبکه پایه ساخته شد"
fi

# ── ۲) Raft ──
step "۲/۷  پیکربندی Raft"
run ./setup-raft.sh "$NODES" || die "setup-raft.sh شکست خورد"
ok "configtx و docker-compose برای $NODES نود"

# ── ۳) TLS ──
# بعد از Raft، تا پوشه نودهای جدید وجود داشته باشد و گواهی همه‌شان از
# یک CA صادر شود.
step "۳/۷  گواهی‌های TLS"
run ./set-tls.sh on || die "set-tls.sh شکست خورد"
ok "TLS روی همه نودها"

# ── ۴) قراردادها ──
step "۴/۷  تولید قراردادها"
if [ "$DRY_RUN" = "1" ]; then
    echo "    \$ for f in generateChaincodes_part*.sh; do bash \"\$f\"; done"
else
    for f in generateChaincodes_part*.sh; do
        bash "$f" >/dev/null 2>&1 || die "$f شکست خورد — با bash $f جداگانه اجرا کنید"
    done
    COUNT=$(ls chaincode 2>/dev/null | wc -l)
    [ "$COUNT" -eq 86 ] || die "$COUNT قرارداد تولید شد، انتظار ۸۶"
    ok "۸۶ قرارداد — و اسکریپت مکانی خودش کامپایل را بررسی کرد"
fi

# ── ۵) بلوک پیدایش ──
# باید پس از Raft و TLS بیاید: هم نوع سرویس ترتیب‌دهی و هم مسیر گواهی
# consenter ها داخل بلوک پیدایش می‌روند.
step "۵/۷  بلوک پیدایش"
run ./deploy-staged.sh artifacts || die "ساخت آرتیفکت شکست خورد"
ok "بلوک پیدایش با etcdraft"

# ── ۶) بالا آوردن ──
step "۶/۷  راه‌اندازی کانتینرها"
if [ "$DRY_RUN" = "1" ]; then
    echo "    \$ cd $CONFIG && docker compose down && docker compose up -d"
else
    (cd "$CONFIG" && docker compose down --remove-orphans >/dev/null 2>&1
     docker compose up -d) || die "بالا آوردن کانتینرها شکست خورد"

    echo -n "  انتظار برای انتخاب رهبر Raft"
    LEADER=""
    for i in $(seq 1 30); do
        sleep 2; echo -n "."
        LEADER=$(docker logs orderer.example.com 2>&1 | grep -oi "leader.*changed\|became leader\|Raft leader" | tail -1)
        [ -n "$LEADER" ] && break
    done
    echo ""
    if [ -n "$LEADER" ]; then
        ok "خوشه Raft فعال است"
    else
        warn "رهبری در لاگ دیده نشد — با این بررسی کنید:"
        echo "     docker logs orderer.example.com 2>&1 | tail -20"
    fi
fi

# ── ۷) کانال‌ها و قراردادها ──
step "۷/۷  استقرار کانال‌ها"
if [ "$CHANNELS" = "all" ]; then
    run ./deploy-staged.sh all || warn "استقرار کامل با خطا — با list بررسی کنید"
else
    for ch in $CHANNELS; do
        echo "  ── $ch ──"
        run ./deploy-staged.sh channel "$ch" || warn "$ch با خطا"
    done
fi

if [ "$DRY_RUN" != "1" ]; then
    echo ""
    ./deploy-staged.sh list
    echo ""
    # بذرکاری فقط وقتی معنا دارد که قراردادی مستقر شده باشد
    COMMITTED=$(./deploy-staged.sh list 2>/dev/null | grep -oE "[1-9][0-9]*/[0-9]+" | head -1)
    if [ -n "$COMMITTED" ]; then
        ok "قراردادها مستقر شدند — بذرکاری چیدمان آنتن"
        for ch in $CHANNELS; do
            [ "$ch" = "all" ] && ./seed-network.sh || ./seed-network.sh "$ch"
        done
    else
        die "هیچ قراردادی commit نشد — خروجی بالا را بررسی کنید"
    fi
fi

# ── ابزارها و سرویس ──
step "ابزارهای تست و داشبورد"
if [ "$DRY_RUN" != "1" ]; then
    node gen-caliper-network.js >/dev/null 2>&1 && ok "پروفایل‌های Caliper (grpcs://)"
    ./fix-tape-policy.sh >/dev/null 2>&1 && ok "سیاست Tape"
    node update-fn-map.js >/dev/null 2>&1 && ok "نگاشت توابع"
    bash "$ROOT_DIR/server/patch-index.sh" >/dev/null 2>&1 && ok "سرور پچ شد"
    systemctl restart dashboard 2>/dev/null && ok "داشبورد ری‌استارت شد"
fi

echo ""
echo "════════════════════════════════════════════"
[ "$DRY_RUN" = "1" ] && { echo "DRY_RUN تمام شد."; exit 0; }
echo -e "${GREEN} شبکه با Raft ($NODES نود) و TLS کامل بالا آمد.${NC}"
echo "════════════════════════════════════════════"
cat <<'NEXT'

بررسی‌های پیشنهادی:

  # رهبر خوشه
  docker logs orderer.example.com 2>&1 | grep -i leader | tail -3

  # TLS روی peer
  docker logs peer0.org1.example.com 2>&1 | grep -i tls | tail -3

  # تحمل خطا — نود رهبر را بخوابانید و ببینید شبکه کار می‌کند
  docker stop orderer.example.com
  ./deploy-staged.sh list          # باید همچنان جواب بدهد
  docker start orderer.example.com

آزمایشی که حالا ممکن شد و پیش از این نبود:

  همان بنچمارک را با solo و با Raft بگیرید و مقایسه کنید. اختلاف،
  «بهای تحمل خطا» است — عددی که در ادبیات شبکه‌های 6G کم سنجیده شده.

  ./setup-raft.sh solo   # و دوباره از گام ۵ به بعد
NEXT
