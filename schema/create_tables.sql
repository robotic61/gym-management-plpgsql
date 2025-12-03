-- Gym Management Database Schema 

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS classes CASCADE;
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS admins CASCADE;
DROP TABLE IF EXISTS gyms CASCADE;

-- TABLE: gyms
CREATE TABLE gyms (
    gym_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- TABLE: admins
CREATE TABLE admins (
    admin_id SERIAL PRIMARY KEY,
    gym_id INT NOT NULL REFERENCES gyms(gym_id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT NOW(),
    last_login_at TIMESTAMP
);

-- TABLE: staff (trainers + employees)
CREATE TABLE staff (
    staff_id SERIAL PRIMARY KEY,
    gym_id INT NOT NULL REFERENCES gyms(gym_id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    role TEXT DEFAULT 'staff',
    is_trainer BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- TABLE: members
CREATE TABLE members (
    member_id SERIAL PRIMARY KEY,
    gym_id INT NOT NULL REFERENCES gyms(gym_id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    membership_plan TEXT,
    membership_start_date DATE,
    membership_end_date DATE,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast “expiring membership” queries
CREATE INDEX idx_members_membership_end
    ON members (membership_end_date);

-- TABLE: classes
CREATE TABLE classes (
    class_id SERIAL PRIMARY KEY,
    gym_id INT NOT NULL REFERENCES gyms(gym_id) ON DELETE CASCADE,
    trainer_id INT REFERENCES staff(staff_id) ON DELETE SET NULL,
    class_name TEXT NOT NULL,
    class_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME,
    capacity INT DEFAULT 20,
    description TEXT,
    status TEXT DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Trainer must be someone marked as a trainer
ALTER TABLE classes
ADD CONSTRAINT trainer_must_be_trainer
CHECK (
    trainer_id IS NULL OR 
    trainer_id IN (SELECT staff_id FROM staff WHERE is_trainer = TRUE)
);

-- TABLE: bookings 
CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    class_id INT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
    booking_status TEXT DEFAULT 'booked',
    booking_date TIMESTAMP DEFAULT NOW(),
    UNIQUE(member_id, class_id) -- Prevent duplicate booking
);

-- TABLE: payments
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,
    due_date DATE,
    payment_date DATE,
    payment_status TEXT DEFAULT 'pending',
    payment_method TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for financial reporting
CREATE INDEX idx_payments_status
ON payments(payment_status);
