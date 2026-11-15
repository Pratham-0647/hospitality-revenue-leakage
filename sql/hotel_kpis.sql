/* =====================================================================
   hotel_kpis.sql  ·  AtliQ Grands revenue KPIs in PostgreSQL
   ---------------------------------------------------------------------
   PURPOSE : The same headline KPIs as the Python notebook, in SQL.
             Use it for SQL interview practice, and as an independent
             cross-check of the notebook's numbers.
   RUN     : from the repo root
             createdb atliq_hotels
             psql -d atliq_hotels -f sql/hotel_kpis.sql
   ===================================================================== */

DROP SCHEMA IF EXISTS hotel CASCADE;
CREATE SCHEMA hotel;
SET search_path = hotel;

/* ---------- 1. Load (dates arrive as text in two formats) ---------- */
CREATE TABLE dim_hotels (property_id INT PRIMARY KEY, property_name TEXT, category TEXT, city TEXT);
CREATE TABLE dim_rooms  (room_id TEXT PRIMARY KEY, room_class TEXT);
CREATE TABLE dim_date_raw (date_txt TEXT, mmm_yy TEXT, week_no TEXT, day_type TEXT);
CREATE TABLE fact_aggregated_raw (property_id INT, check_in_txt TEXT, room_category TEXT,
                                  successful_bookings INT, capacity INT);
CREATE TABLE fact_bookings (
    booking_id TEXT PRIMARY KEY, property_id INT, booking_date DATE, check_in_date DATE, checkout_date DATE,
    no_guests INT, room_category TEXT, booking_platform TEXT, ratings_given NUMERIC,
    booking_status TEXT, revenue_generated BIGINT, revenue_realized BIGINT);

\copy dim_hotels FROM 'data/raw/dim_hotels.csv' WITH (FORMAT csv, HEADER true)
\copy dim_rooms FROM 'data/raw/dim_rooms.csv' WITH (FORMAT csv, HEADER true)
\copy dim_date_raw FROM 'data/raw/dim_date.csv' WITH (FORMAT csv, HEADER true)
\copy fact_aggregated_raw FROM 'data/raw/fact_aggregated_bookings.csv' WITH (FORMAT csv, HEADER true)
\copy fact_bookings FROM 'data/raw/fact_bookings.csv' WITH (FORMAT csv, HEADER true)

-- Clean the date dimension: real dates, the "weekeday" typo fixed, numeric week
CREATE TABLE dim_date AS
SELECT TO_DATE(date_txt, 'DD-Mon-YY')               AS date,
       mmm_yy                                       AS month,
       REPLACE(week_no, 'W ', '')::INT              AS week_num,
       REPLACE(day_type, 'weekeday', 'weekday')     AS day_type
FROM dim_date_raw;
ALTER TABLE dim_date ADD PRIMARY KEY (date);

CREATE TABLE fact_aggregated AS
SELECT property_id, TO_DATE(check_in_txt, 'DD-Mon-YY') AS check_in_date,
       room_category, successful_bookings, capacity
FROM fact_aggregated_raw;
ALTER TABLE fact_aggregated ADD PRIMARY KEY (property_id, check_in_date, room_category);

CREATE INDEX ix_fb_checkin ON fact_bookings (check_in_date, property_id);

/* ---------- 2. Headline KPIs ---------- */
-- Capacity and booked occupancy come from fact_aggregated; revenue and status from fact_bookings.
WITH b AS (
    SELECT SUM(revenue_realized)                                   AS revenue,
           SUM(revenue_generated)                                  AS booked_revenue,
           COUNT(*)                                                AS bookings,
           COUNT(*) FILTER (WHERE booking_status = 'Cancelled')    AS cancelled,
           COUNT(*) FILTER (WHERE booking_status = 'No Show')      AS no_show,
           COUNT(*) FILTER (WHERE booking_status = 'Checked Out')  AS checked_out,
           AVG(ratings_given)                                      AS avg_rating
    FROM fact_bookings
), a AS (
    SELECT SUM(capacity) AS capacity, SUM(successful_bookings) AS successful,
           COUNT(DISTINCT check_in_date) AS days
    FROM fact_aggregated
)
SELECT revenue, booked_revenue,
       booked_revenue - revenue                                    AS leakage,
       ROUND(100.0 * (booked_revenue - revenue) / booked_revenue, 2) AS leakage_pct,
       ROUND(100.0 * successful / capacity, 2)                     AS occupancy_pct,
       ROUND(100.0 * checked_out / capacity, 2)                    AS realised_occupancy_pct,
       ROUND(revenue::NUMERIC / bookings, 2)                       AS adr,
       ROUND(revenue::NUMERIC / capacity, 2)                       AS revpar,
       ROUND(100.0 * cancelled / bookings, 2)                      AS cancellation_pct,
       ROUND(100.0 * no_show / bookings, 2)                        AS noshow_pct,
       ROUND(100.0 * checked_out / bookings, 2)                    AS realisation_pct,
       ROUND(avg_rating, 2)                                        AS avg_rating,
       ROUND(capacity::NUMERIC / days, 0)                          AS dsrn
