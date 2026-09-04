import React from 'react';
import { Search, Bell, Activity, RefreshCw } from 'lucide-react';

export const Navbar = ({ onRefresh, isRefreshing = false }) => {
  const currentDate = new Date().toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });

  return (
    <header className="h-16 border-b border-slate-800 bg-slate-900/80 backdrop-blur-md px-6 flex items-center justify-between sticky top-0 z-30">
      {/* Search & System Indicator */}
      <div className="flex items-center gap-4 flex-1 max-w-md">
        <div className="relative w-full">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Cari user, driver, plat nomor, booking ID..."
            className="w-full pl-10 pr-4 py-2 bg-slate-800/60 border border-slate-700/60 rounded-xl text-xs text-white placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
          />
        </div>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-4">
        {/* Refresh Button */}
        {onRefresh && (
          <button
            onClick={onRefresh}
            disabled={isRefreshing}
            className="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-slate-300 bg-slate-800 hover:bg-slate-700/80 border border-slate-700 rounded-xl transition-colors disabled:opacity-50"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin text-indigo-400' : ''}`} />
            <span>Refresh</span>
          </button>
        )}

        {/* Live System Badge */}
        <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-emerald-500/10 border border-emerald-500/20 rounded-xl text-xs font-semibold text-emerald-400">
          <Activity className="w-3.5 h-3.5 animate-pulse" />
          <span>System Live</span>
        </div>

        {/* Date Display */}
        <div className="hidden lg:block text-xs font-medium text-slate-400 border-l border-slate-800 pl-4">
          {currentDate}
        </div>

        {/* Notification Bell */}
        <button className="relative p-2 text-slate-400 hover:text-white rounded-xl hover:bg-slate-800 transition-colors">
          <Bell className="w-5 h-5" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-indigo-500 rounded-full ring-4 ring-slate-900"></span>
        </button>
      </div>
    </header>
  );
};
