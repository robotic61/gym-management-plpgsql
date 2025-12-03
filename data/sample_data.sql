-- SAMPLE DATA FOR GYM MANAGEMENT SYSTEM
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Clear previous data (if any)
TRUNCATE bookings, payments, classes, members, staff, admins, gyms
RESTART IDENTITY CASCADE;


INSERT INTO gyms (name, address, phone)
VALUES
('FitHub Central',   '123 Main Street',          '000-000-0001'),
('FitHub West',      '45 Sunset Road',           '000-000-0002'),
('FitHub East',      '88 River Avenue',          '000-000-0003'),
('FitHub North',     '12 Mountain View',         '000-000-0004'),
('FitHub South',     '67 Lakeside Drive',        '000-000-0005'),
('FitHub Airport',   '99 Skyway Plaza',          '000-000-0006'),
('FitHub City Mall', '3rd Floor, City Mall',     '000-000-0007'),
('FitHub Park',      '5 Green Park Road',        '000-000-0008'),
('FitHub Office',    'Tower B, Business Center', '000-000-0009'),
('FitHub Studio',    '21 Fitness Street',        '000-000-0010');


INSERT INTO admins (gym_id, full_name, email, password_hash)
VALUES
(1, 'Alice Tan',     'admin1@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Brian Wong',    'admin2@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Carol Smith',   'admin3@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'David Lee',     'admin4@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Emily Chen',    'admin5@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Frank Miller',  'admin6@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Grace Kim',     'admin7@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Henry Wilson',  'admin8@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Ivy Johnson',   'admin9@fitlife.com',  crypt('admin123', gen_salt('bf'))),
(1, 'Jack Thompson', 'admin10@fitlife.com', crypt('admin123', gen_salt('bf')));


INSERT INTO staff (gym_id, full_name, email, phone, is_trainer)
VALUES
(1, 'Lisa Anderson',  'lisa@fitlife.com',   '555-1001', TRUE),
(1, 'Mark Wilson',    'mark@fitlife.com',   '555-1002', TRUE),
(1, 'Tom Rodriguez',  'tom@fitlife.com',    '555-1003', TRUE),
(1, 'Sarah Lee',      'sarah@fitlife.com',  '555-1004', TRUE),
(1, 'Kevin Brown',    'kevin@fitlife.com',  '555-1005', TRUE),
(1, 'Rachel Green',   'rachel@fitlife.com', '555-1006', TRUE),
(1, 'John Carter',    'john@fitlife.com',   '555-1007', FALSE),
(1, 'Olivia Park',    'olivia@fitlife.com', '555-1008', FALSE),
(1, 'Peter Young',    'peter@fitlife.com',  '555-1009', FALSE),
(1, 'Nancy White',    'nancy@fitlife.com',  '555-1010', FALSE);


INSERT INTO members (
    gym_id,
    full_name,
    email,
    phone,
    membership_plan,
    status,
    membership_start_date,
    membership_end_date
)
VALUES
-- Active, end in future
(1, 'John Smith',    'member1@example.com',  '555-2001', 'MONTHLY',   'active',
    CURRENT_DATE - INTERVAL '20 days',
    CURRENT_DATE + INTERVAL '10 days'),
(1, 'Sarah Johnson', 'member2@example.com',  '555-2002', 'MONTHLY',   'active',
    CURRENT_DATE - INTERVAL '5 days',
    CURRENT_DATE + INTERVAL '25 days'),
(1, 'Mike Chen',     'member3@example.com',  '555-2003', 'QUARTERLY', 'active',
    CURRENT_DATE - INTERVAL '40 days',
    CURRENT_DATE + INTERVAL '60 days'),
-- Expired recently
(1, 'Emma Davis',    'member4@example.com',  '555-2004', 'MONTHLY',   'active',
    CURRENT_DATE - INTERVAL '40 days',
    CURRENT_DATE - INTERVAL '2 days'),
(1, 'Adam Lee',      'member5@example.com',  '555-2005', 'YEARLY',    'active',
    CURRENT_DATE - INTERVAL '100 days',
    CURRENT_DATE + INTERVAL '250 days'),
-- Expiring soon (within 7 days)
(1, 'Linda Brown',   'member6@example.com',  '555-2006', 'MONTHLY',   'active',
    CURRENT_DATE - INTERVAL '25 days',
    CURRENT_DATE + INTERVAL '3 days'),
(1, 'Robert King',   'member7@example.com',  '555-2007', 'MONTHLY',   'active',
    CURRENT_DATE - INTERVAL '27 days',
    CURRENT_DATE + INTERVAL '1 days'),
-- Already expired longer ago
(1, 'Sophia Turner', 'member8@example.com',  '555-2008', 'QUARTERLY', 'active',
    CURRENT_DATE - INTERVAL '120 days',
    CURRENT_DATE - INTERVAL '10 days'),
-- No current plan (null end date)
(1, 'Daniel Harris', 'member9@example.com',  '555-2009', 'MONTHLY',   'inactive',
    CURRENT_DATE - INTERVAL '200 days',
    NULL),
(1, 'Olivia Martin', 'member10@example.com', '555-2010', 'YEARLY',    'active',
    CURRENT_DATE - INTERVAL '10 days',
    CURRENT_DATE + INTERVAL '355 days');


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
)
VALUES
-- Today classes
(1, 1, 'Morning Yoga',     CURRENT_DATE,                 '07:00', '08:00', 15,
    'Relaxing morning yoga.', 'scheduled', NOW()),
