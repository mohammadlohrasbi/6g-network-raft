'use strict';

/* marketBlock — the resource market, injected into every spatial contract.
 *
 * The governing rule is that a contract only accepts what it can check for
 * itself. That rules out self-reported numbers and shapes every mechanism
 * here:
 *
 *   spectrum  the contract issued the grant, so it knows exactly how much
 *             an entity holds; sharing moves part of that grant
 *   energy    the contract meters every transmission, so the battery
 *             figure is its own, not the entity's claim
 *   compute   nothing on-chain can watch a CPU, so work is proven rather
 *             than reported: the worker searches for a nonce, the contract
 *             verifies it with a single hash
 *
 * Accounts are striped. A payment concentrates writes on whoever is paid,
 * and with eight operators that is eight keys taking every credit in the
 * block — the same read-modify-write contention that capacity tracking
 * showed. Splitting a balance across sub-keys spreads it; the stripe count
 * is configurable so the effect can be measured rather than assumed.
 */

module.exports = function marketBlock(contract, recordType) {
  return `
// ═══════════════════════════════════════════════════════════════════════
// Resource market — accounts, verifiable sharing, proof of work, relaying.
// ═══════════════════════════════════════════════════════════════════════

const (
    accountPrefix = "~ACC:"
    taskPrefix    = "~TASK:"   // relay deals
    grantPrefix   = "~GRANT:"
    // The price of one QoS tier. Defined here beside the other market
    // constants, though NetworkConfig — written by the network block — is
    // what reads it: Go compiles both blocks into one package, so where a
    // constant is declared does not matter, only that it is declared once.
    defaultQosPrice    = int64(50000)  // 0.05 coin per tier
    defaultStripes     = int64(1)
    defaultPriceScale  = int64(1000)  // micro-tokens per µJ-equivalent
)

// Account is one participant's balance. It is stored across Stripes
// sub-keys: see stripeOf for why.
type Account struct {
    AccountID   string \`json:"accountID"\`
    Balance     int64  \`json:"balance"\`
    Earned      int64  \`json:"earned"\`
    Spent       int64  \`json:"spent"\`
    TxCount     int64  \`json:"txCount"\`
    Timestamp   string \`json:"timestamp"\`
}

// SpectrumGrant is what an entity holds and may sublet. The contract
// issued it, so the figure cannot be forged by the holder.
type SpectrumGrant struct {
    EntityID  string \`json:"entityID"\`
    Cell      string \`json:"servingCell"\`
    HeldHz    int64  \`json:"heldHz"\`
    SubletHz  int64  \`json:"subletHz"\`
    Timestamp string \`json:"timestamp"\`
}

// RelayDeal records a two-hop delivery: the edge entity paid, the relay
// carried. Both figures come from the propagation model, not from either
// party.
type RelayDeal struct {
    DealID        string \`json:"dealID"\`
    EdgeEntity    string \`json:"edgeEntity"\`
    RelayEntity   string \`json:"relayEntity"\`
    DirectEnergy  int64  \`json:"directEnergyMicroJ"\`
    RelayedEnergy int64  \`json:"relayedEnergyMicroJ"\`
    SavedMicroJ   int64  \`json:"savedMicroJ"\`
    PaidMicro     int64  \`json:"paidMicro"\`
    Timestamp     string \`json:"timestamp"\`
}

/* ── striping ──────────────────────────────────────────────────────────
   Credits land on a stripe chosen from the transaction id, which every
   endorsing peer derives identically. Debits walk the stripes from the
   same starting point and take from the first that can cover the amount.  */

func stripeOf(ctx contractapi.TransactionContextInterface, accountID string, stripes int64) int64 {
    if stripes <= 1 {
        return 0
    }
    return int64(mix32(fnv1a(ctx.GetStub().GetTxID()+"|"+accountID))) % stripes
}

func stripeKey(accountID string, stripe int64) string {
    return accountPrefix + accountID + ":" + strconv.FormatInt(stripe, 10)
}

func (s *${contract}) readStripe(ctx contractapi.TransactionContextInterface, accountID string, stripe int64, cfg *NetworkConfig) (*Account, error) {
    b, err := ctx.GetStub().GetState(stripeKey(accountID, stripe))
    if err != nil {
        return nil, err
    }
    if b == nil {
        // A wallet opens at first touch with a starting balance, the same way
        // energyOf hands out a full battery. Without it, benchmarking any
        // paying operation measured "insufficient funds" rather than the
        // operation itself — a cold BuyQos could never succeed, because the
        // account it charges had never been minted into.
        //
        // Only stripe 0 carries the opening balance, so BalanceOf still sums
        // to one starting balance rather than one per stripe.
        opening := int64(0)
        if stripe == 0 {
            opening = cfg.InitialBalanceMicro
        }
        return &Account{AccountID: accountID, Balance: opening}, nil
    }
    var a Account
    if err := json.Unmarshal(b, &a); err != nil {
        return nil, err
    }
    return &a, nil
}

func (s *${contract}) writeStripe(ctx contractapi.TransactionContextInterface, a *Account, stripe int64) error {
    a.Timestamp = txTimestamp(ctx)
    b, err := json.Marshal(a)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(stripeKey(a.AccountID, stripe), b)
}

// credit adds to one stripe — the write that striping is meant to spread.
func (s *${contract}) credit(ctx contractapi.TransactionContextInterface, accountID string, amount int64, cfg *NetworkConfig) error {
    if amount <= 0 {
        return nil
    }
    st := stripeOf(ctx, accountID, cfg.Stripes)
    a, err := s.readStripe(ctx, accountID, st, cfg)
    if err != nil {
        return err
    }
    a.Balance += amount
    a.Earned += amount
    a.TxCount++
    return s.writeStripe(ctx, a, st)
}

// debit takes from the first stripe that can cover the amount, starting at
// the transaction's own stripe so concurrent debits do not all begin at
// stripe zero.
func (s *${contract}) debit(ctx contractapi.TransactionContextInterface, accountID string, amount int64, cfg *NetworkConfig) error {
    if amount <= 0 {
        return nil
    }
    start := stripeOf(ctx, accountID, cfg.Stripes)
    for i := int64(0); i < cfg.Stripes; i++ {
        st := (start + i) % cfg.Stripes
        a, err := s.readStripe(ctx, accountID, st, cfg)
        if err != nil {
            return err
        }
        if a.Balance >= amount {
            a.Balance -= amount
            a.Spent += amount
            a.TxCount++
            return s.writeStripe(ctx, a, st)
        }
    }
    return fmt.Errorf(
        "%s cannot cover %d micro-tokens across %d stripes — an account opens with %d, so this has been spent",
        accountID, amount, cfg.Stripes, cfg.InitialBalanceMicro)
}

// Mint creates tokens. Bootstrap only — there is no supply counter, which
// deliberately avoids one global key every mint would contend on.
func (s *${contract}) Mint(ctx contractapi.TransactionContextInterface, accountID, amount string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    n, err := strconv.ParseInt(amount, 10, 64)
    if err != nil || n <= 0 {
        return fmt.Errorf("amount must be a positive whole number, got %q", amount)
    }
    return s.credit(ctx, accountID, n, cfg)
}

// BalanceOf sums every stripe.
func (s *${contract}) BalanceOf(ctx contractapi.TransactionContextInterface, accountID string) (*Account, error) {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return nil, err
    }
    total := Account{AccountID: accountID}
    for st := int64(0); st < cfg.Stripes; st++ {
        a, err := s.readStripe(ctx, accountID, st, cfg)
        if err != nil {
            return nil, err
        }
        total.Balance += a.Balance
        total.Earned += a.Earned
        total.Spent += a.Spent
        total.TxCount += a.TxCount
    }
    return &total, nil
}

// Transfer moves tokens between accounts. Both keys are per-account, so
// entity-to-entity trade carries no shared-key contention — unlike paying
// an operator, where every payer writes the same few keys.
func (s *${contract}) Transfer(ctx contractapi.TransactionContextInterface, from, to, amount string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    if from == to {
        return fmt.Errorf("cannot transfer to the same account")
    }
    n, err := strconv.ParseInt(amount, 10, 64)
    if err != nil || n <= 0 {
        return fmt.Errorf("amount must be a positive whole number, got %q", amount)
    }
    if err := s.debit(ctx, from, n, cfg); err != nil {
        return err
    }
    return s.credit(ctx, to, n, cfg)
}

/* ── sharing what you actually hold ───────────────────────────────────── */

func (s *${contract}) grantOf(ctx contractapi.TransactionContextInterface, entityID string) (*SpectrumGrant, error) {
    b, err := ctx.GetStub().GetState(grantPrefix + entityID)
    if err != nil {
        return nil, err
    }
    if b == nil {
        return &SpectrumGrant{EntityID: entityID}, nil
    }
    var g SpectrumGrant
    if err := json.Unmarshal(b, &g); err != nil {
        return nil, err
    }
    return &g, nil
}

func (s *${contract}) saveGrant(ctx contractapi.TransactionContextInterface, g *SpectrumGrant) error {
    g.Timestamp = txTimestamp(ctx)
    b, err := json.Marshal(g)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(grantPrefix+g.EntityID, b)
}

// GrantOf reports the spectrum an entity holds and how much it has sublet.
func (s *${contract}) GrantOf(ctx contractapi.TransactionContextInterface, entityID string) (*SpectrumGrant, error) {
    return s.grantOf(ctx, entityID)
}

// ShareBandwidth sublets part of a grant.
//
// The holder cannot invent capacity: the grant was issued by this contract
// when the entity was admitted, and the check below is against that record
// rather than against anything the caller says it owns.
func (s *${contract}) ShareBandwidth(ctx contractapi.TransactionContextInterface, from, to, hz, priceMicro string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    if from == to {
        return fmt.Errorf("cannot sublet to yourself")
    }
    amount, err := strconv.ParseInt(hz, 10, 64)
    if err != nil || amount <= 0 {
        return fmt.Errorf("hz must be a positive whole number, got %q", hz)
    }
    price := parseIntOr(priceMicro, 0)

    g, err := s.grantOf(ctx, from)
    if err != nil {
        return err
    }
    available := g.HeldHz - g.SubletHz
    if available < amount {
        if g.HeldHz == 0 {
            return fmt.Errorf(
                "%s holds no spectrum to sublet: a grant is issued when an entity is admitted, and only while spectrum accounting is on — call SetResources with trackBandwidth on, then admit %s before it can sell",
                from, from)
        }
        return fmt.Errorf("%s holds %d Hz with %d already sublet, so only %d Hz is free",
            from, g.HeldHz, g.SubletHz, available)
    }

    recipient, err := s.grantOf(ctx, to)
    if err != nil {
        return err
    }
    if recipient.Cell == "" {
        recipient.Cell = g.Cell
    }
    if recipient.Cell != g.Cell {
        return fmt.Errorf("spectrum is only usable on the cell that issued it: %s holds %s, %s is on %s",
            from, g.Cell, to, recipient.Cell)
    }

    g.SubletHz += amount
    recipient.HeldHz += amount
    if err := s.saveGrant(ctx, g); err != nil {
        return err
    }
    if err := s.saveGrant(ctx, recipient); err != nil {
        return err
    }
    if price > 0 {
        if err := s.debit(ctx, to, price, cfg); err != nil {
            return err
        }
        return s.credit(ctx, from, price, cfg)
    }
    return nil
}

/* ── quality of service ────────────────────────────────────────────────
   The one thing a user can buy that the contract can actually deliver.

   Energy and computation were tried here and removed: a ledger entry
   moving microjoules between two batteries has no physical counterpart —
   devices do not charge each other — and proof-of-work rewards effort
   rather than useful output, which belongs to public-chain mining and not
   to a permissioned network with endorsement consensus.

   Priority is different. The contract itself decides which entity gets a
   cell when spectrum is short, so a priority it sells is a priority it
   enforces. Three tiers, each buying a larger share of the cell and a
   claim ahead of lower tiers when the cell fills.                        */

// QosTier is what an entity has bought. Held per entity, so purchases
// never contend with one another.
type QosTier struct {
    EntityID    string \`json:"entityID"\`
    Tier        int64  \`json:"tier"\`          // 0 best-effort, 1 standard, 2 premium
    ShareHz     int64  \`json:"shareHz"\`       // spectrum this tier grants
    PaidMicro   int64  \`json:"paidMicro"\`
    ExpiresAt   int64  \`json:"expiresAtBlock"\`
    Timestamp   string \`json:"timestamp"\`
}

const qosPrefix = "~QOS:"

// tierShareHz is the spectrum a tier is entitled to, as a multiple of the
// base grant: best-effort takes the base, standard twice, premium four
// times. A premium entity therefore reaches roughly twice the rate of a
// standard one at the same SINR — Shannon is logarithmic in power but
// linear in bandwidth, so the gain here is real and proportional.
func tierShareHz(tier, baseHz int64) int64 {
    switch tier {
    case 2:
        return baseHz * 4
    case 1:
        return baseHz * 2
    default:
        return baseHz
    }
}

func (s *${contract}) qosOf(ctx contractapi.TransactionContextInterface, entityID string) (*QosTier, error) {
    b, err := ctx.GetStub().GetState(qosPrefix + entityID)
    if err != nil {
        return nil, err
    }
    if b == nil {
        return &QosTier{EntityID: entityID, Tier: 0}, nil
    }
    var q QosTier
    if err := json.Unmarshal(b, &q); err != nil {
        return nil, err
    }
    return &q, nil
}

// QosOf reports an entity's tier.
func (s *${contract}) QosOf(ctx contractapi.TransactionContextInterface, entityID string) (*QosTier, error) {
    return s.qosOf(ctx, entityID)
}

// BuyQos purchases a service tier.
//
// The price is charged to the buyer's own account and credited to the
// operator of the cell it is attached to — so this is the one market
// mechanism with a shared-key write on the receiving side. That is
// deliberate: it makes the contrast with the peer-to-peer mechanisms
// measurable rather than assumed.
func (s *${contract}) BuyQos(ctx contractapi.TransactionContextInterface, entityID, tier string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    t, err := strconv.ParseInt(tier, 10, 64)
    if err != nil || t < 0 || t > 2 {
        return fmt.Errorf("tier must be 0, 1 or 2, got %q", tier)
    }

    price := cfg.QosPriceMicro * t
    if price > 0 {
        if err := s.debit(ctx, entityID, price, cfg); err != nil {
            return fmt.Errorf("cannot pay for tier %d: %v", t, err)
        }
    }

    q := QosTier{
        EntityID:  entityID,
        Tier:      t,
        ShareHz:   tierShareHz(t, cfg.RequestHz),
        PaidMicro: price,
        Timestamp: txTimestamp(ctx),
    }
    b, err := json.Marshal(&q)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(qosPrefix+entityID, b)
}

// SellQos drops back to best-effort and refunds nothing — the tier was
// consumed while it was held.
func (s *${contract}) SellQos(ctx contractapi.TransactionContextInterface, entityID string) error {
    return ctx.GetStub().DelState(qosPrefix + entityID)
}

/* ── relaying ──────────────────────────────────────────────────────────
   The paper routes small-cell users through an SBS. The same idea works
   between entities: an edge device with a weak link sends through a
   neighbour that has a strong one.

   Both energy figures come from the propagation model, so neither party
   states its own saving. The relay is paid a share of what the edge entity
   avoided spending — capped so the deal is worthwhile for both.            */

func (s *${contract}) RelayFor(ctx contractapi.TransactionContextInterface, dealID, edgeEntity, edgeX, edgeY, relayEntity, relayX, relayY string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    if dealID == "" || edgeEntity == "" || relayEntity == "" {
        return fmt.Errorf("dealID, edgeEntity and relayEntity are all required")
    }
    if edgeEntity == relayEntity {
        return fmt.Errorf("an entity cannot relay for itself")
    }
    existing, err := ctx.GetStub().GetState(taskPrefix + "relay:" + dealID)
    if err != nil {
        return err
    }
    if existing != nil {
        return fmt.Errorf("deal %s already exists", dealID)
    }

    ex, err := parseCoord(edgeX)
    if err != nil {
        return err
    }
    ey, err := parseCoord(edgeY)
    if err != nil {
        return err
    }
    rx, err := parseCoord(relayX)
    if err != nil {
        return err
    }
    ry, err := parseCoord(relayY)
    if err != nil {
        return err
    }

    antennas, err := s.listAntennas(ctx)
    if err != nil {
        return err
    }
    // Both cellular links are measured against the entity's own slice, the
    // same width the device-to-device hop below uses. Evaluating them at the
    // cell's full band — which is what evaluate does while spectrum
    // accounting is off — made the direct path look almost free next to a
    // hop priced on 100 kHz, so every deal was refused for costing more than
    // it saved. Relay economics is a comparison, and a comparison needs both
    // sides on the same scale.
    edgeReports, _, err := s.evaluateWithShare(antennas, cfg, edgeEntity, ex, ey, cfg.RequestHz)
    if err != nil {
        return err
    }
    relayReports, _, err := s.evaluateWithShare(antennas, cfg, relayEntity, rx, ry, cfg.RequestHz)
    if err != nil {
        return err
    }
    edgeDirect := edgeReports[0]
    relayLink := relayReports[0]

    if edgeDirect.EnergyMicroJ < 0 || relayLink.EnergyMicroJ < 0 {
        return fmt.Errorf("neither path carries a usable rate")
    }
    if relayLink.SinrMilliDb <= edgeDirect.SinrMilliDb {
        return fmt.Errorf(
            "relaying gains nothing: %s sees %d mdB, %s sees %d mdB",
            relayEntity, relayLink.SinrMilliDb, edgeEntity, edgeDirect.SinrMilliDb)
    }

    // The device-to-device hop is short, so it costs far less than the
    // direct uplink. Its rate is derived the same way as any other link.
    d2dDist := DistanceM(ex, ey, rx, ry)
    d2dPl := PathLossMilliDb(d2dDist, defaultFreqMHz, cfg.PathLossExponentMilli)
    d2dRssi := RssiMilliDbm(cfg.TxPowerMilliDbm, 0, d2dPl, 0)
    // Noise scales with the bandwidth actually occupied, and a device-to-
    // device hop occupies the entity's slice — not the cell's whole band.
    // Measuring it against 20 MHz overstated the noise floor by 23 dB and
    // made every hop beyond a few hundred metres carry no usable rate, so
    // no relay deal could ever clear.
    d2dSinr := SinrMilliDb(d2dRssi, []int64{},
        NoiseFloorMilliDbm(cfg.RequestHz, cfg.NoiseFigureMilliDb))
    d2dRate := ShannonBps(cfg.RequestHz, d2dSinr)
    d2dEnergy := TransmitEnergyMicroJ(cfg.TxPowerMilliDbm, cfg.PayloadBits, d2dRate)
    if d2dEnergy < 0 {
        return fmt.Errorf("the device-to-device hop carries no usable rate over %d m", d2dDist)
    }

    saved := edgeDirect.EnergyMicroJ - d2dEnergy
    if saved <= relayLink.EnergyMicroJ {
        return fmt.Errorf(
            "relaying costs more than it saves: %d µJ saved against %d µJ spent by the relay",
            saved, relayLink.EnergyMicroJ)
    }

    // The relay recovers its own cost plus a share of the surplus.
    surplus := saved - relayLink.EnergyMicroJ
    pay := ((relayLink.EnergyMicroJ + (surplus*cfg.RelayShareHundred)/100) * cfg.PriceScale) / 1000

    if err := s.debit(ctx, edgeEntity, pay, cfg); err != nil {
        return fmt.Errorf("%s cannot pay the relay: %v", edgeEntity, err)
    }
    if err := s.credit(ctx, relayEntity, pay, cfg); err != nil {
        return err
    }

    // Both parties spend the energy the model says they spend.
    if cfg.TrackEnergy {
        if err := s.spendEnergy(ctx, edgeEntity, d2dEnergy, cfg); err != nil {
            return err
        }
        if err := s.spendEnergy(ctx, relayEntity, relayLink.EnergyMicroJ, cfg); err != nil {
            return err
        }
    }

    deal := RelayDeal{
        DealID:        dealID,
        EdgeEntity:    edgeEntity,
        RelayEntity:   relayEntity,
        DirectEnergy:  edgeDirect.EnergyMicroJ,
        RelayedEnergy: d2dEnergy,
        SavedMicroJ:   saved,
        PaidMicro:     pay,
        Timestamp:     txTimestamp(ctx),
    }
    db, err := json.Marshal(deal)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(taskPrefix+"relay:"+dealID, db)
}

// spendEnergy debits a battery, refusing rather than going negative.
func (s *${contract}) spendEnergy(ctx contractapi.TransactionContextInterface, entityID string, amount int64, cfg *NetworkConfig) error {
    b, err := s.energyOf(ctx, entityID, cfg)
    if err != nil {
        return err
    }
    if b.RemainingMicroJ < amount {
        return fmt.Errorf("%s has %d µJ but the hop costs %d µJ",
            entityID, b.RemainingMicroJ, amount)
    }
    b.RemainingMicroJ -= amount
    b.SpentMicroJ += amount
    b.TxCount++
    b.Timestamp = txTimestamp(ctx)
    bb, err := json.Marshal(b)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(energyPrefix+entityID, bb)
}

// RelayOf reads a deal.
func (s *${contract}) RelayOf(ctx contractapi.TransactionContextInterface, dealID string) (*RelayDeal, error) {
    b, err := ctx.GetStub().GetState(taskPrefix + "relay:" + dealID)
    if err != nil {
        return nil, err
    }
    if b == nil {
        return nil, fmt.Errorf("no relay deal %s", dealID)
    }
    var d RelayDeal
    if err := json.Unmarshal(b, &d); err != nil {
        return nil, err
    }
    return &d, nil
}

// SetMarket configures the market.
//   stripes     sub-keys per account; 1 is the naive layout, higher spreads
//               the contention a payee otherwise concentrates
//   priceScale  micro-tokens per 1000 µJ of value
//   relayShare  the relay's cut of the surplus, in percent
//   qosPrice    cost of one service tier, in micro-tokens
func (s *${contract}) SetMarket(ctx contractapi.TransactionContextInterface, stripes, priceScale, relayShare, qosPrice string) error {
    cfg, err := s.loadConfig(ctx)
    if err != nil {
        return err
    }
    cfg.Stripes = parseIntOr(stripes, cfg.Stripes)
    cfg.PriceScale = parseIntOr(priceScale, cfg.PriceScale)
    cfg.RelayShareHundred = parseIntOr(relayShare, cfg.RelayShareHundred)
    cfg.QosPriceMicro = parseIntOr(qosPrice, cfg.QosPriceMicro)

    if cfg.Stripes < 1 || cfg.Stripes > 256 {
        return fmt.Errorf("stripes must be between 1 and 256, got %d", cfg.Stripes)
    }
    if cfg.RelayShareHundred < 0 || cfg.RelayShareHundred > 100 {
        return fmt.Errorf("relayShare must be a percentage, got %d", cfg.RelayShareHundred)
    }
    cfgJSON, err := json.Marshal(cfg)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(configKey, cfgJSON)
}
`;
};
