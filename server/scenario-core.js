'use strict';

// ═══════════════════════════════════════════════════════════════
// scenario-core.js — منطق خالص سناریوی شبیه‌سازی 6G
// سازمان‌ها = آنتن‌های ماکروسل با جانمایی تصادفی در مربع ۱۰×۱۰ کیلومتر
// IoT ها و کاربرها = موقعیت تصادفی، متصل به نزدیک‌ترین آنتن (ورونوی)
// هر تراکنش هر موجودیت از دروازه سازمانِ آنتنِ نزدیکش ارسال می‌شود.
// این ماژول هیچ وابستگی به فابریک ندارد و مستقلاً قابل تست است.
// ═══════════════════════════════════════════════════════════════

const { CONTRACT_FN } = require('./contract-fn-map');

// RNG قطعی (mulberry32) — با seed یکسان، توپولوژی یکسان (تکرارپذیری آزمایش)
function makeRng(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// تولید توپولوژی: مختصات بر حسب متر در مربع areaMeters×areaMeters
/* Place entities from a seed.
 *
 * A caveat that matters for the coverage map: the location-aware contracts
 * now hold their OWN antenna layout, seeded through SeedNetwork, and they
 * derive it from a different generator than the mulberry32 below. Feeding
 * both the same seed does NOT produce the same positions.
 *
 * The contract is the source of truth — it is what actually decides serving
 * cell and SINR. Pass its layout in as `antennas` (from a NetworkStatus
 * query) so the map shows what the ledger is really computing against.
 * Without it the antenna positions are illustrative only; entity positions
 * are unaffected either way.
 */
function generateTopology({ seed, areaMeters = 10000, orgCount = 8, iotCount = 20, userCount = 20, antennas: fromLedger = null }) {
  const realSeed = Number.isFinite(seed) ? seed : Math.floor(Math.random() * 2 ** 31);
  const rng = makeRng(realSeed);
  const rand = () => Math.round(rng() * areaMeters);

  const antennas = [];
  for (let i = 1; i <= orgCount; i++) {
    antennas.push({ orgNum: i, id: `ANT-org${i}`, x: rand(), y: rand() });
  }
  const iots = [];
  for (let i = 1; i <= iotCount; i++) {
    iots.push({ id: `IoT-${i}`, x: rand(), y: rand() });
  }
  const users = [];
  for (let i = 1; i <= userCount; i++) {
    users.push({ id: `User-${i}`, x: rand(), y: rand() });
  }
  // A layout read from the ledger wins over the locally generated one.
  const finalAntennas = Array.isArray(fromLedger) && fromLedger.length
    ? fromLedger.map((a, i) => ({
        id: a.antennaID || `antenna-${i + 1}`,
        orgNum: (i % orgCount) + 1,
        x: Number(a.x),
        y: Number(a.y),
        fromLedger: true,
      }))
    : antennas;

  return {
    seed: realSeed,
    areaMeters,
    antennas: finalAntennas,
    antennaSource: finalAntennas === antennas ? 'generated' : 'ledger',
    iots,
    users,
  };
}

function distance(a, b) {
  return Math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2);
}

// تخصیص هر موجودیت به نزدیک‌ترین آنتن (محدوده هر آنتن = سلول ورونوی آن)
function assignNearest(topology) {
  const assignOne = (e) => {
    let best = null, bestD = Infinity;
    for (const ant of topology.antennas) {
      const d = distance(e, ant);
      if (d < bestD) { bestD = d; best = ant; }
    }
    return { ...e, orgNum: best.orgNum, antennaId: best.id, distToAntenna: Math.round(bestD) };
  };
  const iots = topology.iots.map(assignOne);
  const users = topology.users.map(assignOne);

  const perOrg = {};
  for (const ant of topology.antennas) {
    perOrg[ant.orgNum] = { antennaId: ant.id, x: ant.x, y: ant.y, iotCount: 0, userCount: 0 };
  }
  for (const e of iots) perOrg[e.orgNum].iotCount++;
  for (const e of users) perOrg[e.orgNum].userCount++;

  return { iots, users, perOrg };
}

