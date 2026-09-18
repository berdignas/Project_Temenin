-- ============================================================================
-- FIX: MIGRASI PENYIMPANAN CHAT KE TABEL KHUSUS (PUBLIC.BOOKING_MESSAGES)
-- Mencegah Race Condition yang Menimpa additional_details & Status Finansial
-- ============================================================================

-- 1. Pastikan tabel booking_messages ada dengan struktur lengkap
CREATE TABLE IF NOT EXISTS public.booking_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    sender_role TEXT CHECK (sender_role IN ('client', 'driver', 'admin')),
    message TEXT NOT NULL,
    attachment_url TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Aktifkan Replica Identity Full untuk Realtime Broadcast
ALTER TABLE public.booking_messages REPLICA IDENTITY FULL;

-- 3. Tambahkan Index untuk Query Kecepatan Tinggi
CREATE INDEX IF NOT EXISTS idx_booking_messages_booking_id ON public.booking_messages(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_messages_created_at ON public.booking_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_booking_messages_sender_id ON public.booking_messages(sender_id);

-- 4. Pastikan RLS Aktif dan Aman
ALTER TABLE public.booking_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Booking Messages Select Authorized" ON public.booking_messages;
DROP POLICY IF EXISTS "Booking Messages Insert Authorized" ON public.booking_messages;

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

-- 5. Tambahkan ke Realtime Publication Supabase
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'booking_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_messages;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END $$;
