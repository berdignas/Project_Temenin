import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Sidebar } from './components/Sidebar';
import { Navbar } from './components/Navbar';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { Clients } from './pages/Clients';
import { Drivers } from './pages/Drivers';
import { DriverApprovals } from './pages/DriverApprovals';
import { Bookings } from './pages/Bookings';
import { Finance } from './pages/Finance';
import { Community } from './pages/Community';
import { Events } from './pages/Events';
import { Settings } from './pages/Settings';
import { adminApi } from './services/api';

const ProtectedLayout = () => {
  const { isAuthenticated } = useAuth();
  const [pendingCount, setPendingCount] = useState(2);
  const [isRefreshing, setIsRefreshing] = useState(false);

  const fetchPendingCount = async () => {
    setIsRefreshing(true);
    const data = await adminApi.getDrivers('pending');
    setPendingCount(data ? data.length : 0);
    setIsRefreshing(false);
  };

  useEffect(() => {
    if (isAuthenticated) {
      fetchPendingCount();
    }
  }, [isAuthenticated]);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="flex min-h-screen bg-slate-950 text-slate-100">
      <Sidebar pendingCount={pendingCount} />
      <div className="flex-1 flex flex-col min-w-0">
        <Navbar onRefresh={fetchPendingCount} isRefreshing={isRefreshing} />
        <main className="flex-1 p-6 md:p-8 overflow-y-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<ProtectedLayout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/clients" element={<Clients />} />
            <Route path="/drivers" element={<Drivers />} />
            <Route path="/driver-approvals" element={<DriverApprovals />} />
            <Route path="/bookings" element={<Bookings />} />
            <Route path="/events" element={<Events />} />
            <Route path="/finance" element={<Finance />} />
            <Route path="/community" element={<Community />} />
            <Route path="/settings" element={<Settings />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
