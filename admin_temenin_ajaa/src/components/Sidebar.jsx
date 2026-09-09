import React from 'react';
import { NavLink } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Users, 
  Car, 
  UserCheck, 
  CalendarCheck, 
  Ticket,
  Wallet, 
  MessageSquare, 
  Settings, 
  LogOut,
  ShieldCheck
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export const Sidebar = ({ pendingCount = 2 }) => {
  const { logout, admin } = useAuth();

  const navItems = [
    { label: 'Dashboard', path: '/', icon: LayoutDashboard },
    { label: 'Client / Pengguna', path: '/clients', icon: Users },
    { label: 'Driver / Mitra', path: '/drivers', icon: Car },
    { 
      label: 'Persetujuan Mitra', 
      path: '/driver-approvals', 
      icon: UserCheck, 
      badge: pendingCount > 0 ? pendingCount : null 
    },
    { label: 'Pemesanan & Order', path: '/bookings', icon: CalendarCheck },
    { label: 'Event Terdekat', path: '/events', icon: Ticket },
    { label: 'Keuangan & Saldo', path: '/finance', icon: Wallet },
    { label: 'Komunitas & Konten', path: '/community', icon: MessageSquare },
    { label: 'Pengaturan Sistem', path: '/settings', icon: Settings },
  ];

  return (
    <aside className="w-64 bg-slate-900 border-r border-slate-800 flex flex-col h-screen sticky top-0 z-40">
      {/* Brand Header */}
      <div className="p-6 border-b border-slate-800 flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 via-blue-600 to-cyan-400 flex items-center justify-center shadow-lg shadow-indigo-500/20">
          <ShieldCheck className="w-6 h-6 text-white" />
        </div>
        <div>
          <h1 className="font-extrabold text-lg text-white tracking-wide">TEMENIN AJAA</h1>
          <p className="text-xs font-semibold text-indigo-400 uppercase tracking-wider">Admin Control Center</p>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-1.5 overflow-y-auto">
        <div className="px-3 py-2 text-[10px] font-bold tracking-widest text-slate-500 uppercase">
          Menu Utama
        </div>
        {navItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-semibold transition-all duration-200 ${
                  isActive
                    ? 'bg-indigo-600/15 text-indigo-400 border border-indigo-500/30 shadow-md shadow-indigo-500/10'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`
              }
            >
              <div className="flex items-center gap-3">
                <Icon className="w-5 h-5" />
                <span>{item.label}</span>
              </div>
              {item.badge && (
                <span className="px-2 py-0.5 text-xs font-bold bg-rose-500 text-white rounded-full animate-pulse">
                  {item.badge}
                </span>
              )}
            </NavLink>
          );
        })}
      </nav>

      {/* Footer Profile & Logout */}
      <div className="p-4 border-t border-slate-800 bg-slate-900/50">
        <div className="flex items-center justify-between p-2.5 rounded-xl bg-slate-800/40 border border-slate-700/50">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-indigo-500/20 text-indigo-300 flex items-center justify-center font-bold text-sm border border-indigo-500/30">
              {admin?.name ? admin.name.charAt(0) : 'A'}
            </div>
            <div className="truncate">
              <p className="text-xs font-bold text-white truncate">{admin?.name || 'Super Admin'}</p>
              <p className="text-[10px] text-slate-400 truncate">{admin?.role || 'Administrator'}</p>
            </div>
          </div>
          <button
            onClick={logout}
            title="Keluar / Logout"
            className="p-1.5 text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
};
