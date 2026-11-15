-- Palm Court Guesthouse | Tolulope Otayomi | 301920758
-- PostgreSQL 17. Fresh project database only; never drops existing objects.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;

DO $$
BEGIN
    IF current_database() NOT IN (
        'tolu_guesthouse_301920758', 'tolu_guesthouse_301920758_replay'
    ) THEN
        RAISE EXCEPTION 'Use an isolated Tolu guesthouse database';
    END IF;
END;
$$;

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA guesthouse;
REVOKE ALL ON SCHEMA guesthouse FROM PUBLIC;

CREATE DOMAIN guesthouse.ngn_amount AS numeric
    CONSTRAINT ngn_amount_valid CHECK (
        VALUE > 0 AND VALUE <= 99999999.99 AND VALUE = round(VALUE, 2)
    );

-- A technical fixture control, not an organisation entity or real system clock.
-- Only the database owner maintains it; the operator cannot change scenario time.
CREATE TABLE guesthouse.demo_clock (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    as_of_date date NOT NULL CHECK (isfinite(as_of_date))
);
INSERT INTO guesthouse.demo_clock VALUES (true, DATE '2026-12-01');

CREATE TABLE guesthouse.guest (
    guest_code text PRIMARY KEY,
    display_name text NOT NULL,
    CONSTRAINT guest_code_valid CHECK (guest_code ~ '^G[0-9]{3,}$'),
    CONSTRAINT guest_name_present CHECK (btrim(display_name) <> '')
);

CREATE TABLE guesthouse.room_category (
    category_code text PRIMARY KEY,
    category_name text NOT NULL UNIQUE,
    current_nightly_rate guesthouse.ngn_amount NOT NULL,
    CONSTRAINT category_code_valid CHECK (category_code ~ '^[A-Z]{3}$'),
    CONSTRAINT category_name_present CHECK (btrim(category_name) <> '')
);

CREATE TABLE guesthouse.room (
    room_number text PRIMARY KEY,
    category_code text NOT NULL REFERENCES guesthouse.room_category(category_code),
    capacity integer NOT NULL,
    CONSTRAINT room_number_valid CHECK (room_number ~ '^[0-9]{3}$'),
    CONSTRAINT room_capacity_positive CHECK (capacity > 0)
);

CREATE TABLE guesthouse.reservation (
    reservation_ref text PRIMARY KEY,
    guest_code text NOT NULL REFERENCES guesthouse.guest(guest_code),
    room_number text NOT NULL REFERENCES guesthouse.room(room_number),
    arrival date NOT NULL,
    departure date NOT NULL,
    party_size integer NOT NULL,
    status text NOT NULL DEFAULT 'CONFIRMED',
    agreed_nightly_rate guesthouse.ngn_amount NOT NULL,
    booked_on date NOT NULL,
    status_changed_on date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    status_changed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reservation_ref_valid CHECK (reservation_ref ~ '^PCG-[A-Z0-9-]+$'),
    CONSTRAINT reservation_dates_valid CHECK (
        isfinite(arrival) AND isfinite(departure) AND departure > arrival
    ),
    CONSTRAINT reservation_party_positive CHECK (party_size > 0),
    CONSTRAINT reservation_status_valid CHECK (
        status IN ('CONFIRMED', 'CANCELLED', 'COMPLETED')
    ),
    CONSTRAINT reservation_business_dates CHECK (
        booked_on <= arrival AND status_changed_on >= booked_on
    ),
    CONSTRAINT reservation_no_overlap EXCLUDE USING gist (
        room_number WITH =,
        daterange(arrival, departure, '[)') WITH &&
    ) WHERE (status <> 'CANCELLED')
);

CREATE FUNCTION guesthouse.business_date()
RETURNS date LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, guesthouse, pg_temp AS $$
DECLARE
    result date;
BEGIN
    SELECT as_of_date INTO STRICT result FROM guesthouse.demo_clock WHERE singleton;
    RETURN result;
END;
$$;

CREATE FUNCTION guesthouse.guard_room()
RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, guesthouse, pg_temp AS $$
BEGIN
    RAISE EXCEPTION USING ERRCODE = '23514',
        CONSTRAINT = 'room_fixed_inventory',
        MESSAGE = 'Room identity, category and capacity are fixed in this demonstration';
END;
$$;
CREATE TRIGGER room_fixed_inventory
    BEFORE UPDATE OR DELETE ON guesthouse.room
    FOR EACH ROW EXECUTE FUNCTION guesthouse.guard_room();

