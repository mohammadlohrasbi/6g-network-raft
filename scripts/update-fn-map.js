#!/usr/bin/env node
'use strict';

/* Rewrites server/contract-fn-map.js so it matches the regenerated spatial
   contracts. Three things change for the 34 of them:

     · antennaID leaves the parameter list — the contract now selects the
       serving cell itself, so nothing outside it names one. The exception
       is LocationBasedAntennaConfig, which acts ON a cell.
     · seed joins the end, so every write is evaluated against a known layout.
     · antennaDep becomes false everywhere: the seven contracts that could
       not run are now seeded by SeedNetwork instead of needing an antenna
       record that only they could create.

   A new needsSeed flag records which contracts must have SeedNetwork called
   before they will accept a write. The benchmark uses it to decide what to
   prepare. */

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..');
const mapPath = path.join(repoRoot, 'server', 'contract-fn-map.js');
// Shipped beside this script. It used to be read from /tmp, which only
// existed on the machine that generated it — on a real server the script
// died with MODULE_NOT_FOUND before doing anything.
const sigPath = path.join(__dirname, 'spatial-signatures.json');
if (!fs.existsSync(sigPath)) {
  console.error(`spatial-signatures.json is missing from ${__dirname}.`);
  console.error('It ships alongside this script; copy it from the package.');
  process.exit(1);
}
const sigs = require(sigPath);

const { CONTRACT_FN } = require(mapPath);
const bySig = Object.fromEntries(sigs.map((s) => [s.contract, s]));

const lines = [
  "'use strict';",
  '',
  '// تولیدشده خودکار از کد ۸۶ قرارداد — نگاشت تابع نوشتنی و پارامترهای هر قرارداد',
  '//',
  '// needsSeed: قراردادهای مکانی که سلول سرویس‌دهنده را خودشان انتخاب می‌کنند و',
  '// پیش از هر نوشتنی به SeedNetwork نیاز دارند تا چیدمان آنتن موجود باشد.',
  '// antennaDep دیگر در هیچ قراردادی true نیست: هفت قرارداد قفل‌شده حالا از',
  '// طریق SeedNetwork بذرکاری می‌شوند به‌جای اینکه رکورد آنتنی بخواهند که فقط',
  '// خودشان می‌توانستند بسازند.',
  'const CONTRACT_FN = {',
];

let changed = 0;
for (const name of Object.keys(CONTRACT_FN).sort()) {
  const cur = CONTRACT_FN[name];
  const s = bySig[name];
  const fn = s ? s.fn : cur.fn;
  const params = s ? s.params : cur.params;
  const needsSeed = !!s;
  const antennaDep = false;
  if (s && JSON.stringify(params) !== JSON.stringify(cur.params)) changed++;

  lines.push(
    `  ${name}: { fn: '${fn}', params: ${JSON.stringify(params)}, ` +
    `antennaDep: ${antennaDep}, needsSeed: ${needsSeed} },`);
}

// VerifyIdentity was never blocked — it writes with a blind PutState. The
// auto-mapper skipped it only because its second parameter is a bool, the
// one non-string writer on the network. contractapi parses "true" itself.
if (!CONTRACT_FN.VerifyIdentity) {
  lines.push(
    "  VerifyIdentity: { fn: 'Verify', params: [\"entityID\", \"verified\"], " +
    'antennaDep: false, needsSeed: false },');
}

lines.push('};', '', 'module.exports = { CONTRACT_FN };', '');
fs.writeFileSync(mapPath, lines.join('\n'), 'utf8');

console.log(`contract-fn-map.js rewritten`);
console.log(`  contracts:        ${Object.keys(CONTRACT_FN).length + (CONTRACT_FN.VerifyIdentity ? 0 : 1)}`);
console.log(`  signatures changed: ${changed}`);
console.log(`  needsSeed:        ${sigs.length}`);
