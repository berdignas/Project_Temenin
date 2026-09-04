import React from 'react';

export const Badge = ({ children, variant = 'neutral', size = 'md' }) => {
  const variants = {
    success: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
    warning: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
    danger: 'bg-rose-500/10 text-rose-400 border-rose-500/20',
    info: 'bg-sky-500/10 text-sky-400 border-sky-500/20',
    indigo: 'bg-indigo-500/10 text-indigo-400 border-indigo-500/20',
    neutral: 'bg-slate-700/50 text-slate-300 border-slate-600/30',
  };

  const sizes = {
    sm: 'px-2 py-0.5 text-xs',
    md: 'px-2.5 py-1 text-xs font-semibold',
    lg: 'px-3 py-1.5 text-sm font-semibold'
  };

  return (
    <span className={`inline-flex items-center rounded-full border ${variants[variant] || variants.neutral} ${sizes[size]}`}>
      {children}
    </span>
  );
};
