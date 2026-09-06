import React, { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [admin, setAdmin] = useState(() => {
    const saved = localStorage.getItem('admin_user');
    return saved ? JSON.parse(saved) : { name: 'Super Admin', email: 'admin@temenin.aja', role: 'Super Admin' };
  });

  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return !!localStorage.getItem('admin_token');
  });

  const login = (email, password) => {
    if (email === 'admin@temenin.aja' && password === 'admin123') {
      const user = { name: 'Super Admin', email, role: 'Super Admin' };
      localStorage.setItem('admin_token', 'token_admin_temenin_ajaa_secret');
      localStorage.setItem('admin_user', JSON.stringify(user));
      setAdmin(user);
      setIsAuthenticated(true);
      return true;
    }
    return false;
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
