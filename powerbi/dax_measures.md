# Power BI build guide: AtliQ Grands KPI dashboard

The brief lists an interactive Power BI / Tableau prototype as optional. This file has everything needed to build one
from the raw CSVs: the data model, the Power Query fixes and every DAX measure.

> Written for Power BI Desktop but **not tested inside Power BI**. Every measure mirrors a Python/SQL KPI in this repo,
> so check your first numbers against `outputs/tables/kpi_overall.csv` (e.g. Revenue ₹1,708,771,229; RevPAR ₹7,347.15).

---

## 1. Load and clean (Power Query)

| Table | Fix |
|---|---|
| `dim_date` | Change `date` to **Date** using locale *English (United Kingdom)* (values look like `01-May-22`). Replace `weekeday` → `weekday` in `day_type`. Add column `wn = Number.From(Text.AfterDelimiter([week no], " "))`. |
| `fact_aggregated_bookings` | Change `check_in_date` to **Date**, same locale as above. |
| `fact_bookings` | `booking_date`, `check_in_date`, `checkout_date` are ISO dates, so just set type **Date**. |
| `dim_hotels`, `dim_rooms` | No changes. |

## 2. Relationships (all single-direction, many-to-one)

```
fact_bookings[check_in_date]              → dim_date[date]
fact_bookings[property_id]                → dim_hotels[property_id]
fact_bookings[room_category]              → dim_rooms[room_id]
fact_aggregated_bookings[check_in_date]   → dim_date[date]
fact_aggregated_bookings[property_id]     → dim_hotels[property_id]
fact_aggregated_bookings[room_category]   → dim_rooms[room_id]
```

## 3. Measures

Create an empty table called `_Measures` and add these:

```dax
Revenue = SUM ( fact_bookings[revenue_realized] )
Booked Revenue = SUM ( fact_bookings[revenue_generated] )
Revenue Leakage = [Booked Revenue] - [Revenue]
Leakage % = DIVIDE ( [Revenue Leakage], [Booked Revenue] )

Total Bookings = COUNTROWS ( fact_bookings )
Total Capacity = SUM ( fact_aggregated_bookings[capacity] )
Successful Bookings = SUM ( fact_aggregated_bookings[successful_bookings] )

Checked Out = CALCULATE ( [Total Bookings], fact_bookings[booking_status] = "Checked Out" )
Cancelled Bookings = CALCULATE ( [Total Bookings], fact_bookings[booking_status] = "Cancelled" )
No Show Bookings = CALCULATE ( [Total Bookings], fact_bookings[booking_status] = "No Show" )

Occupancy % = DIVIDE ( [Successful Bookings], [Total Capacity] )          -- booked occupancy
Realised Occupancy % = DIVIDE ( [Checked Out], [Total Capacity] )
Cancellation % = DIVIDE ( [Cancelled Bookings], [Total Bookings] )
No Show % = DIVIDE ( [No Show Bookings], [Total Bookings] )
Realisation % = DIVIDE ( [Checked Out], [Total Bookings] )

ADR = DIVIDE ( [Revenue], [Total Bookings] )
RevPAR = DIVIDE ( [Revenue], [Total Capacity] )
Average Rating = AVERAGE ( fact_bookings[ratings_given] )

No of Days = DATEDIFF ( MIN ( dim_date[date] ), MAX ( dim_date[date] ), DAY ) + 1
DSRN = DIVIDE ( [Total Capacity], [No of Days] )
DBRN = DIVIDE ( [Total Bookings], [No of Days] )
DURN = DIVIDE ( [Checked Out], [No of Days] )
```

### Week-on-Week measures

The pattern is the same for every KPI: value in the selected week ÷ value in the week before, minus 1.

```dax
Revenue WoW % =
VAR sel_week = IF ( HASONEVALUE ( dim_date[wn] ), VALUES ( dim_date[wn] ), MAX ( dim_date[wn] ) )
VAR this_week = CALCULATE ( [Revenue], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week ) )
VAR last_week = CALCULATE ( [Revenue], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week - 1 ) )
RETURN DIVIDE ( this_week, last_week ) - 1

RevPAR WoW % =
VAR sel_week = IF ( HASONEVALUE ( dim_date[wn] ), VALUES ( dim_date[wn] ), MAX ( dim_date[wn] ) )
VAR this_week = CALCULATE ( [RevPAR], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week ) )
VAR last_week = CALCULATE ( [RevPAR], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week - 1 ) )
RETURN DIVIDE ( this_week, last_week ) - 1

Occupancy WoW % =
VAR sel_week = IF ( HASONEVALUE ( dim_date[wn] ), VALUES ( dim_date[wn] ), MAX ( dim_date[wn] ) )
VAR this_week = CALCULATE ( [Occupancy %], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week ) )
VAR last_week = CALCULATE ( [Occupancy %], FILTER ( ALL ( dim_date ), dim_date[wn] = sel_week - 1 ) )
RETURN DIVIDE ( this_week, last_week ) - 1
```

Copy the same pattern for `ADR WoW %`, `Realisation WoW %` and `DSRN WoW %`.

> **Watch out:** week 32 has only one day (31 Jul). Exclude it from WoW cards with a visual-level filter (`wn` ≤ 31),
> or W32 will show a fake −82% revenue drop.

## 4. Suggested report pages

1. **Overview:** KPI cards (Revenue, RevPAR, Occupancy %, ADR, Realisation %, Cancellation %) each with its WoW %;
   slicers for city, category, room class, month, week, day type.
2. **Trends:** weekly revenue (column) + occupancy % (line); occupancy % by day of week.
3. **Hotels:** matrix of property × RevPAR, Occupancy %, ADR, Average Rating, with conditional formatting.
4. **Leakage:** waterfall Booked Revenue → Revenue Leakage → Revenue; cancellation % by platform and room class.
