# Portfolio 3 — Transactions and concurrency

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

Status: the dedicated portfolio exercise is not implemented in the steps 5–9 batch.

Planned evidence will show a committed booking, rollback of a failed multi-step operation, isolation behaviour and genuinely overlapping sessions competing for the same room-night. The exclusion constraint exists in Portfolio 1, but its sequential overlap tests do not demonstrate concurrent execution. Session-specific scripts, wait/conflict evidence and a final invariant check will be added when this activity is authorized.

Database `COMMIT` and `ROLLBACK` are distinct from Git commits. No Git publishing is authorized by the database scripts.