(1, 2, 'HIIT Training',    CURRENT_DATE,                 '18:00', '19:00', 20,
    'High intensity HIIT.',   'scheduled', NOW()),
(1, 3, 'Pilates',          CURRENT_DATE,                 '09:00', '10:00', 12,
    'Core pilates class.',    'scheduled', NOW()),
(1, 4, 'Boxing Basics',    CURRENT_DATE,                 '17:00', '18:00', 10,
    'Beginner boxing.',       'scheduled', NOW()),
-- Future classes
(1, 5, 'Zumba Dance',      CURRENT_DATE + INTERVAL '1 day', '19:00', '20:00', 20,
    'Energetic dance workout.', 'scheduled', NOW()),
(1, 6, 'Strength Training',CURRENT_DATE + INTERVAL '2 days','18:00','19:00', 18,
    'Full body strength.',      'scheduled', NOW()),
-- Past classes
(1, 1, 'Sunrise Yoga',     CURRENT_DATE - INTERVAL '1 day', '06:30', '07:30', 15,
    'Early morning yoga.', 'completed', NOW()),
(1, 2, 'Cardio Blast',     CURRENT_DATE - INTERVAL '2 days','17:00','18:00', 20,
    'Cardio focused.',     'completed', NOW()),
(1, 3, 'Pilates Basics',   CURRENT_DATE - INTERVAL '3 days','09:00','10:00', 12,
    'Intro pilates.',      'completed', NOW()),
(1, 4, 'Kickboxing',       CURRENT_DATE - INTERVAL '4 days','18:00','19:00', 16,
    'Kickboxing workout.', 'completed', NOW());


INSERT INTO bookings (member_id, class_id, booking_status, booking_date)
VALUES
(1,  1, 'confirmed', NOW() - INTERVAL '1 day'),
(2,  1, 'confirmed', NOW() - INTERVAL '1 day'),
(3,  2, 'confirmed', NOW() - INTERVAL '1 day'),
(4,  2, 'confirmed', NOW() - INTERVAL '1 day'),
(5,  3, 'confirmed', NOW() - INTERVAL '1 day'),
(6,  3, 'confirmed', NOW() - INTERVAL '1 day'),
(7,  4, 'confirmed', NOW() - INTERVAL '2 days'),
(8,  4, 'cancelled', NOW() - INTERVAL '2 days'),
(9,  5, 'confirmed', NOW()),
(10, 6, 'confirmed', NOW());


INSERT INTO payments (
    member_id,
    amount,
    due_date,
    payment_date,
    payment_status,
    payment_method,
    created_at
)
VALUES
-- Paid this month
(1,  49.00,
    date_trunc('month', CURRENT_DATE)::DATE + 0,
    date_trunc('month', CURRENT_DATE)::DATE + 1,
    'paid', 'card', NOW()),
(2,  49.00,
    date_trunc('month', CURRENT_DATE)::DATE + 5,
    date_trunc('month', CURRENT_DATE)::DATE + 5,
    'paid', 'cash', NOW()),
(3, 135.00,
    date_trunc('month', CURRENT_DATE)::DATE + 10,
    date_trunc('month', CURRENT_DATE)::DATE + 9,
    'paid', 'transfer', NOW()),
-- Paid last month
(4,  49.00,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '15 days')::DATE,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '10 days')::DATE,
    'paid', 'card', NOW()),
(5, 400.00,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '20 days')::DATE,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '18 days')::DATE,
    'paid', 'card', NOW()),
-- Pending this month (not overdue yet)
(6,  49.00,
    date_trunc('month', CURRENT_DATE)::DATE + 15,
    NULL,
    'pending', NULL, NOW()),
(7,  49.00,
    date_trunc('month', CURRENT_DATE)::DATE + 18,
    NULL,
    'pending', NULL, NOW()),
-- Overdue (pending, due before this month)
(8,  49.00,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '5 days')::DATE,
    NULL,
    'pending', NULL, NOW()),
(9, 135.00,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '20 days')::DATE,
    NULL,
    'pending', NULL, NOW()),
(10, 49.00,
    (date_trunc('month', CURRENT_DATE) - INTERVAL '40 days')::DATE,
    NULL,
    'pending', NULL, NOW());
