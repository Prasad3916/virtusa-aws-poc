import React, { useState } from 'react';
import { useFormik } from 'formik';
import * as Yup from 'yup';
import {
  Box, Card, CardContent, Typography, TextField,
  Button, Divider, CircularProgress, Alert, Tab, Tabs, Chip,
  InputAdornment, IconButton,
} from '@mui/material';
import ConfirmationNumberOutlinedIcon from '@mui/icons-material/ConfirmationNumberOutlined';
import LockOutlinedIcon   from '@mui/icons-material/LockOutlined';
import PersonAddIcon      from '@mui/icons-material/PersonAdd';
import EmailOutlinedIcon  from '@mui/icons-material/EmailOutlined';
import PersonOutlineIcon  from '@mui/icons-material/PersonOutline';
import VisibilityIcon     from '@mui/icons-material/Visibility';
import VisibilityOffIcon  from '@mui/icons-material/VisibilityOff';
import { ApiService } from '../services/api';
import { useAuth }    from '../context/AuthContext';

// ── Shared input styles ───────────────────────────────────────────────────────
const fieldSx = {
  mb: 2.5,
  '& .MuiOutlinedInput-root': {
    color: '#f1f5f9',
    bgcolor: 'rgba(15,23,42,0.7)',
    borderRadius: 2.5,
    '& fieldset':              { borderColor: 'rgba(71,85,105,0.4)' },
    '&:hover fieldset':        { borderColor: '#3b82f6' },
    '&.Mui-focused fieldset':  { borderColor: '#3b82f6', borderWidth: '1.5px' },
    '&.Mui-error fieldset':    { borderColor: '#f87171 !important' },
  },
  '& .MuiInputLabel-root':             { color: '#64748b' },
  '& .MuiInputLabel-root.Mui-focused': { color: '#3b82f6' },
  '& .MuiInputLabel-root.Mui-error':   { color: '#f87171' },
  '& .MuiFormHelperText-root':         { color: '#f87171', fontSize: '0.72rem', mt: 0.5 },
};

// ── Password field with show/hide ─────────────────────────────────────────────
function PasswordField({ id, name, label, formik }) {
  const [show, setShow] = useState(false);
  return (
    <TextField
      fullWidth id={id} name={name} label={label} size="small"
      type={show ? 'text' : 'password'}
      sx={fieldSx}
      value={formik.values[name]}
      onChange={formik.handleChange}
      onBlur={formik.handleBlur}
      error={formik.touched[name] && Boolean(formik.errors[name])}
      helperText={formik.touched[name] && formik.errors[name]}
      InputProps={{
        endAdornment: (
          <InputAdornment position="end">
            <IconButton size="small" onClick={() => setShow(s => !s)} edge="end"
              sx={{ color: '#64748b', '&:hover': { color: '#3b82f6' } }}>
              {show ? <VisibilityOffIcon fontSize="small" /> : <VisibilityIcon fontSize="small" />}
            </IconButton>
          </InputAdornment>
        ),
      }}
    />
  );
}

