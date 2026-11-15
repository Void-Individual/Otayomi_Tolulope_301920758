# Portfolio 3 — Transactions and concurrency

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

A reservation must either reserve the whole stay or have no effect. Two receptionists can request the same apparently available room, so the database must enforce the overlap rule even when their requests arrive together.

## Transaction results

[Transactions.sql](Otayomi_Tolulope_301920758_P3_Transactions.sql) and its [captured output](Otayomi_Tolulope_301920758_P3_TransactionResults.txt) demonstrate three cases in a separate copy of the P1 seed database.

| Case                | Action                                                                                | Observed outcome                                                                             |
| ------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Commit              | Operator role books room 103 for 16–18 December                                       | `PCG-P3-COMMIT` remains after `COMMIT`, with two nights at NGN 25,000                        |
| Rollback            | Insert temporary guest G900 and a valid booking, then attempt a booking for 99 people | Capacity check returns `23514`; `ROLLBACK` removes the guest and both attempted reservations |
| Duplicate reference | Reuse `PCG-P3-COMMIT` for another request                                             | Primary key returns `23505`; the first accepted booking remains unchanged                    |

The expected error messages in the transcript are part of the tests. Assertions check their SQLSTATE values and the retained rows. Temporarily disabling psql's stop-on-error around these intentional failures lets the script issue `ROLLBACK`; unexpected assertion failures still stop execution.

Atomicity is demonstrated by the multi-statement rollback. Consistency follows from the capacity, reference and overlap constraints. Isolation is observed below. A successful commit is checked from subsequent statements and an independent connection; this is not a power-loss or recovery test of durability.

## Two real sessions

[Session A](Otayomi_Tolulope_301920758_P3_SessionA.sql) and [Session B](Otayomi_Tolulope_301920758_P3_SessionB.sql) both use **READ COMMITTED**. [RunConcurrency.py](Otayomi_Tolulope_301920758_P3_RunConcurrency.py) keeps separate psql connections open, executes their labelled phases, and uses a third connection to observe blocking before allowing A to commit.

1. A inserts `PCG-P3-WINNER` for room 104, 24–26 December, but leaves its transaction open. A sees its own row.
2. B starts and sees zero rows for A's uncommitted reference: there is no dirty read.
3. B attempts `PCG-P3-LOSER` for the same room and dates. The GiST exclusion constraint waits for A's outcome.
4. The monitor actually observes B waiting on A's transaction ID. A then commits; B receives exclusion violation `23P01` and rolls back.
5. A fresh query finds exactly one accepted booking, `PCG-P3-WINNER`. Both experiment sessions close.

The [machine-readable observation](Otayomi_Tolulope_301920758_P3_ConcurrencyResults.json) records backend PIDs 520 and 534 and the real `Lock`/`transactionid` wait at `2026-11-15T15:24:52.650760+00:00`. Full command/output transcripts are [A results](Otayomi_Tolulope_301920758_P3_SessionAResults.txt) and [B results](Otayomi_Tolulope_301920758_P3_SessionBResults.txt). PIDs and execution times will differ on another run.

READ COMMITTED gives each statement a new committed-data snapshot. A preliminary availability query therefore cannot reserve a room or guarantee a later insert will succeed. The exclusion constraint is the decisive protection: it coordinates conflicting writes even though B's earlier SELECT could not see A's uncommitted row. This demonstrates a controlled booking race, rather than a lost-update example or a claim of serializable isolation. These behaviours follow PostgreSQL's [isolation rules](https://www.postgresql.org/docs/17/transaction-iso.html); [`pg_stat_activity` and wait events](https://www.postgresql.org/docs/17/monitoring-stats.html) provide the observation.

## Reproduce

Complete the P1 schema and seed in the documented replay database first, with no open sessions using it. Create the P3 copy once:

```bash
docker exec tolu-mit8103-postgres createdb -U tolu_admin \
  --template=tolu_guesthouse_301920758_replay tolu_guesthouse_301920758_p3

docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758_p3 \
  < portfolio-3-transactions-concurrency/Otayomi_Tolulope_301920758_P3_Transactions.sql

python3 portfolio-3-transactions-concurrency/Otayomi_Tolulope_301920758_P3_RunConcurrency.py
```

Run each command only after the previous one succeeds. The scripts refuse existing P3 references; they do not delete previous evidence or reset databases. The Python runner writes the two session transcripts and the JSON observation. For a manual run, use two terminals and execute each `@phase` block separately in the order above; pasting Session A's whole file would commit too soon. The scripted monitor requires the administrative connection to inspect both sessions; the first commit test separately verifies the restricted operator API.

The completed P3 database has 12 reservations and the original eight guests: ten seed records plus the commit example and concurrency winner. The main and replay databases retain their original ten business reservations. Any separate P2 benchmark schema in a template is irrelevant to these tests. This exercise does not modify P1's model or evidence.
