-- Manual: run begin, leave the transaction open, then run commit only after
-- Session B's attempt is visibly blocked. The runner uses these same blocks.
-- @phase begin
SET application_name = 'ToluP3-A';
BEGIN ISOLATION LEVEL READ COMMITTED;
SHOW transaction_isolation;
SELECT pg_backend_pid() AS session_a_pid;
SELECT guesthouse.reserve_room('PCG-P3-WINNER', 'G001', '104', '2026-12-24', '2026-12-26', 2);
SELECT count(*) AS own_uncommitted_row_visible
FROM guesthouse.reservation WHERE reservation_ref = 'PCG-P3-WINNER';
-- @phase commit
COMMIT;
