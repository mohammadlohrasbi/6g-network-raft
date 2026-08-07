'use strict';

/* ═══════════════════════════════════════════════════════════════════════
   bench-catalog.js — single source of truth for benchmark targets.

   Both the Tape runner and the Caliper asset generator read from here, so
   a contract's write function and its argument shape are defined exactly
   once. Derived from contract-fn-map.js (the 84 mapped contracts) and
   CHANNEL_CHAINCODE_MAP in fabric.js (which contract lives on which
   channel).

   A "target" is one (channel, contract) pair. Every benchmark run — from
   a single contract to a full 20-channel sweep — is just a list of
   targets, so the same code path serves every mode in the UI.
   ═══════════════════════════════════════════════════════════════════════ */

const { CONTRACT_FN } = require('./contract-fn-map');

// Canonical channel → contract map, mirroring scripts/channel_contract_map.sh.
// It lives here rather than being imported from fabric.js so this module
// stays loadable without the Fabric SDK — the Caliper asset generator runs
// it from the command line. fabric.js keeps an identical copy for the
// ledger routes; assertCatalogInSync() below flags any divergence.
const CHANNEL_CHAINCODE_MAP = {
  networkchannel: ['LocationBasedNetworkLoad', 'LocationBasedNetworkHealth', 'ManageNetwork', 'MonitorNetwork'],
  resourcechannel: ['LocationBasedResourceAllocation', 'LocationBasedIoTResource', 'AllocateResource', 'LogResourceAudit', 'MonitorResourceUsage'],
  performancechannel: ['LocationBasedLatency', 'LogPerformance', 'LogNetworkPerformance', 'LogPerformanceAudit'],
  iotchannel: ['LocationBasedIoTConnection', 'LocationBasedIoTBandwidth', 'LocationBasedIoTStatus', 'LocationBasedIoTFault', 'LocationBasedIoTSession', 'ManageIoTDevice', 'MonitorIoT', 'LogIoTActivity'],
  authchannel: ['LocationBasedIoTAuthentication', 'AuthenticateUser', 'AuthenticateIoT', 'VerifyIdentity'],
  connectivitychannel: ['LocationBasedConnection', 'LocationBasedRoaming', 'ConnectUser', 'ConnectIoT', 'LogConnectionAudit'],
  sessionchannel: ['LocationBasedSessionManagement', 'LocationBasedIoTSession', 'ManageSession', 'LogSession', 'LogSessionAudit'],
  policychannel: ['SetPolicy', 'GetPolicy', 'UpdatePolicy', 'LogPolicyAudit', 'LogPolicyChange'],
  auditchannel: ['LogNetworkAudit', 'LogAntennaAudit', 'LogIoTAudit', 'LogUserAudit', 'LogAccessAudit', 'LogSecurityAudit', 'LogComplianceAudit'],
  securitychannel: ['EncryptData', 'DecryptData', 'SecureCommunication', 'LogSecurityEvent'],
  datachannel: ['LocationBasedAssignment', 'LocationBasedBandwidth', 'LocationBasedSignalStrength', 'LocationBasedSignalQuality'],
  analyticschannel: ['LocationBasedQoS', 'LocationBasedCoverage', 'LocationBasedEnergy'],
  monitoringchannel: ['MonitorTraffic', 'MonitorInterference', 'LocationBasedStatus'],
  managementchannel: ['ManageAntenna', 'ManageUser', 'LocationBasedAntennaConfig', 'LocationBasedPowerManagement', 'LocationBasedChannelAllocation'],
  optimizationchannel: ['OptimizeNetwork', 'BalanceLoad', 'LocationBasedDynamicRouting'],
  faultchannel: ['LocationBasedFault', 'LocationBasedIoTFault', 'LogFault'],
  trafficchannel: ['LocationBasedTraffic', 'LogTraffic', 'LocationBasedCongestion'],
  accesschannel: ['RegisterUser', 'RegisterIoT', 'RevokeUser', 'RevokeIoT', 'AssignRole', 'LocationBasedIoTRegistration', 'LocationBasedIoTRevocation', 'LogAccessControl'],
  compliancechannel: ['LogComplianceAudit', 'LocationBasedPriority'],
  integrationchannel: ['LocationBasedInterference', 'LocationBasedSignalStrength', 'LocationBasedUserActivity', 'LogUserActivity', 'LogInterference'],
};

