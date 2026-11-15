// Run with mongosh against the dedicated local guesthouse database.
// Scenario dates/events are reconstructed from the P1 synthetic fixture.
if (db.getName() !== "tolu_guesthouse_301920758") {
  throw new Error("Use the dedicated Tolu database");
}
function canonical(value) {
  const sort = (item) => {
    if (Array.isArray(item)) return item.map(sort);
    if (item && typeof item === "object")
      return Object.fromEntries(
        Object.keys(item)
          .sort()
          .map((key) => [key, sort(item[key])]),
      );
    return item;
  };
  return JSON.stringify(sort(EJSON.serialize(value, { relaxed: false })));
}
const collectionName = "reservation_events";
const states = ["CONFIRMED", "CANCELLED", "COMPLETED"];
const validator = {
  $and: [
    {
      $jsonSchema: {
        bsonType: "object",
        additionalProperties: false,
        required: [
          "_id",
          "schemaVersion",
          "reservationRef",
          "sequence",
          "eventType",
          "scenarioDate",
          "snapshot",
        ],
        properties: {
          _id: { bsonType: "string" },
          schemaVersion: { bsonType: "int", enum: [1] },
          reservationRef: { bsonType: "string", pattern: "^PCG-[A-Z0-9-]+$" },
          sequence: { bsonType: "int", minimum: 1, maximum: 2 },
          eventType: { enum: states },
          scenarioDate: { bsonType: "date" },
          snapshot: {
            bsonType: "object",
            additionalProperties: false,
            required: [
              "guestCode",
              "roomNumber",
              "categoryCode",
              "arrival",
              "departure",
              "partySize",
              "agreedNightlyRate",
              "currency",
              "status",
            ],
            properties: {
              guestCode: { bsonType: "string", pattern: "^G[0-9]{3,}$" },
              roomNumber: { bsonType: "string", pattern: "^[0-9]{3}$" },
              categoryCode: { enum: ["STD", "DLX", "FAM"] },
              arrival: { bsonType: "date" },
              departure: { bsonType: "date" },
              partySize: { bsonType: "int", minimum: 1, maximum: 5 },
              agreedNightlyRate: {
                bsonType: "decimal",
                minimum: NumberDecimal("0.01"),
                maximum: NumberDecimal("99999999.99"),
              },
              currency: { enum: ["NGN"] },
              status: { enum: states },
            },
          },
        },
      },
    },
    {
      $expr: {
        $and: [
          { $gt: ["$snapshot.departure", "$snapshot.arrival"] },
          { $eq: ["$eventType", "$snapshot.status"] },
          {
            $eq: [
              "$snapshot.agreedNightlyRate",
              { $round: ["$snapshot.agreedNightlyRate", 2] },
            ],
          },
        ],
      },
    },
  ],
};
const info = db.getCollectionInfos({ name: collectionName });
if (info.length === 0) {
  db.createCollection(collectionName, {
    validator,
    validationLevel: "strict",
    validationAction: "error",
  });
} else if (
  canonical(info[0].options.validator) !== canonical(validator) ||
  info[0].options.validationLevel !== "strict" ||
  info[0].options.validationAction !== "error"
) {
  throw new Error(
    "Existing collection validation differs; inspect it instead of overwriting",
  );
}
const events = db.getCollection(collectionName);
events.createIndex(
  { reservationRef: 1, sequence: 1 },
  { unique: true, name: "reservation_sequence" },
);
events.createIndex(
  { "snapshot.roomNumber": 1, scenarioDate: 1 },
  { name: "room_event_date" },
);

