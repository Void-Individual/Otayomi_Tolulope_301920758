# Portfolio 2 — Measured guest-history index experiment

**Tolulope Otayomi · 301920758**

## Workload and method

[BenchmarkSetup.sql](Otayomi_Tolulope_301920758_P2_BenchmarkSetup.sql) creates `p2_benchmark` separately from the `guesthouse` business schema. It generates 5,000 synthetic guest identifiers and 200,000 two-night booking requests over 2027–2040, rotating through the same 12 rooms and three category prices. Each room/stay slot has nine cancelled requests and one confirmed request: 20,000 confirmed and 180,000 cancelled rows. The 90% cancellation rate is an artificial stress distribution, not an estimate of guesthouse behaviour. Primary keys, foreign keys and a partial overlap exclusion constraint remain enabled. [Setup output](Otayomi_Tolulope_301920758_P2_BenchmarkSetupResults.txt) records the actual load.

The [query](Otayomi_Tolulope_301920758_P2_BenchmarkQuery.sql) returns guest G04242's history with arrival dates in `[2030-01-01,2035-01-01)`, including cancelled requests, ordered by arrival and reference. It returns **16 rows**. A partial index excluding cancellations would not serve the whole requirement. The added [B-tree index](Otayomi_Tolulope_301920758_P2_Index.sql) is `(guest_code, arrival)`: equality on the leading column and a date range on the second narrow the search. The small final sort remains because the requested tie-breaker is not in that index.

[RunBenchmark.py](Otayomi_Tolulope_301920758_P2_RunBenchmark.py) executes two unmeasured warm-up queries and five measured `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` queries per phase. It runs `ANALYZE`, keeps data/query/settings constant, creates the index between phases, and compares all ordered output rows before and after. A separate Python calculation of the fixture verifies the 16 expected rows. No planner access method is forced. The final run used the replay database, with zero other client sessions at its start and no other controlled experiment running alongside it.

## Actual measurements

Captured UTC: `2026-11-15T15:27:31.301352+00:00`. PostgreSQL 17.11 on arm64 Linux inside the project's Docker container. The complete [results JSON](Otayomi_Tolulope_301920758_P2_BenchmarkResults.json) records configuration, individual runs, rows, equality checks and storage sizes.

| Measure                                    | Before index                          | After index                     |
| ------------------------------------------ | ------------------------------------- | ------------------------------- |
| Plan                                       | Sequential scan + sort                | Bitmap index/heap scan + sort   |
| Execution times, ms                        | 14.916, 14.19, 14.923, 14.373, 14.455 | 0.8, 0.671, 0.784, 0.743, 0.694 |
| Median execution, ms                       | 14.455                                | 0.743                           |
| Median planning, ms                        | 2.84                                  | 2.137                           |
| Shared buffer hits per measured execution  | 6                                     | 6                               |
| Shared buffer reads per measured execution | 1,935                                 | 19                              |
| Rows returned                              | 16                                    | 16                              |

The execution-only median fell by approximately **94.9%**, or a **19.45×** before/after ratio. Planning is reported separately; these are server execution times, not client/network latency or end-to-end application response times.

[Before text plan](Otayomi_Tolulope_301920758_P2_PlanBefore.txt) and [after text plan](Otayomi_Tolulope_301920758_P2_PlanAfter.txt) are additional illustrative executions, so their times need not equal the medians. The five measured plans are retained in [Before JSON](Otayomi_Tolulope_301920758_P2_PlansBefore.json) and [After JSON](Otayomi_Tolulope_301920758_P2_PlansAfter.json). The sequential plan filters out 199,984 rows. The indexed plan visits 16 exact heap blocks via a bitmap built from the new index. Buffer counts at a parent node include its descendants; they must not be added again across the plan tree. PostgreSQL explains these metrics in [Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html).

## Interpretation and limits

The selective index reduces the amount of data examined, while identical results show that optimisation preserved query meaning. It adds **6,332,416 bytes (6.04 MiB)** beside a **15,851,520-byte (15.12 MiB)** table heap. These are individual relation sizes, not total database storage. Maintaining another index also adds write/storage cost; insert throughput and index-build cost were not benchmarked, so no numerical write-overhead claim is made.

The actual server has an unusually small **400 kB `shared_buffers`**, while `effective_cache_size=4GB` is only a planner estimate. Warm-up runs therefore do not make this a fully cached experiment: both phases still report shared-buffer reads. Those reads may be satisfied by the operating-system cache, so they are not proof of physical disk I/O. `work_mem=4MB`, 8 kB blocks and `random_page_cost=4` were retained. JIT and parallel query were disabled equally in both phases to simplify the comparison; these are experiment settings, not recommended production defaults.

Five runs on one machine, a fixed phase order, synthetic skew and this constrained buffer pool limit generalisation. The workload is much larger than the real 12-room fixture and has an intentionally unrealistic cancellation mix. A production decision would require representative workloads, concurrent users and write-cost measurements. No production capacity or cloud performance is inferred.

## Reproduce on a fresh benchmark schema

Complete P1 in the documented replay database first. The setup intentionally fails if `p2_benchmark` already exists; the runner also refuses an existing benchmark index. There is no automatic destructive reset. Run each command only after its predecessor succeeds:

```bash
docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758_replay \
  < portfolio-2-query-optimisation/Otayomi_Tolulope_301920758_P2_BenchmarkSetup.sql

python3 portfolio-2-query-optimisation/Otayomi_Tolulope_301920758_P2_RunBenchmark.py \
  --database tolu_guesthouse_301920758_replay
```

The runner applies `P2_Index.sql` at the correct point; do not run that file beforehand. It writes evidence into this portfolio directory by default; use `--output-directory temp/benchmark-replay` to keep a later measurement separate. Timings will vary. Both the main and replay databases in the current workspace already contain completed benchmark schemas.
