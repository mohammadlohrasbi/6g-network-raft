#!/usr/bin/env node
'use strict';

/* Extracts a full inventory of the chaincode from the generator scripts.
   Everything here is read from the Go source, not from the function map —
   the point is to find what the map got wrong. */

const fs = require('fs');
const path = require('path');

const SCRIPTS = process.argv[2];
const CHANNELS = require(process.argv[3]).CHANNEL_CHAINCODE_MAP;

// Split each generator into per-contract Go sources.
const sources = new Map();
for (const f of fs.readdirSync(SCRIPTS).filter((n) => /^generateChaincodes_part\d+\.sh$/.test(n))) {
  const text = fs.readFileSync(path.join(SCRIPTS, f), 'utf8');
  // case <Name>) ... cat > chaincode/$contract/chaincode.go <<'EOF' ... EOF
  const re = /^\s{8}([A-Za-z0-9_]+)\)\s*\n\s*cat > chaincode\/\$contract\/chaincode\.go <<'EOF'\n([\s\S]*?)\nEOF/gm;
  for (const m of text.matchAll(re)) {
    sources.set(m[1], { file: f, go: m[2] });
  }
}

const RESERVED = new Set(['Init', 'QueryAsset', 'QueryAllAssets']);

function analyse(name, go) {
  const fns = [];
  const re = new RegExp(
    `func \\(s \\*${name}\\) ([A-Za-z0-9_]+)\\(ctx contractapi\\.TransactionContextInterface(?:, )?([^)]*)\\)([^{]*)\\{`, 'g');

  for (const m of go.matchAll(re)) {
    const [, fn, rawParams, ret] = m;
    // Body: from the match to the next top-level closing brace.
    const start = m.index + m[0].length;
    let depth = 1, i = start;
    while (i < go.length && depth > 0) {
      if (go[i] === '{') depth++;
      else if (go[i] === '}') depth--;
      i++;
    }
    const body = go.slice(start, i);

    // Go groups same-typed params: "entityID, antennaID, x, y string"
    const params = [];
    for (const group of rawParams.split(/,\s*(?![^(]*\))/).join(',').split(',').map((s) => s.trim()).filter(Boolean)) {
      const parts = group.split(/\s+/);
      params.push(parts.length > 1
        ? { name: parts[0], type: parts.slice(1).join(' ') }
        : { name: parts[0], type: null });
    }
    // Backfill types left-to-right (Go's grouped declaration).
    for (let k = params.length - 1; k >= 0; k--) {
      if (!params[k].type) params[k].type = params[k + 1] ? params[k + 1].type : 'string';
    }

    fns.push({
      name: fn,
      params,
      returns: ret.trim(),
      writes: /PutState|DelState/.test(body),
      deletes: /DelState/.test(body),
      readsFirst: /GetState|QueryAsset\(/.test(body) && /PutState/.test(body),
      readsForeignKey: /s\.QueryAsset\(ctx,\s*(antennaID|[a-zA-Z]*[Aa]ntenna[A-Za-z]*)\)/.test(body),
      iterates: /GetStateByRange|GetQueryResult/.test(body),
      nonString: params.some((p) => p.type && p.type !== 'string'),
    });
  }
  return fns;
}

const contractChannels = new Map();
for (const [ch, list] of Object.entries(CHANNELS)) {
  for (const c of list) {
    if (!contractChannels.has(c)) contractChannels.set(c, []);
    contractChannels.get(c).push(ch);
  }
}

const report = [];
for (const [name, { file, go }] of sources) {
  const fns = analyse(name, go);
  const writers = fns.filter((f) => f.writes && !RESERVED.has(f.name));
  const primary = writers[0] || null;
  report.push({
    name,
    file,
    channels: contractChannels.get(name) || [],
    functions: fns,
    writers,
    primary,
    blocked: !primary ? 'no-write-function'
      : primary.readsForeignKey ? 'needs-seed'
      : null,
    hasNonStringWriter: writers.some((w) => w.nonString),
    readModifyWrite: primary ? primary.readsFirst : false,
  });
}

report.sort((a, b) => a.name.localeCompare(b.name));
fs.writeFileSync('/tmp/inventory.json', JSON.stringify(report, null, 1));

const inCatalog = new Set(Object.values(CHANNELS).flat());
console.log(`Go sources parsed:        ${sources.size}`);
console.log(`Contracts in the catalog: ${inCatalog.size}`);
console.log(`Missing Go source:        ${[...inCatalog].filter((c) => !sources.has(c)).join(', ') || 'none'}`);
console.log(`Not on any channel:       ${[...sources.keys()].filter((c) => !contractChannels.has(c)).join(', ') || 'none'}`);
console.log('');
console.log(`Blocked — no write fn:    ${report.filter((r) => r.blocked === 'no-write-function').map((r) => r.name).join(', ') || 'none'}`);
console.log(`Blocked — needs a seed:   ${report.filter((r) => r.blocked === 'needs-seed').length}`);
console.log(`  ${report.filter((r) => r.blocked === 'needs-seed').map((r) => r.name).join('\n  ')}`);
console.log('');
console.log(`Read-modify-write primary: ${report.filter((r) => r.readModifyWrite && !r.blocked).length}`);
console.log(`Non-string writer params:  ${report.filter((r) => r.hasNonStringWriter).map((r) => r.name).join(', ')}`);
console.log(`Delete functions:          ${report.filter((r) => r.functions.some((f) => f.deletes)).map((r) => r.name).join(', ')}`);
