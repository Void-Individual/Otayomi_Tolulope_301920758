-- Fictional fixture history. Scenario dates are independent of actual execution time.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
SET LOCAL TIME ZONE 'Africa/Lagos';

INSERT INTO guesthouse.guest VALUES
    ('G001', 'Synthetic Guest A'), ('G002', 'Synthetic Guest B'),
    ('G003', 'Synthetic Guest C'), ('G004', 'Synthetic Guest D'),
    ('G005', 'Synthetic Guest E'), ('G006', 'Synthetic Guest F'),
    ('G007', 'Synthetic Guest G'), ('G008', 'Synthetic Guest H');

INSERT INTO guesthouse.room_category VALUES
    ('STD', 'Standard', 25000.00),
    ('DLX', 'Deluxe', 40000.00),
    ('FAM', 'Family', 60000.00);

INSERT INTO guesthouse.room VALUES
    ('101', 'STD', 2), ('102', 'STD', 2), ('103', 'STD', 2), ('104', 'STD', 2),
    ('201', 'DLX', 2), ('202', 'DLX', 2), ('203', 'DLX', 3), ('204', 'DLX', 3),
    ('301', 'FAM', 4), ('302', 'FAM', 4), ('303', 'FAM', 5), ('304', 'FAM', 5);

-- Create two historical stays using the same validated operations as future stays.
UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-11-01';
SELECT guesthouse.reserve_room('PCG-H001', 'G001', '101', '2026-11-05', '2026-11-07', 2);
SELECT guesthouse.reserve_room('PCG-H002', 'G002', '201', '2026-11-06', '2026-11-09', 1);
UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-11-09';
SELECT guesthouse.change_status('PCG-H001', 'COMPLETED');
SELECT guesthouse.change_status('PCG-H002', 'COMPLETED');

UPDATE guesthouse.demo_clock SET as_of_date = DATE '2026-12-01';
SELECT guesthouse.reserve_room('PCG-F001', 'G003', '101', '2026-12-10', '2026-12-12', 2);
SELECT guesthouse.reserve_room('PCG-F002', 'G004', '101', '2026-12-12', '2026-12-15', 1);
SELECT guesthouse.reserve_room('PCG-F003', 'G005', '102', '2026-12-10', '2026-12-13', 2);
SELECT guesthouse.reserve_room('PCG-F004', 'G006', '201', '2026-12-11', '2026-12-14', 2);
SELECT guesthouse.reserve_room('PCG-F005', 'G007', '301', '2026-12-20', '2026-12-23', 4);
SELECT guesthouse.reserve_room('PCG-F006', 'G003', '202', '2026-12-31', '2027-01-03', 1);
SELECT guesthouse.reserve_room('PCG-C001', 'G008', '302', '2026-12-20', '2026-12-22', 3);
SELECT guesthouse.change_status('PCG-C001', 'CANCELLED');
SELECT guesthouse.reserve_room('PCG-F007', 'G002', '302', '2026-12-20', '2026-12-22', 4);
COMMIT;
\echo Seed complete: 8 guests, 3 categories, 12 rooms, 10 reservations.
