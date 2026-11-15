"""Measure the same guest-history query before/after one index; Python stdlib only."""

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import statistics
import subprocess

PREFIX = "Otayomi_Tolulope_301920758_"
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", default="tolu_guesthouse_301920758")
    parser.add_argument("--output-directory", type=Path, default=HERE)
    args = parser.parse_args()
    if args.database not in ("tolu_guesthouse_301920758", "tolu_guesthouse_301920758_replay"):
        raise SystemExit("Use a documented isolated Tolu database")
    args.output_directory.mkdir(parents=True, exist_ok=True)
    command = ["docker", "exec", "-i", "tolu-mit8103-postgres", "psql", "-X", "-qAt",
               "-v", "ON_ERROR_STOP=1", "-U", "tolu_admin", "-d", args.database]
    settings = "SET jit=off; SET max_parallel_workers_per_gather=0; SET statement_timeout='60s';\n"

    def sql(statement):
        return subprocess.check_output(command, input=settings + statement, text=True).strip()

    if sql("SELECT to_regclass('p2_benchmark.reservation_guest_arrival_idx') IS NOT NULL;") == "t":
        raise SystemExit("Benchmark index already exists; use a fresh benchmark setup, not an automatic reset")
    server_settings = json.loads(sql("SELECT json_object_agg(name,current_setting(name)) FROM unnest(ARRAY["
        "'shared_buffers','effective_cache_size','work_mem','block_size','random_page_cost',"
        "'jit','max_parallel_workers_per_gather']) AS t(name);"))
    other_clients = int(sql("SELECT count(*) FROM pg_stat_activity WHERE backend_type='client backend' AND pid<>pg_backend_pid();"))
    if other_clients:
        raise SystemExit("Close other experiment database sessions before benchmarking")
    query = (HERE / (PREFIX + "P2_BenchmarkQuery.sql")).read_text().strip().rstrip(";")
    ordered_result = "SELECT coalesce(json_agg(q ORDER BY arrival,reservation_ref),'[]') FROM (" + query + ") q;"
    before_rows = json.loads(sql(ordered_result))
    expected = []
    for n in range(1, 200001):
        if (n * 37 + n // 97) % 5000 != 4242:
            continue
        slot = (n - 1) // 10
        arrival = dt.date(2027, 1, 1) + dt.timedelta(days=(slot // 12) * 3)
        if dt.date(2030, 1, 1) <= arrival < dt.date(2035, 1, 1):
            expected.append({"reservation_ref": f"BENCH-{n:06d}", "arrival": arrival.isoformat(),
                             "departure": (arrival + dt.timedelta(days=2)).isoformat(),
                             "status": "CONFIRMED" if n % 10 == 0 else "CANCELLED",
                             "agreed_nightly_rate": [25000] * 4 + [40000] * 4 + [60000] * 4})
            expected[-1]["agreed_nightly_rate"] = expected[-1]["agreed_nightly_rate"][slot % 12]
    expected.sort(key=lambda row: (row["arrival"], row["reservation_ref"]))
    if not expected or before_rows != expected:
        raise AssertionError("Benchmark query differs from independent Python fixture calculation")

    def measure(label):
        plans = []
        for _ in range(2):
            sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query + ";")
        for _ in range(5):
            plans.append(json.loads(sql("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query + ";"))[0])
        (args.output_directory / (PREFIX + "P2_Plans" + label + ".json")).write_text(json.dumps(plans, indent=2) + "\n")
        text_plan = sql("EXPLAIN (ANALYZE, BUFFERS) " + query + ";")
        (args.output_directory / (PREFIX + "P2_Plan" + label + ".txt")).write_text(text_plan + "\n")
        return {"execution_ms": [p["Execution Time"] for p in plans],
                "planning_ms": [p["Planning Time"] for p in plans],
                "median_execution_ms": statistics.median(p["Execution Time"] for p in plans),
                "median_planning_ms": statistics.median(p["Planning Time"] for p in plans),
                "root_shared_hit_blocks": [p["Plan"].get("Shared Hit Blocks", 0) for p in plans],
                "root_shared_read_blocks": [p["Plan"].get("Shared Read Blocks", 0) for p in plans]}

    before = measure("Before")
    sql((HERE / (PREFIX + "P2_Index.sql")).read_text())
    after = measure("After")
    after_rows = json.loads(sql(ordered_result))
    if after_rows != before_rows:
        raise AssertionError("Index changed query results")
    sizes = json.loads(sql("SELECT json_build_object('heap_bytes',pg_relation_size('p2_benchmark.reservation_history'),"
                          "'new_index_bytes',pg_relation_size('p2_benchmark.reservation_guest_arrival_idx'))"))
    result = {"captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "database": args.database,
              "server": sql("SELECT version();"), "synthetic_rows": int(sql("SELECT count(*) FROM p2_benchmark.reservation_history;")),
              "query": query, "settings": server_settings, "other_client_sessions_at_start": other_clients,
              "warmup_runs_per_phase": 2, "measured_runs_per_phase": 5, "before": before, "after": after,
              "result_rows": before_rows, "independent_expected_rows_match": True, "result_equivalence": True,
              "result_sha256": hashlib.sha256(json.dumps(before_rows, sort_keys=True).encode()).hexdigest(),
              "storage": sizes, "median_execution_ratio_before_over_after": before["median_execution_ms"] / after["median_execution_ms"]}
    (args.output_directory / (PREFIX + "P2_BenchmarkResults.json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
