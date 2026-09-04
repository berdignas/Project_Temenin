import React, { useState } from 'react';
import { Settings as SettingsIcon, Save, Server, Shield, Bell, CheckCircle2 } from 'lucide-react';

export const Settings = () => {
  const [commissionRate, setCommissionRate] = useState(10);
  const [minHourlyPrice, setMinHourlyPrice] = useState(35000);
  const [apiEndpoint, setApiEndpoint] = useState('http://localhost:3002/api');
  const [autoApprove, setAutoApprove] = useState(false);
  const [message, setMessage] = useState('');

  const handleSave = (e) => {
    e.preventDefault();
    setMessage('Pengaturan platform berhasil disimpan');
    setTimeout(() => setMessage(''), 3000);
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

      {/* Header */}
      <div>
        <h2 className="text-2xl font-extrabold text-white tracking-tight">Pengaturan Sistem Platform</h2>
        <p className="text-sm text-slate-400">Konfigurasi persentase komisi, tarif standar, dan koneksi server backend</p>
      </div>

      <form onSubmit={handleSave} className="space-y-6 text-xs">
        {/* Tariff & Commission Section */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <Shield className="w-5 h-5 text-indigo-400" />
            <h3 className="font-extrabold text-white text-sm">Komisi Platform & Tarif Minimum</h3>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Potongan Komisi Platform (%)</label>
              <input
                type="number"
                value={commissionRate}
                onChange={(e) => setCommissionRate(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold focus:outline-none focus:border-indigo-500"
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Diambil dari total nilai transaksi per booking</span>
            </div>

            <div>
              <label className="block text-slate-400 font-semibold mb-1.5">Batas Tarif Minimal Per Jam (Rp)</label>
              <input
                type="number"
                value={minHourlyPrice}
                onChange={(e) => setMinHourlyPrice(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-white font-mono font-bold focus:outline-none focus:border-indigo-500"
              />
              <span className="text-[10px] text-slate-500 mt-1 block">Batas bawah penawaran negosiasi driver</span>
            </div>
          </div>
        </div>

        {/* Server & API Section */}
        <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 space-y-4 backdrop-blur-md">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <Server className="w-5 h-5 text-sky-400" />
            <h3 className="font-extrabold text-white text-sm">Koneksi Backend Express & Supabase</h3>
          </div>

          <div>
            <label className="block text-slate-400 font-semibold mb-1.5">Backend REST API Endpoint Base URL</label>
            <input
              type="text"
              value={apiEndpoint}
              onChange={(e) => setApiEndpoint(e.target.value)}
              className="w-full px-3.5 py-2.5 bg-slate-900 border border-slate-700 rounded-xl text-indigo-300 font-mono text-xs focus:outline-none focus:border-indigo-500"
            />
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
            className="px-6 py-3 bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-500 hover:to-blue-500 text-white font-bold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2 transition-all"
          >
            <Save className="w-4 h-4" />
            <span>Simpan Perubahan Pengaturan</span>
          </button>
        </div>
      </form>
    </div>
  );
};
