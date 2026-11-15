SELECT reservation_ref, arrival, departure, status, agreed_nightly_rate
FROM p2_benchmark.reservation_history
WHERE guest_code = 'G04242'
  AND arrival >= DATE '2030-01-01'
  AND arrival < DATE '2035-01-01'
ORDER BY arrival, reservation_ref;
