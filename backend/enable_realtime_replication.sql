-- ==============================================================================
-- TEMENIN AJAA - ENABLE SUPABASE REALTIME REPLICATION & RLS STREAM ACCESS
-- Eksekusi file ini di: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Tambahkan tabel-tabel utama ke publikasi Realtime Supabase
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.drivers;
ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_negotiations;

-- 2. Pastikan RLS SELECT policy pada tabel bookings memperbolehkan baca realtime untuk role authenticated dan anon
DROP POLICY IF EXISTS "Bookings Select Authorized" ON public.bookings;
CREATE POLICY "Bookings Select Authorized" ON public.bookings
FOR SELECT
TO authenticated, anon
USING (
    true
);

-- 3. Pastikan RLS SELECT policy pada tabel drivers memperbolehkan baca realtime
DROP POLICY IF EXISTS "Drivers Read Approved Or Self Or Admin" ON public.drivers;
CREATE POLICY "Drivers Read Approved Or Self Or Admin" ON public.drivers
FOR SELECT
TO authenticated, anon
USING (
    true
);

-- 4. Pastikan RLS SELECT policy pada tabel booking_messages memperbolehkan baca realtime
DROP POLICY IF EXISTS "Booking Messages Select Authorized" ON public.booking_messages;
CREATE POLICY "Booking Messages Select Authorized" ON public.booking_messages
FOR SELECT
TO authenticated, anon
USING (
    true
);
