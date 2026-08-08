import React, { useState, useEffect, useCallback } from 'react';
import {
  ThemeProvider, createTheme, CssBaseline,
  Container, Box, Snackbar, Alert, GlobalStyles, Typography, Tab, Tabs,
} from '@mui/material';
import DashboardIcon          from '@mui/icons-material/Dashboard';
import FormatListBulletedIcon from '@mui/icons-material/FormatListBulleted';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import AddCircleOutlineIcon   from '@mui/icons-material/AddCircleOutline';

import Navbar           from './components/Navbar';
import KpiDashboard     from './components/KpiDashboard';
import CreateTicketForm from './components/CreateTicketForm';
import TicketQueue      from './components/TicketQueue';
import AdminPanel       from './components/AdminPanel';
import LoginPage        from './pages/LoginPage';

import { AuthProvider, useAuth } from './context/AuthContext';
import { ApiService }            from './services/api';

// ── Dark Theme ────────────────────────────────────────────────────────────────
const darkTheme = createTheme({
  palette: {
    mode: 'dark',
    background: { default: '#060a14', paper: '#0f172a' },
    primary:    { main: '#3b82f6' },
    secondary:  { main: '#8b5cf6' },
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica Neue", sans-serif',
    h6: { fontWeight: 700 },
  },
  components: {
    MuiCard:    { styleOverrides: { root: { backgroundImage: 'none' } } },
    MuiDivider: { styleOverrides: { root: { borderColor: 'rgba(71,85,105,0.3)' } } },
  },
});

const globalStyles = {
  body: {
    background:
      'radial-gradient(ellipse at 20% 20%, rgba(59,130,246,0.06) 0%, transparent 50%), ' +
      'radial-gradient(ellipse at 80% 80%, rgba(139,92,246,0.06) 0%, transparent 50%), ' +
      '#060a14',
    minHeight: '100vh',
  },
  '*::-webkit-scrollbar':       { width: '6px' },
  '*::-webkit-scrollbar-track': { background: 'rgba(15,23,42,0.5)' },
  '*::-webkit-scrollbar-thumb': { background: 'rgba(59,130,246,0.4)', borderRadius: '3px' },
  '*::-webkit-scrollbar-thumb:hover': { background: 'rgba(59,130,246,0.7)' },
};