// ساخت آرگومان‌های یک تابع قرارداد بر اساس نام پارامترها
const PARAM_DEFAULTS = {
  signal: '-70', signalQuality: '85', bandwidth: '50', load: '55', coverage: '85',
  energy: '40', latency: '12', priority: 'high', status: 'Active', traffic: '800',
  congestion: '30', interference: '10', activity: 'active', resource: 'spectrum',
  amount: '100', metric: 'latency', value: '12', action: 'update', event: 'event',
  faultType: 'link-down', policy: 'allow-all', strategy: 'load-balance', role: 'member',
  data: 'payload', details: 'details', config: 'macro-cell', power: '20', channel: 'ch1',
  route: 'r1', newBandwidth: '60',
};

function buildArgs(paramNames, ctx) {
  // ctx: { id, x, y, antennaId, seed }
  return paramNames.map((p) => {
    if (/(entityID|deviceID|userID|networkID|policyID|nodeID)$/i.test(p)) return ctx.id;
    // The location-aware contracts now take the scenario seed and check it
    // against the antenna layout they were seeded with. Falling through to
    // the 'n/a' default below would make every one of them reject the
    // transaction with a seed mismatch.
    if (p === 'seed') return String(ctx.seed ?? '');
    // Those contracts also pick their own serving cell now, so antennaID
    // only survives where the antenna is the subject of the contract.
    if (p === 'antennaID') return ctx.antennaId || ctx.id;
    if (p === 'x') return String(ctx.x);
    if (p === 'y') return String(ctx.y);
    if (p === 'sessionID') return `sess-${ctx.id}`;
    if (p === 'token') return `token-${ctx.id}`;
    if (PARAM_DEFAULTS[p] !== undefined) return PARAM_DEFAULTS[p];
    return 'n/a';
  });
}

// برنامه‌ریزی تراکنش‌ها برای کانال‌ها/قراردادهای انتخابی
// selection: [{ channel, chaincodes: [name, ...] }]
function planScenario({ topology, assigned, selection, connectEntities = true }) {
  const tasks = [];
  const skipped = [];

  const push = (orgNum, channel, chaincode, fn, args, kind) =>
    tasks.push({ orgNum, channel, chaincode, fn, args, kind });

  for (const sel of selection) {
    for (const cc of sel.chaincodes) {
      const meta = CONTRACT_FN[cc];
      if (!meta) { skipped.push({ chaincode: cc, reason: 'no-write-fn' }); continue; }
      // antennaDep no longer exists: those seven contracts create their own
      // antenna layout through SeedNetwork and run like any other. What
      // matters now is that the layout was seeded with this scenario's seed —
      // see the note returned alongside the plan.

      // فاز الف — ثبت خود آنتن‌ها روی همین (کانال، قرارداد): id=ANT-orgN با مختصات آنتن
      for (const ant of topology.antennas) {
        push(ant.orgNum, sel.channel, cc, meta.fn,
          buildArgs(meta.params, {
            id: ant.id, x: ant.x, y: ant.y, antennaId: ant.id, seed: topology.seed,
          }),
          'antenna');
      }
      // فاز ج — داده هر موجودیت از دروازه سازمانِ نزدیکش
      for (const e of [...assigned.iots, ...assigned.users]) {
        push(e.orgNum, sel.channel, cc, meta.fn,
          buildArgs(meta.params, {
            id: e.id, x: e.x, y: e.y, antennaId: e.antennaId, seed: topology.seed,
          }),
          'entity-data');
      }
    }
  }

  // فاز ب — برقراری اتصال روی connectivitychannel (ConnectUser / ConnectIoT)
  if (connectEntities) {
    for (const e of assigned.users) {
      push(e.orgNum, 'connectivitychannel', 'ConnectUser', 'Connect', [e.id, e.antennaId], 'connect');
    }
    for (const e of assigned.iots) {
      push(e.orgNum, 'connectivitychannel', 'ConnectIoT', 'Connect', [e.id, e.antennaId], 'connect');
    }
  }

  return { tasks, skipped };
}

module.exports = { makeRng, generateTopology, assignNearest, buildArgs, planScenario, CONTRACT_FN };
