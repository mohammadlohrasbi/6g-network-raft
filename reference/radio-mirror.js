'use strict';
/* Mirror of the fixed-point radio kernel, used to validate the algorithms
   before they are emitted as Go. Every operation here is integer-only and
   maps 1:1 onto int64 Go arithmetic, so agreement with the float reference
   proves the Go version is both correct and deterministic.

   Units throughout:
     position, distance   metres            (integer)
     power, RSSI, SINR    milli-dB / mdBm   (1 dB = 1000)
     frequency            MHz               (integer)
     bandwidth            Hz                (integer)
     linear power         Q16, offset 150dB (integer)                     */

const Q = 16;
const ONE = 1 << Q;                 // 65536
const DB_OFFSET = 150000;           // shifts the weakest signal above unity
const LOG2_10_OVER_10 = 3322;       // log2(10)/10 * 10000

/* ── integer square root (Newton, exact floor) ───────────────────────── */
function isqrt(n) {
  if (n < 0) throw new Error('isqrt of a negative');
  if (n < 2) return n;
  let x = n, y = Math.floor((x + 1) / 2);
  while (y < x) { x = y; y = Math.floor((x + Math.floor(n / x)) / 2); }
  return x;
}

/* ── log2 in milli-units, integer only ───────────────────────────────
   x = 2^k · m with m in [1,2). The integer part is the bit length; the
   fraction comes from repeated squaring, which is exact in integers.   */
function log2Milli(x) {
  if (x <= 0) return -(1 << 30);          // floor for "no power"
  let k = 0, v = x;
  while (v >= 2) { v = Math.floor(v / 2); k++; }

  // m in Q16, range [ONE, 2*ONE)
  let m = k <= Q ? x * (1 << (Q - k)) : Math.floor(x / (1 << (k - Q)));

  let frac = 0;
  for (let i = 0; i < 20; i++) {
    m = Math.floor((m * m) / ONE);        // square, stay in Q16
    frac <<= 1;
    if (m >= 2 * ONE) { m = Math.floor(m / 2); frac |= 1; }
  }
  return k * 1000 + Math.floor((frac * 1000) / (1 << 20));
}

function log10Milli(x) {
  // log10 = log2 / log2(10);  log2(10) = 3.321928
  return Math.floor((log2Milli(x) * 10000) / 33219);
}

/* ── 2^(f/1000) for f in [0,1000), Q16 ──────────────────────────────
   Binary decomposition: 2^(f/1000) = Π 2^(bit_i / 2^i).                */
const HALF_POWERS = [           // 2^(1/2^(i+1)) in Q16, exact to the rounding
  92682, 77936, 71468, 68438, 66971, 66250, 65892, 65714, 65625, 65580,
];

/* Decompose the fraction in binary against the table. f arrives in milli
   units; convert to a 10-bit binary fraction first, because dividing 1000
   by powers of two truncates and the error compounds across ten steps. */
function exp2FracQ16(f) {
  let r = ONE;
  const bits = Math.floor((f * 1024) / 1000);      // 0..1023
  for (let i = 0; i < 10; i++) {
    if (bits & (1 << (9 - i))) r = Math.floor((r * HALF_POWERS[i]) / ONE);
  }
  return r;
}

/* Floor division — Go truncates toward zero, which breaks the exponent
   split for negative powers, so both sides use an explicit floor. */
function floorDiv(a, b) {
  const q = Math.trunc(a / b);
  return (a % b !== 0 && (a < 0) !== (b < 0)) ? q - 1 : q;
}

function exp2Q16(milli) {
  const k = floorDiv(milli, 1000);
  const f = milli - k * 1000;                      // always 0..999
  const frac = BigInt(exp2FracQ16(f));
  if (k >= 0) {
    if (k >= 62) return (1n << 62n);               // saturate rather than wrap
    return frac << BigInt(k);
  }
  if (k <= -17) return 0n;                         // below Q16 resolution
  return frac >> BigInt(-k);
}

/* ── dB ↔ linear ─────────────────────────────────────────────────────
   Linear power is offset by DB_OFFSET so the weakest signal of interest
   still lands above unity in Q16. Values reach ~2^55, which int64 holds
   exactly; the mirror uses BigInt for the same reason.                  */
function linearQ16(mdbm) {
  const e = floorDiv((mdbm + DB_OFFSET) * LOG2_10_OVER_10, 10000);
  return exp2Q16(e);
}

function dbmFromLinearQ16(lin) {
  if (lin <= 0n) return -DB_OFFSET;
  const l2 = log2MilliBig(lin) - Q * 1000;         // undo Q16
  return Math.floor((l2 * 10000) / LOG2_10_OVER_10) - DB_OFFSET;
}

/* log2 of a BigInt, milli units — same algorithm, wider input. */
function log2MilliBig(x) {
  if (x <= 0n) return -(1 << 30);
  let k = 0, v = x;
  while (v >= 2n) { v >>= 1n; k++; }
  let m = k <= Q ? x << BigInt(Q - k) : x >> BigInt(k - Q);
  const oneB = BigInt(ONE);
  let frac = 0;
  for (let i = 0; i < 20; i++) {
    m = (m * m) / oneB;
    frac <<= 1;
    if (m >= 2n * oneB) { m >>= 1n; frac |= 1; }
  }
  return k * 1000 + Math.floor((frac * 1000) / (1 << 20));
}