CREATE FUNCTION guesthouse.guard_reservation()
RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog, guesthouse, pg_temp AS $$
DECLARE
    today date := guesthouse.business_date();
    room_capacity integer;
    quoted_rate guesthouse.ngn_amount;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'reservation_history_retained', MESSAGE = 'Booking history is retained';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NOT isfinite(NEW.arrival) OR NOT isfinite(NEW.departure)
            OR NEW.departure <= NEW.arrival THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'reservation_dates_valid', MESSAGE = 'Invalid stay interval';
        END IF;
        IF NEW.arrival < today THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'reservation_not_in_past', MESSAGE = 'Arrival precedes scenario business date';
        END IF;
        IF NEW.status IS DISTINCT FROM 'CONFIRMED' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'reservation_initial_status', MESSAGE = 'New bookings must be confirmed';
        END IF;
        SELECT r.capacity, c.current_nightly_rate INTO room_capacity, quoted_rate
        FROM guesthouse.room AS r
        JOIN guesthouse.room_category AS c USING (category_code)
        WHERE r.room_number = NEW.room_number;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '23503',
                CONSTRAINT = 'reservation_room_number_fkey', MESSAGE = 'Room does not exist';
        END IF;
        IF NEW.party_size > room_capacity THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'reservation_capacity', MESSAGE = 'Party exceeds room capacity';
        END IF;
        -- Snapshot once for the entire stay; later category-rate changes do not alter it.
        NEW.agreed_nightly_rate := quoted_rate;
        NEW.booked_on := today;
        NEW.status_changed_on := today;
        NEW.created_at := clock_timestamp();
        NEW.status_changed_at := NEW.created_at;
        RETURN NEW;
    END IF;

    IF ROW(NEW.reservation_ref, NEW.guest_code, NEW.room_number, NEW.arrival,
        NEW.departure, NEW.party_size, NEW.agreed_nightly_rate, NEW.booked_on,
        NEW.created_at, NEW.status_changed_on, NEW.status_changed_at)
        IS DISTINCT FROM
        ROW(OLD.reservation_ref, OLD.guest_code, OLD.room_number, OLD.arrival,
        OLD.departure, OLD.party_size, OLD.agreed_nightly_rate, OLD.booked_on,
        OLD.created_at, OLD.status_changed_on, OLD.status_changed_at) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'reservation_terms_immutable', MESSAGE = 'Only an allowed status change is supported';
    END IF;
    IF OLD.status <> 'CONFIRMED' OR NEW.status IS NULL
        OR NEW.status NOT IN ('CANCELLED', 'COMPLETED') THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'reservation_status_transition', MESSAGE = 'Invalid status transition';
    END IF;
    IF today < OLD.booked_on
        OR (NEW.status = 'CANCELLED' AND today >= OLD.arrival)
        OR (NEW.status = 'COMPLETED' AND today < OLD.departure) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            CONSTRAINT = 'reservation_transition_date', MESSAGE = 'Status change is not allowed on this business date';
    END IF;
    NEW.status_changed_on := today;
    NEW.status_changed_at := clock_timestamp();
    RETURN NEW;
END;
$$;
CREATE TRIGGER reservation_guard
    BEFORE INSERT OR UPDATE OR DELETE ON guesthouse.reservation
    FOR EACH ROW EXECUTE FUNCTION guesthouse.guard_reservation();

CREATE FUNCTION guesthouse.reserve_room(
    p_reference text, p_guest text, p_room text,
    p_arrival date, p_departure date, p_party integer
)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, guesthouse, pg_temp AS $$
BEGIN
    INSERT INTO guesthouse.reservation (
        reservation_ref, guest_code, room_number, arrival, departure, party_size
    ) VALUES (p_reference, p_guest, p_room, p_arrival, p_departure, p_party);
    RETURN p_reference;
END;
$$;

CREATE FUNCTION guesthouse.change_status(p_reference text, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, guesthouse, pg_temp AS $$
BEGIN
    UPDATE guesthouse.reservation SET status = p_status WHERE reservation_ref = p_reference;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Reservation does not exist';
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'tolu_guesthouse_operator') THEN
        CREATE ROLE tolu_guesthouse_operator NOLOGIN;
    END IF;
END;
$$;
REVOKE ALL ON ALL TABLES IN SCHEMA guesthouse FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA guesthouse FROM PUBLIC;
GRANT USAGE ON SCHEMA guesthouse TO tolu_guesthouse_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA guesthouse TO tolu_guesthouse_operator;
GRANT EXECUTE ON FUNCTION guesthouse.business_date() TO tolu_guesthouse_operator;
GRANT EXECUTE ON FUNCTION guesthouse.reserve_room(text, text, text, date, date, integer)
    TO tolu_guesthouse_operator;
GRANT EXECUTE ON FUNCTION guesthouse.change_status(text, text) TO tolu_guesthouse_operator;
COMMIT;
\echo Schema created successfully. No seed data loaded yet.