// ref, guest, room, category, arrival, departure, party, rate, current status.
const fixtures = [
  [
    "PCG-C001",
    "G008",
    "302",
    "FAM",
    "2026-12-20",
    "2026-12-22",
    3,
    "60000.00",
    "CANCELLED",
  ],
  [
    "PCG-F001",
    "G003",
    "101",
    "STD",
    "2026-12-10",
    "2026-12-12",
    2,
    "25000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F002",
    "G004",
    "101",
    "STD",
    "2026-12-12",
    "2026-12-15",
    1,
    "25000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F003",
    "G005",
    "102",
    "STD",
    "2026-12-10",
    "2026-12-13",
    2,
    "25000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F004",
    "G006",
    "201",
    "DLX",
    "2026-12-11",
    "2026-12-14",
    2,
    "40000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F005",
    "G007",
    "301",
    "FAM",
    "2026-12-20",
    "2026-12-23",
    4,
    "60000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F006",
    "G003",
    "202",
    "DLX",
    "2026-12-31",
    "2027-01-03",
    1,
    "40000.00",
    "CONFIRMED",
  ],
  [
    "PCG-F007",
    "G002",
    "302",
    "FAM",
    "2026-12-20",
    "2026-12-22",
    4,
    "60000.00",
    "CONFIRMED",
  ],
  [
    "PCG-H001",
    "G001",
    "101",
    "STD",
    "2026-11-05",
    "2026-11-07",
    2,
    "25000.00",
    "COMPLETED",
  ],
  [
    "PCG-H002",
    "G002",
    "201",
    "DLX",
    "2026-11-06",
    "2026-11-09",
    1,
    "40000.00",
    "COMPLETED",
  ],
];
const day = (value) => ISODate(value + "T00:00:00Z");
const documents = fixtures.flatMap(
  ([ref, guest, room, category, arrival, departure, party, rate, status]) => {
    const historical = status === "COMPLETED";
    const base = {
      _id: ref + ":1",
      schemaVersion: NumberInt(1),
      reservationRef: ref,
      sequence: NumberInt(1),
      eventType: "CONFIRMED",
      scenarioDate: day(historical ? "2026-11-01" : "2026-12-01"),
      snapshot: {
        guestCode: guest,
        roomNumber: room,
        categoryCode: category,
        arrival: day(arrival),
        departure: day(departure),
        partySize: NumberInt(party),
        agreedNightlyRate: NumberDecimal(rate),
        currency: "NGN",
        status: "CONFIRMED",
      },
    };
    if (status === "CONFIRMED") return [base];
    return [
      base,
      {
        ...base,
        _id: ref + ":2",
        sequence: NumberInt(2),
        eventType: status,
        scenarioDate: day(historical ? "2026-11-09" : "2026-12-01"),
        snapshot: { ...base.snapshot, status },
      },
    ];
  },
);
function check(condition, label) {
  if (!condition) throw new Error("FAIL: " + label);
  print("PASS: " + label);
}
print("Actual execution UTC: " + new Date().toISOString());
print("Server: " + db.version() + " | Database: " + db.getName());
print(
  "Fixture: reconstructed P1 synthetic events; dates are scenario dates, not execution timestamps.",
);
check(
  events.countDocuments({ _id: { $nin: documents.map((doc) => doc._id) } }) ===
    0,
  "no unexpected existing events",
);
let inserted = 0;
for (const document of documents) {
  inserted += events.updateOne(
    { _id: document._id },
    { $setOnInsert: document },
    { upsert: true },
  ).upsertedCount;
  check(
    canonical(events.findOne({ _id: document._id })) === canonical(document),
    "stored snapshot matches " + document._id,
  );
}
print("Inserted events this run: " + inserted);
check(
  events.countDocuments({}) === 13,
  "13 events retained without duplicate replay writes",
);

print("\nExample nested document (Extended JSON preserves BSON types):");
print(
  EJSON.stringify(events.findOne({ _id: "PCG-C001:2" }), null, 2, {
    relaxed: false,
  }),
);
print("\nRoom 302 event history:");
const roomHistory = events
  .find(
    { "snapshot.roomNumber": "302" },
    { _id: 1, eventType: 1, scenarioDate: 1 },
  )
  .sort({ scenarioDate: 1, _id: 1 })
  .toArray();