/**
 * Compare this map against the one in fabric.js and return a list of
 * differences. Returns [] when they agree or when fabric.js cannot be
 * loaded (no SDK installed — the generator case).
 */
function assertCatalogInSync() {
  let other;
  try {
    ({ CHANNEL_CHAINCODE_MAP: other } = require('./fabric'));
  } catch (_) {
    return [];
  }
  const diffs = [];
  const keys = new Set([...Object.keys(CHANNEL_CHAINCODE_MAP), ...Object.keys(other)]);
  for (const k of keys) {
    const a = (CHANNEL_CHAINCODE_MAP[k] || []).slice().sort().join(',');
    const b = (other[k] || []).slice().sort().join(',');
    if (a !== b) diffs.push(k);
  }
  return diffs;
}

// Contracts with no write function at all. They expose only reads, so a
// write benchmark against them can never commit anything.
//
// VerifyIdentity is NOT one of them, despite having been treated as such:
// it writes with a blind PutState. The auto-mapper skipped it because its
// second parameter is a bool — the only non-string writer on the network —
// and contractapi parses "true" itself.
const READ_ONLY_CONTRACTS = new Set(['GetPolicy']);

// Every generated contract exposes these two read functions.
// Only these carry the market code; the 52 record-only contracts do not.
const SPATIAL_CONTRACTS = new Set(
  Object.values(CONTRACT_FN)
    .map((d, i) => Object.keys(CONTRACT_FN)[i])
    .filter((name) => CONTRACT_FN[name] && CONTRACT_FN[name].needsSeed)
);

const READ_FN = 'QueryAsset';
const READ_ALL_FN = 'QueryAllAssets';

/* ── Argument synthesis ────────────────────────────────────────────────
   Parameter names in contract-fn-map.js are consistent across all 86
   contracts (entityID, antennaID, x, y, signal, status, …), so a value
   can be derived from the name. `i` makes each transaction write a
   distinct key, which is what keeps a benchmark from measuring MVCC
   conflicts instead of throughput.                                      */

// Parameters that can serve as the ledger key.
const ID_PARAMS = new Set([
  'entityID', 'deviceID', 'userID', 'networkID', 'antennaID',
  'policyID', 'sessionID', 'channelID', 'resourceID',
]);

// antennaID in second position points at an antenna record that must
// already exist, so it stays fixed instead of varying per transaction.
const SHARED_REF_PARAMS = new Set(['antennaID']);

// Coordinates are metres on the scenario grid. The spatial contracts now
// place antennas across a 10 km square and pick a serving cell, so x and y
// have to span that square — the old 1..100 range put every entity in one
// corner and every transaction on the same cell.
const GRID_SIZE_M = 10000;

// Two reference points in the seed-42 antenna layout, used to place the
// parties in a relay benchmark: RELAY_EDGE is the corner furthest from every
// cell, RELAY_HUB sits almost on top of one.
// Chosen by searching the seed-42 layout for the pairing that clears the
// contract's own conditions most often. The relay sits 565 m from the edge
// entity — close enough for the device-to-device hop to carry the payload,
// far enough to reach a different cell.
//
// It clears about two thirds of the time, not always: shadow fading varies
// per link, so some pairs come out with the relay no better placed than the
// entity it would carry. A relay market where every deal is worthwhile
// would be the unrealistic result.
const RELAY_EDGE = { x: 3600, y: 8400 };
const RELAY_OFFSET = { dx: -400, dy: -400 };
const BENCH_SEED = '42';
const ANTENNA_COUNT = 8;   // one macrocell per organization

