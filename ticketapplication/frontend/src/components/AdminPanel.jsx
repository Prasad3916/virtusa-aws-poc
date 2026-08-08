import React, { useState, useEffect, useCallback } from 'react';
import {
  Box, Card, CardContent, Typography, TextField, Button,
  Divider, Chip, Avatar, IconButton, Tooltip, CircularProgress,
  Alert, Skeleton, Tab, Tabs, InputAdornment,
} from '@mui/material';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import PersonAddAlt1Icon      from '@mui/icons-material/PersonAddAlt1';
import DeleteOutlineIcon      from '@mui/icons-material/DeleteOutline';
import GroupIcon              from '@mui/icons-material/Group';
import EngineeringIcon        from '@mui/icons-material/Engineering';
import PersonOutlineIcon      from '@mui/icons-material/PersonOutline';
import EmailOutlinedIcon      from '@mui/icons-material/EmailOutlined';
import VisibilityIcon         from '@mui/icons-material/Visibility';
import VisibilityOffIcon      from '@mui/icons-material/VisibilityOff';
import { useFormik }  from 'formik';
import * as Yup       from 'yup';
import { ApiService } from '../services/api';

const fieldSx = {
  mb: 2,
  '& .MuiOutlinedInput-root': {
    color: '#f1f5f9', bgcolor: 'rgba(15,23,42,0.7)', borderRadius: 2,
    '& fieldset':             { borderColor: 'rgba(71,85,105,0.4)' },
    '&:hover fieldset':       { borderColor: '#fbbf24' },
    '&.Mui-focused fieldset': { borderColor: '#fbbf24', borderWidth: '1.5px' },
  },
  '& .MuiInputLabel-root':             { color: '#64748b' },
  '& .MuiInputLabel-root.Mui-focused': { color: '#fbbf24' },
  '& .MuiFormHelperText-root':         { color: '#f87171', fontSize: '0.72rem' },
};

const ROLE_CONFIG = {
  ADMIN: { color: '#f87171', bg: 'rgba(239,68,68,0.12)', border: 'rgba(239,68,68,0.3)', icon: '👑' },
  AGENT: { color: '#fbbf24', bg: 'rgba(245,158,11,0.12)', border: 'rgba(245,158,11,0.3)', icon: '🛠️' },
  USER:  { color: '#34d399', bg: 'rgba(16,185,129,0.12)', border: 'rgba(16,185,129,0.3)', icon: '👤' },
};

// ── Create Agent Form ─────────────────────────────────────────────────────────
function CreateAgentForm({ onSuccess, onToast }) {
  const [showPw, setShowPw] = useState(false);

  const formik = useFormik({
    initialValues: { name: '', email: '', password: '' },
    validationSchema: Yup.object({
      name:     Yup.string().trim().min(2, 'Min 2 characters').max(60).required('Name is required'),
      email:    Yup.string().email('Enter a valid email').required('Email is required'),
      password: Yup.string().min(6, 'Min 6 characters').required('Password is required'),
    }),
    validateOnBlur: true,
    validateOnChange: false,
    onSubmit: async (values, { resetForm, setSubmitting }) => {
      try {
        const res = await ApiService.createAgent(values.name.trim(), values.email.trim(), values.password);
        if (res.success) {
          onToast(`Agent "${values.name}" created successfully`, 'success');
          resetForm();
          onSuccess();
        } else {
          onToast(res.message || 'Failed to create agent', 'error');
        }
      } catch (e) {
        const msg = e?.response?.data?.message;
        if (e?.response?.status === 409) onToast('Email already registered', 'error');
        else if (e?.response?.status === 403) onToast('Only Admin can create agents', 'error');
        else onToast(msg || 'Failed to create agent — check connection', 'error');
      } finally {
        setSubmitting(false);
      }
    },
  });

  return (
    <Box component="form" onSubmit={formik.handleSubmit} noValidate>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3, p: 2, bgcolor: 'rgba(245,158,11,0.06)', borderRadius: 3, border: '1px solid rgba(245,158,11,0.2)' }}>
        <EngineeringIcon sx={{ color: '#fbbf24', fontSize: '1.4rem' }} />
        <Box>
          <Typography variant="body2" sx={{ fontWeight: 700, color: '#fbbf24' }}>Create Agent Account</Typography>
          <Typography variant="caption" sx={{ color: '#64748b' }}>Agent can manage & resolve tickets assigned to them</Typography>
        </Box>
      </Box>

      <TextField
        fullWidth size="small" id="agent-name" name="name" label="Full Name" sx={fieldSx}
        value={formik.values.name} onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.name && Boolean(formik.errors.name)}
        helperText={formik.touched.name && formik.errors.name}
        InputProps={{ startAdornment: <InputAdornment position="start"><PersonOutlineIcon sx={{ color: '#475569', fontSize: '1rem' }} /></InputAdornment> }}
      />
      <TextField
        fullWidth size="small" id="agent-email" name="email" label="Email Address" sx={fieldSx}
        value={formik.values.email} onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.email && Boolean(formik.errors.email)}
        helperText={formik.touched.email && formik.errors.email}
        InputProps={{ startAdornment: <InputAdornment position="start"><EmailOutlinedIcon sx={{ color: '#475569', fontSize: '1rem' }} /></InputAdornment> }}
      />
      <TextField
        fullWidth size="small" id="agent-password" name="password" label="Password"
        type={showPw ? 'text' : 'password'} sx={fieldSx}
        value={formik.values.password} onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.password && Boolean(formik.errors.password)}
        helperText={formik.touched.password && formik.errors.password}
        InputProps={{
          endAdornment: (
            <InputAdornment position="end">
              <IconButton size="small" onClick={() => setShowPw(s => !s)} sx={{ color: '#64748b' }}>
                {showPw ? <VisibilityOffIcon fontSize="small" /> : <VisibilityIcon fontSize="small" />}
              </IconButton>
            </InputAdornment>
          ),
        }}
      />

      <Button
        type="submit" variant="contained" fullWidth
        disabled={formik.isSubmitting}
        endIcon={formik.isSubmitting ? <CircularProgress size={16} color="inherit" /> : <PersonAddAlt1Icon />}
        sx={{
          py: 1.3, borderRadius: 2.5, fontWeight: 700, textTransform: 'none',
          background: 'linear-gradient(135deg, #f59e0b, #d97706)',
          '&:hover': { background: 'linear-gradient(135deg, #d97706, #b45309)' },
          '&:disabled': { opacity: 0.6 },
        }}
      >
        {formik.isSubmitting ? 'Creating agent…' : 'Create Agent Account'}
      </Button>
    </Box>
  );
}

