import React from 'react';
import { useFormik } from 'formik';
import * as Yup from 'yup';
import {
  Card, CardContent, Typography, TextField, MenuItem,
  Button, Box, Divider, Chip, CircularProgress,
} from '@mui/material';
import SendIcon from '@mui/icons-material/Send';
import AddTaskIcon from '@mui/icons-material/AddTask';
import { ApiService } from '../services/api';
import { useAuth } from '../context/AuthContext';

const CATEGORIES = [
  { value: 'HARDWARE',  label: '🖥️  Hardware Issue' },
  { value: 'SOFTWARE',  label: '💻  Software & Apps' },
  { value: 'NETWORK',   label: '🌐  Network & VPN' },
  { value: 'ACCESS',    label: '🔐  Access & Permissions' },
  { value: 'OTHER',     label: '📋  Other Request' },
];

const PRIORITIES = [
  { value: 'LOW',    label: 'Low',    color: '#94a3b8' },
  { value: 'MEDIUM', label: 'Medium', color: '#60a5fa' },
  { value: 'HIGH',   label: 'High',   color: '#fbbf24' },
  { value: 'URGENT', label: 'Urgent', color: '#f87171' },
];

const inputSx = {
  mb: 2.5,
  '& .MuiOutlinedInput-root': {
    color: '#f1f5f9',
    bgcolor: 'rgba(15,23,42,0.6)',
    borderRadius: 2,
    '& fieldset': { borderColor: 'rgba(71,85,105,0.5)' },
    '&:hover fieldset': { borderColor: '#3b82f6' },
    '&.Mui-focused fieldset': { borderColor: '#3b82f6', borderWidth: '1.5px' },
  },
  '& .MuiInputLabel-root': { color: '#64748b' },
  '& .MuiInputLabel-root.Mui-focused': { color: '#3b82f6' },
  '& .MuiFormHelperText-root': { color: '#f87171' },
};

export default function CreateTicketForm({ onTicketCreated, onToast }) {
  const { user } = useAuth();

  const formik = useFormik({
    initialValues: { title: '', description: '', category: 'SOFTWARE', priority: 'MEDIUM' },
    validationSchema: Yup.object({
      title:       Yup.string().min(5, 'Minimum 5 characters').max(100).required('Title is required'),
      description: Yup.string().min(10, 'Minimum 10 characters').required('Description is required'),
      category:    Yup.string().required('Select a category'),
      priority:    Yup.string().required('Select a priority'),
    }),
    onSubmit: async (values, { resetForm, setSubmitting }) => {
      try {
        const payload = { ...values, status: 'OPEN', createdBy: user?.email || user?.name || 'User' };
        const res = await ApiService.createTicket(payload);
        if (res.success) {
          onToast('✅ Ticket created successfully!', 'success');
          resetForm();
          onTicketCreated();
        } else {
          onToast(res.message || 'Failed to create ticket', 'error');
        }
      } catch {
        onToast('❌ Cannot connect to backend API. Is the server running?', 'error');
      } finally {
        setSubmitting(false);
      }
    },
  });

  const selectedPriority = PRIORITIES.find(p => p.value === formik.values.priority);

  return (
    <Card
      sx={{
        background: 'linear-gradient(180deg, rgba(19,27,46,0.95) 0%, rgba(15,23,42,0.95) 100%)',
        border: '1px solid rgba(59,130,246,0.15)',
        borderRadius: 4,
        boxShadow: '0 25px 50px rgba(0,0,0,0.4)',
        overflow: 'visible',
      }}
    >
      <CardContent sx={{ p: 3 }}>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
          <Box sx={{ bgcolor: 'rgba(59,130,246,0.15)', p: 1, borderRadius: 2, display: 'flex' }}>
            <AddTaskIcon sx={{ color: '#60a5fa', fontSize: '1.3rem' }} />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 700, color: '#f1f5f9', lineHeight: 1 }}>
              New IT Ticket
            </Typography>
            <Typography variant="caption" sx={{ color: '#64748b' }}>
              Submit an IT support request
            </Typography>
          </Box>
          {selectedPriority && (
            <Chip
              label={selectedPriority.label}
              size="small"
              sx={{ ml: 'auto', bgcolor: `${selectedPriority.color}18`, color: selectedPriority.color, border: `1px solid ${selectedPriority.color}40`, fontWeight: 700, fontSize: '0.7rem' }}
            />
          )}
        </Box>

        <Divider sx={{ borderColor: 'rgba(71,85,105,0.3)', mb: 3 }} />

        <form onSubmit={formik.handleSubmit}>
          {/* Title */}
          <TextField
            fullWidth
            id="title"
            name="title"
            label="Issue Title *"
            placeholder="e.g. VPN not connecting from home office"
            size="small"
            sx={inputSx}
            value={formik.values.title}
            onChange={formik.handleChange}
            onBlur={formik.handleBlur}
            error={formik.touched.title && Boolean(formik.errors.title)}
            helperText={formik.touched.title && formik.errors.title}
          />

          {/* Category */}
          <TextField
            fullWidth select id="category" name="category" label="Category *" size="small" sx={inputSx}
            value={formik.values.category} onChange={formik.handleChange}
            SelectProps={{ MenuProps: { PaperProps: { sx: { bgcolor: '#1e293b', color: '#f1f5f9' } } } }}
          >
            {CATEGORIES.map(c => <MenuItem key={c.value} value={c.value}>{c.label}</MenuItem>)}
          </TextField>

          {/* Priority */}
          <TextField
            fullWidth select id="priority" name="priority" label="Priority *" size="small" sx={inputSx}
            value={formik.values.priority} onChange={formik.handleChange}
            SelectProps={{ MenuProps: { PaperProps: { sx: { bgcolor: '#1e293b', color: '#f1f5f9' } } } }}
          >
            {PRIORITIES.map(p => (
              <MenuItem key={p.value} value={p.value}>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                  <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: p.color }} />
                  {p.label}
                </Box>
              </MenuItem>
            ))}
          </TextField>

          {/* Description */}
          <TextField
            fullWidth multiline rows={4} id="description" name="description"
            label="Detailed Description *"
            placeholder="Describe the issue step-by-step, include error messages..."
            sx={{ ...inputSx, mb: 3 }}
            value={formik.values.description}
            onChange={formik.handleChange}
            onBlur={formik.handleBlur}
            error={formik.touched.description && Boolean(formik.errors.description)}
            helperText={formik.touched.description && formik.errors.description}
          />

          {/* Submit Button */}
          <Button
            type="submit"
            fullWidth
            variant="contained"
            disabled={formik.isSubmitting}
            endIcon={formik.isSubmitting ? <CircularProgress size={16} color="inherit" /> : <SendIcon />}
            sx={{
              py: 1.3,
              borderRadius: 2.5,
              fontWeight: 700,
              fontSize: '0.95rem',
              background: 'linear-gradient(135deg, #3b82f6, #2563eb)',
              boxShadow: '0 4px 20px rgba(37,99,235,0.4)',
              textTransform: 'none',
              '&:hover': { background: 'linear-gradient(135deg, #2563eb, #1d4ed8)', boxShadow: '0 6px 25px rgba(37,99,235,0.5)' },
              '&:disabled': { opacity: 0.6 },
            }}
          >
            {formik.isSubmitting ? 'Submitting...' : 'Submit IT Ticket'}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
