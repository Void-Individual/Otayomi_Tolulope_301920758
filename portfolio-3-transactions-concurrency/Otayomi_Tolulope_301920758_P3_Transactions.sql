-- Run once in the dedicated P3 copy of the original seed database.
\set ON_ERROR_STOP on
\set VERBOSITY verbose
\pset pager off
DO $$
BEGIN
    IF current_database() <> 'tolu_guesthouse_301920758_p3' THEN
        RAISE EXCEPTION 'Use the dedicated P3 database';
    END IF;
    IF EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref LIKE 'PCG-P3-%') THEN
        RAISE EXCEPTION 'P3 examples already exist; use a fresh P3 database copy';
    END IF;
END;
$$;
CREATE FUNCTION pg_temp.check_true(label text, condition boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
    RAISE NOTICE 'PASS: %', label;
END;
$$;
SELECT clock_timestamp() AS actual_execution_time, guesthouse.business_date() AS scenario_date;
SELECT count(*) AS initial_reservations FROM guesthouse.reservation;

\echo CASE 1: commit a complete two-night reservation
BEGIN;
SET LOCAL ROLE tolu_guesthouse_operator;
SELECT guesthouse.reserve_room('PCG-P3-COMMIT', 'G001', '103', '2026-12-16', '2026-12-18', 2);
COMMIT;
SELECT pg_temp.check_true('committed booking persists',
    (SELECT status = 'CONFIRMED' AND departure-arrival = 2 AND agreed_nightly_rate = 25000
     FROM guesthouse.reservation WHERE reservation_ref = 'PCG-P3-COMMIT'));

\echo CASE 2: rollback a valid guest and booking after a later capacity failure
BEGIN;
INSERT INTO guesthouse.guest VALUES ('G900', 'Synthetic Rollback Guest');
SELECT guesthouse.reserve_room('PCG-P3-ROLLBACK', 'G900', '203', '2026-12-16', '2026-12-18', 2);
\set ON_ERROR_STOP off
SELECT guesthouse.reserve_room('PCG-P3-INVALID', 'G900', '104', '2026-12-16', '2026-12-18', 99);
\set failure_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK;
SELECT pg_temp.check_true('capacity error had expected SQLSTATE', :'failure_state' = '23514');
SELECT pg_temp.check_true('guest and both attempted bookings absent after rollback',
    NOT EXISTS (SELECT FROM guesthouse.guest WHERE guest_code = 'G900') AND
    NOT EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref IN ('PCG-P3-ROLLBACK','PCG-P3-INVALID')));

\echo CASE 3: repeated reference fails without creating another booking
BEGIN;
\set ON_ERROR_STOP off
SELECT guesthouse.reserve_room('PCG-P3-COMMIT', 'G002', '204', '2026-12-16', '2026-12-18', 1);
\set duplicate_state :SQLSTATE
\set ON_ERROR_STOP on
ROLLBACK;
SELECT pg_temp.check_true('repeat rejected by primary-key SQLSTATE', :'duplicate_state' = '23505');
SELECT pg_temp.check_true('exactly one extra reservation and original guest count',
    (SELECT count(*) = 11 FROM guesthouse.reservation) AND (SELECT count(*) = 8 FROM guesthouse.guest));
SELECT reservation_ref, guest_code, room_number, arrival, departure, status, agreed_nightly_rate
FROM guesthouse.reservation WHERE reservation_ref LIKE 'PCG-P3-%' ORDER BY reservation_ref;
