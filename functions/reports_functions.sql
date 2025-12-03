-- 1) Membership summary for a gym
CREATE OR REPLACE FUNCTION fn_get_membership_summary(p_gym_id INT)
RETURNS TABLE (
    total_members    INT,
    active_members   INT,
    new_this_month   INT,
    expired_members  INT,
    retention_rate   NUMERIC(5,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) AS total_members,
        COUNT(*) FILTER (
            WHERE status = 'active'
              AND membership_end_date >= CURRENT_DATE
        ) AS active_members,
        COUNT(*) FILTER (
            WHERE created_at >= date_trunc('month', CURRENT_DATE)
              AND created_at <  (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')
        ) AS new_this_month,
        COUNT(*) FILTER (
            WHERE membership_end_date IS NOT NULL
              AND membership_end_date < CURRENT_DATE
        ) AS expired_members,
        -- retention ≈ active / total * 100
        CASE
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(
                COUNT(*) FILTER (
                    WHERE status = 'active'
                      AND membership_end_date >= CURRENT_DATE
                )::NUMERIC * 100.0 / COUNT(*),
                1
            )
        END AS retention_rate
    FROM members
    WHERE gym_id = p_gym_id;
END;
$$;


-- 2) Class attendance report per class name
CREATE OR REPLACE FUNCTION fn_get_class_attendance_report(p_gym_id INT)
RETURNS TABLE (
    class_name          TEXT,
    total_sessions      INT,
    total_bookings      INT,
    avg_attendance      NUMERIC(10,2),
    capacity_utilization NUMERIC(5,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.class_name,
        COUNT(*) AS total_sessions,
        COUNT(b.booking_id) FILTER (
            WHERE b.booking_status <> 'cancelled'
        ) AS total_bookings,
        -- average attendance per session
        CASE
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(
                COUNT(b.booking_id) FILTER (
                    WHERE b.booking_status <> 'cancelled'
                )::NUMERIC / COUNT(*),
                2
            )
        END AS avg_attendance,
        -- how full the classes are on average (0–100%)
        CASE
            WHEN SUM(c.capacity) IS NULL OR SUM(c.capacity) = 0 THEN 0
            ELSE ROUND(
                COUNT(b.booking_id) FILTER (
                    WHERE b.booking_status <> 'cancelled'
                )::NUMERIC * 100.0 / SUM(c.capacity),
                1
            )
        END AS capacity_utilization
    FROM classes c
    LEFT JOIN bookings b
           ON b.class_id = c.class_id
          AND b.booking_status <> 'cancelled'
    WHERE c.gym_id = p_gym_id
    GROUP BY c.class_name
    ORDER BY c.class_name;
END;
$$;


-- 3) Revenue report for a gym
CREATE OR REPLACE FUNCTION fn_get_revenue_report(p_gym_id INT)
RETURNS TABLE (
    current_month_revenue NUMERIC(10,2),
    last_month_revenue    NUMERIC(10,2),
    pending_revenue       NUMERIC(10,2),
    overdue_amount        NUMERIC(10,2),
    payments_count        INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_curr_start  DATE := date_trunc('month', CURRENT_DATE)::DATE;
    v_next_start  DATE := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::DATE;
    v_last_start  DATE := (date_trunc('month', CURRENT_DATE) - INTERVAL '1 month')::DATE;
BEGIN
    RETURN QUERY
    SELECT
        -- paid this month
        COALESCE(SUM(
            CASE
                WHEN p.payment_status = 'paid'
                 AND p.payment_date >= v_curr_start
                 AND p.payment_date <  v_next_start
                THEN p.amount ELSE 0
            END
        ), 0)::NUMERIC(10,2) AS current_month_revenue,

        -- paid last month
        COALESCE(SUM(
            CASE
                WHEN p.payment_status = 'paid'
                 AND p.payment_date >= v_last_start
                 AND p.payment_date <  v_curr_start
                THEN p.amount ELSE 0
            END
        ), 0)::NUMERIC(10,2) AS last_month_revenue,

        -- pending for this month
        COALESCE(SUM(
            CASE
                WHEN p.payment_status = 'pending'
                 AND p.due_date >= v_curr_start
                 AND p.due_date <  v_next_start
                THEN p.amount ELSE 0
            END
        ), 0)::NUMERIC(10,2) AS pending_revenue,

        -- still pending but due before this month (overdue)
        COALESCE(SUM(
            CASE
                WHEN p.payment_status = 'pending'
                 AND p.due_date < v_curr_start
                THEN p.amount ELSE 0
            END
        ), 0)::NUMERIC(10,2) AS overdue_amount,

        -- how many payments rows belong to this month (paid + pending + overdue)
        COUNT(*) FILTER (
            WHERE p.due_date >= v_curr_start
              AND p.due_date <  v_next_start
        )  AS payments_count
    FROM payments p
    JOIN members m
      ON p.member_id = m.member_id
    WHERE m.gym_id = p_gym_id;
END;
$$;
