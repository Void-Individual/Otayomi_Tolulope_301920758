"""Coordinate real overlapping psql sessions, waiting for observed database blocking."""

import datetime as dt
import json
from pathlib import Path
import queue
import subprocess
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
PREFIX = "Otayomi_Tolulope_301920758_"
DATABASE = "tolu_guesthouse_301920758_p3"
BASE = ["docker", "exec", "-i", "tolu-mit8103-postgres", "psql", "-X", "-qAt",
        "-U", "tolu_admin", "-d", DATABASE, "-v", "ON_ERROR_STOP=1"]


def query(sql):
    return subprocess.check_output(BASE, input=sql, text=True).strip()


def phases(filename):
    result = {}
    current = None
    for line in (HERE / filename).read_text().splitlines():
        if line.startswith("-- @phase "):
            current = line.split()[-1]
            result[current] = []
        elif current:
            result[current].append(line)
    return {name: "\n".join(lines) for name, lines in result.items()}


class Session:
    def __init__(self, name):
        self.name = name
        self.log = []
        self.pending = queue.Queue()
        self.process = subprocess.Popen(BASE, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()
        self.run("SET statement_timeout='30s'; SET lock_timeout='25s'; SET timezone='Africa/Lagos';")
        self.pid = int(self.run("SELECT pg_backend_pid();")[-1])

    def read(self):
        for line in self.process.stdout:
            self.log.append(line.rstrip("\n"))
            self.pending.put(line.rstrip("\n"))
        self.pending.put(None)

    def send(self, sql):
        token = "DONE_" + uuid.uuid4().hex
        self.log.append("SQL> " + sql)
        self.process.stdin.write(sql + "\n\\echo " + token + "\n")
        self.process.stdin.flush()
        return token

    def collect(self, token, timeout=30):
        output = []
        end = time.monotonic() + timeout
        while True:
            line = self.pending.get(timeout=max(0.01, end-time.monotonic()))
            if line is None:
                raise RuntimeError(self.name + " exited unexpectedly: " + "\n".join(output))
            if line == token:
                return output
            output.append(line)

    def run(self, sql):
        return self.collect(self.send(sql))

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write("ROLLBACK;\n\\q\n")
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)
        self.reader.join(timeout=2)


def main():
    if query("SELECT count(*) FROM guesthouse.reservation WHERE reservation_ref IN ('PCG-P3-WINNER','PCG-P3-LOSER');") != "0":
        raise SystemExit("Concurrency references already exist; use a fresh dedicated P3 database copy")
    if query("SELECT count(*) FROM guesthouse.reservation WHERE reservation_ref='PCG-P3-COMMIT';") != "1":
        raise SystemExit("Run P3_Transactions.sql first")
    a = b = None
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    try:
        a = Session("A")
        b = Session("B")
        sa = phases(PREFIX + "P3_SessionA.sql")
        sb = phases(PREFIX + "P3_SessionB.sql")
        a_output = a.run(sa["begin"])
        b_output = b.run(sb["begin"])
        if a_output[-1] != "1" or b_output[-1] != "0" or a.pid == b.pid:
            raise AssertionError("Independent-session visibility checks failed")
        pending_b = b.send(sb["attempt"])
        end = time.monotonic() + 15
        blocked = None
        while time.monotonic() < end:
            observation = json.loads(query(
                "SELECT row_to_json(s) FROM (SELECT pid,state,wait_event_type,wait_event,"
                "pg_blocking_pids(pid) AS blockers FROM pg_stat_activity WHERE pid=" + str(b.pid) + ") s;"))
            if observation["wait_event_type"] == "Lock" and a.pid in observation["blockers"]:
                blocked = observation
                break
            time.sleep(0.1)
        if blocked is None:
            raise AssertionError("No actual B-on-A database lock wait was observed")
        observed_at = dt.datetime.now(dt.timezone.utc).isoformat()
        a.run(sa["commit"])
        conflict = b.collect(pending_b)
        if "CONFLICT_SQLSTATE 23P01" not in conflict:
            raise AssertionError("Expected exclusion violation, got " + repr(conflict))
        b.run(sb["finish"])
        final_rows = json.loads(query(
            "SELECT json_agg(r ORDER BY reservation_ref) FROM (SELECT reservation_ref,room_number,arrival,departure,status "
            "FROM guesthouse.reservation WHERE reservation_ref IN ('PCG-P3-WINNER','PCG-P3-LOSER')) r;"))
        if len(final_rows) != 1 or final_rows[0]["reservation_ref"] != "PCG-P3-WINNER":
            raise AssertionError("Double-booking invariant failed")
        summary = {"started_at_utc": started, "database": DATABASE,
                   "session_a_pid": a.pid, "session_b_pid": b.pid, "isolation": "read committed",
                   "a_sees_own_uncommitted_booking": 1, "b_sees_a_uncommitted_booking": 0,
                   "blocking_observed_at_utc": observed_at, "blocking_observation": blocked,
                   "b_error_sqlstate": "23P01", "final_rows": final_rows,
                   "invariant": "Exactly one accepted booking; losing transaction rolled back"}
    finally:
        for session in (a, b):
            if session:
                session.close()
                clean_log = [line for line in session.log if not line.startswith("DONE_")]
                (HERE / (PREFIX + "P3_Session" + session.name + "Results.txt")).write_text(
                    "Session " + session.name + " | database " + DATABASE + "\nStarted UTC: " + started +
                    "\nSQL> denotes the sent commands; remaining lines are captured psql output.\n\n" + "\n".join(clean_log) + "\n")
    leftovers = int(query("SELECT count(*) FROM pg_stat_activity WHERE application_name IN ('ToluP3-A','ToluP3-B');"))
    if leftovers:
        raise AssertionError("Experiment sessions remain connected")
    summary["experiment_sessions_remaining"] = leftovers
    (HERE / (PREFIX + "P3_ConcurrencyResults.json")).write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