FROM b, a;

/* ---------- 3. Weekday vs weekend ---------- */
WITH occ AS (
    SELECT d.day_type, SUM(a.capacity) AS capacity, SUM(a.successful_bookings) AS successful
    FROM fact_aggregated a JOIN dim_date d ON d.date = a.check_in_date
    GROUP BY d.day_type
), rev AS (
    SELECT d.day_type, SUM(f.revenue_realized) AS revenue
    FROM fact_bookings f JOIN dim_date d ON d.date = f.check_in_date
    GROUP BY d.day_type
)
SELECT o.day_type,
       ROUND(100.0 * o.capacity / SUM(o.capacity) OVER (), 2) AS capacity_share_pct,
       ROUND(100.0 * o.successful / o.capacity, 2)            AS occupancy_pct,
       ROUND(r.revenue::NUMERIC / o.capacity, 2)              AS revpar
FROM occ o JOIN rev r USING (day_type)
ORDER BY o.day_type;

/* ---------- 4. Hotel scorecard with performance tier ---------- */
WITH a AS (
    SELECT property_id, SUM(capacity) AS capacity, SUM(successful_bookings) AS successful
    FROM fact_aggregated GROUP BY property_id
), b AS (
    SELECT property_id, SUM(revenue_realized) AS revenue, COUNT(*) AS bookings, AVG(ratings_given) AS avg_rating
    FROM fact_bookings GROUP BY property_id
)
SELECT h.property_id, h.property_name, h.city,
       ROUND(100.0 * a.successful / a.capacity, 2)  AS occupancy_pct,
       ROUND(b.revenue::NUMERIC / a.capacity, 0)    AS revpar,
       ROUND(b.avg_rating, 2)                       AS avg_rating,
       CASE WHEN 100.0 * a.successful / a.capacity < 50 THEN 'Low'
            WHEN 100.0 * a.successful / a.capacity < 60 THEN 'Mid'
            ELSE 'High' END                         AS tier,
       RANK() OVER (ORDER BY b.revenue::NUMERIC / a.capacity DESC) AS revpar_rank
FROM dim_hotels h JOIN a USING (property_id) JOIN b USING (property_id)
ORDER BY revpar_rank;

/* ---------- 5. Week-on-Week (full Sun–Sat weeks only; W32 has 1 day) ---------- */
WITH full_weeks AS (
    SELECT week_num FROM dim_date GROUP BY week_num HAVING COUNT(*) = 7
), wk AS (
    SELECT d.week_num,
           SUM(f.revenue_realized)                                    AS revenue,
           COUNT(*)                                                   AS bookings,
           COUNT(*) FILTER (WHERE f.booking_status = 'Checked Out')   AS checked_out
    FROM fact_bookings f JOIN dim_date d ON d.date = f.check_in_date
    WHERE d.week_num IN (SELECT week_num FROM full_weeks)
    GROUP BY d.week_num
), cap AS (
    SELECT d.week_num, SUM(a.capacity) AS capacity, SUM(a.successful_bookings) AS successful
    FROM fact_aggregated a JOIN dim_date d ON d.date = a.check_in_date
    GROUP BY d.week_num
)
SELECT w.week_num,
       w.revenue,
       ROUND(100.0 * c.successful / c.capacity, 2)                        AS occupancy_pct,
       ROUND(w.revenue::NUMERIC / c.capacity, 0)                          AS revpar,
       ROUND(100.0 * (w.revenue - LAG(w.revenue) OVER (ORDER BY w.week_num))
             / LAG(w.revenue) OVER (ORDER BY w.week_num), 2)              AS revenue_wow_pct,
       CASE WHEN 100.0 * c.successful / c.capacity < 56 THEN 'dip' ELSE 'normal' END AS week_type
FROM wk w JOIN cap c USING (week_num)
ORDER BY w.week_num;

/* ---------- 6. Cancellation rate is flat across platforms ---------- */
SELECT booking_platform,
       COUNT(*)                                                                    AS bookings,
       ROUND(100.0 * COUNT(*) FILTER (WHERE booking_status = 'Cancelled') / COUNT(*), 2) AS cancellation_pct,
       SUM(revenue_generated - revenue_realized)                                   AS leakage
FROM fact_bookings
GROUP BY booking_platform
ORDER BY bookings DESC;