function paramValue(name, i, keyPrefix) {
  // The first ID parameter is the ledger key — it must be unique per tx.
  switch (name) {
    case 'seed':              return BENCH_SEED;
    case 'verified':          return i % 5 === 0 ? 'false' : 'true';
    case 'x':                 return String((i * 2654435761) % GRID_SIZE_M);
    case 'y':                 return String((i * 1597334677) % GRID_SIZE_M);
    case 'signal':            return String(-60 - (i % 40));
    case 'signalQuality':     return String(50 + (i % 50));
    case 'load':              return String(10 + (i % 90));
    case 'coverage':          return String(50 + (i % 50));
    case 'congestion':        return String(i % 100);
    case 'energy':            return String(100 + (i % 900));
    case 'latency':           return String(1 + (i % 50));
    case 'traffic':           return String(100 + (i % 2000));
    case 'interferenceLevel': return String(i % 30);
    case 'bandwidth':         return String(10 + (i % 90));
    case 'amount':            return String(1 + (i % 500));
    case 'value':             return String(1 + (i % 100));
    case 'powerLevel':        return String(1 + (i % 40));
    case 'priority':          return ['low', 'normal', 'high'][i % 3];
    case 'qosLevel':          return ['bronze', 'silver', 'gold'][i % 3];
    case 'status':            return 'Active';
    case 'healthStatus':      return 'Healthy';
    case 'complianceStatus':  return 'Compliant';
    case 'token':             return `token-${i}`;
    case 'role':              return ['reader', 'writer', 'admin'][i % 3];
    case 'policy':            return 'allow-all';
    case 'change':            return 'threshold-raised';
    case 'action':            return 'config-change';
    case 'activity':          return 'handover';
    case 'event':             return 'login-ok';
    case 'metric':            return 'latency';
    case 'resource':          return 'spectrum';
    case 'strategy':          return 'load-balance';
    case 'route':             return 'path-a';
    case 'config':            return 'band-n78';
    case 'faultType':         return 'link-down';
    case 'data':              return `payload-${i}`;
    case 'maxDistance':       return '5000';
    default:                  return `v-${i}`;
  }
}

/**
 * Build the full argument list for one write transaction.
 * The first parameter is treated as the ledger key.
 */
function buildArgs(contract, i, keyPrefix = 'bench', operation = null) {
  // A market target names its operation; the contract's own primary
  // function is used when it does not.
  if (operation) return buildMarketArgs(operation, i, keyPrefix);
  const def = CONTRACT_FN[contract];
  if (!def) return null;
  let keyTaken = false;
  return def.params.map((p) => {
    // antennaID always names a cell in the registry, never a fresh key —
    // even when it is the first parameter, as it is for the contract that
    // reconfigures a cell rather than being served by one. Cycling across
    // the eight keeps every cell exercised.
    if (SHARED_REF_PARAMS.has(p)) {
      keyTaken = true;
      return `antenna-${1 + (i % ANTENNA_COUNT)}`;
    }
    if (!keyTaken && ID_PARAMS.has(p)) {
      keyTaken = true;
      return `${keyPrefix}-${i}`;
    }
    if (ID_PARAMS.has(p)) return `${p}-${keyPrefix}-${i}`;
    return paramValue(p, i, keyPrefix);
  });
}

/** The ledger key a given iteration wrote — used by read benchmarks. */
function buildKey(i, keyPrefix = 'bench') {
  return `${keyPrefix}-${i}`;
}


/* ── market operations ─────────────────────────────────────────────────
   The spatial contracts expose a second family of write functions: the
   resource market. These do not fit the one-function-per-contract shape
   the catalog was built around — ShareBandwidth needs two entities,
   RelayFor needs six arguments across two positions — so they are
   described separately and offered as extra targets rather than replacing
   the primary function of a contract.

   Why they are worth benchmarking: each one writes a different set of
   keys, and Fabric validates read-write sets after ordering. A payment to
   an operator touches one of only eight cell records; a transfer between
   two entities touches two unique ones. The throughput difference between
   those two shapes is a property of the ledger, not of the network being
   modelled, and it is measurable here.

   writePattern says which shape a call has:
     'unique'  every key is per-entity — no contention expected
     'shared'  at least one key is a cell or operator record — contention
     'mixed'   both

   Only contracts that carry the market code (the spatial ones) offer
   these, and only when explicitly requested: including them by default
   would change what a plain channel sweep measures.                      */

