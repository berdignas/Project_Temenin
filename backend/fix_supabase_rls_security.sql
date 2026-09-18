-- ==============================================================================
-- TEMENIN AJAA - SUPABASE ROW LEVEL SECURITY (RLS) HARDENING MIGRATION
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================
-- Memperbaiki celah keamanan kebocoran data sensitif (UU PDP No. 27/2022)
-- Menjamin:
-- 1. Tabel users tidak dapat di-dump oleh pemegang ANON_KEY (password, no hp, email, saldo aman).
-- 2. Tabel bookings hanya dapat dibaca/diedit oleh pemilik pesanan dan driver yang ditugaskan.
-- 3. Tabel booking_messages (chat) terisolasi hanya untuk penumpang dan driver terkait.
-- 4. Admin Dashboard (Backend Express service_role & Supabase Admin) tetap 100% BISA BACA & EDIT.
-- ==============================================================================

-- 0. HELPER FUNCTION: Periksa Role Admin
-- Mengembalikan true jika pemanggil adalah backend service_role atau user dengan role admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        -- Bypass otomatis untuk backend service_role key
        (auth.jwt() ->> 'role') = 'service_role'
        -- Atau jika user authenticated terdaftar dengan role admin di database
        OR EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ==============================================================================
-- 1. TABEL USERS (PENGGUNA & SALDO)
-- ==============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama yang bocor (USING true)
DROP POLICY IF EXISTS "Users Read Public Profile" ON public.users;
DROP POLICY IF EXISTS "Users Update Self" ON public.users;
DROP POLICY IF EXISTS "Users Read Self Or Admin" ON public.users;
DROP POLICY IF EXISTS "Users Update Self Or Admin" ON public.users;
DROP POLICY IF EXISTS "Users Insert Self" ON public.users;
DROP POLICY IF EXISTS "Users Delete Admin Only" ON public.users;

-- SELECT: Pengguna HANYA dapat membaca profil lengkap miliknya sendiri, atau Admin
CREATE POLICY "Users Read Self Or Admin" ON public.users
FOR SELECT
TO authenticated
USING (
    auth.uid() = id
    OR public.is_admin()
);

-- UPDATE: Pengguna HANYA dapat mengubah data dirinya sendiri, atau Admin
CREATE POLICY "Users Update Self Or Admin" ON public.users
FOR UPDATE
TO authenticated
USING (
    auth.uid() = id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = id
    OR public.is_admin()
);

-- INSERT: Registrasi akun baru milik sendiri, atau Admin
CREATE POLICY "Users Insert Self" ON public.users
FOR INSERT
TO authenticated, anon
WITH CHECK (
    auth.uid() = id
    OR auth.uid() IS NULL
    OR public.is_admin()
);

-- Anti Privilege-Escalation: Mencegah user mengubah role, balance, points langsung via Supabase REST
CREATE OR REPLACE FUNCTION public.protect_user_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT public.is_admin() THEN
        NEW.role := OLD.role;
        NEW.balance := OLD.balance;
        NEW.points := OLD.points;
        NEW.is_verified := OLD.is_verified;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_user_fields ON public.users;
CREATE TRIGGER trg_protect_user_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_fields();

-- View Publik Aman untuk Kebutuhan Menampilkan Nama / Avatar Tanpa Membocorkan Hash Password & Saldo
CREATE OR REPLACE VIEW public.public_user_profiles AS
SELECT 
    id,
    full_name,
    avatar_url,
    gender,
    role,
    is_verified,
    created_at
FROM public.users;

GRANT SELECT ON public.public_user_profiles TO anon, authenticated;

-- ==============================================================================
-- 2. TABEL DRIVERS (MITRA DRIVER)
-- ==============================================================================
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers Read Public" ON public.drivers;
DROP POLICY IF EXISTS "Drivers Read Approved Or Self Or Admin" ON public.drivers;
DROP POLICY IF EXISTS "Drivers Update Self Or Admin" ON public.drivers;
DROP POLICY IF EXISTS "Drivers Insert Self Or Admin" ON public.drivers;

-- SELECT: Driver approved dapat dilihat untuk kebutuhan matchmaking/pesan, atau data diri sendiri, atau Admin
CREATE POLICY "Drivers Read Approved Or Self Or Admin" ON public.drivers
FOR SELECT
USING (
    status = 'approved'
    OR auth.uid() = user_id
    OR public.is_admin()
);

-- UPDATE: Driver hanya bisa memperbarui data miliknya (lokasi, online status), atau Admin
CREATE POLICY "Drivers Update Self Or Admin" ON public.drivers
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- INSERT: Registrasi driver untuk akun sendiri, atau Admin
CREATE POLICY "Drivers Insert Self Or Admin" ON public.drivers
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- Mencegah driver mengubah status verifikasi sendiri (pending -> approved) atau memalsukan rating
CREATE OR REPLACE FUNCTION public.protect_driver_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT public.is_admin() THEN
        NEW.status := OLD.status;
        NEW.rating := OLD.rating;
        NEW.total_rides := OLD.total_rides;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_driver_fields ON public.drivers;
