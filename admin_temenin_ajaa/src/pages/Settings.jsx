import React, { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Save, Server, Shield, CheckCircle2, Navigation, Clock, Gamepad2, PhoneCall, Moon, AlertCircle, Sparkles } from 'lucide-react';
import { adminApi } from '../services/api';

export const Settings = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  // Pricing Form State
  const [pricePerKm, setPricePerKm] = useState(5000);
  const [pricePerKmSporty, setPricePerKmSporty] = useState(7500);
  const [minRidePrice, setMinRidePrice] = useState(15000);
  const [baseHourlyPrice, setBaseHourlyPrice] = useState(50000);
  const [minHourlyPrice, setMinHourlyPrice] = useState(35000);
  const [virtualPrice, setVirtualPrice] = useState(35000);
  const [sleepCallPrice, setSleepCallPrice] = useState(45000);
  const [gamingPrice, setGamingPrice] = useState(15000);
  const [commissionRate, setCommissionRate] = useState(10);
  const [apiEndpoint, setApiEndpoint] = useState('http://localhost:3002/api');
  const [autoApprove, setAutoApprove] = useState(false);

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        setLoading(true);
        const data = await adminApi.getSettings();
        if (data) {
          if (data.price_per_km !== undefined) setPricePerKm(data.price_per_km);
          if (data.price_per_km_sporty !== undefined) setPricePerKmSporty(data.price_per_km_sporty);
          if (data.min_ride_price !== undefined) setMinRidePrice(data.min_ride_price);
          if (data.base_hourly_price !== undefined) setBaseHourlyPrice(data.base_hourly_price);
          if (data.min_hourly_price !== undefined) setMinHourlyPrice(data.min_hourly_price);
          if (data.virtual_counseling_hourly_price !== undefined) setVirtualPrice(data.virtual_counseling_hourly_price);
          if (data.sleep_call_package_price !== undefined) setSleepCallPrice(data.sleep_call_package_price);
          if (data.gaming_buddy_per_match_price !== undefined) setGamingPrice(data.gaming_buddy_per_match_price);
          if (data.commission_rate !== undefined) setCommissionRate(data.commission_rate);
        }
      } catch (err) {
        console.error('Failed to load settings:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchSettings();
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setMessage('');
    setErrorMessage('');

    try {
      const payload = {
        price_per_km: Number(pricePerKm),
        price_per_km_sporty: Number(pricePerKmSporty),
        min_ride_price: Number(minRidePrice),
        base_hourly_price: Number(baseHourlyPrice),
        min_hourly_price: Number(minHourlyPrice),
        virtual_counseling_hourly_price: Number(virtualPrice),
        sleep_call_package_price: Number(sleepCallPrice),
        gaming_buddy_per_match_price: Number(gamingPrice),
        commission_rate: Number(commissionRate),
        allow_negotiation_flexible_only: true
      };

      const res = await adminApi.updateSettings(payload);
      if (res.success) {
        setMessage('Pengaturan tarif platform dan sistem berhasil disimpan ke backend & database!');
      } else {
        setMessage('Pengaturan berhasil diperbarui!');
      }
      setTimeout(() => setMessage(''), 4000);
    } catch (err) {
      setErrorMessage('Gagal menyimpan pengaturan: ' + (err.message || 'Terjadi kesalahan'));
      setTimeout(() => setErrorMessage(''), 4000);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Alert */}
      {message && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-2xl text-sm font-semibold text-emerald-400 flex items-center gap-2 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5" />
          <span>{message}</span>
        </div>
      )}

      {errorMessage && (
        <div className="p-4 bg-rose-500/10 border border-rose-500/30 rounded-2xl text-sm font-semibold text-rose-400 flex items-center gap-2 animate-in fade-in">
          <AlertCircle className="w-5 h-5" />
          <span>{errorMessage}</span>
        </div>
      )}

      {/* Header */}
      <div>
        <h2 className="text-2xl font-extrabold text-white tracking-tight">Pengaturan Sistem & Tarif Layanan</h2>
        <p className="text-sm text-slate-400">Konfigurasi tarif resmi platform per-KM, per-jam, komisi, dan kebijakan non-negosiasi driver</p>
      </div>

      {/* Policy Card: Non-Negotiation Rule */}
      <div className="bg-gradient-to-r from-indigo-950/60 via-purple-950/40 to-slate-900 border border-indigo-500/30 rounded-2xl p-5 space-y-2 backdrop-blur-md">
        <div className="flex items-center gap-2 text-indigo-300 font-bold text-sm">
          <Sparkles className="w-4 h-4 text-pink-400" />
          <span>Kebijakan Harga Platform & Aturan Non-Negosiasi Driver</span>
        </div>
        <p className="text-xs text-slate-300 leading-relaxed">
          Seluruh tarif layanan diatur terpusat oleh Admin pada panel ini. 
          Pada aplikasi <strong>Client</strong>, biaya dihitung otomatis secara transparan dan berstatus <strong>Harga Pas</strong>.
          Pada aplikasi <strong>Driver</strong>, tombol <strong>"TAWAR" / Nego dinonaktifkan</strong> untuk pesanan reguler (Antar-Jemput, Hangout, Sleep Call, Virtual). 
          Driver hanya dapat memilih <strong>Terima</strong> atau <strong>Tolak</strong> pesanan.
          Fitur negosiasi budget <strong>hanya aktif</strong> khusus untuk <strong>Layanan Fleksibel (Freedom Request / Jasa Suruh)</strong>.
        </p>
      </div>

      <form onSubmit={handleSave} className="space-y-6 text-xs">
        {/* Section 1: Antar Jemput Pricing (Per KM) */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <Navigation className="w-5 h-5 text-emerald-400" />
            <h3 className="font-extrabold text-white text-sm">Tarif Layanan Antar Jemput (Berdasarkan Jarak / KM)</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Tarif Standar Per KM (Rp)</label>
              <input
                type="number"
                value={pricePerKm}
                onChange={(e) => setPricePerKm(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-emerald-400 font-mono font-bold text-sm focus:outline-none focus:border-emerald-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Contoh: Rp 3.000 atau Rp 5.000 per KM</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Tarif Motor Sport Per KM (Rp)</label>
              <input
                type="number"
                value={pricePerKmSporty}
                onChange={(e) => setPricePerKmSporty(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold text-sm focus:outline-none focus:border-emerald-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Layanan sensasi motor sport premium</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Tarif Minimal Perjalanan (Rp)</label>
              <input
                type="number"
                value={minRidePrice}
                onChange={(e) => setMinRidePrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold text-sm focus:outline-none focus:border-emerald-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Batas dasar tarif jarak dekat</span>
            </div>
          </div>
        </div>

        {/* Section 2: Hangout & Offline Pricing (Per Jam) */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <Clock className="w-5 h-5 text-pink-400" />
            <h3 className="font-extrabold text-white text-sm">Tarif Layanan Teman Hangout & Offline (Per Jam)</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Tarif Standar Hangout Per Jam (Rp)</label>
              <input
                type="number"
                value={baseHourlyPrice}
                onChange={(e) => setBaseHourlyPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-pink-400 font-mono font-bold text-sm focus:outline-none focus:border-pink-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Diterapkan untuk teman nonton, ngopi, dinner</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Batas Bawah Tarif Per Jam (Rp)</label>
              <input
                type="number"
                value={minHourlyPrice}
                onChange={(e) => setMinHourlyPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold text-sm focus:outline-none focus:border-pink-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Batas bawah sistematis per jam</span>
            </div>
          </div>
        </div>

        {/* Section 3: Virtual & Online Services */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <PhoneCall className="w-5 h-5 text-purple-400" />
            <h3 className="font-extrabold text-white text-sm">Tarif Layanan Virtual & Pendampingan Online</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Konseling & Call Virtual / Jam (Rp)</label>
              <input
                type="number"
                value={virtualPrice}
                onChange={(e) => setVirtualPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-purple-400 font-mono font-bold text-sm focus:outline-none focus:border-purple-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Relationship Counseling in-app</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Sleep Call Companion / Paket (Rp)</label>
              <input
                type="number"
                value={sleepCallPrice}
                onChange={(e) => setSleepCallPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-indigo-400 font-mono font-bold text-sm focus:outline-none focus:border-purple-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Mode tidur malam & alarm bangun pagi</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Gaming Buddy / Match (Rp)</label>
              <input
                type="number"
                value={gamingPrice}
                onChange={(e) => setGamingPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-sky-400 font-mono font-bold text-sm focus:outline-none focus:border-purple-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Tarif mabar per game match</span>
            </div>
          </div>
        </div>

        {/* Section 4: Commission & Platform System */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <Shield className="w-5 h-5 text-indigo-400" />
            <h3 className="font-extrabold text-white text-sm">Komisi Platform & Infrastruktur Backend</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Potongan Komisi Platform (%)</label>
              <input
                type="number"
                value={commissionRate}
                onChange={(e) => setCommissionRate(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold focus:outline-none focus:border-indigo-500"
                required
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Diambil dari total nilai transaksi per booking</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Backend REST API Endpoint Base URL</label>
              <input
                type="text"
                value={apiEndpoint}
                onChange={(e) => setApiEndpoint(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-indigo-300 font-mono text-xs focus:outline-none focus:border-indigo-500"
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Alamat API yang digunakan aplikasi</span>
            </div>
          </div>

          <div className="pt-2">
            <label className="flex items-center gap-2 cursor-pointer text-slate-300 font-semibold">
              <input
                type="checkbox"
                checked={autoApprove}
                onChange={(e) => setAutoApprove(e.target.checked)}
                className="w-4 h-4 rounded text-indigo-600 bg-slate-900 border-slate-700"
              />
              <span>Otomatis Verifikasi Pendaftaran Driver Baru (Auto Approve)</span>
            </label>
          </div>
        </div>

        {/* Submit */}
        <div className="flex justify-end">
          <button
            type="submit"
            disabled={saving || loading}
            className="px-6 py-3 bg-gradient-to-r from-pink-600 to-indigo-600 hover:from-pink-500 hover:to-indigo-500 disabled:opacity-50 text-white font-bold rounded-xl shadow-lg shadow-pink-600/20 flex items-center gap-2 transition-all cursor-pointer"
          >
            <Save className="w-4 h-4" />
            <span>{saving ? 'Menyimpan Pengaturan...' : 'Simpan Perubahan Tarif & Sistem'}</span>
          </button>
        </div>
      </form>
    </div>
  );
};
