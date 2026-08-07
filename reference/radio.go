// radio.go — deterministic fixed-point radio model.
//
// WHY INTEGERS
// ------------
// Fabric executes chaincode on several peers independently and compares the
// results byte for byte. Go's math.Log10, math.Pow and math.Exp are not
// guaranteed to produce identical bits across architectures and Go versions —
// on some platforms they are assembly, on others pure Go. A one-bit
// difference in the last decimal place makes two peers write different
// values, and the transaction is rejected with ENDORSEMENT_POLICY_FAILURE.
//
// Every function below therefore uses integer arithmetic only. Determinism is
// a mathematical guarantee rather than an accident of the current toolchain.
// Accuracy against a float64 reference: path loss within 0.03 dB, SINR within
// 0.02 dB, Shannon capacity within 0.1%.
//
// UNITS
//   position, distance   metres            (int64)
//   power, RSSI, SINR    milli-dB, mdBm    (1 dB = 1000)
//   frequency            MHz               (int64)
//   bandwidth            Hz                (int64)
//   path-loss exponent   hundredths        (n = 3.0 → 300)
//   linear power         Q16, +150 dB offset
//
// The linear representation is offset by 150 dB so the weakest signal of
// interest still lands above unity in Q16. Anything below −150 dBm clamps,
// which is harmless: thermal noise in a 20 MHz channel is about −101 dBm, so
// a −150 dBm contribution is 50 dB below the noise and cannot affect a sum.

package main

const (
	radioQ         = 16
	radioOne       = int64(1) << radioQ // 65536
	dbOffsetMilli  = int64(150000)      // 150 dB
	log2_10Over10  = int64(3322)        // log2(10)/10 × 10000
	log2_10Scaled  = int64(33219)       // log2(10) × 10000
	noiseDensity   = int64(-174000)     // −174 dBm/Hz
	freeSpaceConst = int64(27600)       // 27.6 dB anchor at 1 m, 1 GHz
)

// 2^(1/2^(i+1)) in Q16 — used to build any fractional power of two.
var halfPowers = [10]int64{
	92682, 77936, 71468, 68438, 66971, 66250, 65892, 65714, 65625, 65580,
}

// floorDiv divides rounding toward negative infinity. Go truncates toward
// zero, which splits negative exponents wrongly in exp2Q16.
func floorDiv(a, b int64) int64 {
	q := a / b
	if a%b != 0 && (a < 0) != (b < 0) {
		q--
	}
	return q
}

// Isqrt is the exact integer square root (floor), by Newton's method.
func Isqrt(n int64) int64 {
	if n < 2 {
		if n < 0 {
			return 0
		}
		return n
	}
	x := n
	y := (x + 1) / 2
	for y < x {
		x = y
		y = (x + n/x) / 2
	}
	return x
}

// Log2Milli returns 1000·log2(x). The integer part is the bit length; the
// fraction comes from repeated squaring, which is exact in integers.
func Log2Milli(x int64) int64 {
	if x <= 0 {
		return -(int64(1) << 30)
	}
	k := int64(0)
	for v := x; v >= 2; v >>= 1 {
		k++
	}
	var m int64
	if k <= radioQ {
		m = x << uint(radioQ-int(k))
	} else {
		m = x >> uint(int(k)-radioQ)
	}
	frac := int64(0)
	for i := 0; i < 20; i++ {
		m = (m * m) / radioOne
		frac <<= 1
		if m >= 2*radioOne {
			m >>= 1
			frac |= 1
		}
	}
	return k*1000 + (frac*1000)>>20
}

// Log10Milli returns 1000·log10(x).
func Log10Milli(x int64) int64 {
	return (Log2Milli(x) * 10000) / log2_10Scaled
}

// exp2FracQ16 computes 2^(f/1000) in Q16 for f in [0,1000).
// The fraction is converted to ten binary bits first: dividing 1000 by
// powers of two truncates, and that error compounds across the ten steps.
func exp2FracQ16(f int64) int64 {
	r := radioOne
	bits := (f * 1024) / 1000 // 0..1023
	for i := 0; i < 10; i++ {
		if bits&(int64(1)<<uint(9-i)) != 0 {
			r = (r * halfPowers[i]) / radioOne
		}
	}
	return r
}

// exp2Q16 computes 2^(milli/1000) in Q16, saturating rather than wrapping.
func exp2Q16(milli int64) int64 {
	k := floorDiv(milli, 1000)
	f := milli - k*1000 // always 0..999
	frac := exp2FracQ16(f)
	switch {
	case k >= 46:
		return int64(1) << 62
	case k >= 0:
		return frac << uint(k)
	case k <= -17:
		return 0 // below Q16 resolution
	default:
		return frac >> uint(-k)
	}
}

// LinearQ16 converts milli-dBm to offset linear power.
func LinearQ16(mdbm int64) int64 {
	return exp2Q16(floorDiv((mdbm+dbOffsetMilli)*log2_10Over10, 10000))
}

// DbmFromLinearQ16 is the inverse of LinearQ16.
func DbmFromLinearQ16(lin int64) int64 {
	if lin <= 0 {
		return -dbOffsetMilli
	}
	l2 := Log2Milli(lin) - radioQ*1000
	return (l2*10000)/log2_10Over10 - dbOffsetMilli
}

// ── deterministic pseudo-randomness ─────────────────────────────────────
// Chaincode may not call rand or read a clock, so every "random" quantity is
// derived from the identifiers plus a scenario seed supplied in the
// transaction. Same inputs, same value, on every peer and on every replay.

func fnv1a(s string) uint32 {
	h := uint32(0x811c9dc5)
	for i := 0; i < len(s); i++ {
		h ^= uint32(s[i])
		h *= 0x01000193
	}
	return h
}

