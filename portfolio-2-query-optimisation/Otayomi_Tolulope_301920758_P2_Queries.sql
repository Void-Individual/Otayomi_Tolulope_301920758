-- Palm Court Guesthouse: six business questions against the unchanged P1 seed.
\set ON_ERROR_STOP on
\pset pager off
-- Temporary result tables support assertions; all changes roll back at the end.
BEGIN;
SET LOCAL TIME ZONE 'Africa/Lagos';

-- Q1: rooms that fit two guests and are free for ALL nights, 10-13 December.
CREATE TEMP TABLE q1 AS
SELECT r.room_number, c.category_name, r.capacity, c.current_nightly_rate
FROM guesthouse.room r
JOIN guesthouse.room_category c USING (category_code)
WHERE r.capacity >= 2 AND NOT EXISTS (
    SELECT FROM guesthouse.reservation b
    WHERE b.room_number = r.room_number AND b.status <> 'CANCELLED'
      AND daterange(b.arrival, b.departure, '[)') && daterange('2026-12-10', '2026-12-13', '[)')
);
\echo Q1: available rooms for two guests, [2026-12-10,2026-12-13)
SELECT * FROM q1 ORDER BY room_number;

-- Q2: upcoming confirmed bookings, joined to guest and category descriptions.
CREATE TEMP TABLE q2 AS
SELECT b.reservation_ref, g.display_name, b.room_number, c.category_name,
       b.arrival, b.departure, b.agreed_nightly_rate * (b.departure - b.arrival) AS booking_value_ngn
FROM guesthouse.reservation b
JOIN guesthouse.guest g USING (guest_code)
JOIN guesthouse.room r USING (room_number)
JOIN guesthouse.room_category c USING (category_code)
WHERE b.status = 'CONFIRMED' AND b.arrival >= guesthouse.business_date();
\echo Q2: upcoming bookings and full-stay value (not payment revenue)
SELECT * FROM q2 ORDER BY arrival, reservation_ref;

-- Q3: clip stays to each reporting window; preserve categories with no bookings.
CREATE TEMP TABLE q3 AS
WITH periods(label, first_night, end_exclusive) AS (
    VALUES ('December', DATE '2026-12-01', DATE '2027-01-01'),
           ('Short window', DATE '2026-12-10', DATE '2026-12-14')
), clipped AS (
    SELECT p.label, c.category_code,
           CASE WHEN b.reservation_ref IS NULL THEN 0 ELSE
               greatest(0, least(b.departure, p.end_exclusive) - greatest(b.arrival, p.first_night)) END AS nights,
           b.agreed_nightly_rate
    FROM periods p CROSS JOIN guesthouse.room_category c
    LEFT JOIN guesthouse.room r ON r.category_code = c.category_code
    LEFT JOIN guesthouse.reservation b ON b.room_number = r.room_number
       AND b.status <> 'CANCELLED' AND b.arrival < p.end_exclusive AND b.departure > p.first_night
)
SELECT label, category_code, coalesce(sum(nights), 0)::integer AS booked_nights,
       coalesce(sum(nights * agreed_nightly_rate), 0)::numeric(14,2) AS booking_value_ngn
FROM clipped GROUP BY label, category_code;
\echo Q3: booked room-nights and value inside each reporting window
SELECT * FROM q3 ORDER BY label, category_code;

-- Q4: include rooms with zero non-cancelled reservations in all fixture history.
CREATE TEMP TABLE q4 AS
SELECT r.room_number FROM guesthouse.room r
WHERE NOT EXISTS (
    SELECT FROM guesthouse.reservation b WHERE b.room_number = r.room_number AND b.status <> 'CANCELLED'
);
\echo Q4: rooms with no non-cancelled booking history
SELECT * FROM q4 ORDER BY room_number;

-- Q5: retain cancelled agreements separately from demand/value totals.
CREATE TEMP TABLE q5 AS
SELECT reservation_ref, guest_code, room_number, arrival, departure,
       agreed_nightly_rate * (departure - arrival) AS cancelled_original_value_ngn
FROM guesthouse.reservation WHERE status = 'CANCELLED';
\echo Q5: cancellation history
SELECT * FROM q5 ORDER BY reservation_ref;

-- Q6: guests with no non-cancelled reservations, including cancelled-only guests.
CREATE TEMP TABLE q6 AS
SELECT g.guest_code, g.display_name FROM guesthouse.guest g
WHERE NOT EXISTS (
    SELECT FROM guesthouse.reservation b WHERE b.guest_code = g.guest_code AND b.status <> 'CANCELLED'
);
\echo Q6: guests without a non-cancelled booking
SELECT * FROM q6 ORDER BY guest_code;

DO $$
BEGIN
    IF (SELECT array_agg(room_number ORDER BY room_number) FROM q1)
        IS DISTINCT FROM ARRAY['103','104','202','203','204','301','302','303','304'] THEN
        RAISE EXCEPTION 'Q1 availability mismatch';
    END IF;
    IF (SELECT count(*) FROM q2) <> 7 OR (SELECT sum(booking_value_ngn) FROM q2) <> 740000 THEN
        RAISE EXCEPTION 'Q2 booking/value mismatch';
    END IF;
    IF EXISTS (
        (SELECT * FROM q3 EXCEPT VALUES
            ('December','DLX',4,160000), ('December','FAM',5,300000), ('December','STD',8,200000),
            ('Short window','DLX',3,120000), ('Short window','FAM',0,0), ('Short window','STD',7,175000))
        UNION ALL
        (VALUES
            ('December','DLX',4,160000), ('December','FAM',5,300000), ('December','STD',8,200000),
            ('Short window','DLX',3,120000), ('Short window','FAM',0,0), ('Short window','STD',7,175000)
         EXCEPT SELECT * FROM q3)
    ) THEN RAISE EXCEPTION 'Q3 clipping/zero-category mismatch'; END IF;
    IF (SELECT array_agg(room_number ORDER BY room_number) FROM q4)
        IS DISTINCT FROM ARRAY['103','104','203','204','303','304'] THEN
        RAISE EXCEPTION 'Q4 empty-room mismatch';
    END IF;
    IF (SELECT count(*) FROM q5) <> 1 OR
       NOT EXISTS (SELECT FROM q5 WHERE reservation_ref = 'PCG-C001' AND cancelled_original_value_ngn = 120000) THEN
        RAISE EXCEPTION 'Q5 cancellation mismatch';
    END IF;
    IF (SELECT array_agg(guest_code ORDER BY guest_code) FROM q6) IS DISTINCT FROM ARRAY['G008'] THEN
        RAISE EXCEPTION 'Q6 cancelled-only guest mismatch';
    END IF;
END;
$$;
\echo PASS: all six business results match independently specified expectations.
ROLLBACK;