// ── Main App Content (shown when logged in) ───────────────────────────────────
function MainContent() {
  const { user, isAdmin, isAgent, isUser } = useAuth();
  const [activeTab, setActiveTab] = useState(0);
  const [stats,     setStats]     = useState(null);
  const [tickets,   setTickets]   = useState([]);
  const [loading,   setLoading]   = useState(true);
  const [toast,     setToast]     = useState({ open: false, message: '', severity: 'success' });

  const showToast = useCallback((message, severity = 'success') =>
    setToast({ open: true, message, severity }), []);

  const loadData = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    try {
      const [dashRes, tickRes] = await Promise.allSettled([
        ApiService.getDashboardSummary(),
        ApiService.getTickets(),
      ]);

      if (dashRes.status === 'fulfilled' && dashRes.value?.success) {
        setStats(dashRes.value.data);
      }

      if (tickRes.status === 'fulfilled' && tickRes.value?.success) {
        setTickets(Array.isArray(tickRes.value.data) ? tickRes.value.data : []);
      }
    } catch (e) {
      console.error('Data load error:', e);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => { loadData(); }, [loadData]);

  // Build tabs per role
  // ADMIN:  Dashboard | Ticket Queue | Admin Panel
  // AGENT:  Dashboard | My Assigned Tickets
  // USER:   Dashboard | Create Ticket | My Tickets
  const tabs = isAdmin
    ? [
        { icon: <DashboardIcon sx={{ fontSize: '1rem' }} />, label: 'Dashboard' },
        { icon: <FormatListBulletedIcon sx={{ fontSize: '1rem' }} />, label: 'All Tickets' },
        { icon: <AdminPanelSettingsIcon sx={{ fontSize: '1rem' }} />, label: 'Admin Panel' },
      ]
    : isAgent
    ? [
        { icon: <DashboardIcon sx={{ fontSize: '1rem' }} />, label: 'Dashboard' },
        { icon: <FormatListBulletedIcon sx={{ fontSize: '1rem' }} />, label: 'Assigned Tickets' },
      ]
    : [
        { icon: <DashboardIcon sx={{ fontSize: '1rem' }} />, label: 'Dashboard' },
        { icon: <AddCircleOutlineIcon sx={{ fontSize: '1rem' }} />, label: 'Create Ticket' },
        { icon: <FormatListBulletedIcon sx={{ fontSize: '1rem' }} />, label: 'My Tickets' },
      ];

  return (
    <>
      <Navbar onRefresh={loadData} />

      <Container maxWidth="xl" sx={{ pt: 3, pb: 8 }}>

        {/* Tab Navigation */}
        <Tabs
          value={activeTab}
          onChange={(_, v) => setActiveTab(v)}
          sx={{
            mb: 3,
            '& .MuiTab-root': {
              color: '#475569', fontWeight: 600, textTransform: 'none', fontSize: '0.875rem',
              minHeight: 42, borderRadius: 2, mr: 0.5,
              '&:hover': { color: '#94a3b8', bgcolor: 'rgba(71,85,105,0.08)' },
            },
            '& .Mui-selected':      { color: '#f8fafc !important' },
            '& .MuiTabs-indicator': { bgcolor: '#3b82f6', height: '2px', borderRadius: '2px' },
          }}
        >
          {tabs.map((t, i) => (
            <Tab key={i} icon={t.icon} iconPosition="start" label={t.label} id={`main-tab-${i}`} disableRipple />
          ))}
        </Tabs>

        {/* ── ADMIN TABS ────────────────────────────────────────────────────── */}
        {isAdmin && (
          <>
            {activeTab === 0 && <KpiDashboard stats={stats} loading={loading} />}

            {activeTab === 1 && (
              <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', lg: '400px 1fr' }, gap: 3, alignItems: 'start' }}>
                <Box sx={{ position: { lg: 'sticky' }, top: { lg: 80 } }}>
                  <CreateTicketForm onTicketCreated={loadData} onToast={showToast} />
                </Box>
                <TicketQueue tickets={tickets} loading={loading} onRefresh={loadData} onToast={showToast} />
              </Box>
            )}

            {activeTab === 2 && (
              <AdminPanel onToast={showToast} />
            )}
          </>
        )}

        {/* ── AGENT TABS ────────────────────────────────────────────────────── */}
        {isAgent && (
          <>
            {activeTab === 0 && <KpiDashboard stats={stats} loading={loading} />}
            {activeTab === 1 && (
              <TicketQueue tickets={tickets} loading={loading} onRefresh={loadData} onToast={showToast} />
            )}
          </>
        )}

        {/* ── USER TABS ─────────────────────────────────────────────────────── */}
        {isUser && (
          <>
            {activeTab === 0 && <KpiDashboard stats={stats} loading={loading} />}
            {activeTab === 1 && (
              <CreateTicketForm onTicketCreated={() => { loadData(); setActiveTab(2); }} onToast={showToast} />
            )}
            {activeTab === 2 && (
              <TicketQueue tickets={tickets} loading={loading} onRefresh={loadData} onToast={showToast} />
            )}
          </>
        )}

      </Container>

      {/* Toast */}
      <Snackbar
        open={toast.open}
        autoHideDuration={4000}
        onClose={() => setToast(t => ({ ...t, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert
          onClose={() => setToast(t => ({ ...t, open: false }))}
          severity={toast.severity}
          variant="filled"
          sx={{ borderRadius: 2, fontWeight: 500 }}
        >
          {toast.message}
        </Alert>
      </Snackbar>
    </>
  );
}

// ── Root App ──────────────────────────────────────────────────────────────────
function AppRouter() {
  const { user } = useAuth();
  return user ? <MainContent /> : <LoginPage />;
}

export default function App() {
  return (
    <ThemeProvider theme={darkTheme}>
      <CssBaseline />
      <GlobalStyles styles={globalStyles} />
      <AuthProvider>
        <AppRouter />
      </AuthProvider>
    </ThemeProvider>
  );
}
