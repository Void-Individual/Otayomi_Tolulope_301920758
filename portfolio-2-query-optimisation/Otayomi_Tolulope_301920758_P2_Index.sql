CREATE INDEX reservation_guest_arrival_idx
ON p2_benchmark.reservation_history (guest_code, arrival);
ANALYZE p2_benchmark.reservation_history;
