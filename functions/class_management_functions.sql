-- 1) Class schedule for a gym
CREATE OR REPLACE FUNCTION fn_get_class_schedule(p_gym_id INT)
RETURNS TABLE (
    class_id            INT,
    class_name          TEXT,
    class_date          DATE,
    start_time          TIME,
    capacity            INT,
    trainer_name        TEXT,
    booked_count        INT,
    availability_status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.class_id,
        c.class_name,
        c.class_date,
        c.start_time,
        c.capacity,
        COALESCE(s.full_name, 'Unassigned') AS trainer_name,
        COALESCE(COUNT(b.booking_id), 0)::INT AS booked_count,   -- << cast here
        CASE
            WHEN COALESCE(COUNT(b.booking_id), 0) >= c.capacity
                THEN 'Full'
            ELSE 'Available'
        END AS availability_status
    FROM classes c
    LEFT JOIN staff s
        ON c.trainer_id = s.staff_id
    LEFT JOIN bookings b
        ON b.class_id = c.class_id
       AND b.booking_status <> 'cancelled'
    WHERE c.gym_id = p_gym_id
    GROUP BY
        c.class_id,
        c.class_name,
        c.class_date,
        c.start_time,
        c.capacity,
        s.full_name
    ORDER BY c.class_date, c.start_time;
END;
$$;


-- 2) Bookings for a specific class
CREATE OR REPLACE FUNCTION fn_get_class_bookings(p_class_id INT)
RETURNS TABLE (
    booking_id     INT,
    member_id      INT,
    full_name      TEXT,
    email          TEXT,
    phone          TEXT,
    booking_status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.booking_id,
        m.member_id,
        m.full_name,
        m.email,
        m.phone,
        b.booking_status
    FROM bookings b
    JOIN members m
      ON b.member_id = m.member_id
    WHERE b.class_id = p_class_id
    ORDER BY m.full_name;
END;
$$;

-- 3) Create a new class
CREATE OR REPLACE FUNCTION fn_create_new_class(
    p_gym_id       INT,
    p_trainer_id   INT,
    p_class_name   TEXT,
    p_class_date   DATE,
    p_start_time   TIME,
    p_end_time     TIME,
    p_capacity     INT,
    p_description  TEXT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_trainer   BOOLEAN;
    v_has_overlap  BOOLEAN;
    v_capacity     INT;
BEGIN
    -- Validate trainer (must belong to this gym and be marked as trainer)
    IF p_trainer_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM staff
            WHERE staff_id = p_trainer_id
              AND gym_id   = p_gym_id
              AND is_trainer = TRUE
        ) INTO v_is_trainer;

        IF NOT v_is_trainer THEN
            RETURN -1;
        END IF;
    END IF;

    -- Check overlapping classes for the same trainer on the same date
    IF p_trainer_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM classes c
            WHERE c.trainer_id = p_trainer_id
              AND c.class_date = p_class_date
              AND c.status <> 'cancelled'
              AND (
                    p_start_time < COALESCE(c.end_time, p_end_time)
                AND c.start_time < COALESCE(p_end_time, c.end_time)
              )
        ) INTO v_has_overlap;

        IF v_has_overlap THEN
            RETURN -1;
        END IF;
    END IF;

    v_capacity := COALESCE(p_capacity, 20);

    INSERT INTO classes (
        gym_id,
        trainer_id,
        class_name,
        class_date,
        start_time,
        end_time,
        capacity,
        description,
        status,
        created_at
    ) VALUES (
        p_gym_id,
        p_trainer_id,
        p_class_name,
        p_class_date,
        p_start_time,
        p_end_time,
        v_capacity,
        p_description,
        'scheduled',
        NOW()
    );

    RETURN 0;
END;
$$;

-- 4) Book a class for a member
CREATE OR REPLACE FUNCTION fn_book_class_for_member(
    p_member_id INT,
    p_class_id  INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_capacity    INT;
    v_booked      INT;
    v_status      TEXT;
    v_already     BOOLEAN;
BEGIN
    -- Get class info
    SELECT
        c.capacity,
        COALESCE((
            SELECT COUNT(*)
            FROM bookings b
            WHERE b.class_id = c.class_id
              AND b.booking_status <> 'cancelled'
        ), 0) AS booked,
        c.status
    INTO
        v_capacity,
        v_booked,
        v_status
    FROM classes c
    WHERE c.class_id = p_class_id;

    IF NOT FOUND THEN
        RETURN -1;  -- class not found
    END IF;

    -- Class must be scheduled and not full
    IF v_status <> 'scheduled' OR v_booked >= v_capacity THEN
        RETURN -1;
    END IF;

    -- Member must not already be booked
    SELECT EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.class_id = p_class_id
          AND b.member_id = p_member_id
          AND b.booking_status <> 'cancelled'
    ) INTO v_already;

    IF v_already THEN
        RETURN -1;
    END IF;

    INSERT INTO bookings (
        member_id,
        class_id,
        booking_status,
        booking_date
    ) VALUES (
        p_member_id,
        p_class_id,
        'confirmed',
        NOW()
    );

    RETURN 0;
END;
$$;

-- 5) Update an existing class
CREATE OR REPLACE FUNCTION fn_update_class_details(
    p_class_id        INT,
    p_new_date        DATE,
    p_new_start_time  TIME,
    p_new_end_time    TIME,
    p_new_capacity    INT,
    p_new_trainer_id  INT,
    p_new_description TEXT,
    p_new_status      TEXT
)
    RETURNS INT
    LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE classes
    SET
        class_date   = p_new_date,
        start_time   = p_new_start_time,
        end_time     = p_new_end_time,
        capacity     = p_new_capacity,
        trainer_id   = p_new_trainer_id,
        description  = p_new_description,
        status       = p_new_status
    WHERE class_id = p_class_id;


    IF NOT FOUND THEN
        RETURN -1;  -- class not found
    END IF;

    RETURN 0;  -- success
END;
$$;

