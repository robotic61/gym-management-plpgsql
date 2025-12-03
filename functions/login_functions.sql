-- fn_login.sql
-- Check admin login using email + password.
-- Returns:
--   0  = login successful
--  -1  = login failed (wrong email or password)

-- Note: requires extension pgcrypto for crypt() function:
--   CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION fn_login(
    p_email    TEXT,
    p_password TEXT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_admin_id       INT;
    v_password_hash  TEXT;
BEGIN
    -- Find admin with this email
    SELECT admin_id, password_hash
    INTO v_admin_id, v_password_hash
    FROM admins
    WHERE email = p_email;

    -- If no such email found → fail
    IF v_admin_id IS NULL THEN
        RETURN -1;
    END IF;

    -- Compare given password with stored hash
    IF v_password_hash = crypt(p_password, v_password_hash) THEN

        -- Update last login time on success
        UPDATE admins
        SET last_login_at = NOW()
        WHERE admin_id = v_admin_id;

        RETURN 0;   -- success
    ELSE
        RETURN -1;  -- wrong password
    END IF;
END;
$$;