const MARKET_FN = {
  Mint: {
    fn: 'Mint',
    params: ['accountID', 'amount'],
    writePattern: 'unique',
    note: 'creates tokens on one account stripe',
    tapeSafe: true,
  },
  Transfer: {
    fn: 'Transfer',
    params: ['from', 'to', 'amount'],
    writePattern: 'unique',
    note: 'two account stripes, both per-entity',
    tapeSafe: true,
  },
  BuyQos: {
    fn: 'BuyQos',
    params: ['entityID', 'tier'],
    writePattern: 'unique',
    note: 'buyer account plus their QoS record',
    tapeSafe: true,
  },
  ShareBandwidth: {
    fn: 'ShareBandwidth',
    // 'from' deliberately reuses the key the contract's own write function
    // creates, so the seller already holds a grant. Naming a fresh entity
    // here meant the seller had nothing to sell and every call was refused.
    params: ['fromAdmitted', 'to', 'hz', 'priceMicro'],
    writePattern: 'unique',
    note: 'two grants and two accounts, all per-entity',
    // A grant is finite: 100 kHz sold 20 kHz at a time runs out after five
    // sales. Tape repeats one seller for the whole run, so it would clear
    // five transactions and refuse the rest.
    tapeSafe: false,
    requires: 'the contract\'s own write function run first, so the seller '
      + 'holds a grant to sell — and Caliper, because a grant only covers a '
      + 'few sales and Tape reuses one seller throughout',
  },
  RelayFor: {
    fn: 'RelayFor',
    params: ['dealID', 'edgeEntity', 'edgeX', 'edgeY', 'relayEntity', 'relayX', 'relayY'],
    writePattern: 'unique',
    note: 'deal record plus two batteries and two accounts',
    // Every deal needs a fresh id. Tape repeats one argument set for the
    // whole run, so the first call succeeds and the rest collide with it.
    tapeSafe: false,
    requires: 'a unique deal id per call, so Caliper only — Tape repeats '
      + 'its arguments and every call after the first hits the same deal',
  },
};

/** Values for market parameters. Pairs are derived from i so that no two
    concurrent transactions touch the same account. */
function marketValue(name, i, keyPrefix) {
  switch (name) {
    // Matches the ledger key the primary write function uses, so this
    // entity has already been admitted and holds a grant.
    case 'fromAdmitted': return `${keyPrefix}-${i}`;
    case 'accountID':
    case 'entityID':
    case 'from':
    case 'edgeEntity':   return `${keyPrefix}-a-${i}`;
    case 'to':
    case 'relayEntity':  return `${keyPrefix}-b-${i}`;
    case 'dealID':       return `${keyPrefix}-deal-${i}`;
    case 'amount':       return '1000';
    case 'tier':         return String(1 + (i % 2));
    case 'hz':           return '20000';
    case 'priceMicro':   return '500';
    // Relaying only makes sense when the relay has the better link, and the
    // contract refuses the deal otherwise. The first attempt put the edge
    // near the map origin and the relay in the middle, which failed every
    // time: the antennas are placed pseudo-randomly from the seed, so "the
    // middle" landed in a coverage gap while "the origin" sat beside a cell.
    //
    // These two regions are derived from the seed-42 layout: the corner
    // around (9800, 1600) is the furthest any point gets from every cell —
    // 6.6 km — and (3200, 7800) is within 20 m of antenna-5. That gives the
    // edge entity a weak link and the relay a strong one, which is the
    // situation relaying exists for.
    //
    // Change the scenario seed and these lose their meaning; RELAY_EDGE and
    // RELAY_HUB below are the two values to recompute.
    case 'edgeX':        return String(RELAY_EDGE.x - 200 + (i * 79) % 400);
    case 'edgeY':        return String(RELAY_EDGE.y - 200 + (i * 113) % 400);
    case 'relayX':       return String(RELAY_EDGE.x - 200 + (i * 79) % 400 + RELAY_OFFSET.dx);
    case 'relayY':       return String(RELAY_EDGE.y - 200 + (i * 113) % 400 + RELAY_OFFSET.dy);
    default:             return `v-${i}`;
  }
}