// ── Login Form ────────────────────────────────────────────────────────────────
function LoginForm({ onError, onSuccess }) {
  const { login } = useAuth();

  const formik = useFormik({
    initialValues: { email: '', password: '' },
    validationSchema: Yup.object({
      email:    Yup.string()
        .email('Enter a valid email address')
        .required('Email is required'),
      password: Yup.string()
        .min(4, 'Password must be at least 4 characters')
        .required('Password is required'),
    }),
    validateOnBlur: true,
    validateOnChange: false,
    onSubmit: async (values, { setSubmitting }) => {
      onError('');
      try {
        const res = await ApiService.login(values.email.trim(), values.password);
        if (res.success) {
          login(res.data);
          onSuccess();
        } else {
          onError(res.message || 'Login failed. Check your credentials.');
        }
      } catch (e) {
        const msg = e?.response?.data?.message;
        if (e?.response?.status === 401) onError('Invalid email or password');
        else if (!e?.response)           onError('Cannot connect to server. Make sure services are running.');
        else                             onError(msg || 'Login failed');
      } finally {
        setSubmitting(false);
      }
    },
  });

  return (
    <form onSubmit={formik.handleSubmit} noValidate>
      <TextField
        fullWidth id="login-email" name="email" label="Email Address" size="small"
        sx={fieldSx} value={formik.values.email}
        onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.email && Boolean(formik.errors.email)}
        helperText={formik.touched.email && formik.errors.email}
        InputProps={{ startAdornment: <InputAdornment position="start"><EmailOutlinedIcon sx={{ color: '#475569', fontSize: '1rem' }} /></InputAdornment> }}
      />
      <PasswordField id="login-password" name="password" label="Password" formik={formik} />

      <Button
        type="submit" fullWidth variant="contained"
        disabled={formik.isSubmitting}
        endIcon={formik.isSubmitting ? <CircularProgress size={16} color="inherit" /> : <LockOutlinedIcon />}
        sx={{
          py: 1.4, borderRadius: 2.5, fontWeight: 700, fontSize: '0.95rem', textTransform: 'none',
          background: 'linear-gradient(135deg, #3b82f6, #2563eb)',
          boxShadow: '0 4px 20px rgba(37,99,235,0.35)',
          '&:hover':    { background: 'linear-gradient(135deg, #2563eb, #1d4ed8)', boxShadow: '0 6px 24px rgba(37,99,235,0.5)' },
          '&:disabled': { opacity: 0.6, cursor: 'not-allowed' },
        }}
      >
        {formik.isSubmitting ? 'Signing in…' : 'Sign In'}
      </Button>
    </form>
  );
}

