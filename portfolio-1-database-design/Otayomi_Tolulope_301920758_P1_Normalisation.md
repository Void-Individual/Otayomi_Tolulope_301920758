# Portfolio 1 — From an unnormalised booking sheet to 3NF

**Tolulope Otayomi · 301920758 · Palm Court Guesthouse**

This explanation follows the functional dependencies of the agreed case. It does not treat the presence of an ID as proof of normalisation. Example values are fictional and match the P1 fixture `PCG-F001`.

## Unnormalised form

A receptionist's imagined booking sheet could contain one record with a repeating list of nights:

```text
Reference: PCG-F001
Guest: G003 / Synthetic Guest C
Room: 101 / capacity 2
Category: STD / Standard / current rate NGN 25,000
Stay: 2026-12-10 to 2026-12-12
Party: 2; status: CONFIRMED
Agreed nightly rate: NGN 25,000
Nights: [2026-12-10, 2026-12-11]
```

The `Nights` list is a repeating group in this proposed tabular representation. Guest, room and category details also repeat across bookings. Editing a current category price in every booking would risk rewriting historical agreements; keeping old names in some rows could make the catalogue inconsistent.

## First normal form

Flatten the repeating group into one row per reservation/night. Every cell is now a scalar; the natural key of this intermediate relation is `(reservation_ref, night_date)`.

| reservation_ref | night_date | guest_code | guest_name        | room_number | capacity | category_code | category_name | current_rate | agreed_rate |
| --------------- | ---------- | ---------- | ----------------- | ----------- | -------: | ------------- | ------------- | -----------: | ----------: |
| PCG-F001        | 2026-12-10 | G003       | Synthetic Guest C | 101         |        2 | STD           | Standard      |        25000 |       25000 |
| PCG-F001        | 2026-12-11 | G003       | Synthetic Guest C | 101         |        2 | STD           | Standard      |        25000 |       25000 |

Arrival, departure, party size and status would also repeat on both rows; they are omitted from this wide table only for readability. This representation satisfies 1NF but not 2NF: `reservation_ref` alone determines all booking-level facts. Those are partial dependencies on the composite key.

## Second normal form

Split the intermediate relation into:

```text
Booking2NF(reservation_ref PK, guest_code, guest_name, room_number,
           capacity, category_code, category_name, current_rate,
           arrival, departure, party_size, status, agreed_rate)
BookingNight(reservation_ref PK/FK, night_date PK)
```

`Booking2NF` has a single-attribute key, so there is no partial dependency on a proper subset of that key. `BookingNight` has no non-key attributes. This removes the repeated booking facts from individual nights, but `Booking2NF` still has transitive dependencies:

- `reservation_ref → guest_code → guest_name`.
- `reservation_ref → room_number → capacity, category_code`.
- `room_number → category_code → category_name, current_rate`.

Thus this stage satisfies 2NF but not 3NF. There is no claim that adding a surrogate key would remove those dependencies.

## Third normal form and the implemented model

Separate independent entities, leaving their keys in the referencing table:

| Relation        | Candidate keys                   | Relevant nontrivial functional dependencies                                                                                                      |
| --------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `guest`         | `guest_code`                     | `guest_code → display_name`. Names need not be unique.                                                                                           |
| `room_category` | `category_code`; `category_name` | Either candidate key determines the other and `current_nightly_rate`.                                                                            |
| `room`          | `room_number`                    | `room_number → category_code, capacity`. Capacity is room-specific, not assumed determined by category.                                          |
| `reservation`   | `reservation_ref`                | Reference determines guest, room, dates, party, state, agreed rate and scenario/actual audit fields. No guest or category names are stored here. |

Under these stated dependencies, each nontrivial determinant in the four business relations is a candidate key. The relations satisfy 3NF (and BCNF under these assumptions). These conclusions depend on the case's actual dependencies, not the small sample accidentally containing unique names or dates.

Each decomposition can be joined losslessly through the corresponding unique parent key; the referencing FK preserves the connection. Required parent facts are stored once. The identified dependencies are enforceable in their own relations through keys and constraints. Temporal overlap and state-transition rules are additional integrity rules, not functional dependencies solved by normalisation.

`agreed_nightly_rate` remains in `reservation`: it is a historical agreement determined by the booking, not the category's current price. After a rate change, bookings in the same category can have different agreed rates. Therefore `category_code → agreed_nightly_rate` is not a valid dependency and the snapshot does not create that transitive dependency.

The implemented design omits `BookingNight` because all nights form one continuous interval with the same agreed rate. Its rows can be derived from arrival/departure without losing an independent fact. Keeping an explicit night table would require an additional completeness rule to prevent missing nights. This omission is a representation choice after normalisation, not a claim that the intermediate `BookingNight` relation violated 3NF.

Booking value (`agreed_nightly_rate × nights`) and night count (`departure − arrival`) are also derived. Cancellation changes status, retaining the agreement. Completion retains historical occupancy. The technical `demo_clock` is a separate singleton configuration relation; its key determines its scenario date and it adds no redundant business attributes.

## Check against the implementation

The [ER diagram](Otayomi_Tolulope_301920758_P1_ERDiagram.svg) and [SQL schema](Otayomi_Tolulope_301920758_P1_Schema.sql) use exactly these relations, keys and required relationships. The [constraint evidence](Otayomi_Tolulope_301920758_P1_Results.txt) verifies preserved quotations after a category-rate change and that cancellation retains the booking record.

The case-specific decomposition was developed for this portfolio. PostgreSQL's [constraints documentation](https://www.postgresql.org/docs/17/ddl-constraints.html) supports the implementation of keys and references; the normalisation argument above follows the explicitly stated dependencies rather than copying the peer library design.