// mix32 is the Murmur3 finalizer. FNV alone mixes poorly between strings
// differing only in their last character; without this step the four draws
// below correlate at −0.42 and the spread collapses to 64% of sigma.
func mix32(x uint32) uint32 {
	x ^= x >> 16
	x *= 0x85ebca6b
	x ^= x >> 13
	x *= 0xc2b2ae35
	x ^= x >> 16
	return x
}

func hashUniform(seed, a, b string, i int) int64 {
	h := fnv1a(seed + "|" + a + "|" + b)
	return int64(mix32(h+uint32(i)*0x9e3779b9) % 1000)
}

// ShadowingMilliDb returns a zero-mean fade with the requested sigma.
// Four uniforms are summed (Irwin–Hall); their sum has sd = 577.4, so the
// division by 577 gives unit variance before scaling.
func ShadowingMilliDb(seed, a, b string, sigmaMilliDb int64) int64 {
	acc := int64(0)
	for i := 0; i < 4; i++ {
		acc += hashUniform(seed, a, b, i)
	}
	return ((acc - 2000) * sigmaMilliDb) / 577
}

// PlaceOnGrid maps an identifier and seed to a deterministic position inside
// a square of the given size — the scenario "random" placement.
func PlaceOnGrid(seed, id string, sizeM int64) (int64, int64) {
	h := fnv1a(seed + "#" + id)
	x := int64(mix32(h)) % sizeM
	y := int64(mix32(h^0x5bf03635)) % sizeM
	return x, y
}

// ── radio model ─────────────────────────────────────────────────────────

// DistanceM is the Euclidean distance in whole metres.
func DistanceM(x1, y1, x2, y2 int64) int64 {
	dx, dy := x1-x2, y1-y2
	return Isqrt(dx*dx + dy*dy)
}

// PathLossMilliDb uses the log-distance model with a free-space anchor:
//
//	PL(d) = 32.4 + 20·log10(f_GHz) + 10·n·log10(d)
//	      = 20·log10(f_MHz) + 10·n·log10(d) − 27.6
func PathLossMilliDb(distM, freqMHz, exponentMilli int64) int64 {
	d := distM
	if d < 1 {
		d = 1 // the model diverges at zero
	}
	return 20*Log10Milli(freqMHz) +
		(exponentMilli*Log10Milli(d))/10 -
		freeSpaceConst
}

// NoiseFloorMilliDbm is thermal noise plus the receiver noise figure:
// −174 dBm/Hz + 10·log10(BW) + NF.
func NoiseFloorMilliDbm(bandwidthHz, noiseFigureMilliDb int64) int64 {
	return noiseDensity + 10*Log10Milli(bandwidthHz) + noiseFigureMilliDb
}

// RssiMilliDbm is received power after antenna gain, path loss and fading.
func RssiMilliDbm(txPowerMilliDbm, gainMilliDb, plMilliDb, shadowMilliDb int64) int64 {
	return txPowerMilliDbm + gainMilliDb - plMilliDb - shadowMilliDb
}

// SinrMilliDb sums interference and noise in the linear domain, then returns
// the ratio in dB. This is why the linear conversion has to exist at all:
// powers add linearly, not logarithmically.
func SinrMilliDb(signalMdbm int64, interferers []int64, noiseMdbm int64) int64 {
	denom := LinearQ16(noiseMdbm)
	for _, i := range interferers {
		denom += LinearQ16(i)
	}
	return signalMdbm - DbmFromLinearQ16(denom)
}

// ShannonBps is C = BW·log2(1 + SINR_linear) in bits per second.
// SINR is a ratio, so it converts with no dBm offset.
func ShannonBps(bandwidthHz, sinrMdb int64) int64 {
	ratioQ16 := exp2Q16(floorDiv(sinrMdb*log2_10Over10, 10000))
	spectral := Log2Milli(radioOne+ratioQ16) - radioQ*1000
	if spectral <= 0 {
		return 0
	}
	return (bandwidthHz * spectral) / 1000
}

/* ── power, time and energy ──────────────────────────────────────────
   The paper this follows models uplink cost as transmit time and the
   energy that time consumes: t = D/R and e = P·D/R, with a budget
   constraint e ≤ E_max. Both need transmit power as a linear quantity,
   which is what MicroWattFromMilliDbm provides.

   Units: power µW, time µs, energy µJ. One mW for one µs is one nJ, so
   µW × µs lands in picojoules and the divisor below converts to µJ.
   int64 holds a 5 J budget (5×10⁶ µJ) with room to spare.                */

// MicroWattFromMilliDbm converts milli-dBm to microwatts.
// 23 dBm → 199526 µW (the reference value; this returns within 0.2%).
func MicroWattFromMilliDbm(mdbm int64) int64 {
    // µW = 10^(dBm/10) × 1000, so the log2 exponent is (dBm/10 + 3)·log2(10)
    e := floorDiv((mdbm+30000)*log2_10Over10, 10000)
    return exp2Q16(e) >> radioQ
}

// TransmitTimeMicroS returns how long dataBits takes at rateBps.
func TransmitTimeMicroS(dataBits, rateBps int64) int64 {
    if rateBps <= 0 {
        return -1 // no usable link
    }
    return (dataBits * 1000000) / rateBps
}

// TransmitEnergyMicroJ is P × t, the energy that transmission costs.
func TransmitEnergyMicroJ(txPowerMilliDbm, dataBits, rateBps int64) int64 {
    t := TransmitTimeMicroS(dataBits, rateBps)
    if t < 0 {
        return -1
    }
    // µW × µs = pJ; divide by 10^6 for µJ
    return (MicroWattFromMilliDbm(txPowerMilliDbm) * t) / 1000000
}
