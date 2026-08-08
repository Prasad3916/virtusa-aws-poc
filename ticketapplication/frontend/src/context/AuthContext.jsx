import React, { createContext, useContext, useState, useCallback } from 'react';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const stored = () => {
    try {
      const u = localStorage.getItem('td_user');
      return u ? JSON.parse(u) : null;
    } catch { return null; }
  };

  const [user, setUser] = useState(stored);

  const login = useCallback((userData) => {
    localStorage.setItem('td_user',     JSON.stringify(userData));
    localStorage.setItem('auth_token',  userData.token || '');
    localStorage.setItem('auth_role',   userData.role  || '');
    setUser(userData);
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('td_user');
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_role');
    setUser(null);
  }, []);

  const isAdmin = user?.role === 'ADMIN';
  const isAgent = user?.role === 'AGENT';
  const isUser  = user?.role === 'USER';

  return (
    <AuthContext.Provider value={{ user, login, logout, isAdmin, isAgent, isUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
