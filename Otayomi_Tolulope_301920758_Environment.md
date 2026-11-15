# Reproducing the Palm Court Guesthouse environment

**Tolulope Otayomi · 301920758**

Verified on macOS arm64 with Docker Desktop. PostgreSQL runs in its own container with networking disabled and is accessed using `docker exec`. MongoDB runs as a separate process bound only to `127.0.0.1:27058`. Neither uses the existing unrelated PostgreSQL container. Runtime files and generated credentials belong under ignored `temp/runtime/`.

| Component                  | Tested version / identifier                                                        |
| -------------------------- | ---------------------------------------------------------------------------------- |
| PostgreSQL server and psql | 17.11, official `postgres:17-alpine` image                                         |
| Immutable image reference  | `postgres@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b` |
| Docker engine              | 29.8.2                                                                             |
| MongoDB Community          | 7.0.43                                                                             |
| mongosh                    | 2.12.0                                                                             |
| PostgreSQL container       | `tolu-mit8103-postgres`                                                            |
| Main PostgreSQL database   | `tolu_guesthouse_301920758`                                                        |
| Fresh replay database      | `tolu_guesthouse_301920758_replay`                                                 |
| Intended MongoDB database  | `tolu_guesthouse_301920758`                                                        |

Actual checks are in [EnvironmentResults](Otayomi_Tolulope_301920758_EnvironmentResults.txt). MongoDB ping and database selection succeeded with zero collections. Selecting a name does not materialise a MongoDB database; its portfolio data will be created in P4.

## First-time setup on a clean workspace

Install Docker and MongoDB/mongosh from their official sources if absent. Docker must be running. The commands below assume macOS/Linux tools and available `python3`, `docker`, `mongod` and `mongosh`. Run from the repository root. Keep the container name, database names and directory paths specific to this project; do not reuse another project's data directory. On Windows, use equivalent paths/process management rather than pasting the native shell commands unchanged.

```bash
mkdir -p temp/runtime/postgres temp/runtime/mongo temp/runtime/secrets
chmod 700 temp/runtime/secrets
python3 - <<'PY'
from pathlib import Path
import secrets
p = Path('temp/runtime/secrets/postgres_password')
if not p.exists():
    p.write_text(secrets.token_urlsafe(36) + '\n')
    p.chmod(0o600)
PY

docker run -d --name tolu-mit8103-postgres --network none \
  --mount "type=bind,source=$PWD/temp/runtime/postgres,target=/var/lib/postgresql/data" \
  --mount "type=bind,source=$PWD/temp/runtime/secrets/postgres_password,target=/run/secrets/postgres_password,readonly" \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  -e POSTGRES_USER=tolu_admin \
  -e POSTGRES_DB=tolu_guesthouse_301920758 \
  postgres@sha256:266d3c257594e195b309ae9d1805e54c788f1d7b375f56bf6c367aac6c917e7b

docker exec tolu-mit8103-postgres pg_isready \
  -U tolu_admin -d tolu_guesthouse_301920758

mongod --bind_ip 127.0.0.1 --port 27058 \
  --dbpath "$PWD/temp/runtime/mongo" \
  --logpath "$PWD/temp/runtime/mongodb.log" \
  --pidfilepath "$PWD/temp/runtime/mongodb.pid" --fork

MONGOSH_DISABLE_TELEMETRY=1 mongosh --norc --quiet \
  'mongodb://127.0.0.1:27058/tolu_guesthouse_301920758' \
  --eval 'printjson({database: db.getName(), ping: db.runCommand({ping: 1}).ok, version: db.version(), collections: db.getCollectionNames()})'
```

Wait for PostgreSQL readiness before running SQL. If the project container already exists, inspect its name and data mounts, then use `docker start tolu-mit8103-postgres`; do not rerun `docker run` with the same name. If MongoDB is already running on 27058, verify it is this project process instead of starting another one. The tested MongoDB instance has no authentication and contains only synthetic/demo data; loopback binding is not a defence against other local users. Do not expose it to a network or use real personal data. PostgreSQL's local socket inside its isolated container is used for these administration commands; Docker access itself is privileged.

The image is pinned to the actual tested digest for reproducibility; it is not a recommendation to keep an old patch forever. Native MongoDB installation instructions are in the [official MongoDB guide](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-os-x/). The [Docker Official Image documentation](https://hub.docker.com/_/postgres) explains database initialisation and password-file support; [MongoDB configuration](https://www.mongodb.com/docs/v7.0/reference/configuration-options/) documents bind address, port and data path.

## Run Portfolio 1

Run each command only if the previous command succeeds. `-X` avoids user psql configuration; the scripts enable `ON_ERROR_STOP` so an unexpected error fails the run. The schema requires an administrator who can install `btree_gist` and create the dedicated operator role.

```bash
docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758 \
  < portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_Schema.sql

docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758 \
  < portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_Seed.sql

docker exec -i tolu-mit8103-postgres psql -X -U tolu_admin \
  -d tolu_guesthouse_301920758 \
  < portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_ConstraintTests.sql
```

Schema and seed are install-once scripts. They fail safely on existing objects/duplicate fixtures and do not reset an existing portfolio. The test script is repeatable: its changes roll back, then it prints the retained seed state. It also uses temporary helpers to check both SQLSTATE and the intended constraint name for expected failures.

## Fresh replay

Create a second empty database and run the same three files with `-d tolu_guesthouse_301920758_replay`. This leaves the main database untouched. If that replay database already exists, `createdb` should fail; inspect it before choosing an intentional reset. These instructions contain no automatic database deletion.

```bash
docker exec tolu-mit8103-postgres createdb -U tolu_admin \
  tolu_guesthouse_301920758_replay
```

The schema accepts only the two documented database names. [P1 Replay](portfolio-1-database-design/Otayomi_Tolulope_301920758_P1_Replay.txt) records the actual clean installation and test run. Business rows should match the main database; actual audit timestamps naturally differ between executions.

## Scenario clock and process lifecycle

The seed builds fictional November/December 2026 booking history, then leaves `demo_clock.as_of_date` at `2026-12-01`. Only the administrator changes this fixture control. Reservation audit timestamps still come from the real database clock. Advancing the fixture date does not automatically complete a stay; the status operation must be called explicitly.

Stop this PostgreSQL instance with `docker stop tolu-mit8103-postgres`. For MongoDB, verify the process command and project path for the PID in `temp/runtime/mongodb.pid`, then send that process `SIGTERM`. Do not stop a different MongoDB process just because it uses the default port. Keep the data directories to restart later; generated data and secrets are not repository content.