// ── User Row ──────────────────────────────────────────────────────────────────
function UserRow({ user, onDelete }) {
  const rc = ROLE_CONFIG[user.role] || ROLE_CONFIG.USER;
  const initials = user.name ? user.name.substring(0, 2).toUpperCase() : '??';

  return (
    <Box sx={{
      display: 'flex', alignItems: 'center', gap: 2,
      p: 1.5, mb: 1,
      bgcolor: 'rgba(15,23,42,0.5)',
      border: '1px solid rgba(71,85,105,0.2)',
      borderRadius: 2.5,
      transition: 'all 0.2s',
      '&:hover': { bgcolor: 'rgba(15,23,42,0.8)', border: '1px solid rgba(71,85,105,0.4)' },
    }}>
      <Avatar sx={{ width: 36, height: 36, fontSize: '0.8rem', fontWeight: 700, background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)' }}>
        {rc.icon}
      </Avatar>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Typography variant="body2" sx={{ fontWeight: 600, color: '#f1f5f9', lineHeight: 1.2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {user.name}
        </Typography>
        <Typography variant="caption" sx={{ color: '#64748b', fontSize: '0.72rem' }}>
          {user.email}
        </Typography>
      </Box>
      <Chip
        label={user.role}
        size="small"
        sx={{ bgcolor: rc.bg, color: rc.color, border: `1px solid ${rc.border}`, fontWeight: 700, fontSize: '0.65rem', height: 20 }}
      />
      {user.role !== 'ADMIN' && (
        <Tooltip title={`Delete ${user.role.toLowerCase()} account`}>
          <IconButton
            size="small"
            onClick={() => onDelete(user)}
            sx={{ color: '#475569', '&:hover': { color: '#f87171', bgcolor: 'rgba(239,68,68,0.1)' } }}
          >
            <DeleteOutlineIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      )}
    </Box>
  );
}

// ── AdminPanel ────────────────────────────────────────────────────────────────
export default function AdminPanel({ onToast }) {
  const [tab,     setTab]     = useState(0);
  const [users,   setUsers]   = useState([]);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState('');

  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await ApiService.getUsers();
      if (res.success) setUsers(Array.isArray(res.data) ? res.data : []);
      else setError(res.message || 'Failed to load users');
    } catch (e) {
      setError(e?.response?.data?.message || 'Cannot connect to auth service');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadUsers(); }, [loadUsers]);

  const handleDelete = async (targetUser) => {
    if (!window.confirm(`Delete ${targetUser.role} account "${targetUser.name}" (${targetUser.email})?`)) return;
    try {
      const res = await ApiService.deleteUser(targetUser.id);
      if (res.success) {
        onToast(`"${targetUser.name}" deleted`, 'info');
        loadUsers();
      } else {
        onToast(res.message || 'Delete failed', 'error');
      }
    } catch (e) {
      onToast(e?.response?.data?.message || 'Delete failed', 'error');
    }
  };

  const agents = users.filter(u => u.role === 'AGENT');
  const regularUsers = users.filter(u => u.role === 'USER');
  const allUsers = users;

  return (
    <Card sx={{
      background: 'linear-gradient(180deg, rgba(19,27,46,0.95) 0%, rgba(15,23,42,0.95) 100%)',
      border: '1px solid rgba(245,158,11,0.2)',
      borderRadius: 4,
      boxShadow: '0 25px 50px rgba(0,0,0,0.4)',
    }}>
      <CardContent sx={{ p: 3 }}>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
          <Box sx={{ bgcolor: 'rgba(245,158,11,0.12)', p: 1, borderRadius: 2 }}>
            <AdminPanelSettingsIcon sx={{ color: '#fbbf24', fontSize: '1.4rem' }} />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 700, color: '#f1f5f9', lineHeight: 1 }}>
              Admin Panel
            </Typography>
            <Typography variant="caption" sx={{ color: '#64748b' }}>
              Manage agents & users · {users.length} total accounts
            </Typography>
          </Box>
          {/* Quick stats */}
          <Box sx={{ ml: 'auto', display: 'flex', gap: 1 }}>
            <Chip icon={<EngineeringIcon sx={{ fontSize: '0.8rem !important' }} />} label={`${agents.length} Agents`} size="small"
              sx={{ bgcolor: 'rgba(245,158,11,0.1)', color: '#fbbf24', border: '1px solid rgba(245,158,11,0.3)', fontWeight: 600 }} />
            <Chip icon={<GroupIcon sx={{ fontSize: '0.8rem !important' }} />} label={`${regularUsers.length} Users`} size="small"
              sx={{ bgcolor: 'rgba(16,185,129,0.1)', color: '#34d399', border: '1px solid rgba(16,185,129,0.3)', fontWeight: 600 }} />
          </Box>
        </Box>

        <Tabs
          value={tab} onChange={(_, v) => setTab(v)}
          sx={{
            mb: 3,
            '& .MuiTab-root':       { color: '#475569', fontWeight: 600, textTransform: 'none', fontSize: '0.85rem' },
            '& .Mui-selected':      { color: '#fbbf24 !important' },
            '& .MuiTabs-indicator': { bgcolor: '#fbbf24' },
          }}
        >
          <Tab id="admin-tab-create" label="➕  Create Agent"  />
          <Tab id="admin-tab-users"  label={`👥  All Accounts (${users.length})`} />
        </Tabs>

        {/* ── Tab 0: Create Agent ─────────────────────────────────────────── */}
        {tab === 0 && (
          <CreateAgentForm onSuccess={loadUsers} onToast={onToast} />
        )}

        {/* ── Tab 1: All Users ────────────────────────────────────────────── */}
        {tab === 1 && (
          <>
            {error && (
              <Alert severity="error" sx={{ mb: 2, borderRadius: 2, bgcolor: 'rgba(239,68,68,0.1)', color: '#f87171' }}>
                {error}
              </Alert>
            )}

            {loading ? (
              [...Array(4)].map((_, i) => (
                <Skeleton key={i} variant="rounded" height={60} sx={{ bgcolor: 'rgba(255,255,255,0.04)', mb: 1, borderRadius: 2 }} />
              ))
            ) : allUsers.length === 0 ? (
              <Typography variant="body2" sx={{ color: '#475569', textAlign: 'center', py: 4 }}>
                No accounts found
              </Typography>
            ) : (
              <>
                {/* Admins */}
                {allUsers.filter(u => u.role === 'ADMIN').length > 0 && (
                  <>
                    <Typography variant="caption" sx={{ color: '#f87171', fontWeight: 700, letterSpacing: '1px', textTransform: 'uppercase', mb: 1, display: 'block' }}>
                      👑 Administrators
                    </Typography>
                    {allUsers.filter(u => u.role === 'ADMIN').map(u => <UserRow key={u.id} user={u} onDelete={handleDelete} />)}
                    <Divider sx={{ borderColor: 'rgba(71,85,105,0.2)', my: 2 }} />
                  </>
                )}
                {/* Agents */}
                {agents.length > 0 && (
                  <>
                    <Typography variant="caption" sx={{ color: '#fbbf24', fontWeight: 700, letterSpacing: '1px', textTransform: 'uppercase', mb: 1, display: 'block' }}>
                      🛠️ Agents
                    </Typography>
                    {agents.map(u => <UserRow key={u.id} user={u} onDelete={handleDelete} />)}
                    <Divider sx={{ borderColor: 'rgba(71,85,105,0.2)', my: 2 }} />
                  </>
                )}
                {/* Users */}
                {regularUsers.length > 0 && (
                  <>
                    <Typography variant="caption" sx={{ color: '#34d399', fontWeight: 700, letterSpacing: '1px', textTransform: 'uppercase', mb: 1, display: 'block' }}>
                      👤 Users
                    </Typography>
                    {regularUsers.map(u => <UserRow key={u.id} user={u} onDelete={handleDelete} />)}
                  </>
                )}
              </>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