CREATE TRIGGER trg_protect_driver_fields
BEFORE UPDATE ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.protect_driver_fields();

-- ==============================================================================
-- 3. TABEL BOOKINGS (PESANAN PERJALANAN)
-- ==============================================================================
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama yang bocor
DROP POLICY IF EXISTS "Bookings Select Policy" ON public.bookings;
DROP POLICY IF EXISTS "Bookings Insert Authenticated" ON public.bookings;
DROP POLICY IF EXISTS "Bookings Update Authenticated" ON public.bookings;
DROP POLICY IF EXISTS "Bookings Select Authorized" ON public.bookings;
DROP POLICY IF EXISTS "Bookings Insert Authorized" ON public.bookings;
DROP POLICY IF EXISTS "Bookings Update Authorized" ON public.bookings;

-- SELECT:
-- 1. Penumpang yang memesan (user_id)
-- 2. Driver yang ditugaskan (driver_id)
-- 3. Driver terverifikasi yang mencari pesanan broadcast (status pending, belum ada driver)
-- 4. Admin
CREATE POLICY "Bookings Select Authorized" ON public.bookings
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        status = 'pending' 
        AND driver_id IS NULL 
        AND EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
);

-- INSERT: Penumpang hanya bisa membuat pesanan atas namanya sendiri, atau Admin
CREATE POLICY "Bookings Insert Authorized" ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- UPDATE: Pemilik pesanan, driver pesanan, driver pengambil open offer, atau Admin
CREATE POLICY "Bookings Update Authorized" ON public.bookings
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        status = 'pending' 
        AND driver_id IS NULL 
        AND EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = bookings.driver_id)
    OR (
        EXISTS (SELECT 1 FROM public.drivers WHERE user_id = auth.uid() AND status = 'approved')
    )
    OR public.is_admin()
);

-- ==============================================================================
-- 4. TABEL BOOKING_MESSAGES (CHAT LIVE STREAMING)
-- ==============================================================================
ALTER TABLE public.booking_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Booking Messages Read Policy" ON public.booking_messages;
DROP POLICY IF EXISTS "Booking Messages Insert Policy" ON public.booking_messages;
DROP POLICY IF EXISTS "Booking Messages Select Authorized" ON public.booking_messages;
DROP POLICY IF EXISTS "Booking Messages Insert Authorized" ON public.booking_messages;

-- SELECT: HANYA penumpang dan pengemudi dari pesanan terkait yang dapat membaca riwayat obrolan
CREATE POLICY "Booking Messages Select Authorized" ON public.booking_messages
FOR SELECT
TO authenticated
USING (
    auth.uid() = sender_id
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_messages.booking_id
        AND (
            b.user_id = auth.uid()
            OR b.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
        )
    )
    OR public.is_admin()
);

-- INSERT: Pengirim harus merupakan pihak yang sah dalam pesanan tersebut
CREATE POLICY "Booking Messages Insert Authorized" ON public.booking_messages
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = sender_id
    AND (
        EXISTS (
            SELECT 1 FROM public.bookings b
            WHERE b.id = booking_messages.booking_id
            AND (
                b.user_id = auth.uid()
                OR b.driver_id IN (SELECT d.id FROM public.drivers d WHERE d.user_id = auth.uid())
            )
        )
        OR public.is_admin()
    )
);

-- ==============================================================================
-- 5. TABEL BOOKING_NEGOTIATIONS (NEGOSIASI TARIF)
-- ==============================================================================
ALTER TABLE public.booking_negotiations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Negotiations Select Policy" ON public.booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Insert Policy" ON public.booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Update Policy" ON public.booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Select Authorized" ON public.booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Insert Authorized" ON public.booking_negotiations;
DROP POLICY IF EXISTS "Negotiations Update Authorized" ON public.booking_negotiations;

CREATE POLICY "Negotiations Select Authorized" ON public.booking_negotiations
FOR SELECT
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_negotiations.booking_id
        AND b.user_id = auth.uid()
    )
    OR public.is_admin()
);

CREATE POLICY "Negotiations Insert Authorized" ON public.booking_negotiations
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Negotiations Update Authorized" ON public.booking_negotiations
FOR UPDATE
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = booking_negotiations.driver_id)
    OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = booking_negotiations.booking_id
        AND b.user_id = auth.uid()
    )
    OR public.is_admin()
);

