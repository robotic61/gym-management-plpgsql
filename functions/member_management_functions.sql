-- Member Management Screen Functions

-- 1) List all members of a gym with status label
CREATE OR REPLACE FUNCTION fn_get_all_members(p_gym_id INT)
RETURNS TABLE (
    member_id      INT,
    full_name      TEXT,
    email          TEXT,
    phone          TEXT,
    plan           TEXT,
    expiry_date    DATE,
    status_label   TEXT
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
        m.membership_plan        AS plan,
        m.membership_end_date    AS expiry_date,
        CASE
            WHEN m.membership_end_date IS NULL THEN 'No Plan'
            WHEN m.membership_end_date < CURRENT_DATE
                THEN 'Expired'
            WHEN m.membership_end_date <= CURRENT_DATE + INTERVAL '7 days'
                THEN 'Expiring Soon'
            ELSE 'Active'
        END AS status_label
    FROM members m
    WHERE m.gym_id = p_gym_id
    ORDER BY m.full_name;
END;
$$;



-- 2) Details for one member (used when clicking Edit)
CREATE OR REPLACE FUNCTION fn_get_member_details(
    p_member_id INT,
    p_gym_id    INT
)
RETURNS TABLE (
    member_id       INT,
    full_name       TEXT,
    email           TEXT,
    phone           TEXT,
    total_bookings  INT,
    total_payments  NUMERIC(10,2),
    overdue         INT
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
        -- how many class bookings this member has ever made
        (SELECT COUNT(*)
         FROM bookings b
         WHERE b.member_id = m.member_id) AS total_bookings,
        (SELECT COALESCE(SUM(p.amount), 0)
         FROM payments p
         WHERE p.member_id = m.member_id
           AND p.payment_status = 'paid') AS total_payments,
        (SELECT COUNT(*)
         FROM payments p
         WHERE p.member_id = m.member_id
           AND p.payment_status = 'pending'
           AND p.due_date IS NOT NULL
           AND p.due_date < CURRENT_DATE) AS overdue
    FROM members m
    WHERE m.member_id = p_member_id
      AND m.gym_id    = p_gym_id;
END;
$$;



-- 3) Add new member
CREATE OR REPLACE FUNCTION fn_add_new_member(
    p_gym_id            INT,
    p_full_name         TEXT,
    p_email             TEXT,
    p_phone             TEXT,
    p_membership_plan   TEXT,
    p_start_date        DATE,
    p_end_date          DATE
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists  BOOLEAN;
    v_start   DATE;
BEGIN
    -- check duplicate email inside the same gym
    SELECT EXISTS(
        SELECT 1
        FROM members
        WHERE gym_id = p_gym_id
          AND email  = p_email
    ) INTO v_exists;

    IF v_exists THEN
        RETURN -1;
    END IF;

    v_start := COALESCE(p_start_date, CURRENT_DATE);

    INSERT INTO members (
        gym_id,
        full_name,
        email,
        phone,
        membership_plan,
        membership_start_date,
        membership_end_date,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_gym_id,
        p_full_name,
        p_email,
        p_phone,
        p_membership_plan,
        v_start,
        p_end_date,
        'active',
        NOW(),
        NOW()
    );

    RETURN 0;
END;
$$;



-- 4) Renew membership
CREATE OR REPLACE FUNCTION fn_renew_membership(
    p_member_id INT,
    p_gym_id    INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_plan        TEXT;
    v_current_end DATE;
    v_new_end     DATE;
BEGIN
    -- get current plan + end date
    SELECT membership_plan,
           COALESCE(membership_end_date, CURRENT_DATE)
    INTO v_plan, v_current_end
    FROM members
    WHERE member_id = p_member_id
      AND gym_id    = p_gym_id;

    IF NOT FOUND THEN
        RETURN -1;  -- member not found in this gym
    END IF;

    -- extend based on plan
    CASE UPPER(v_plan)
        WHEN 'MONTHLY' THEN
            v_new_end := (v_current_end + INTERVAL '1 month')::DATE;
        WHEN 'QUARTERLY' THEN
            v_new_end := (v_current_end + INTERVAL '3 months')::DATE;
        WHEN 'YEARLY' THEN
            v_new_end := (v_current_end + INTERVAL '12 months')::DATE;
        ELSE
            RETURN -1;  -- unsupported plan type
    END CASE;

    UPDATE members
    SET membership_end_date = v_new_end,
        status              = 'active',
        updated_at          = NOW()
    WHERE member_id = p_member_id
      AND gym_id    = p_gym_id;

    RETURN 0;
END;
$$;
