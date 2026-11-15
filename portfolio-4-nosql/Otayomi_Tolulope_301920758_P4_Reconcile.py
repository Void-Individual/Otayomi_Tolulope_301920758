"""Read both local stores and compare every P1 business field in the latest snapshots."""

import datetime as dt
import json
from pathlib import Path
import subprocess

DATABASE = "tolu_guesthouse_301920758"
sql = """
SELECT json_agg(q ORDER BY reservation_ref) FROM (
 SELECT reservation_ref, guest_code, room_number, category_code,
 arrival, departure, party_size, status, agreed_nightly_rate, booked_on, status_changed_on
 FROM guesthouse.reservation JOIN guesthouse.room USING(room_number)
) q;
"""
sql_rows = json.loads(subprocess.check_output(
    ["docker", "exec", "-i", "tolu-mit8103-postgres", "psql", "-X", "-qAt",
     "-v", "ON_ERROR_STOP=1", "-U", "tolu_admin", "-d", DATABASE], input=sql, text=True))
javascript = """
const rows = db.reservation_events
  .aggregate([
    { $sort: { reservationRef: 1, sequence: 1 } },
    {
      $group: {
        _id: "$reservationRef",
        first: { $first: "$$ROOT" },
        last: { $last: "$$ROOT" },
      },
    },
    { $sort: { _id: 1 } },
  ])
  .toArray()
  .map((r) => ({
    reservation_ref: r._id,
    guest_code: r.last.snapshot.guestCode,
    room_number: r.last.snapshot.roomNumber,
    category_code: r.last.snapshot.categoryCode,
    arrival: r.last.snapshot.arrival.toISOString().slice(0, 10),
    departure: r.last.snapshot.departure.toISOString().slice(0, 10),
    party_size: r.last.snapshot.partySize,
    status: r.last.snapshot.status,
    agreed_nightly_rate: Number(r.last.snapshot.agreedNightlyRate.toString()),
    booked_on: r.first.scenarioDate.toISOString().slice(0, 10),
    status_changed_on: r.last.scenarioDate.toISOString().slice(0, 10),
  }));
print(JSON.stringify(rows));
"""
mongo_rows = json.loads(subprocess.check_output(
    ["mongosh", "--norc", "--quiet", "mongodb://127.0.0.1:27058/" + DATABASE,
     "--eval", javascript], text=True))
if len(sql_rows) != 10 or sql_rows != mongo_rows:
    raise AssertionError("MongoDB latest snapshots differ from the original P1 fixture")
result = {
    "captured_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
    "postgres_database": DATABASE,
    "mongodb_database": DATABASE,
    "matched_reservations": len(sql_rows),
    "fields_compared": list(sql_rows[0]),
    "exact_business_field_match": True,
    "rows": sql_rows,
}
output = Path(__file__).with_name("Otayomi_Tolulope_301920758_P4_Reconciliation.json")
output.write_text(json.dumps(result, indent=2) + "\n")
print("PASS: all 10 latest snapshots and their scenario dates match PostgreSQL")