-- ==============================================================================
-- 6. TABEL NOTIFICATIONS (NOTIFIKASI PENGGUNA)
-- ==============================================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Notifications Select Policy" ON public.notifications;
DROP POLICY IF EXISTS "Notifications Update Policy" ON public.notifications;
DROP POLICY IF EXISTS "Notifications Select Owner" ON public.notifications;
DROP POLICY IF EXISTS "Notifications Update Owner" ON public.notifications;

CREATE POLICY "Notifications Select Owner" ON public.notifications
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Notifications Update Owner" ON public.notifications
FOR UPDATE
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- ==============================================================================
-- 7. TABEL FINANSIAL (WALLET_TRANSACTIONS, DRIVER_WITHDRAWALS, USER_PAYMENT_METHODS)
-- ==============================================================================
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

-- Wallet Transactions: Read hanya untuk pemilik / admin, Modifikasi dilarang untuk user biasa
DROP POLICY IF EXISTS "Wallet Transactions Select Owner" ON public.wallet_transactions;
DROP POLICY IF EXISTS "Wallet Transactions Admin Only" ON public.wallet_transactions;

CREATE POLICY "Wallet Transactions Select Owner" ON public.wallet_transactions
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
);

CREATE POLICY "Wallet Transactions Admin Only" ON public.wallet_transactions
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Driver Withdrawals: Driver hanya bisa melihat dan membuat pengajuan untuk dirinya
DROP POLICY IF EXISTS "Driver Withdrawals Select Owner" ON public.driver_withdrawals;
DROP POLICY IF EXISTS "Driver Withdrawals Insert Owner" ON public.driver_withdrawals;
DROP POLICY IF EXISTS "Driver Withdrawals Update Admin" ON public.driver_withdrawals;

CREATE POLICY "Driver Withdrawals Select Owner" ON public.driver_withdrawals
FOR SELECT
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_withdrawals.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Driver Withdrawals Insert Owner" ON public.driver_withdrawals
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_withdrawals.driver_id)
    OR public.is_admin()
);

CREATE POLICY "Driver Withdrawals Update Admin" ON public.driver_withdrawals
FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- User Payment Methods: Hanya pemilik yang berhak mengelola
DROP POLICY IF EXISTS "Payment Methods Owner Policy" ON public.user_payment_methods;
CREATE POLICY "Payment Methods Owner Policy" ON public.user_payment_methods
FOR ALL
TO authenticated
USING (
    auth.uid() = user_id
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

-- OTP Codes: Ditutup total untuk akses publik/user biasa (Hanya via backend service_role)
DROP POLICY IF EXISTS "OTP Codes Admin Only" ON public.otp_codes;
CREATE POLICY "OTP Codes Admin Only" ON public.otp_codes
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==============================================================================
-- 8. TABEL PROMO & EVENT
-- ==============================================================================
ALTER TABLE public.app_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_promos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Events Read Public" ON public.app_events;
DROP POLICY IF EXISTS "Events Read Active Or Admin" ON public.app_events;
DROP POLICY IF EXISTS "Events Modify Admin Only" ON public.app_events;

CREATE POLICY "Events Read Active Or Admin" ON public.app_events
FOR SELECT
USING (
    is_active = true
    OR public.is_admin()
);

CREATE POLICY "Events Modify Admin Only" ON public.app_events
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Promos Read Public" ON public.app_promos;
DROP POLICY IF EXISTS "Promos Read Active Or Admin" ON public.app_promos;
DROP POLICY IF EXISTS "Promos Modify Admin Only" ON public.app_promos;

CREATE POLICY "Promos Read Active Or Admin" ON public.app_promos
FOR SELECT
USING (
    is_active = true
    OR public.is_admin()
);

CREATE POLICY "Promos Modify Admin Only" ON public.app_promos
FOR ALL
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ==============================================================================
-- 9. TABEL REVIEWS & DRIVER SCHEDULES
-- ==============================================================================
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reviews Read Public" ON public.reviews;
DROP POLICY IF EXISTS "Reviews Insert Authenticated" ON public.reviews;
DROP POLICY IF EXISTS "Reviews Insert Owner" ON public.reviews;

CREATE POLICY "Reviews Read Public" ON public.reviews
FOR SELECT
USING (true);

CREATE POLICY "Reviews Insert Owner" ON public.reviews
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    OR public.is_admin()
);

DROP POLICY IF EXISTS "Driver Schedules Select" ON public.driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Select Public" ON driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Modify Authorized" ON driver_schedules;

CREATE POLICY "Driver Schedules Select Public" ON public.driver_schedules
FOR SELECT
USING (true);

CREATE POLICY "Driver Schedules Modify Authorized" ON public.driver_schedules
FOR ALL
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR public.is_admin()
)
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR public.is_admin()
);

-- ==============================================================================
-- SELESAI: Seluruh celah RLS bocor telah ditutup rapat.
-- ==============================================================================
