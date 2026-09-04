import React from 'react';
import { TrendingUp, TrendingDown } from 'lucide-react';

export const StatCard = ({ title, value, icon: Icon, trend, trendValue, color = 'indigo' }) => {
  const colorMap = {
    indigo: 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20',
    sky: 'bg-sky-500/10 text-sky-400 border-sky-500/20',
    emerald: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
    amber: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
    purple: 'bg-purple-500/10 text-purple-400 border-purple-500/20',
  };

  return (
    <div className="bg-slate-800/40 border border-slate-700/50 rounded-2xl p-6 hover:border-slate-600/60 transition-all duration-300 backdrop-blur-md relative overflow-hidden group">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1">{title}</p>
          <h3 className="text-2xl font-extrabold text-white tracking-tight">{value}</h3>
          {trendValue && (
            <div className="flex items-center gap-1 mt-2 text-xs font-medium">
              {trend === 'up' ? (
                <span className="flex items-center text-emerald-400 gap-0.5">
                  <TrendingUp className="w-3.5 h-3.5" />
                  {trendValue}
                </span>
              ) : (
                <span className="flex items-center text-rose-400 gap-0.5">
                  <TrendingDown className="w-3.5 h-3.5" />
                  {trendValue}
                </span>
              )}
              <span className="text-slate-500">vs bulan lalu</span>
            </div>
          )}
        </div>
        <div className={`p-3.5 rounded-xl border ${colorMap[color] || colorMap.indigo} group-hover:scale-110 transition-transform duration-300`}>
          <Icon className="w-6 h-6" />
        </div>
      </div>
    </div>
  );
};
