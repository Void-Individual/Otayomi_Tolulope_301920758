# Portfolio 2 — Queries and optimisation

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

This portfolio answers operational questions on the original ten-reservation P1 fixture, then measures a selective guest-history query on a separate labelled synthetic workload. The benchmark does not replace the case-study data or represent real guesthouse demand.

## Business queries and verified results

[Queries.sql](Otayomi_Tolulope_301920758_P2_Queries.sql) contains the six queries, temporary result tables and assertions. [Results.txt](Otayomi_Tolulope_301920758_P2_Results.txt) is the actual psql output. The transaction rolls back all temporary work and performs no writes to the business tables.

| Query                                                     | Database techniques                                                                     | Result on the P1 fixture                                                      |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Q1: available rooms for two guests, 10–13 December        | Join categories, capacity filter, correlated `NOT EXISTS`, half-open date-range overlap | Nine rooms: 103, 104, 202, 203, 204, 301, 302, 303, 304                       |
| Q2: upcoming confirmed reservations                       | Four-table join, date/status filters, derived full-stay value                           | Seven bookings, NGN 740,000                                                   |
| Q3: nights and value by category within reporting periods | CTEs, cross/left joins, clipped date intervals, aggregation                             | December: 17 room-nights, NGN 660,000; 10–14 December: 10 nights, NGN 295,000 |
| Q4: rooms with no non-cancelled history                   | Correlated anti-join                                                                    | Six rooms: 103, 104, 203, 204, 303, 304                                       |
| Q5: cancellation history                                  | Filter and derived value                                                                | C001, originally NGN 120,000                                                  |
| Q6: guests without non-cancelled bookings                 | Correlated `NOT EXISTS`                                                                 | G008                                                                          |

Q3 counts only nights inside each half-open reporting interval. F006 spans 31 December–3 January: its full value is NGN 120,000, but only one night/NGN 40,000 belongs to December. The short window deliberately includes a Family category with **zero** nights and value, checking that the left join retains empty groups correctly. Cancelled C001 contributes neither occupancy nor active booking value. Values are agreed booking amounts, not receipts, revenue recognised under an accounting policy, or profit.

## Reproduce the business queries

Use the P1 main database from the [environment guide](../Otayomi_Tolulope_301920758_Environment.md):

```bash
docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758 \
  < portfolio-2-query-optimisation/Otayomi_Tolulope_301920758_P2_Queries.sql
```

## Benchmark and evidence

The [performance analysis](Otayomi_Tolulope_301920758_P2_Performance.md) explains the workload, measured timings, execution plans and limitations. Its result is specific to this machine and configuration. Scripts and evidence are linked there so the experiment can be inspected or repeated on a fresh benchmark schema.