printjson(roomHistory);
check(
  roomHistory.length === 3,
  "room 302 has two confirmations and one cancellation",
);
const eventCounts = events
  .aggregate([
    { $group: { _id: "$eventType", count: { $sum: 1 } } },
    { $sort: { _id: 1 } },
  ])
  .toArray();
print("\nEvent counts:");
printjson(eventCounts);
check(
  JSON.stringify(eventCounts) ===
    JSON.stringify([
      { _id: "CANCELLED", count: 1 },
      { _id: "COMPLETED", count: 2 },
      { _id: "CONFIRMED", count: 10 },
    ]),
  "expected event-type totals",
);
const latestPipeline = [
  { $sort: { reservationRef: 1, sequence: 1 } },
  { $group: { _id: "$reservationRef", latest: { $last: "$$ROOT" } } },
];
const currentStates = events
  .aggregate([
    ...latestPipeline,
    { $group: { _id: "$latest.snapshot.status", count: { $sum: 1 } } },
    { $sort: { _id: 1 } },
  ])
  .toArray();
print(
  "\nLatest reservation states (avoid counting historical confirmations as active):",
);
printjson(currentStates);
check(
  JSON.stringify(currentStates) ===
    JSON.stringify([
      { _id: "CANCELLED", count: 1 },
      { _id: "COMPLETED", count: 2 },
      { _id: "CONFIRMED", count: 7 },
    ]),
  "latest states match P1 totals",
);
const valuation = events
  .aggregate([
    ...latestPipeline,
    { $match: { "latest.snapshot.status": { $ne: "CANCELLED" } } },
    {
      $group: {
        _id: null,
        reservations: { $sum: 1 },
        bookingValueNGN: {
          $sum: {
            $multiply: [
              "$latest.snapshot.agreedNightlyRate",
              {
                $divide: [
                  {
                    $subtract: [
                      "$latest.snapshot.departure",
                      "$latest.snapshot.arrival",
                    ],
                  },
                  86400000,
                ],
              },
            ],
          },
        },
      },
    },
  ])
  .toArray();
print("\nNon-cancelled full-stay booking value (all scenario dates):");
printjson(valuation);
check(
  valuation[0].reservations === 9 &&
    Number(valuation[0].bookingValueNGN.toString()) === 910000,
  "9 reservations total NGN 910000, excluding cancelled value",
);

function rejected(document, code, label) {
  let error;
  try {
    events.insertOne(document);
  } catch (caught) {
    error = caught;
  }
  check(error?.code === code, label + " (MongoDB code " + code + ")");
}
const example = documents[0];
const invalid = (label, changes) => ({
  ...example,
  _id: "INVALID-" + label,
  reservationRef: "PCG-INVALID-" + label,
  snapshot: { ...example.snapshot, ...changes },
});
rejected(example, 11000, "duplicate event ID rejected");
rejected(
  { ...example, _id: "DUPLICATE-SEQUENCE" },
  11000,
  "duplicate reservation sequence rejected",
);
rejected(
  invalid("DATE", { arrival: "2026-12-20" }),
  121,
  "string date rejected",
);
rejected(
  invalid("RATE", { agreedNightlyRate: NumberDecimal("-1.00") }),
  121,
  "negative price rejected",
);
rejected(
  invalid("PRECISION", { agreedNightlyRate: NumberDecimal("1.001") }),
  121,
  "fractional kobo rejected",
);
rejected(
  invalid("INTERVAL", { departure: day("2026-12-19") }),
  121,
  "reversed stay rejected",
);
rejected(
  invalid("PARTY", { partySize: NumberInt(0) }),
  121,
  "zero party size rejected",
);
rejected(
  invalid("STATUS", { status: "CANCELLED" }),
  121,
  "event and snapshot status mismatch rejected",
);
check(
  events.countDocuments({}) === 13,
  "validation tests left the fixture unchanged",
);
print("\nIndexes:");
printjson(events.getIndexes());
print("PASS: all MongoDB checks completed");
