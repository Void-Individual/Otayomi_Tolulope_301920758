# References and acknowledgements

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

## Assessment and workflow

- Miva University. _MIT 8103 Advanced Database Systems Continuous Assessment, September Cohort 2026_, 2026/2027 academic session, first semester. The supplied assessment brief defines the portfolios, evidence and 2–3 page documentation. The LMS submission instructions define naming and submission rules.
- arizonal2014. [MIT8103 Codelab](https://github.com/arizonal2014/MIT8103_Codelab): consulted for the manual workflow and evidence expectations.
- arizonal2014. [MIT8103 Portfolio Generator](https://github.com/arizonal2014/MIT8103_Portfolio_Generator): documentation reviewed for structure; the generator was not run or used.
- arizonal2014. [Worked library portfolio](https://github.com/arizonal2014/Harrison_Perete_202600001): consulted for cross-checking organisation and evidence. Its implementation, student details, datasets, measurements, screenshots and reflection were not copied.

The Palm Court Guesthouse case, business rules, synthetic fixtures, scripts and diagrams were developed for this portfolio. No real guest dataset is used. Tutorial dataset sizes and example-specific rules are not treated as additional assessment requirements.

## PostgreSQL technical sources

PostgreSQL 17 documentation:

- [Constraints](https://www.postgresql.org/docs/17/ddl-constraints.html), [range types](https://www.postgresql.org/docs/17/rangetypes.html), and [btree_gist](https://www.postgresql.org/docs/17/btree-gist.html): keys, references and the room/stay exclusion constraint.
- [PL/pgSQL triggers](https://www.postgresql.org/docs/17/plpgsql-trigger.html) and [function security](https://www.postgresql.org/docs/17/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY): controlled booking operations and rule enforcement.
- [Using EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html): actual plans, execution/planning times and buffer interpretation.
- [Transaction isolation](https://www.postgresql.org/docs/17/transaction-iso.html) and [monitoring statistics](https://www.postgresql.org/docs/17/monitoring-stats.html): READ COMMITTED visibility and observed wait events.
- [Standby replication](https://www.postgresql.org/docs/17/warm-standby.html), [failover](https://www.postgresql.org/docs/17/warm-standby-failover.html), and [continuous archiving/PITR](https://www.postgresql.org/docs/17/continuous-archiving.html): P5 proposal, fencing and recovery considerations.

## MongoDB technical sources

MongoDB 7.0 documentation:

- [Data modelling](https://www.mongodb.com/docs/v7.0/data-modeling/) and [schema validation](https://www.mongodb.com/docs/v7.0/core/schema-validation/): embedded snapshots, explicit BSON types and validation.
- [Replication](https://www.mongodb.com/docs/v7.0/replication/), [write concern](https://www.mongodb.com/docs/v7.0/reference/write-concern/), and [shard keys](https://www.mongodb.com/docs/v7.0/core/sharding-shard-key/): majority acknowledgement and proposed distribution trade-offs.
- [macOS installation](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-os-x/) and [configuration options](https://www.mongodb.com/docs/v7.0/reference/configuration-options/): isolated local process and connection settings.

## Software and document preparation

The [environment guide](Otayomi_Tolulope_301920758_Environment.md) records PostgreSQL 17.11, MongoDB 7.0.43, mongosh 2.12.0 and Docker engine 29.8.2. PostgreSQL uses the [Docker Official Image](https://hub.docker.com/_/postgres) pinned to the tested digest. Python 3.9.6 standard-library scripts coordinate experiments and compare results.

| Tool                                        | Version used | Role                                                              |
| ------------------------------------------- | ------------ | ----------------------------------------------------------------- |
| [ReportLab](https://docs.reportlab.com/)    | 4.5.1        | PDF layout and export                                             |
| Beautiful Soup                              | 4.15.0       | Read the editable HTML document source for export                 |
| pypdf                                       | 6.21.4       | Inspect PDF page count, text, metadata and links                  |
| Pillow                                      | 11.3.0       | Image handling in PDF generation                                  |
| [resvg-js](https://github.com/thx/resvg-js) | 2.6.2        | Render authored SVG diagrams into PNGs                            |
| [Prettier](https://prettier.io/docs/)       | 3.10.1       | Format supported document, JSON, HTML, SVG and JavaScript sources |
| [ESLint](https://eslint.org/docs/latest/)   | 10.15.0      | Check authored mongosh JavaScript                                 |
| Poppler                                     | 26.10.0      | Render PDF pages and inspect document properties                  |

Installed packages, local credentials, database runtime files, downloaded references and internal verification notes are excluded from the submission. The repository contains the assessment sources, outputs, diagrams and final documentation.
