# Portfolio 1 — Palm Court Guesthouse

**Tolulope Otayomi · 301920758**

Palm Court Guesthouse is a fictional single-property business in Lagos with 12 rooms in three categories: Standard, Deluxe and Family. It needs to find available rooms, accept full-stay reservations without double booking, retain booking history and report demand and booking value. The name, scale, policies and records are invented for this portfolio.

## Users, data and operations

Receptionists create single-room reservations and record permitted cancellations or completion. The manager reviews booked nights, booking value and cancellation history. A database maintainer manages fixtures and validation. These business roles do not imply that a staff authentication application has been built.

Stored business data consists of fictional guest codes and names; room categories and current rates; room numbers and capacities; and reservations containing guest/room references, stay dates, party size, status, the agreed nightly rate and audit information. A separate technical `demo_clock` controls the scenario date for repeatable exercises. No real guest contacts, identity documents or payment details are collected.

The system supports availability enquiries, immediate confirmed reservations, cancellation before arrival, completion on/after departure and historical reporting. A booking covers exactly one room and one lead guest. That guest may make multiple bookings. Party size includes everyone sharing the room.

## Business policies

1. Stable guest codes, room numbers and reservation references identify records uniquely. Each room belongs to exactly one category; required references must exist.
2. Arrival is included and departure is excluded. A 10–12 December stay occupies the nights of 10 and 11 December. The next guest can arrive on 12 December. Dates use the Africa/Lagos business calendar.
3. Party size must be a positive integer within room capacity. Rooms and their capacities are fixed for the demonstration.
4. Non-cancelled reservations cannot overlap in the same room. Completed stays retain their historical occupancy; cancellations release their nights while preserving the original record and price.
5. A new reservation is immediately confirmed and covers the entire interval in one atomic database operation. Availability displayed before that operation is advisory; the database exclusion constraint is the final check.
6. Allowed transitions are `CONFIRMED → CANCELLED` before arrival and `CONFIRMED → COMPLETED` on/after departure. Cancelled and completed states are terminal. Confirmed covers both future and ongoing stays until completion is explicitly recorded.
7. New operational bookings cannot arrive before the scenario business date. Only the fixture administrator can move that date. Actual execution timestamps are separate and are never backdated.
8. Prices are positive NGN values with at most two decimal places and a demonstration upper limit of NGN 99,999,999.99. All nights share the category rate captured at booking. Later rate changes affect new bookings only. The upper limit is an implementation bound, not a university requirement.
9. Booking value equals nights multiplied by agreed nightly rate. Reports of non-cancelled bookings exclude cancellations; cancellation reports retain their original value separately. Reporting a period must count only the nights within that period.

## Scope limits

There are no group-room bundles, room moves, stay extensions, temporary holds, waiting lists, overbooking, maintenance closures or multiple properties. Room, dates, party size and agreed price cannot be edited after creation. Cancellation followed by a new reservation is a separate operation and does not guarantee replacement availability.

Payments, refunds, taxes, discounts, currency conversion, physical check-in/out, housekeeping, a guest-facing application and external integrations are excluded. Booking value is not collected revenue. A future MongoDB exercise will use the same fictional identifiers for reservation-event snapshots; automatic SQL-to-MongoDB synchronisation is not implemented.

## Consistency across the portfolio

P1 implements the relational model and rule tests. P2 will query availability, demand, value and cancellations and measure one optimisation. P3 will demonstrate transactions and real competing reservation sessions. P4 will model reservation events as documents. P5 will discuss a proposed architecture that preserves SQL booking authority while examining replication, availability and consistency. The later activities are not claimed as complete.

The assessment permits a simulated organisation and lists hotel reservations among its examples. The specific guesthouse scope, data, code and business policies here were developed for this project. AI assistance and remaining student review are disclosed in the [root README](../Otayomi_Tolulope_301920758_README.md).
