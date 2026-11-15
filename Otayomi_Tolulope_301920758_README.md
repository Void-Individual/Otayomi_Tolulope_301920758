# MIT 8103 — Palm Court Guesthouse

**Tolulope Otayomi · Student ID 301920758**  
Advanced Database Systems · September Cohort 2026

This portfolio uses a fictional Lagos guesthouse to study reliable reservations. It uses synthetic data throughout. The core rule is simple: two non-cancelled reservations must never occupy the same room on the same night.

Public repository: <https://github.com/Void-Individual/Otayomi_Tolulope_301920758>.

## Portfolio contents

| Portfolio                       | Status                                                              | Entry point                                                                               |
| ------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 1. Database design              | Implemented; 47 constraint checks passed                            | [P1 README](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_README.md)          |
| 2. Query optimisation           | Six verified queries; measured index experiment                     | [P2 README](portfolio-2-query-optimisation/Otayomi_Tolulope_301920758_P2_README.md)       |
| 3. Transactions and concurrency | Commit/rollback and observed two-session booking conflict           | [P3 README](portfolio-3-transactions-concurrency/Otayomi_Tolulope_301920758_P3_README.md) |
| 4. NoSQL                        | 13 MongoDB events; validation, replay and SQL reconciliation passed | [P4 README](portfolio-4-nosql/Otayomi_Tolulope_301920758_P4_README.md)                    |
| 5. Distributed/cloud            | Architecture discussion completed; no cloud deployment claimed      | [P5 README](portfolio-5-distributed-cloud/Otayomi_Tolulope_301920758_P5_README.md)        |

The [three-page final summary](Otayomi_Tolulope_301920758_FinalSummary.pdf) brings together the case, all five activities, selected evidence, references and reflection. Its [editable HTML source](Otayomi_Tolulope_301920758_FinalSummary.html) uses the [condensed ER overview](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_SummaryER.svg). The [individual reflection](Otayomi_Tolulope_301920758_IndividualReflection.md) records the reported challenges with requirements, MongoDB configuration and monthly booking values. Detailed [references and tool acknowledgements](Otayomi_Tolulope_301920758_References.md) accompany the portfolio.

## Reproduce the work

Start with the [environment guide](Otayomi_Tolulope_301920758_Environment.md), then run P1 Schema, Seed and ConstraintTests in that order. The SQL targets an isolated PostgreSQL database and refuses an existing `guesthouse` schema instead of deleting it. A separate replay database is used to test installation from scratch. Then follow each portfolio README: P2 keeps its stress data in a separate schema, P3 uses a dedicated database copy, and P4 uses a separate MongoDB collection.

The [case study](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_CaseStudy.md), [relational design](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_RelationalDesign.md), [ER diagram](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_ERDiagram.svg) and [normalisation](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_Normalisation.md) explain the model. The code and evidence must be read together.

The schema stores four business entities and one technical demonstration clock. Scenario dates are fictional and reproducible; actual execution and audit timestamps are retained. Prices represent booking value in NGN, not payment receipts or profit. All nights in a booking share its agreed nightly rate; totals and individual room-nights are derived rather than redundantly stored.

## Sources and declaration

The university assessment brief defines the required activities. The [manual codelab](https://github.com/arizonal2014/MIT8103_Codelab), [portfolio generator documentation](https://github.com/arizonal2014/MIT8103_Portfolio_Generator), and [worked library example](https://github.com/arizonal2014/Harrison_Perete_202600001) were reviewed for workflow and evidence expectations. The generator was not run or used. No example student's implementation, records, measurements or reflection is used as Tolu's work. Technical sources are linked in the relevant documents.

**AI-use declaration:** OpenAI Codex assisted with planning, code, documentation and test execution. I reviewed the benchmark interpretation, concurrency explanation and proposed-cloud scope.
