import React, { useEffect, useState } from 'react';
import { AppBar, Toolbar, Box, Typography, Chip, Avatar, Tooltip, IconButton, Button } from '@mui/material';
import ConfirmationNumberOutlinedIcon from '@mui/icons-material/ConfirmationNumberOutlined';
import CloudDoneIcon from '@mui/icons-material/CloudDone';
import CloudOffIcon from '@mui/icons-material/CloudOff';
import RefreshIcon from '@mui/icons-material/Refresh';
import LogoutIcon from '@mui/icons-material/Logout';
import { ApiService } from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function Navbar({ onRefresh }) {
  const { user, logout } = useAuth();
  const [status, setStatus] = useState('checking');

  const checkHealth = async () => {
    try {
      const res = await ApiService.checkHealth();
      setStatus(res?.status === 'UP' ? 'online' : 'offline');
    } catch {
      setStatus('offline');
    }
  };

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, 30000);
    return () => clearInterval(interval);
  }, []);

  const roleColors = {
    ADMIN: { bg: 'rgba(239,68,68,0.15)', color: '#f87171', border: 'rgba(239,68,68,0.3)' },
    AGENT: { bg: 'rgba(245,158,11,0.15)', color: '#fbbf24', border: 'rgba(245,158,11,0.3)' },
    USER:  { bg: 'rgba(16,185,129,0.15)', color: '#34d399', border: 'rgba(16,185,129,0.3)' },
  };

  const rc = roleColors[user?.role] || roleColors.USER;

  return (
    <AppBar
      position="sticky"
      elevation={0}
      sx={{
        background: 'rgba(10, 14, 26, 0.85)',
        backdropFilter: 'blur(20px)',
        borderBottom: '1px solid rgba(59,130,246,0.15)',
      }}
    >
      <Toolbar sx={{ justifyContent: 'space-between', py: 0.5 }}>
        {/* Brand */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Box
            sx={{
              background: 'linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%)',
              borderRadius: 2.5,
              p: 0.85,
              display: 'flex',
              boxShadow: '0 4px 15px rgba(59,130,246,0.4)',
            }}
          >
            <ConfirmationNumberOutlinedIcon sx={{ color: 'white', fontSize: '1.4rem' }} />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 800, color: '#f8fafc', lineHeight: 1, letterSpacing: '-0.5px' }}>
              Ticket<span style={{ color: '#3b82f6' }}>Desk</span>
            </Typography>
            <Typography variant="caption" sx={{ color: '#64748b', letterSpacing: '1.5px', textTransform: 'uppercase', fontSize: '0.6rem' }}>
              Enterprise Edition
            </Typography>
          </Box>
        </Box>

        {/* Status & User Actions */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <Chip
            icon={status === 'online' ? <CloudDoneIcon sx={{ fontSize: '0.9rem !important' }} /> : <CloudOffIcon sx={{ fontSize: '0.9rem !important' }} />}
            label={status === 'checking' ? 'Connecting...' : status === 'online' ? 'API Connected' : 'API Offline'}
            size="small"
            sx={{
              bgcolor: status === 'online' ? 'rgba(16,185,129,0.12)' : status === 'offline' ? 'rgba(239,68,68,0.12)' : 'rgba(100,116,139,0.12)',
              color: status === 'online' ? '#10b981' : status === 'offline' ? '#ef4444' : '#94a3b8',
              border: `1px solid ${status === 'online' ? 'rgba(16,185,129,0.3)' : status === 'offline' ? 'rgba(239,68,68,0.3)' : 'rgba(100,116,139,0.3)'}`,
              fontWeight: 600,
              fontSize: '0.72rem',
            }}
          />
          <Tooltip title="Refresh data">
            <IconButton onClick={onRefresh} size="small" sx={{ color: '#94a3b8', '&:hover': { color: '#3b82f6', bgcolor: 'rgba(59,130,246,0.1)' } }}>
              <RefreshIcon fontSize="small" />
            </IconButton>
          </Tooltip>

          {user && (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, pl: 1, borderLeft: '1px solid rgba(71,85,105,0.3)' }}>
              <Avatar
                sx={{
                  width: 34, height: 34, fontSize: '0.8rem', fontWeight: 700,
                  background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
                  boxShadow: '0 2px 8px rgba(59,130,246,0.4)',
                }}
              >
                {user.name ? user.name.substring(0, 2).toUpperCase() : 'U'}
              </Avatar>
              <Box sx={{ display: { xs: 'none', sm: 'block' } }}>
                <Typography variant="body2" sx={{ fontWeight: 700, color: '#f1f5f9', lineHeight: 1.1 }}>
                  {user.name}
                </Typography>
                <Chip
                  label={user.role}
                  size="small"
                  sx={{
                    bgcolor: rc.bg, color: rc.color, border: `1px solid ${rc.border}`,
                    fontWeight: 700, fontSize: '0.62rem', height: 18, mt: 0.3,
                  }}
                />
              </Box>
              <Tooltip title="Logout">
                <IconButton onClick={logout} size="small" sx={{ color: '#f87171', '&:hover': { bgcolor: 'rgba(239,68,68,0.12)' } }}>
                  <LogoutIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            </Box>
          )}
        </Box>
      </Toolbar>
    </AppBar>
  );
}
