import React, { createContext, useContext, useState, useEffect } from 'react';
import { adminApi } from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [admin, setAdmin] = useState(() => {
    const saved = localStorage.getItem('admin_user');
    return saved ? JSON.parse(saved) : null;
  });

  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return !!localStorage.getItem('admin_token');
  });

  const login = async (email, password) => {
    try {
      const response = await adminApi.login(email, password);
      if (response && response.success && response.data) {
        const { user, token } = response.data;
        if (user.role !== 'admin') {
          throw new Error('Akun tidak memiliki hak akses administrator');
        }
        localStorage.setItem('admin_token', token);
        localStorage.setItem('admin_user', JSON.stringify(user));
        setAdmin(user);
        setIsAuthenticated(true);
        return { success: true };
      }
      return { success: false, message: response?.message || 'Login gagal' };
    } catch (err) {
      const errorMsg = err.response?.data?.message || err.message || 'Login gagal';
      return { success: false, message: errorMsg };
    }
  };

  const logout = () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    setIsAuthenticated(false);
    setAdmin(null);
  };

  return (
    <AuthContext.Provider value={{ admin, isAuthenticated, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
