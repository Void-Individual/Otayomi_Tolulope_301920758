# Portfolio 4 — MongoDB reservation events

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

The guesthouse needs to inspect a booking's history, including cancelled stays. This implementation stores one document per reservation event in `reservation_events`, with the guest, room, stay dates and price embedded as a snapshot. PostgreSQL remains the authority for accepting bookings and preventing overlaps.

## Document model

| Field                        | Purpose and BSON type                                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `_id`                        | Stable event ID, such as `PCG-C001:2`; string                                                              |
| `reservationRef`, `sequence` | Booking reference and event order; string and integer; unique compound index                               |
| `schemaVersion`              | Integer 1 for this deliberately validated document shape                                                   |
| `eventType`                  | `CONFIRMED`, `CANCELLED` or `COMPLETED`                                                                    |
| `scenarioDate`               | Fictional business date represented by BSON Date                                                           |
| `snapshot`                   | Embedded guest/room/category codes, arrival/departure dates, party size, agreed price, currency and status |

Dates are stored at UTC midnight as a **date-only representation**, not an actual check-in time or audit timestamp. `sequence` orders events on the same day. Rates use Decimal128 and two-decimal validation, preserving NGN values without binary floating-point storage. The script prints a real UTC execution timestamp separately.

[Events.js](Otayomi_Tolulope_301920758_P4_Events.js) reconstructs **13 synthetic events** from the ten P1 fixtures: ten confirmations, two completions and one cancellation. This is an explicit demonstration dataset, not an automatic event feed or a claim that PostgreSQL retained a full historical event log. The P2 stress dataset and P3 experiment bookings are excluded.

Embedding makes an event self-contained for history queries and preserves the agreed rate if a category's current rate later changes. Repeating snapshot fields increases storage, but avoids joining current master data to reconstruct past events. A document per event avoids an indefinitely growing history array in one reservation document. The schema is intentionally controlled; a future version or optional field would require an explicit validator change. These choices apply MongoDB's [access-pattern-based data modelling](https://www.mongodb.com/docs/v7.0/data-modeling/).

## Implementation and actual evidence

The [first execution](Otayomi_Tolulope_301920758_P4_Results.txt) inserted 13 events. The [replay](Otayomi_Tolulope_301920758_P4_Replay.txt) inserted zero and passed the same checks. Upserts use `$setOnInsert`, then compare the complete stored document, so rerunning cannot silently rewrite an existing snapshot. Unexpected records or a different validator stop the script.

| Query / test                                                                                            | Actual result                                                                     |
| ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Nested room filter for 302                                                                              | Three events: C001 confirmation/cancellation and F007 confirmation                |
| Aggregate event types                                                                                   | 10 confirmed, 2 completed, 1 cancelled events                                     |
| Latest event per reservation                                                                            | 7 confirmed, 2 completed, 1 cancelled reservations                                |
| Full-stay value of latest non-cancelled bookings                                                        | Nine reservations, NGN 910,000; includes November and the January portion of F006 |
| Duplicate ID / duplicate reservation sequence                                                           | Rejected with MongoDB code `11000`                                                |
| Invalid date type, negative price, fractional kobo, reversed stay, zero party size, inconsistent status | Six rejected writes with code `121`                                               |
| Final collection count                                                                                  | Still 13 after all attempted invalid writes                                       |

Latest-state aggregation prevents a cancelled booking's earlier confirmation from being counted as active. Its full-stay total differs deliberately from P2's December-only value. The [reconciliation script](Otayomi_Tolulope_301920758_P4_Reconcile.py) reads both databases and compares all 11 represented business fields for every reservation. Its [captured result](Otayomi_Tolulope_301920758_P4_Reconciliation.json) confirms all ten snapshots match P1, including booking and status-change scenario dates.

Validation uses `$jsonSchema` for types/required fields and `$expr` for date order, price precision and matching event/snapshot status, following [MongoDB validation](https://www.mongodb.com/docs/v7.0/core/schema-validation/). The unique reference/sequence index prevents repeated positions within a booking history. The room/date index supports history lookup; no performance improvement is claimed for this 13-document fixture.

## Suitability and limits

This document model suits history retrieval and nested snapshots. It is less suitable as the sole booking authority in this implementation: the validator does not enforce foreign keys to PostgreSQL, room-specific capacity, legal cross-document transitions, or non-overlapping stays. The unique sequence index does not prove that a complete or correctly ordered history exists. Application roles would also be needed to enforce append-only access; the local administrator can still update or delete documents.

Separate local databases do not form a distributed transaction. Their agreement was checked after loading, and future changes would not synchronise automatically. P5 describes a proposed transactional outbox and retry design, clearly separated from this working fixture.

## Reproduce

Start the local MongoDB process using the [environment guide](../Otayomi_Tolulope_301920758_Environment.md), then run from the project root:

```bash
mongosh --norc --quiet \
  'mongodb://127.0.0.1:27058/tolu_guesthouse_301920758' \
  --file portfolio-4-nosql/Otayomi_Tolulope_301920758_P4_Events.js

python3 portfolio-4-nosql/Otayomi_Tolulope_301920758_P4_Reconcile.py
```

The first command is safe to repeat with the unchanged fixture. Reconciliation also requires the original P1 main database to be running. Both scripts stop on an unexpected mismatch. No cloud connection, replica set, payment data or real guest information is used.
