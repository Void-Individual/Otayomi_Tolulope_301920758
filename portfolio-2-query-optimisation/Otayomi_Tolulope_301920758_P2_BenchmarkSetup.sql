-- Separate synthetic load-test data; not observed guesthouse activity.
-- Install once. An existing schema is never automatically removed.
\set ON_ERROR_STOP on
BEGIN;
DO $$
BEGIN
    IF current_database() NOT IN ('tolu_guesthouse_301920758', 'tolu_guesthouse_301920758_replay') THEN
        RAISE EXCEPTION 'Use a documented isolated Tolu database';
    END IF;
END;
$$;
CREATE SCHEMA p2_benchmark;
CREATE TABLE p2_benchmark.guest (
    guest_code text PRIMARY KEY
);
INSERT INTO p2_benchmark.guest
SELECT 'G' || lpad(n::text, 5, '0') FROM generate_series(0, 4999) n;

CREATE TABLE p2_benchmark.reservation_history (
    reservation_ref text PRIMARY KEY,
    guest_code text NOT NULL REFERENCES p2_benchmark.guest,
    room_number text NOT NULL REFERENCES guesthouse.room,
    arrival date NOT NULL,
    departure date NOT NULL CHECK (departure > arrival),
    status text NOT NULL CHECK (status IN ('CONFIRMED', 'CANCELLED')),
    agreed_nightly_rate guesthouse.ngn_amount NOT NULL,
    EXCLUDE USING gist (room_number WITH =, daterange(arrival, departure, '[)') WITH &&)
        WHERE (status <> 'CANCELLED')
);
-- Ten requests per room/slot: nine cancelled, one confirmed. Slots are three
-- days apart, stays two nights; confirmed intervals never overlap.
WITH requests AS (
    SELECT n, (n - 1) / 10 AS slot,
           ARRAY['101','102','103','104','201','202','203','204','301','302','303','304'] AS rooms
    FROM generate_series(1, 200000) n
), rows AS (
    SELECT n, rooms[slot % 12 + 1] AS room_number,
           DATE '2027-01-01' + (slot / 12) * 3 AS arrival
    FROM requests
)
INSERT INTO p2_benchmark.reservation_history
SELECT 'BENCH-' || lpad(n::text, 6, '0'),
       'G' || lpad(((n * 37 + n / 97) % 5000)::text, 5, '0'),
       rows.room_number, arrival, arrival + 2,
       CASE WHEN n % 10 = 0 THEN 'CONFIRMED' ELSE 'CANCELLED' END,
       c.current_nightly_rate
FROM rows JOIN guesthouse.room r USING (room_number)
JOIN guesthouse.room_category c USING (category_code);
COMMIT;
ANALYZE p2_benchmark.reservation_history;
SELECT count(*) AS synthetic_rows, count(*) FILTER (WHERE status = 'CONFIRMED') AS confirmed_rows,
       min(arrival) AS first_arrival, max(departure) AS last_departure
FROM p2_benchmark.reservation_history;
