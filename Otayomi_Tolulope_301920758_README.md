# MIT 8103 — Palm Court Guesthouse

**Tolulope Otayomi · Student ID 301920758**  
Advanced Database Systems · September Cohort 2026

This portfolio uses a fictional Lagos guesthouse to study reliable reservations. It uses synthetic data throughout. The core rule is simple: two non-cancelled reservations must never occupy the same room on the same night.

Public repository: <https://github.com/Void-Individual/Otayomi_Tolulope_301920758>.

## Current coverage

| Portfolio                       | Status                                                 | Entry point                                                                              |
| ------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| 1. Database design              | Implemented and tested; see evidence and review status | [P1 README](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_README.md)         |
| 2. Query optimisation           | Not started                                            | [P2 scope](portfolio-2-query-optimisation/Otayomi_Tolulope_301920758_P2_README.md)       |
| 3. Transactions and concurrency | Not started as a portfolio exercise                    | [P3 scope](portfolio-3-transactions-concurrency/Otayomi_Tolulope_301920758_P3_README.md) |
| 4. NoSQL                        | MongoDB connection checked; model not implemented      | [P4 scope](portfolio-4-nosql/Otayomi_Tolulope_301920758_P4_README.md)                    |
| 5. Distributed/cloud            | Not started                                            | [P5 scope](portfolio-5-distributed-cloud/Otayomi_Tolulope_301920758_P5_README.md)        |

The final 2–3 page summary and individual reflection are not complete. This is an incremental portfolio, not a finished submission.

## Reproduce the current work

Start with the [environment guide](Otayomi_Tolulope_301920758_Environment.md), then run P1 Schema, Seed and ConstraintTests in that order. The SQL targets an isolated PostgreSQL database and refuses an existing `guesthouse` schema instead of deleting it. A separate replay database is used to test installation from scratch.

The [case study](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_CaseStudy.md), [relational design](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_RelationalDesign.md), [ER diagram](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_ERDiagram.svg) and [normalisation](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_Normalisation.md) explain the model. The code and evidence must be read together.

The schema stores four business entities and one technical demonstration clock. Scenario dates are fictional and reproducible; actual execution and audit timestamps are retained. Prices represent booking value in NGN, not payment receipts or profit. All nights in a booking share its agreed nightly rate; totals and individual room-nights are derived rather than redundantly stored.

## Sources and AI assistance

The university assessment brief defines the required activities. The [manual codelab](https://github.com/arizonal2014/MIT8103_Codelab), [portfolio generator documentation](https://github.com/arizonal2014/MIT8103_Portfolio_Generator), and [worked library example](https://github.com/arizonal2014/Harrison_Perete_202600001) were reviewed for workflow and evidence expectations. The generator was not run. No example student's implementation, records, measurements or reflection is used as Tolu's work. Technical sources are linked in the relevant documents.

**Current AI-use declaration:** OpenAI Codex assisted with requirements analysis, case definition, documentation and command execution and the agent was used to perform checks.