// ── Register Form (USER only) ─────────────────────────────────────────────────
function RegisterForm({ onError, onSuccess }) {
  const { login } = useAuth();

  const formik = useFormik({
    initialValues: { name: '', email: '', password: '', confirmPassword: '' },
    validationSchema: Yup.object({
      name: Yup.string()
        .trim()
        .min(2, 'Name must be at least 2 characters')
        .max(60, 'Name cannot exceed 60 characters')
        .matches(/^[a-zA-Z\s]+$/, 'Name can only contain letters and spaces')
        .required('Full name is required'),
      email: Yup.string()
        .email('Enter a valid email address')
        .required('Email is required'),
      password: Yup.string()
        .min(6, 'Password must be at least 6 characters')
        .matches(/[A-Z]/, 'Must contain at least one uppercase letter')
        .matches(/[0-9]/, 'Must contain at least one number')
        .required('Password is required'),
      confirmPassword: Yup.string()
        .oneOf([Yup.ref('password')], 'Passwords do not match')
        .required('Please confirm your password'),
    }),
    validateOnBlur: true,
    validateOnChange: false,
    onSubmit: async (values, { setSubmitting }) => {
      onError('');
      try {
        const res = await ApiService.register(values.name.trim(), values.email.trim(), values.password);
        if (res.success) {
          login(res.data);
          onSuccess();
        } else {
          onError(res.message || 'Registration failed');
        }
      } catch (e) {
        const msg = e?.response?.data?.message;
        if (e?.response?.status === 409) onError('This email is already registered');
        else if (!e?.response)            onError('Cannot connect to server. Make sure services are running.');
        else                              onError(msg || 'Registration failed');
      } finally {
        setSubmitting(false);
      }
    },
  });

  return (
    <form onSubmit={formik.handleSubmit} noValidate>
      {/* Role badge — fixed to USER */}
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2.5, p: 1.5, bgcolor: 'rgba(16,185,129,0.06)', borderRadius: 2.5, border: '1px solid rgba(16,185,129,0.2)' }}>
        <PersonOutlineIcon sx={{ color: '#34d399', fontSize: '1.1rem' }} />
        <Box>
          <Typography variant="caption" sx={{ color: '#34d399', fontWeight: 700, display: 'block', lineHeight: 1.2 }}>
            User Account
          </Typography>
          <Typography variant="caption" sx={{ color: '#64748b', fontSize: '0.68rem' }}>
            Submit & track your own IT support tickets
          </Typography>
        </Box>
        <Chip label="USER" size="small" sx={{ ml: 'auto', bgcolor: 'rgba(16,185,129,0.12)', color: '#34d399', border: '1px solid rgba(16,185,129,0.3)', fontWeight: 700, fontSize: '0.65rem' }} />
      </Box>

      <TextField
        fullWidth id="reg-name" name="name" label="Full Name" size="small"
        sx={fieldSx} value={formik.values.name}
        onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.name && Boolean(formik.errors.name)}
        helperText={formik.touched.name && formik.errors.name}
        InputProps={{ startAdornment: <InputAdornment position="start"><PersonOutlineIcon sx={{ color: '#475569', fontSize: '1rem' }} /></InputAdornment> }}
      />
      <TextField
        fullWidth id="reg-email" name="email" label="Email Address" size="small"
        sx={fieldSx} value={formik.values.email}
        onChange={formik.handleChange} onBlur={formik.handleBlur}
        error={formik.touched.email && Boolean(formik.errors.email)}
        helperText={formik.touched.email && formik.errors.email}
        InputProps={{ startAdornment: <InputAdornment position="start"><EmailOutlinedIcon sx={{ color: '#475569', fontSize: '1rem' }} /></InputAdornment> }}
      />
      <PasswordField id="reg-password"  name="password"        label="Password"         formik={formik} />
      <PasswordField id="reg-confirm"   name="confirmPassword" label="Confirm Password"  formik={formik} />

      {/* Password hints */}
      <Box sx={{ mb: 2.5, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
        {['Min 6 chars', 'One uppercase', 'One number'].map(hint => (
          <Typography key={hint} variant="caption" sx={{ color: '#475569', bgcolor: 'rgba(71,85,105,0.1)', px: 1, py: 0.3, borderRadius: 1, fontSize: '0.65rem' }}>
            ✓ {hint}
          </Typography>
        ))}
      </Box>

      <Button
        type="submit" fullWidth variant="contained"
        disabled={formik.isSubmitting}
        endIcon={formik.isSubmitting ? <CircularProgress size={16} color="inherit" /> : <PersonAddIcon />}
        sx={{
          py: 1.4, borderRadius: 2.5, fontWeight: 700, fontSize: '0.95rem', textTransform: 'none',
          background: 'linear-gradient(135deg, #10b981, #059669)',
          boxShadow: '0 4px 20px rgba(16,185,129,0.35)',
          '&:hover':    { background: 'linear-gradient(135deg, #059669, #047857)', boxShadow: '0 6px 24px rgba(16,185,129,0.5)' },
          '&:disabled': { opacity: 0.6 },
        }}
      >
        {formik.isSubmitting ? 'Creating account…' : 'Create Account'}
      </Button>
    </form>
  );
}

