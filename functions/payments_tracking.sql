-- 1) List all payments for a gym
CREATE OR REPLACE FUNCTION fn_get_all_payments(p_gym_id INT)
RETURNS TABLE (
    payment_id     INT,
    member_name    TEXT,
    amount         NUMERIC(10,2),
    due_date       DATE,
    payment_date   DATE,
    payment_status TEXT,
    days_overdue   INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.payment_id,
        m.full_name AS member_name,
        p.amount,
        p.due_date,
        p.payment_date,
        CASE
            WHEN p.payment_status = 'paid' THEN 'paid'
            WHEN p.payment_status = 'pending'
                 AND p.due_date < CURRENT_DATE THEN 'overdue'
            ELSE 'pending'
        END AS payment_status,
        CASE
            WHEN p.payment_status = 'pending' THEN
                GREATEST((CURRENT_DATE - p.due_date)::INT, 0)
            ELSE
                NULL
        END AS days_overdue
    FROM payments p
    JOIN members m
      ON p.member_id = m.member_id
    WHERE m.gym_id = p_gym_id
    ORDER BY p.due_date, m.full_name;
END;
$$;


-- 2) Record / mark a payment as paid
CREATE OR REPLACE FUNCTION fn_record_payment(
    p_payment_id   INT,
    p_payment_method TEXT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status TEXT;
BEGIN
    SELECT payment_status
    INTO v_status
    FROM payments
    WHERE payment_id = p_payment_id;

    IF NOT FOUND THEN
        RETURN -1;              
    END IF;

    IF v_status = 'paid' THEN
        RETURN -1;              
    END IF;

    UPDATE payments
    SET payment_status = 'paid',
        payment_date   = CURRENT_DATE,
        payment_method = p_payment_method
    WHERE payment_id = p_payment_id;

    RETURN 0;
END;
$$;


-- 3) Count overdue payments for a gym
CREATE OR REPLACE FUNCTION fn_get_overdue_payments(p_gym_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_overdue_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_overdue_count
    FROM payments p
    JOIN members m
      ON p.member_id = m.member_id
    WHERE m.gym_id = p_gym_id
      AND p.payment_status = 'pending'
      AND p.due_date < CURRENT_DATE;

    RETURN v_overdue_count;
END;
$$;


-- 4) Generate monthly payments for all active members
CREATE OR REPLACE FUNCTION fn_generate_monthly_payments(p_gym_id INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_next_month_first DATE;
    v_inserted         INT;
BEGIN
    -- First day of next month
    v_next_month_first :=
        (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::DATE;

    INSERT INTO payments (
        member_id,
        amount,
        due_date,
        payment_status,
        created_at
    )
    SELECT
        m.member_id,
        CASE UPPER(m.membership_plan)
            WHEN 'MONTHLY'   THEN 49.00
            WHEN 'QUARTERLY' THEN 135.00
            WHEN 'YEARLY'    THEN 400.00
            ELSE 49.00
        END AS amount,
        v_next_month_first AS due_date,
        'pending'          AS payment_status,
        NOW()              AS created_at
    FROM members m
    WHERE m.gym_id = p_gym_id
      AND m.status = 'active'
      AND m.membership_end_date >= CURRENT_DATE
      -- avoid duplicates for the same month
      AND NOT EXISTS (
          SELECT 1
          FROM payments p
          WHERE p.member_id = m.member_id
            AND date_trunc('month', p.due_date)
                = date_trunc('month', v_next_month_first)
      );

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;
