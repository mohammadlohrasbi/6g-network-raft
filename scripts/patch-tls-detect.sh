#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# patch-tls-paths.sh — مسیرهای گواهی TLS در server/config.js را با آنچه
# واقعاً روی دیسک است هم‌راستا می‌کند.
#
# مسئله
# ─────
# config.js مسیر گواهی ریشه TLS را با نام‌گذاری cryptogen می‌سازد:
#
#   .../orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
#
# ولی network.sh از fabric-ca استفاده می‌کند و ساختار دیگری می‌سازد:
#
#   .../ordererOrganizations/example.com/msp/tlscacerts/ca-cert.pem
#
# تا وقتی TLS خاموش بود این مسیر خوانده نمی‌شد. با TLS روشن، Tape سر آن
# می‌ایستد:
#
#   fail to load TLS CA Cert ...: no such file or directory
#
# و Caliper بی‌صدا پروفایل با مسیر ناموجود می‌سازد.
#
# این اسکریپت مسیر واقعی را روی دیسک پیدا می‌کند و در config.js می‌نشاند.
#
# استفاده:
#   ./patch-tls-paths.sh
#   DRY_RUN=1 ./patch-tls-paths.sh
# ══════════════════════════════════════════════════════════════════════
set -uo pipefail

ROOT_DIR="${ROOT_DIR:-/root/6g-network-raft}"
CONFIG_JS="$ROOT_DIR/server/config.js"
CRYPTO="$ROOT_DIR/config/crypto-config"
DRY_RUN="${DRY_RUN:-0}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; }

echo ""
echo "هم‌راستاسازی مسیر گواهی TLS با دیسک"
[ "$DRY_RUN" = "1" ] && warn "DRY_RUN — چیزی نوشته نمی‌شود"
echo "────────────────────────────────────────────"

[ -f "$CONFIG_JS" ] || { bad "$CONFIG_JS نیست"; exit 1; }
[ -d "$CRYPTO" ]    || { bad "$CRYPTO نیست — اول network.sh"; exit 1; }

# ── مسیر واقعی گواهی ریشه TLS هر سازمان ──
ORD_TLS="$(find "$CRYPTO/ordererOrganizations" -path "*msp/tlscacerts/*.pem" 2>/dev/null | head -1)"
PEER_TLS="$(find "$CRYPTO/peerOrganizations/org1.example.com" -path "*msp/tlscacerts/*.pem" 2>/dev/null | head -1)"

if [ -z "$ORD_TLS" ]; then
    bad "گواهی TLS سازمان اوردرر پیدا نشد"
    echo "     انتظار: $CRYPTO/ordererOrganizations/example.com/msp/tlscacerts/*.pem"
    echo "     اگر نیست، network.sh را با NETWORK_TLS=true اجرا کنید."
    exit 1
fi
ok "اوردرر: ${ORD_TLS#$ROOT_DIR/}"
[ -n "$PEER_TLS" ] && ok "peer:    ${PEER_TLS#$ROOT_DIR/}"

# نام فایل و شکل مسیر، تا الگوی درست ساخته شود
ORD_NAME="$(basename "$ORD_TLS")"
PEER_NAME="$(basename "${PEER_TLS:-ca-cert.pem}")"

echo ""
echo "مسیرهای فعلی در config.js"
echo "────────────────────────────────────────────"
grep -n "tlscacerts" "$CONFIG_JS" | head -6 | sed 's/^/  /' || warn "الگوی tlscacerts پیدا نشد"

if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo "  → جایگزینی با $ORD_NAME و ساختار msp/ سازمان"
    exit 0
fi

cp "$CONFIG_JS" "$CONFIG_JS.bak-$(date +%Y%m%d-%H%M%S)"

ORD_TLS="$ORD_TLS" PEER_NAME="$PEER_NAME" node - "$CONFIG_JS" "$CRYPTO" <<'NODEEOF'
const fs = require('fs');
const [, , cfgPath, crypto] = process.argv;
let s = fs.readFileSync(cfgPath, 'utf8');
const ordTls = process.env.ORD_TLS;
const peerName = process.env.PEER_NAME;

// نام فایل به سبک cryptogen → نام واقعی fabric-ca
s = s.replace(/tlsca\.example\.com-cert\.pem/g, peerName);
s = s.replace(/tlsca\.org(\$\{[^}]+\}|\d)\.example\.com-cert\.pem/g, peerName);

// گواهی سازمان اوردرر از msp/ خود سازمان می‌آید، نه از پوشه هر نود.
// دو صورت نگارش پوشش داده می‌شود: path.join چندآرگومانی و مسیر رشته‌ای.
s = s.replace(
  /(['"])orderers\1\s*,\s*(['"])orderer\.example\.com\2\s*,\s*(?=(['"])msp\3)/g,
  ''
);
s = s.replace(
  /ordererOrganizations\/example\.com\/orderers\/orderer\.example\.com\/msp/g,
  'ordererOrganizations/example.com/msp'
);

fs.writeFileSync(cfgPath, s);
NODEEOF

if ! node --check "$CONFIG_JS" 2>/dev/null; then
    bad "config.js پس از ویرایش معتبر نیست — از پشتیبان بازگردانید"
    ls -t "$CONFIG_JS".bak-* 2>/dev/null | head -1
    exit 1
fi

# ── تأیید: مسیری که config.js می‌دهد واقعاً وجود دارد ──
echo ""
echo "تأیید"
echo "────────────────────────────────────────────"
RESULT="$(cd "$ROOT_DIR/server" && node -e "
const c = require('./config');
const fs = require('fs');
const paths = [c.orderer && c.orderer.tlsCaCert].filter(Boolean);
if (c.orgs) for (const o of Object.values(c.orgs)) if (o.tlsRootCert) paths.push(o.tlsRootCert);
let bad = 0;
for (const p of paths) {
  const okp = fs.existsSync(p);
  if (!okp) { bad++; console.log('MISSING ' + p); }
}
console.log(bad === 0 ? 'ALLOK ' + paths.length : 'BAD ' + bad);
" 2>&1)"

echo "$RESULT" | grep -q "^ALLOK" \
    && ok "همه مسیرها روی دیسک موجودند ($(echo "$RESULT" | grep ALLOK | awk '{print $2}') مسیر)" \
    || { echo "$RESULT" | sed 's/^/  /'; bad "بعضی مسیرها هنوز اشتباه‌اند — خروجی بالا را بفرستید"; exit 1; }

echo ""
echo "────────────────────────────────────────────"
cat <<'NEXT'
حالا پیکربندی ابزارها را از نو بسازید:

  node gen-caliper-network.js
  ./fix-tape-policy.sh
  systemctl restart dashboard

بررسی:

  grep tls_ca_cert ../test-tools/tape-configs/config-datachannel.yaml
NEXT