/* ── deterministic shadowing ─────────────────────────────────────────
   Fabric forbids rand and clocks, so shadow fading is derived from a
   hash of the identifiers and the scenario seed. Same inputs always give
   the same value on every peer, while different links get different
   fades — which is what shadowing means physically.                    */
function fnv1a(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h = (h ^ s.charCodeAt(i)) >>> 0;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/* Murmur3 finalizer. FNV alone mixes poorly between strings that differ
   only in their last character — the four draws below came out correlated
   at −0.42, which compressed the spread to 64% of the requested sigma.
   Running each draw through an avalanche step fixes that. */
function mix32(x) {
  x = (x ^ (x >>> 16)) >>> 0;
  x = Math.imul(x, 0x85ebca6b) >>> 0;
  x = (x ^ (x >>> 13)) >>> 0;
  x = Math.imul(x, 0xc2b2ae35) >>> 0;
  return (x ^ (x >>> 16)) >>> 0;
}

/* Shadow fading. Fabric forbids rand and clocks, so the fade is derived
   from the identifiers and the scenario seed: identical inputs give an
   identical value on every peer, while different links fade differently —
   which is what shadowing means physically.

   Four uniforms are summed (Irwin–Hall) to approximate a normal variate;
   their sum has sd = 1000/sqrt(12)*2 = 577.4, so dividing by 577 yields
   unit variance before scaling to the requested sigma. */
function shadowingMilliDb(seed, a, b, sigmaMilliDb) {
  const h = fnv1a(`${seed}|${a}|${b}`);
  let acc = 0;
  for (let i = 0; i < 4; i++) {
    acc += mix32((h + Math.imul(i, 0x9e3779b9)) >>> 0) % 1000;
  }
  return Math.floor(((acc - 2000) * sigmaMilliDb) / 577);
}

/* ── radio model ─────────────────────────────────────────────────── */
function distanceM(x1, y1, x2, y2) {
  const dx = x1 - x2, dy = y1 - y2;
  return isqrt(dx * dx + dy * dy);
}

/* Log-distance path loss, 3GPP-style free-space anchor:
     PL(d) = 32.4 + 20·log10(f_MHz/1000) + 10·n·log10(d)
           = 20·log10(f_MHz) + 10·n·log10(d) − 27.6                     */
function pathLossMilliDb(distM, freqMHz, exponentMilli) {
  const d = distM < 1 ? 1 : distM;
  return 20 * log10Milli(freqMHz)
    + Math.floor((exponentMilli * log10Milli(d)) / 10)
    - 27600;
}

/* Thermal noise: −174 dBm/Hz + 10·log10(BW) + noise figure */
function noiseFloorMilliDbm(bandwidthHz, noiseFigureMilliDb) {
  return -174000 + 10 * log10Milli(bandwidthHz) + noiseFigureMilliDb;
}

function rssiMilliDbm(txPowerMilliDbm, gainMilliDb, plMilliDb, shadowMilliDb) {
  return txPowerMilliDbm + gainMilliDb - plMilliDb - shadowMilliDb;
}

/* SINR = S / (ΣI + N), summed in the linear domain then returned in dB */
function sinrMilliDb(signalMdbm, interferersMdbm, noiseMdbm) {
  let denom = linearQ16(noiseMdbm);
  for (const i of interferersMdbm) denom += linearQ16(i);
  return signalMdbm - dbmFromLinearQ16(denom);
}

/* Shannon: C = BW · log2(1 + SINR_linear), bits/s */
/* Shannon: C = BW · log2(1 + SINR_linear), bits/s.
   SINR is a ratio, so it converts with no dBm offset. */
function shannonBps(bandwidthHz, sinrMdb) {
  const e = floorDiv(sinrMdb * LOG2_10_OVER_10, 10000);   // log2 of the ratio
  const ratioQ16 = exp2Q16(e);
  const spectralMilli = log2MilliBig(BigInt(ONE) + ratioQ16) - Q * 1000;
  if (spectralMilli <= 0) return 0;
  return Math.floor((bandwidthHz * spectralMilli) / 1000);
}


/* ── power, time and energy ───────────────────────────────────────── */
function microWattFromMilliDbm(mdbm) {
  const e = floorDiv((mdbm + 30000) * LOG2_10_OVER_10, 10000);
  return Number(exp2Q16(e) >> BigInt(Q));
}
function transmitTimeMicroS(dataBits, rateBps) {
  if (rateBps <= 0) return -1;
  return Math.floor((dataBits * 1000000) / rateBps);
}
function transmitEnergyMicroJ(txPowerMilliDbm, dataBits, rateBps) {
  const t = transmitTimeMicroS(dataBits, rateBps);
  if (t < 0) return -1;
  return Math.floor((microWattFromMilliDbm(txPowerMilliDbm) * t) / 1000000);
}

module.exports = {
  isqrt, log2Milli, log10Milli, exp2Q16, linearQ16, dbmFromLinearQ16,
  shadowingMilliDb, distanceM, pathLossMilliDb, noiseFloorMilliDbm, log2MilliBig,
  rssiMilliDbm, sinrMilliDb, shannonBps, fnv1a, mix32, floorDiv, ONE, DB_OFFSET,
  microWattFromMilliDbm, transmitTimeMicroS, transmitEnergyMicroJ,
};