/** Build arguments for a market call. */
function buildMarketArgs(opName, i, keyPrefix = 'mkt') {
  const def = MARKET_FN[opName];
  if (!def) return null;
  return def.params.map((p) => marketValue(p, i, keyPrefix));
}

/** Market operations available on one spatial contract. */
function marketTargets(channel, contract) {
  if (!SPATIAL_CONTRACTS.has(contract)) return [];
  return Object.keys(MARKET_FN).map((op) => {
    const def = MARKET_FN[op];
    return {
      channel,
      contract,
      id: `${channel}/${contract}#${op}`,
      caliperId: caliperId(channel, contract),
      fn: def.fn,
      params: def.params,
      readFn: READ_FN,
      readAllFn: READ_ALL_FN,
      writable: true,
      antennaDep: false,
      needsSeed: false,
      market: true,
      operation: op,
      writePattern: def.writePattern,
      note: def.note,
      tapeSafe: def.tapeSafe !== false,
      requires: def.requires || null,
      needsGrant: !!def.needsGrant,
      sampleArgs: buildMarketArgs(op, 1),
    };
  });
}

/* ── Target catalog ────────────────────────────────────────────────── */

/**
 * Describe one (channel, contract) pair.
 * `writable` is false when the contract has no write function.
 * `antennaDep` marks contracts that read an antenna record before
 * writing — they fail unless that record was seeded first, so they are
 * excluded from sweeps by default.
 */
/**
 * Caliper indexes contracts by a globally unique contractID, not per
 * channel. Four contracts here sit on two channels each
 * (LocationBasedIoTSession, LocationBasedIoTFault, LocationBasedSignalStrength,
 * LogComplianceAudit), so declaring them under their plain name makes
 * Caliper reject the whole configuration as a duplicate definition.
 * Channel-qualifying every id keeps each (channel, contract) pair
 * separately addressable, which is what per-target benchmarking needs.
 */
function caliperId(channel, contract) {
  return `${channel}_${contract}`;
}

function describeTarget(channel, contract) {
  const def = CONTRACT_FN[contract];
  const readOnly = READ_ONLY_CONTRACTS.has(contract) || !def;
  return {
    channel,
    contract,
    id: `${channel}/${contract}`,
    caliperId: caliperId(channel, contract),
    fn: def ? def.fn : null,
    params: def ? def.params : [],
    readFn: READ_FN,
    readAllFn: READ_ALL_FN,
    writable: !readOnly,
    antennaDep: def ? !!def.antennaDep : false,
    // Spatial contracts pick their own serving cell, so the antenna layout
    // has to exist before they will accept a write.
    needsSeed: def ? !!def.needsSeed : false,
    sampleArgs: def ? buildArgs(contract, 1) : [],
  };
}

/** Every (channel, contract) pair in the network — 86 contracts, 20 channels. */
function allTargets() {
  const out = [];
  for (const [channel, contracts] of Object.entries(CHANNEL_CHAINCODE_MAP)) {
    for (const contract of contracts) out.push(describeTarget(channel, contract));
  }
  return out;
}

/** Targets grouped by channel, for the UI's channel picker. */
function catalog() {
  const channels = Object.entries(CHANNEL_CHAINCODE_MAP).map(([channel, contracts]) => ({
    channel,
    contracts: contracts.map((c) => describeTarget(channel, c)),
  }));
  return {
    channels,
    counts: {
      channels: channels.length,
      targets: channels.reduce((n, c) => n + c.contracts.length, 0),
      writable: channels.reduce(
        (n, c) => n + c.contracts.filter((t) => t.writable).length, 0),
      antennaDep: channels.reduce(
        (n, c) => n + c.contracts.filter((t) => t.antennaDep).length, 0),
    },
  };
}

