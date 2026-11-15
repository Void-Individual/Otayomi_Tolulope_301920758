-- Run after Schema and Seed. Fail-fast checks; all test changes roll back.
\set ON_ERROR_STOP on
\pset pager off
\pset null '(null)'
BEGIN;
\o /dev/null
SET LOCAL TIME ZONE 'Africa/Lagos';
CREATE TEMP TABLE check_results (label text PRIMARY KEY, outcome text NOT NULL);

CREATE FUNCTION pg_temp.assert_true(label text, actual boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF actual IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'FAIL: %', label;
    END IF;
    INSERT INTO check_results VALUES (label, 'PASS');
END;
$$;

CREATE FUNCTION pg_temp.expect_error(
    label text, command text, expected_state text, expected_constraint text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    observed_state text;
    observed_constraint text;
BEGIN
    BEGIN
        EXECUTE command;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS observed_state = RETURNED_SQLSTATE,
            observed_constraint = CONSTRAINT_NAME;
        IF observed_state <> expected_state OR
            (expected_constraint IS NOT NULL AND observed_constraint <> expected_constraint) THEN
            RAISE EXCEPTION 'FAIL %: expected %/%, got %/%', label,
                expected_state, expected_constraint, observed_state, observed_constraint;
        END IF;
        INSERT INTO check_results VALUES (
            label, 'PASS: rejected ' || observed_state ||
            CASE WHEN observed_constraint <> '' THEN ' / ' || observed_constraint ELSE '' END
        );
        RETURN;
    END;
    RAISE EXCEPTION 'FAIL %: command unexpectedly succeeded', label;
END;
$$;

SELECT pg_temp.assert_true('01 seed counts',
    (SELECT count(*) = 8 FROM guesthouse.guest) AND
    (SELECT count(*) = 3 FROM guesthouse.room_category) AND
    (SELECT count(*) = 12 FROM guesthouse.room) AND
    (SELECT count(*) = 10 FROM guesthouse.reservation));
SELECT pg_temp.assert_true('02 seeded state distribution',
    (SELECT count(*) FILTER (WHERE status = 'COMPLETED') = 2
        AND count(*) FILTER (WHERE status = 'CANCELLED') = 1
        AND count(*) FILTER (WHERE status = 'CONFIRMED') = 7
    FROM guesthouse.reservation));
SELECT pg_temp.assert_true('03 exclusive departure and preserved quote',
    (SELECT departure - arrival = 2 AND agreed_nightly_rate * (departure - arrival) = 50000
    FROM guesthouse.reservation WHERE reservation_ref = 'PCG-F001'));

SELECT pg_temp.expect_error('04 duplicate guest',
    $$INSERT INTO guesthouse.guest VALUES ('G001', 'Duplicate')$$, '23505', 'guest_pkey');
SELECT pg_temp.expect_error('05 required guest name',
    $$INSERT INTO guesthouse.guest VALUES ('G900', NULL)$$, '23502');
SELECT pg_temp.expect_error('06 blank guest name',
    $$INSERT INTO guesthouse.guest VALUES ('G900', '  ')$$, '23514', 'guest_name_present');
SELECT pg_temp.expect_error('07 duplicate category name',
    $$INSERT INTO guesthouse.room_category VALUES ('OTH', 'Standard', 100)$$,
    '23505', 'room_category_category_name_key');
SELECT pg_temp.expect_error('08 negative rate',
    $$UPDATE guesthouse.room_category SET current_nightly_rate = -1 WHERE category_code = 'STD'$$,
    '23514', 'ngn_amount_valid');
SELECT pg_temp.expect_error('09 excessive price precision',
    $$UPDATE guesthouse.room_category SET current_nightly_rate = 20.001 WHERE category_code = 'STD'$$,
    '23514', 'ngn_amount_valid');
SELECT pg_temp.expect_error('10 NaN price',
    $$UPDATE guesthouse.room_category SET current_nightly_rate = 'NaN'::numeric WHERE category_code = 'STD'$$,
    '23514', 'ngn_amount_valid');
SELECT pg_temp.expect_error('11 infinite price',
    $$UPDATE guesthouse.room_category SET current_nightly_rate = 'Infinity'::numeric WHERE category_code = 'STD'$$,
    '23514', 'ngn_amount_valid');
SELECT pg_temp.expect_error('12 unknown room category',
    $$INSERT INTO guesthouse.room VALUES ('901', 'BAD', 2)$$,
    '23503', 'room_category_code_fkey');
SELECT pg_temp.expect_error('13 zero capacity',
    $$INSERT INTO guesthouse.room VALUES ('901', 'STD', 0)$$,
    '23514', 'room_capacity_positive');
SELECT pg_temp.expect_error('14 fixed capacity',
    $$UPDATE guesthouse.room SET capacity = 1 WHERE room_number = '101'$$,
    '23514', 'room_fixed_inventory');

SELECT pg_temp.expect_error('15 unknown guest',
    $$SELECT guesthouse.reserve_room('PCG-T15', 'G999', '104', '2026-12-10', '2026-12-12', 1)$$,
    '23503', 'reservation_guest_code_fkey');
SELECT pg_temp.expect_error('16 unknown room',
    $$SELECT guesthouse.reserve_room('PCG-T16', 'G001', '999', '2026-12-10', '2026-12-12', 1)$$,
    '23503', 'reservation_room_number_fkey');
SELECT pg_temp.expect_error('17 required party size',
    $$SELECT guesthouse.reserve_room('PCG-T17', 'G001', '104', '2026-12-10', '2026-12-12', NULL)$$,
    '23502');
SELECT pg_temp.expect_error('18 zero party size',
    $$SELECT guesthouse.reserve_room('PCG-T18', 'G001', '104', '2026-12-10', '2026-12-12', 0)$$,
    '23514', 'reservation_party_positive');
SELECT pg_temp.expect_error('19 over capacity',
    $$SELECT guesthouse.reserve_room('PCG-T19', 'G001', '104', '2026-12-10', '2026-12-12', 3)$$,
    '23514', 'reservation_capacity');
SELECT pg_temp.expect_error('20 zero length stay',
    $$SELECT guesthouse.reserve_room('PCG-T20', 'G001', '104', '2026-12-10', '2026-12-10', 1)$$,
    '23514', 'reservation_dates_valid');
SELECT pg_temp.expect_error('21 reversed stay',
    $$SELECT guesthouse.reserve_room('PCG-T21', 'G001', '104', '2026-12-12', '2026-12-10', 1)$$,
    '23514', 'reservation_dates_valid');
SELECT pg_temp.expect_error('22 infinite departure',
    $$SELECT guesthouse.reserve_room('PCG-T22', 'G001', '104', '2026-12-10', 'infinity', 1)$$,
    '23514', 'reservation_dates_valid');
SELECT pg_temp.expect_error('23 past arrival',
    $$SELECT guesthouse.reserve_room('PCG-T23', 'G001', '104', '2026-11-30', '2026-12-02', 1)$$,
    '23514', 'reservation_not_in_past');
SELECT pg_temp.expect_error('24 duplicate reference',
    $$SELECT guesthouse.reserve_room('PCG-F001', 'G001', '104', '2026-12-10', '2026-12-12', 1)$$,
    '23505', 'reservation_pkey');

SELECT pg_temp.expect_error('25 identical overlap',
    $$SELECT guesthouse.reserve_room('PCG-T25', 'G001', '101', '2026-12-10', '2026-12-12', 1)$$,
    '23P01', 'reservation_no_overlap');
SELECT pg_temp.expect_error('26 contained overlap',
    $$SELECT guesthouse.reserve_room('PCG-T26', 'G001', '101', '2026-12-10', '2026-12-11', 1)$$,
    '23P01', 'reservation_no_overlap');
SELECT pg_temp.expect_error('27 partial overlap',
    $$SELECT guesthouse.reserve_room('PCG-T27', 'G001', '101', '2026-12-09', '2026-12-11', 1)$$,
    '23P01', 'reservation_no_overlap');
SELECT guesthouse.reserve_room('PCG-T28', 'G001', '101', '2026-12-15', '2026-12-16', 2);
SELECT guesthouse.reserve_room('PCG-T29', 'G001', '103', '2026-12-10', '2026-12-12', 2);
SELECT pg_temp.assert_true('28 adjacent stay accepted',
    EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T28'));
SELECT pg_temp.assert_true('29 other room and exact capacity accepted',
    EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T29' AND party_size = 2));

SELECT pg_temp.expect_error('30 immutable booking terms',
    $$UPDATE guesthouse.reservation SET departure = '2026-12-17' WHERE reservation_ref = 'PCG-T28'$$,
    '23514', 'reservation_terms_immutable');
SELECT pg_temp.expect_error('31 retained booking history',
    $$DELETE FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T28'$$,
    '23514', 'reservation_history_retained');
SELECT pg_temp.expect_error('32 premature completion',
    $$SELECT guesthouse.change_status('PCG-T28', 'COMPLETED')$$,
    '23514', 'reservation_transition_date');
SELECT pg_temp.expect_error('33 terminal cancellation',
    $$SELECT guesthouse.change_status('PCG-C001', 'CONFIRMED')$$,
    '23514', 'reservation_status_transition');
SELECT pg_temp.expect_error('34 unknown status',
    $$SELECT guesthouse.change_status('PCG-T28', 'PENDING')$$,
    '23514', 'reservation_status_transition');
SELECT guesthouse.change_status('PCG-T29', 'CANCELLED');
SELECT guesthouse.reserve_room('PCG-T35', 'G002', '103', '2026-12-10', '2026-12-12', 1);
SELECT pg_temp.assert_true('35 cancellation releases nights and preserves prices',
    (SELECT status = 'CANCELLED' AND agreed_nightly_rate = 25000
    FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T29') AND
    EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T35'));

UPDATE guesthouse.room_category SET current_nightly_rate = 27500 WHERE category_code = 'STD';
SELECT guesthouse.reserve_room('PCG-T36', 'G001', '104', '2026-12-20', '2026-12-22', 1);
SELECT pg_temp.assert_true('36 new rate does not reprice older bookings',
    (SELECT agreed_nightly_rate = 27500 FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T36') AND
    (SELECT agreed_nightly_rate = 25000 FROM guesthouse.reservation WHERE reservation_ref = 'PCG-F001'));

UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-12-10';
SELECT pg_temp.expect_error('37 cancellation on arrival rejected',
    $$SELECT guesthouse.change_status('PCG-T35', 'CANCELLED')$$,
    '23514', 'reservation_transition_date');
UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-12-12';
SELECT guesthouse.change_status('PCG-T35', 'COMPLETED');
SELECT pg_temp.assert_true('38 completion on departure accepted',
    (SELECT status = 'COMPLETED' FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T35'));
SELECT pg_temp.expect_error('39 completion is terminal',
    $$SELECT guesthouse.change_status('PCG-T35', 'CANCELLED')$$,
    '23514', 'reservation_status_transition');
UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-12-01';
SELECT pg_temp.expect_error('40 completed history still excludes overlaps',
    $$SELECT guesthouse.reserve_room('PCG-T40', 'G001', '103', '2026-12-10', '2026-12-12', 1)$$,
    '23P01', 'reservation_no_overlap');

SELECT pg_temp.expect_error('41 atomic failed multi-step operation',
    $command$DO $block$ BEGIN
        INSERT INTO guesthouse.guest VALUES ('G999', 'Temporary Fictional Guest');
        PERFORM guesthouse.reserve_room('PCG-T41', 'G999', '101', '2026-12-10', '2026-12-12', 1);
    END; $block$$command$,
    '23P01', 'reservation_no_overlap');
SELECT pg_temp.assert_true('42 failed operation leaves no partial records',
    NOT EXISTS (SELECT FROM guesthouse.guest WHERE guest_code = 'G999') AND
    NOT EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T41'));

-- The business operator can only read and invoke the two controlled operations.
GRANT SELECT, INSERT ON check_results TO tolu_guesthouse_operator;
SET LOCAL ROLE tolu_guesthouse_operator;
SELECT pg_temp.expect_error('43 operator cannot change fixture clock',
    $$UPDATE guesthouse.demo_clock SET as_of_date = '2020-01-01'$$, '42501');
SELECT pg_temp.expect_error('44 operator cannot bypass booking API',
    $$INSERT INTO guesthouse.reservation (reservation_ref) VALUES ('PCG-BYPASS')$$, '42501');
SELECT pg_temp.expect_error('45 operator cannot truncate history',
    $$TRUNCATE guesthouse.reservation$$, '42501');
SELECT guesthouse.reserve_room('PCG-T46', 'G001', '304', '2026-12-01', '2026-12-02', 5);
SELECT pg_temp.assert_true('46 operator can book on business date at capacity',
    EXISTS (SELECT FROM guesthouse.reservation WHERE reservation_ref = 'PCG-T46'));
RESET ROLE;

SELECT pg_temp.assert_true('47 all expected cases ran', (SELECT count(*) = 46 FROM check_results));
\o
SELECT label, outcome FROM check_results ORDER BY label;
SELECT count(*) AS passed_checks FROM check_results;
ROLLBACK;
\echo All 47 checks passed; test changes rolled back.

-- Independent state evidence after rollback, not merely test assertions.
SELECT 'guest' AS entity, count(*) AS rows FROM guesthouse.guest
UNION ALL SELECT 'room_category', count(*) FROM guesthouse.room_category
UNION ALL SELECT 'room', count(*) FROM guesthouse.room
UNION ALL SELECT 'reservation', count(*) FROM guesthouse.reservation ORDER BY entity;
SELECT status, count(*) AS reservations FROM guesthouse.reservation GROUP BY status ORDER BY status;
SELECT as_of_date AS scenario_business_date FROM guesthouse.demo_clock;
SELECT reservation_ref, room_number, arrival, departure, status,
    agreed_nightly_rate, (departure - arrival) AS nights,
    agreed_nightly_rate * (departure - arrival) AS original_booking_value_ngn
FROM guesthouse.reservation ORDER BY reservation_ref;
