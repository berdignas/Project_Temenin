const { supabase } = require('../config/supabase');

/**
 * Pengecekan Ketersediaan Jadwal Driver
 */
const checkDriverAvailability = async (driverId, startTime, durationMinutes) => {
  // 1. Ambil buffer time driver
  const { data: driver } = await supabase
    .from('drivers')
    .select('buffer_time_minutes')
    .eq('id', driverId)
    .maybeSingle();

  const bufferMinutes = driver?.buffer_time_minutes ?? 30;

  const start = new Date(startTime);
  const end = new Date(start.getTime() + durationMinutes * 60 * 1000);

  // Waktu dengan toleransi buffer
  const bufferedStart = new Date(start.getTime() - bufferMinutes * 60 * 1000).toISOString();
  const bufferedEnd = new Date(end.getTime() + bufferMinutes * 60 * 1000).toISOString();

  // 2. Cek tabel driver_schedules yang berstatus 'locked'
  const { data: schedules, error: schedError } = await supabase
    .from('driver_schedules')
    .select('*')
    .eq('driver_id', driverId)
    .eq('status', 'locked')
    .lt('start_time', bufferedEnd)
    .gt('end_time', bufferedStart);

  if (schedError && schedError.code !== 'PGRST116') {
    console.error('Error checking driver_schedules:', schedError);
  }

  if (schedules && schedules.length > 0) {
    return {
      available: false,
      reason: 'Jadwal driver terkunci di rentang waktu tersebut (termasuk jeda istirahat).',
      conflict: schedules[0],
      bufferMinutes
    };
  }

  // 3. Fallback: Cek tabel bookings yang statusnya accepted atau ongoing
  const { data: bookings, error: bookError } = await supabase
    .from('bookings')
    .select('id, booking_date, duration, status')
    .eq('driver_id', driverId)
    .in('status', ['accepted', 'ongoing']);

  if (!bookError && bookings) {
    for (const b of bookings) {
      if (!b.booking_date) continue;
      const bStart = new Date(b.booking_date);
      const bEnd = new Date(bStart.getTime() + (b.duration || 60) * 60 * 1000);

      const bBufStart = new Date(bStart.getTime() - bufferMinutes * 60 * 1000);
      const bBufEnd = new Date(bEnd.getTime() + bufferMinutes * 60 * 1000);

      if (start < bBufEnd && end > bBufStart) {
        return {
          available: false,
          reason: 'Driver memiliki pesanan aktif di jam tersebut.',
          conflict: b,
          bufferMinutes
        };
      }
    }
  }

  return {
    available: true,
    bufferMinutes
  };
};

/**
 * Mengunci Jadwal Driver Otomatis saat Pesanan Disetujui/Dibuat dari Profil
 */
const lockDriverSchedule = async (driverId, bookingId, startTime, durationMinutes, title = 'Pesanan Terkunci') => {
  const start = new Date(startTime);
  const end = new Date(start.getTime() + durationMinutes * 60 * 1000);

  // Hapus/update kuncian lama jika ada
  if (bookingId) {
    await supabase.from('driver_schedules').delete().eq('booking_id', bookingId);
  }

  const { data: schedule, error } = await supabase
    .from('driver_schedules')
    .insert({
      driver_id: driverId,
      booking_id: bookingId || null,
      start_time: start.toISOString(),
      end_time: end.toISOString(),
      status: 'locked'
    })
    .select()
    .single();

  if (error) {
    console.error('Failed to lock driver schedule:', error);
  }
  return schedule;
};

/**
 * Membuka Kembali Jadwal Driver jika Pesanan Dibatalkan
 */
const unlockDriverSchedule = async (bookingId) => {
  const { error } = await supabase
    .from('driver_schedules')
    .update({ status: 'cancelled' })
    .eq('booking_id', bookingId);

  if (error) {
    console.error('Failed to unlock driver schedule:', error);
  }
};

module.exports = {
  checkDriverAvailability,
  lockDriverSchedule,
  unlockDriverSchedule
};
