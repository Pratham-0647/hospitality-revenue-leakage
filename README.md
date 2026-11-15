# AtliQ Grands: Revenue Leakage & Profitability in Hospitality

Consulting & Analytics Club, IIT Guwahati, Summer Projects '25:
*Optimizing Revenue Leakage & Profitability in the Hospitality Sector*.

A data analysis of the AtliQ Grands hotel chain (25 hotels, 4 cities, 134,590 bookings, check-ins from
1 May to 31 Jul 2022). It finds where revenue leaks, explains why, and sizes four fixes with ROI, payback and
best / likely / worst scenarios. It closes with a week-on-week forecast for August.

---

## Headline results (May–Jul 2022)

| KPI | Value |
|---|---|
| Realised revenue | ₹1,708.8M |
| Booked revenue | ₹2,007.5M |
| **Revenue leakage** | **₹298.8M (14.88% of booked), all from cancellations** |
| RevPAR | ₹7,347 |
| ADR (revenue per booking) | ₹12,696 |
| Booked occupancy / realised occupancy | 57.9% / 40.6% |
| Cancellation rate / realisation rate | 24.8% / 70.1% |
| Average rating | 3.62 |

## Key findings

1. **Cancellations leak 14.88% of booked revenue.** Cancelled bookings keep only 40% of their value; no-shows pay in full.
2. **Cancellation is a policy problem, not a segment problem.** The rate is ~25% on every platform, lead time,
   room class, city and day type (spread under 3 points).
3. **Weekdays are half-empty.** Weekday occupancy is 51% vs 74% at weekends, yet weekdays hold 71% of
   room-nights. **Prices never change**, not by day, lead time or season.
4. **Four low-rated hotels drag.** Hotels rated ~2.3 fill 45% of rooms; ~3.0 → 53%; ~4.3 → 66%
   (rating ↔ occupancy r = 0.998 across hotels).
5. **Five "dip weeks"** run ~11 occupancy points lower at every hotel, costing ~₹24M each. The data doesn't explain why.

## Recommendations (four levers)

| Lever | Root cause it fixes | Likely RevPAR uplift | Likely year-1 ROI |
|---|---|---|---|
| L1 Cancellation recovery (re-confirmation, deposits, waitlist resale) | 25% cancellations | +1.6% | 233% |
| L2 Weekday corporate & co-working packages | 51% weekday occupancy | +3.5% | 306% |
| L3 Weekend dynamic pricing | Static price at 74% weekend occupancy | +0.7% | 265% |
| L4 Low-tier hotel turnaround | 4 hotels at 45% occupancy | +1.2% | 52% |
| **Total** | | **+6.9% likely (3.1% worst, 11.8% best)** | **203%** |

Every lever size, cost and margin is a **labelled assumption** (the data has no cost figures). They all sit in one
`ASSUMPTIONS` dictionary in the notebook, so they can be replaced with real numbers.

**August forecast:** about ₹130M a week, between ₹115M (dip week) and ₹139M (normal week). The week starting 31 July
opened at dip level. The two-state model beat naive week-on-week in backtesting (MAPE 10.7% vs 12.6%).

---

## Repository layout

```
├── data/raw/                         the five AtliQ CSVs, as provided
├── notebooks/
│   ├── hospitality_revenue_analysis.py      notebook source (percent format, easy to diff)
│   ├── hospitality_revenue_analysis.ipynb   executed notebook with all outputs
│   └── build_notebook.py                    rebuilds + runs the .ipynb from the .py
├── sql/hotel_kpis.sql                headline KPIs in PostgreSQL (cross-check + SQL practice)
├── powerbi/dax_measures.md           Power BI data model, Power Query fixes and DAX measures
├── outputs/
│   ├── charts/                       8 report charts (PNG)
│   ├── tables/                       every result table (CSV) + SQL output
│   └── dashboard_data/               tidy CSVs behind the KPI dashboard
└── README.md
```

## How to run

```bash
pip install pandas numpy matplotlib nbformat nbconvert ipykernel
cd notebooks
python build_notebook.py          # runs the whole analysis, writes charts and tables
```

Optional SQL cross-check (PostgreSQL 13+, run from the repo root):

```bash
createdb atliq_hotels
psql -d atliq_hotels -f sql/hotel_kpis.sql
```

---

## KPI definitions

| KPI | Definition |
|---|---|
| Revenue | Σ revenue_realized |
| Revenue leakage | Σ revenue_generated − Σ revenue_realized |
| Occupancy % (booked) | Σ successful_bookings ÷ Σ capacity |
| Realised occupancy % | checked-out bookings ÷ Σ capacity |
| ADR | revenue ÷ total bookings |
| RevPAR | revenue ÷ capacity (= ADR × booked occupancy) |
| Cancellation % / Realisation % | cancelled ÷ bookings / checked-out ÷ bookings |
| DSRN / DBRN / DURN | capacity / bookings / checked-out, per day |
| WoW % | this full week ÷ previous full week − 1 |

## Data issues found (and how they were handled)

- **`successful_bookings` includes cancellations and no-shows**, so "occupancy" is booked occupancy.
  Realised occupancy is reported alongside it.
- **Two hotels share the name "Atliq Exotica, Mumbai"** (IDs 16559 and 17559). The ID pattern suggests 16559 is a
  Delhi hotel. Data kept as given; hotels are labelled by ID; Mumbai's city totals may be overstated.
- **Booked revenue doesn't grow with length of stay**, so revenue is treated as per booking.
- **Week 32 has one day (31 Jul)** and is excluded from week-on-week figures.
- `dim_date` spells "weekday" as "weekeday"; fixed on load.
- **Not in the data:** ancillary services (spa, meals), cancellation reasons, competitor prices, review text and costs.
  The brief's asks on these are covered with assumptions or flagged as gaps.

## Assumptions

| Assumption | Value |
|---|---|
| Contribution margin on incremental room revenue | 70% |
| Cancellation-rate cut (worst / likely / best) | 2 / 3 / 5 points |
| Bookings lost to deposit friction | 1.0 / 0.5 / 0.25% |
| Weekday occupancy lift in Mid/High hotels | 2 / 4 / 6 points at 15% package discount |
| Weekend price rise, elasticity −0.6 | 3 / 5 / 8% |
| Low-tier occupancy lift | 2 / 4 / 8 points |
| One-time cost (L1 / L2 / L3 / L4) | ₹5.0M / ₹10.5M / ₹3.0M / ₹24.0M |
| Monthly cost (L1 / L2 / L3 / L4) | ₹1.5M / ₹2.5M / ₹0.5M / ₹1.0M |
| Annualisation | ×365/92, assuming the quarter is representative |
