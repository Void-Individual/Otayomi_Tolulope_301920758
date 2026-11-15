-- Manual: run begin after A's insertion; run attempt while A is still open.
-- The attempt waits until A commits, then fails. Run finish afterwards.
-- @phase begin
SET application_name = 'ToluP3-B';
BEGIN ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;
SELECT pg_backend_pid() AS session_b_pid;
SELECT count(*) AS other_uncommitted_row_visible
FROM guesthouse.reservation WHERE reservation_ref = 'PCG-P3-WINNER';
-- @phase attempt
\set ON_ERROR_STOP off
SELECT guesthouse.reserve_room('PCG-P3-LOSER', 'G002', '104', '2026-12-24', '2026-12-26', 1);
\echo CONFLICT_SQLSTATE :SQLSTATE
\set ON_ERROR_STOP on
-- @phase finish
ROLLBACK;
-- This read is a new transaction, after the aborted transaction was rolled back.
SELECT reservation_ref, room_number, status FROM guesthouse.reservation
WHERE room_number = '104' AND arrival = DATE '2026-12-24' ORDER BY reservation_ref;