/**
 * Turn a UI selection into a concrete, ordered target list.
 *
 *   mode 'contract' → one pair, needs { channel, contract }
 *   mode 'channel'  → every contract on { channel }
 *   mode 'channels' → every contract on each of { channels: [] }
 *   mode 'targets'  → exactly the pairs in { targets: [{channel,contract}] }
 *   mode 'all'      → the whole network
 *
 * `includeAntennaDep` and `includeReadOnly` default to false because
 * those targets cannot commit a blind write.
 */
function resolveTargets(sel = {}) {
  const {
    mode = 'contract',
    channel,
    contract,
    channels = [],
    targets = [],
    includeAntennaDep = false,
    includeReadOnly = false,
    // Market operations are opt-in: adding them to a plain sweep would
    // change what that sweep measures.
    includeMarket = false,
    marketOnly = false,
  } = sel;

  let list = [];
  switch (mode) {
    case 'contract':
      if (!channel || !contract) throw new Error('mode "contract" needs a channel and a contract');
      list = [describeTarget(channel, contract)];
      break;
    case 'channel': {
      if (!channel) throw new Error('mode "channel" needs a channel');
      const ccs = CHANNEL_CHAINCODE_MAP[channel];
      if (!ccs) throw new Error(`Unknown channel: ${channel}`);
      list = ccs.map((c) => describeTarget(channel, c));
      break;
    }
    case 'channels': {
      if (!channels.length) throw new Error('mode "channels" needs at least one channel');
      for (const ch of channels) {
        const ccs = CHANNEL_CHAINCODE_MAP[ch];
        if (!ccs) throw new Error(`Unknown channel: ${ch}`);
        list.push(...ccs.map((c) => describeTarget(ch, c)));
      }
      break;
    }
    case 'targets':
      if (!targets.length) throw new Error('mode "targets" needs at least one target');
      list = targets.map((t) => describeTarget(t.channel, t.contract));
      break;
    case 'all':
      list = allTargets();
      break;
    default:
      throw new Error(`Unknown selection mode: ${mode}`);
  }

  // Deduplicate — a contract can sit on more than one channel, and the
  // same pair can arrive twice from overlapping selections.
  const seen = new Set();
  list = list.filter((t) => {
    if (seen.has(t.id)) return false;
    seen.add(t.id);
    return true;
  });

  if (!includeReadOnly) list = list.filter((t) => t.writable);
  if (!includeAntennaDep) list = list.filter((t) => !t.antennaDep);

  if (includeMarket || marketOnly) {
    const seenPairs = new Set();
    const extra = [];
    for (const t of list) {
      const pair = `${t.channel}/${t.contract}`;
      if (seenPairs.has(pair)) continue;
      seenPairs.add(pair);
      extra.push(...marketTargets(t.channel, t.contract));
    }
    list = marketOnly ? extra : [...list, ...extra];
  }
  return list;
}

/** Distinct write function names across the network — one Caliper asset each. */
function writeFunctions() {
  const fns = new Set();
  for (const t of allTargets()) if (t.writable && t.fn) fns.add(t.fn);
  return [...fns].sort();
}

module.exports = {
  CONTRACT_FN,
  CHANNEL_CHAINCODE_MAP,
  READ_ONLY_CONTRACTS,
  GRID_SIZE_M,
  BENCH_SEED,
  ANTENNA_COUNT,
  READ_FN,
  READ_ALL_FN,
  buildArgs,
  buildKey,
  describeTarget,
  allTargets,
  catalog,
  caliperId,
  MARKET_FN,
  SPATIAL_CONTRACTS,
  marketTargets,
  buildMarketArgs,
  resolveTargets,
  writeFunctions,
  assertCatalogInSync,
};