// ── LoginPage ─────────────────────────────────────────────────────────────────
export default function LoginPage() {
  const [tab,   setTab]   = useState(0);
  const [error, setError] = useState('');

  const handleTabChange = (_, v) => { setTab(v); setError(''); };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background:
          'radial-gradient(ellipse at 25% 25%, rgba(59,130,246,0.1) 0%, transparent 55%), ' +
          'radial-gradient(ellipse at 75% 75%, rgba(139,92,246,0.08) 0%, transparent 55%), ' +
          '#060a14',
        p: 2,
      }}
    >
      <Box sx={{ width: '100%', maxWidth: 430 }}>

        {/* Brand Header */}
        <Box sx={{ textAlign: 'center', mb: 4 }}>
          <Box sx={{
            display: 'inline-flex', p: 1.5, borderRadius: 3.5, mb: 2,
            background: 'linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%)',
            boxShadow: '0 8px 32px rgba(59,130,246,0.4)',
          }}>
            <ConfirmationNumberOutlinedIcon sx={{ color: 'white', fontSize: '2.2rem' }} />
          </Box>
          <Typography variant="h4" sx={{ fontWeight: 800, color: '#f8fafc', letterSpacing: '-0.5px' }}>
            Ticket<span style={{ color: '#3b82f6' }}>Desk</span>
          </Typography>
          <Typography variant="body2" sx={{ color: '#475569', mt: 0.5 }}>
            Enterprise IT Support Platform
          </Typography>
        </Box>

        {/* Roles info */}
        <Box sx={{ display: 'flex', gap: 1, justifyContent: 'center', mb: 3 }}>
          {[
            { label: 'Admin', color: '#f87171', bg: 'rgba(239,68,68,0.08)', border: 'rgba(239,68,68,0.25)', desc: 'Full control' },
            { label: 'Agent', color: '#fbbf24', bg: 'rgba(245,158,11,0.08)', border: 'rgba(245,158,11,0.25)', desc: 'Resolve tickets' },
            { label: 'User',  color: '#34d399', bg: 'rgba(16,185,129,0.08)', border: 'rgba(16,185,129,0.25)', desc: 'Submit tickets' },
          ].map(r => (
            <Box key={r.label} sx={{ textAlign: 'center', px: 1.5, py: 1, bgcolor: r.bg, border: `1px solid ${r.border}`, borderRadius: 2, flex: 1 }}>
              <Typography variant="caption" sx={{ color: r.color, fontWeight: 700, display: 'block', fontSize: '0.75rem' }}>{r.label}</Typography>
              <Typography variant="caption" sx={{ color: '#475569', fontSize: '0.62rem' }}>{r.desc}</Typography>
            </Box>
          ))}
        </Box>

        {/* Card */}
        <Card sx={{
          background: 'linear-gradient(180deg, rgba(19,27,46,0.98) 0%, rgba(13,19,38,0.98) 100%)',
          border: '1px solid rgba(59,130,246,0.15)',
          borderRadius: 4,
          boxShadow: '0 30px 60px rgba(0,0,0,0.5)',
        }}>
          <CardContent sx={{ p: 3.5 }}>
            <Tabs
              value={tab} onChange={handleTabChange}
              variant="fullWidth"
              sx={{
                mb: 3,
                '& .MuiTab-root':       { color: '#475569', fontWeight: 600, textTransform: 'none', fontSize: '0.9rem', borderRadius: 2 },
                '& .Mui-selected':      { color: '#f8fafc !important' },
                '& .MuiTabs-indicator': { bgcolor: '#3b82f6', height: '2px', borderRadius: '2px' },
              }}
            >
              <Tab id="tab-login"    label="Sign In"      disableRipple />
              <Tab id="tab-register" label="Register"     disableRipple />
            </Tabs>

            {error && (
              <Alert
                severity="error"
                sx={{
                  mb: 2.5, borderRadius: 2.5, fontSize: '0.82rem',
                  bgcolor: 'rgba(239,68,68,0.08)', color: '#f87171',
                  border: '1px solid rgba(239,68,68,0.25)',
                  '& .MuiAlert-icon': { color: '#f87171' },
                }}
              >
                {error}
              </Alert>
            )}

            {tab === 0
              ? <LoginForm   onError={setError} onSuccess={() => setError('')} />
              : <RegisterForm onError={setError} onSuccess={() => setError('')} />
            }

            {tab === 1 && (
              <Box sx={{ mt: 2, p: 1.5, bgcolor: 'rgba(245,158,11,0.06)', borderRadius: 2, border: '1px solid rgba(245,158,11,0.2)' }}>
                <Typography variant="caption" sx={{ color: '#94a3b8', display: 'block', textAlign: 'center', lineHeight: 1.5 }}>
                  🛠️  <strong style={{ color: '#fbbf24' }}>Agent accounts</strong> are created by the Admin from inside the dashboard.
                </Typography>
              </Box>
            )}
          </CardContent>
        </Card>
      </Box>
    </Box>
  );
}
