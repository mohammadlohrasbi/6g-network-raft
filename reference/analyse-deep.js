#!/usr/bin/env node
'use strict';

/* Deep inventory: data model, ledger key, and behaviour of every function,
   read from the Go source rather than inferred from names. */

const fs = require('fs');
const path = require('path');

const SCRIPTS = process.argv[2];
const { CHANNEL_CHAINCODE_MAP: CHANNELS } = require(process.argv[3]);

const sources = new Map();
for (const f of fs.readdirSync(SCRIPTS).filter((n) => /^generateChaincodes_part\d+\.sh$/.test(n))) {
  const text = fs.readFileSync(path.join(SCRIPTS, f), 'utf8');
  const re = /^\s{8}([A-Za-z0-9_]+)\)\s*\n\s*cat > chaincode\/\$contract\/chaincode\.go <<'EOF'\n([\s\S]*?)\nEOF/gm;
  for (const m of text.matchAll(re)) sources.set(m[1], { file: f, go: m[2] });
}

function structs(go) {
  const out = [];
  for (const m of go.matchAll(/type ([A-Za-z0-9_]+) struct \{([\s\S]*?)\n\}/g)) {
    const fields = [];
    for (const line of m[2].split('\n')) {
      const f = line.match(/^\s*([A-Za-z0-9_]+)\s+([A-Za-z0-9_\[\]*.]+)\s*`json:"([^"]+)"`/);
      if (f) fields.push({ name: f[1], type: f[2], json: f[3] });
    }
    if (fields.length) out.push({ name: m[1], fields });
  }
  return out;
}

function bodyOf(go, from) {
  let depth = 1, i = from;
  while (i < go.length && depth > 0) {
    if (go[i] === '{') depth++;
    else if (go[i] === '}') depth--;
    i++;
  }
  return go.slice(from, i);
}

function splitParams(raw) {
  const parts = raw.split(',').map((s) => s.trim()).filter(Boolean);
  const params = parts.map((g) => {
    const bits = g.split(/\s+/);
    return bits.length > 1
      ? { name: bits[0], type: bits.slice(1).join(' ') }
      : { name: bits[0], type: null };
  });
  for (let k = params.length - 1; k >= 0; k--) {
    if (!params[k].type) params[k].type = params[k + 1] ? params[k + 1].type : 'string';
  }
  return params;
}

const RESERVED = new Set(['Init', 'QueryAsset', 'QueryAllAssets']);

function analyse(name, go) {
  const fns = [];
  const re = new RegExp(
    `func \\(s \\*${name}\\) ([A-Za-z0-9_]+)\\(ctx contractapi\\.TransactionContextInterface(?:, )?([^)]*)\\)([^{]*)\\{`, 'g');

  for (const m of go.matchAll(re)) {
    const [, fn, rawParams, ret] = m;
    const body = bodyOf(go, m.index + m[0].length);
    const params = splitParams(rawParams);

    // Which value becomes the ledger key.
    const put = body.match(/PutState\(\s*([A-Za-z0-9_.]+)\s*,/);
    const del = body.match(/DelState\(\s*([A-Za-z0-9_.]+)\s*\)/);

    fns.push({
      name: fn,
      params,
      returns: ret.trim().replace(/\s+/g, ' '),
      writes: /PutState/.test(body),
      deletes: /DelState/.test(body),
      key: put ? put[1] : del ? del[1] : null,
      readsSelf: /s\.QueryAsset\(ctx,\s*([A-Za-z0-9_]+)\)/.test(body),
      readsWhat: (body.match(/s\.QueryAsset\(ctx,\s*([A-Za-z0-9_]+)\)/) || [])[1] || null,
      computesDistance: /calculateDistance\(/.test(body),
      iterates: /GetStateByRange|GetQueryResult/.test(body),
      timestamps: /txTimestamp\(/.test(body),
      reserved: RESERVED.has(fn),
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
  const st = structs(go).filter((s) => s.name !== name);
  const writers = fns.filter((f) => f.writes && !f.reserved);
  const primary = writers[0] || null;
  report.push({
    name,
    file,
    channels: contractChannels.get(name) || [],
    struct: st[0] || null,
    functions: fns,
    writers,
    primary,
    validators: fns.filter((f) => !f.writes && /^Validate/.test(f.name)),
    spatial: !!(primary && primary.params.some((p) => p.name === 'x')),
    blocked: !primary ? 'no-write'
      : (primary.readsWhat && /antenna/i.test(primary.readsWhat)) ? 'needs-seed'
      : null,
    readModifyWrite: !!(primary && primary.readsSelf && primary.readsWhat
      && !/antenna/i.test(primary.readsWhat)),
  });
}

report.sort((a, b) => a.name.localeCompare(b.name));
fs.writeFileSync('/tmp/deep.json', JSON.stringify(report, null, 1));

console.log(`contracts: ${report.length}`);
console.log(`with a struct: ${report.filter((r) => r.struct).length}`);
console.log(`spatial: ${report.filter((r) => r.spatial).length}`);
console.log(`with validators: ${report.filter((r) => r.validators.length).length}`);
console.log(`key == first param: ${report.filter((r) => r.primary && r.primary.key === r.primary.params[0]?.name).length}`);
const fields = new Map();
for (const r of report) for (const f of (r.struct?.fields || [])) fields.set(f.json, (fields.get(f.json) || 0) + 1);
console.log('common fields:', [...fields].sort((a, b) => b[1] - a[1]).slice(0, 12).map(([k, v]) => `${k}(${v})`).join(' '));
