CREATE OR REPLACE FUNCTION fn_get_active_members(p_gym_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM members
    WHERE gym_id = p_gym_id
      AND status = 'active'
      AND membership_end_date >= CURRENT_DATE;

    RETURN v_count;
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_members_expiring_soon_count(p_gym_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM members
    WHERE gym_id = p_gym_id
      AND membership_end_date IS NOT NULL
      AND membership_end_date BETWEEN CURRENT_DATE
                                  AND (CURRENT_DATE + INTERVAL '7 days');

    RETURN v_count;
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_monthly_revenue(p_gym_id INT)
RETURNS TABLE(
    total_revenue NUMERIC(10,2),
    paid_count    INT,
    pending_count INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN p.payment_status = 'paid'
                          THEN p.amount ELSE 0 END), 0)::NUMERIC(10,2) AS total_revenue,
        COUNT(CASE WHEN p.payment_status = 'paid' THEN 1 END)         AS paid_count,
        COUNT(CASE WHEN p.payment_status = 'pending' THEN 1 END)      AS pending_count
    FROM payments p
    JOIN members m ON p.member_id = m.member_id
    WHERE m.gym_id = p_gym_id
      AND p.payment_date IS NOT NULL
      AND DATE_TRUNC('month', p.payment_date) = DATE_TRUNC('month', CURRENT_DATE);
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_today_classes(p_gym_id INT)
RETURNS TABLE(
    class_name   TEXT,
    start_time   TIME,
    trainer_name TEXT,
    capacity     INT,
    booked_count INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.class_name,
        c.start_time,
        s.full_name AS trainer_name,
        c.capacity,
        COALESCE(COUNT(b.booking_id), 0) AS booked_count
    FROM classes c
    LEFT JOIN staff s    ON c.trainer_id = s.staff_id
    LEFT JOIN bookings b ON b.class_id  = c.class_id
                         AND b.booking_status <> 'cancelled'
    WHERE c.gym_id    = p_gym_id
      AND c.class_date = CURRENT_DATE
    GROUP BY
        c.class_name,
        c.start_time,
        s.full_name,
        c.capacity
    ORDER BY c.start_time;
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_expiring_members_list(p_gym_id INT)
RETURNS TABLE(
    member_id           INT,
    full_name           TEXT,
    email               TEXT,
    phone               TEXT,
    membership_end_date DATE,
    days_remaining      INT,
    status_label        TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.member_id,
        m.full_name,
        m.email,
        m.phone,
        m.membership_end_date,
        (m.membership_end_date - CURRENT_DATE)::INT AS days_remaining,
        CASE
            WHEN m.membership_end_date < CURRENT_DATE
                THEN 'Expired'
            WHEN m.membership_end_date <= CURRENT_DATE + INTERVAL '7 days'
                THEN 'Expiring Soon'
            ELSE 'Active'
        END AS status_label
    FROM members m
    WHERE m.gym_id = p_gym_id
      AND m.membership_end_date IS NOT NULL
      -- show ones expiring within next 7 days or expired in last few days
      AND m.membership_end_date BETWEEN (CURRENT_DATE - INTERVAL '7 days')
                                   AND (CURRENT_DATE + INTERVAL '7 days')
    ORDER BY m.membership_end_date;
END;
$$;
