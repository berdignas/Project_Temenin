-- ==============================================================================
-- TEMENIN AJAA - FIX DRIVER SCHEDULES SCHEMA & FOREIGN KEY DEPENDENCY
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================
-- Memperbaiki error: relation "bookings" does not exist saat inisialisasi schema.
-- Script ini aman dijalankan baik pada database baru maupun database yang sudah berjalan.
-- ==============================================================================

-- 1. Pastikan tabel bookings sudah ada sebelum membuat driver_schedules
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'bookings'
    ) THEN
        RAISE NOTICE 'Peringatan: Tabel bookings belum ditemukan. Jalankan pembuatan tabel bookings terlebih dahulu.';
    END IF;
END $$;

-- 2. Buat tabel driver_schedules jika belum ada
CREATE TABLE IF NOT EXISTS public.driver_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE NOT NULL,
    booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE, -- NULL jika driver set manual "Libur/Off"
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    title TEXT DEFAULT 'Terkunci',
    status TEXT DEFAULT 'locked' CHECK (status IN ('locked', 'completed', 'cancelled', 'off')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Jika tabel driver_schedules sudah terlanjur dibuat tanpa foreign key booking_id, tambahkan constraint-nya secara aman
DO $$
BEGIN
    -- Cek apakah kolom booking_id sudah ada
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'driver_schedules' AND column_name = 'booking_id'
    ) THEN
        ALTER TABLE public.driver_schedules 
        ADD COLUMN booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE;
    END IF;

    -- Cek dan pasang foreign key constraint jika belum terpasang
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_schema = 'public' 
          AND table_name = 'driver_schedules' 
          AND constraint_name = 'driver_schedules_booking_id_fkey'
    ) THEN
        BEGIN
            ALTER TABLE public.driver_schedules 
            ADD CONSTRAINT driver_schedules_booking_id_fkey 
            FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE CASCADE;
        EXCEPTION
            WHEN duplicate_object THEN
                NULL; -- Constraint sudah ada
        END;
    END IF;
END $$;

-- 4. Index performa pencarian jadwal dan ketersediaan driver
CREATE INDEX IF NOT EXISTS idx_driver_schedules_driver_time 
ON public.driver_schedules(driver_id, status, start_time, end_time);

CREATE INDEX IF NOT EXISTS idx_driver_schedules_booking_id 
ON public.driver_schedules(booking_id);

-- 5. Aktifkan Row Level Security (RLS)
ALTER TABLE public.driver_schedules ENABLE ROW LEVEL SECURITY;

-- 6. Policy RLS untuk driver_schedules
DROP POLICY IF EXISTS "Driver Schedules Select" ON public.driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Select Public" ON public.driver_schedules;
DROP POLICY IF EXISTS "Driver Schedules Modify Authorized" ON public.driver_schedules;

-- Publik & Client dapat membaca ketersediaan jadwal driver
CREATE POLICY "Driver Schedules Select Public" ON public.driver_schedules
FOR SELECT
USING (true);

-- Driver yang bersangkutan atau Admin yang dapat menambah/mengubah jadwal
CREATE POLICY "Driver Schedules Modify Authorized" ON public.driver_schedules
FOR ALL
TO authenticated
USING (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR (auth.jwt() ->> 'role') = 'service_role'
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    auth.uid() IN (SELECT user_id FROM public.drivers WHERE id = driver_schedules.driver_id)
    OR (auth.jwt() ->> 'role') = 'service_role'
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);
