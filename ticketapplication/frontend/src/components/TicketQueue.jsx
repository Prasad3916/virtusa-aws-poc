import React, { useState, useEffect, useCallback } from 'react';
import {
  Card, CardContent, Typography, Box, TextField, MenuItem,
  Chip, Button, InputAdornment, Collapse, Divider, Skeleton,
  IconButton, Tooltip, LinearProgress, List, ListItem,
  ListItemText, ListItemSecondaryAction, Select, FormControl, InputLabel
} from '@mui/material';
import SearchIcon          from '@mui/icons-material/Search';
import FormatListBulletedIcon from '@mui/icons-material/FormatListBulleted';
import ReplyIcon           from '@mui/icons-material/Reply';
import ExpandMoreIcon      from '@mui/icons-material/ExpandMore';
import ExpandLessIcon      from '@mui/icons-material/ExpandLess';
import CommentIcon         from '@mui/icons-material/Comment';
import AttachFileIcon      from '@mui/icons-material/AttachFile';
import DeleteOutlineIcon   from '@mui/icons-material/DeleteOutline';
import FileDownloadIcon    from '@mui/icons-material/FileDownload';
import CloudUploadIcon     from '@mui/icons-material/CloudUpload';
import PersonIcon          from '@mui/icons-material/Person';
import AssignmentIndIcon   from '@mui/icons-material/AssignmentInd';
import { ApiService }      from '../services/api';
import { useAuth }         from '../context/AuthContext';

// ── Status / Priority config ──────────────────────────────────────────────────
const STATUS_CONFIG = {
  OPEN:        { color: '#60a5fa',  bg: 'rgba(59,130,246,0.12)',  border: 'rgba(59,130,246,0.3)',  label: 'OPEN' },
  IN_PROGRESS: { color: '#fbbf24',  bg: 'rgba(245,158,11,0.12)',  border: 'rgba(245,158,11,0.3)',  label: 'IN PROGRESS' },
  RESOLVED:    { color: '#34d399',  bg: 'rgba(16,185,129,0.12)',  border: 'rgba(16,185,129,0.3)',  label: 'RESOLVED' },
  CLOSED:      { color: '#94a3b8',  bg: 'rgba(100,116,139,0.12)', border: 'rgba(100,116,139,0.3)', label: 'CLOSED' },
};

const PRIORITY_CONFIG = {
  URGENT: { color: '#f87171', dot: '#ef4444' },
  HIGH:   { color: '#fb923c', dot: '#f97316' },
  MEDIUM: { color: '#60a5fa', dot: '#3b82f6' },
  LOW:    { color: '#94a3b8', dot: '#64748b' },
};

const TRANSITIONS = {
  OPEN:        ['IN_PROGRESS'],
  IN_PROGRESS: ['RESOLVED'],
  RESOLVED:    ['CLOSED'],
  CLOSED:      [],
};

const selectSx = {
  '& .MuiOutlinedInput-root': {
    color: '#f1f5f9', bgcolor: 'rgba(15,23,42,0.6)', borderRadius: 2, fontSize: '0.875rem',
    '& fieldset': { borderColor: 'rgba(71,85,105,0.5)' },
    '&:hover fieldset': { borderColor: '#3b82f6' },
    '&.Mui-focused fieldset': { borderColor: '#3b82f6' },
  },
  '& .MuiInputLabel-root': { color: '#64748b', fontSize: '0.875rem' },
};

const formatBytes = (bytes) => {
  if (!bytes) return '';
  if (bytes < 1024)        return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};

// ── TicketCard ────────────────────────────────────────────────────────────────
function TicketCard({ ticket, agents, onRefresh, onToast }) {
  const { user, isAdmin, isAgent } = useAuth();
  const [expanded,    setExpanded]    = useState(false);
  const [activeTab,   setActiveTab]   = useState('comments'); // 'comments' | 'attachments'
  const [comment,     setComment]     = useState('');
  const [submitting,  setSubmitting]  = useState(false);
  const [attachments, setAttachments] = useState([]);
  const [attachLoad,  setAttachLoad]  = useState(false);
  const [uploading,   setUploading]   = useState(false);
  const [uploadPct,   setUploadPct]   = useState(0);
  const [assignedAgent, setAssignedAgent] = useState(ticket.assignedTo || '');

  const sc          = STATUS_CONFIG[ticket.status]    || STATUS_CONFIG.OPEN;
  const pc          = PRIORITY_CONFIG[ticket.priority] || PRIORITY_CONFIG.MEDIUM;
  const transitions = TRANSITIONS[ticket.status]       || [];

  const handleExpand = useCallback(async () => {
    const next = !expanded;
    setExpanded(next);
    if (next && activeTab === 'attachments') await loadAttachments();
  }, [expanded, activeTab]);

  const loadAttachments = useCallback(async () => {
    setAttachLoad(true);
    try {
      const res = await ApiService.getAttachments(ticket.id);
      if (res.success) setAttachments(res.data || []);
    } catch {
      /* silently fail */
    } finally {
      setAttachLoad(false);
    }
  }, [ticket.id]);

  const handleTabChange = async (tab) => {
    setActiveTab(tab);
    if (tab === 'attachments') await loadAttachments();
  };

  const handleStatusChange = async (newStatus) => {
    try {
      await ApiService.updateStatus(ticket.id, newStatus);
      onToast(`Ticket #${ticket.id} → ${newStatus}`, 'success');
      onRefresh();
    } catch {
      onToast('Failed to update status', 'error');
    }
  };

  const handleAssignAgent = async (agentEmail) => {
    setAssignedAgent(agentEmail);
    try {
      await ApiService.assignTicket(ticket.id, agentEmail);
      onToast(`Ticket #${ticket.id} assigned to ${agentEmail}`, 'success');
      onRefresh();
    } catch {
      onToast('Failed to assign agent', 'error');
    }
  };

  const handleDeleteTicket = async () => {
    if (!window.confirm(`Are you sure you want to delete ticket #${ticket.id}?`)) return;
    try {
      await ApiService.deleteTicket(ticket.id);
      onToast(`Ticket #${ticket.id} deleted`, 'info');
      onRefresh();
    } catch {
      onToast('Failed to delete ticket', 'error');
    }
  };

  const handleComment = async () => {
    if (!comment.trim()) return;
    setSubmitting(true);
    try {
      await ApiService.addComment(ticket.id, comment.trim(), user?.name || user?.email || 'User');
      setComment('');
      onToast('Comment added', 'success');
      onRefresh();
    } catch {
      onToast('Failed to add comment', 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      onToast('File must be smaller than 10 MB', 'error');
      return;
    }

    setUploading(true);
    setUploadPct(0);
    const timer = setInterval(() => setUploadPct(p => Math.min(p + 15, 90)), 200);

    try {
      const res = await ApiService.uploadAttachment(ticket.id, file);
      clearInterval(timer);
      setUploadPct(100);
      if (res.success) {
        onToast(`"${file.name}" uploaded successfully`, 'success');
        await loadAttachments();
      } else {
        onToast(res.message || 'Upload failed', 'error');
      }
    } catch (err) {
      clearInterval(timer);
      onToast(err?.response?.data?.message || 'Upload failed', 'error');
    } finally {
      setTimeout(() => { setUploading(false); setUploadPct(0); }, 600);
      e.target.value = '';
    }
  };

  const handleDeleteAttachment = async (attachId, fileName) => {
    try {
      await ApiService.deleteAttachment(attachId);
      onToast(`"${fileName}" deleted`, 'info');
      setAttachments(a => a.filter(x => x.id !== attachId));
    } catch {
      onToast('Delete failed', 'error');
    }
  };

  const formatDate = (d) =>
    d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';

  return (
    <Box
      sx={{
        bgcolor: 'rgba(10,14,26,0.7)',
        border: '1px solid rgba(71,85,105,0.3)',
        borderRadius: 3,
        mb: 2,
        overflow: 'hidden',
        transition: 'all 0.25s ease',
        '&:hover': { border: '1px solid rgba(59,130,246,0.35)', bgcolor: 'rgba(10,14,26,0.9)' },
      }}
    >
      {/* Priority stripe */}
      <Box sx={{ height: 3, background: `linear-gradient(90deg, ${pc.dot}, transparent)` }} />

      <Box sx={{ p: 2.5 }}>
        {/* Top Row */}
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', mb: 1.5 }}>
          <Box sx={{ flex: 1, mr: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5, flexWrap: 'wrap' }}>
              <Typography variant="caption" sx={{ color: '#3b82f6', fontWeight: 700, fontFamily: 'monospace' }}>
                #{String(ticket.id).padStart(4, '0')}
              </Typography>
              <Box sx={{ width: 4, height: 4, borderRadius: '50%', bgcolor: '#334155' }} />
              <Typography variant="caption" sx={{ color: '#64748b' }}>{ticket.category}</Typography>
              <Box sx={{ width: 4, height: 4, borderRadius: '50%', bgcolor: '#334155' }} />
              <Box sx={{ width: 6, height: 6, borderRadius: '50%', bgcolor: pc.dot }} />
              <Typography variant="caption" sx={{ color: pc.color, fontWeight: 600 }}>{ticket.priority}</Typography>
              
              {ticket.assignedTo && (
                <>
                  <Box sx={{ width: 4, height: 4, borderRadius: '50%', bgcolor: '#334155' }} />
                  <Chip
                    icon={<AssignmentIndIcon sx={{ fontSize: '0.75rem !important', color: '#fbbf24' }} />}
                    label={`Agent: ${ticket.assignedTo}`}
                    size="small"
                    sx={{ height: 20, bgcolor: 'rgba(245,158,11,0.1)', color: '#fbbf24', border: '1px solid rgba(245,158,11,0.3)', fontSize: '0.65rem', fontWeight: 600 }}
                  />
                </>
              )}
            </Box>
            <Typography variant="body1" sx={{ fontWeight: 600, color: '#f1f5f9', lineHeight: 1.3 }}>
              {ticket.title}
            </Typography>
          </Box>

          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Chip
              label={sc.label}
              size="small"
              sx={{ bgcolor: sc.bg, color: sc.color, border: `1px solid ${sc.border}`, fontWeight: 700, fontSize: '0.68rem', letterSpacing: '0.5px' }}
            />
            {isAdmin && (
              <Tooltip title="Delete ticket (Admin)">
                <IconButton size="small" onClick={handleDeleteTicket} sx={{ color: '#64748b', '&:hover': { color: '#f87171' } }}>
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            )}
            <Tooltip title={expanded ? 'Collapse' : 'Expand details'}>
              <IconButton size="small" onClick={handleExpand} sx={{ color: '#64748b', '&:hover': { color: '#60a5fa' } }}>
                {expanded ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
              </IconButton>
            </Tooltip>
          </Box>
        </Box>

        {/* Description */}
        <Typography variant="body2" sx={{ color: '#94a3b8', lineHeight: 1.6, mb: 1.5 }}>
          {ticket.description}
        </Typography>

        {/* Admin Assign Agent Controls & Created Date */}
        <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 1.5 }}>
          <Typography variant="caption" sx={{ color: '#475569' }}>
            Created by: {ticket.createdBy || 'User'} · {formatDate(ticket.createdAt)}
          </Typography>

          {/* Admin Assign Agent Dropdown */}
          {isAdmin && (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="caption" sx={{ color: '#fbbf24', fontWeight: 600 }}>Assign Agent:</Typography>
              <TextField
                select
                size="small"
                value={assignedAgent}
                onChange={e => handleAssignAgent(e.target.value)}
                sx={{ width: 180, ...selectSx, '& .MuiOutlinedInput-root': { height: 30, fontSize: '0.75rem' } }}
                SelectProps={{ MenuProps: { PaperProps: { sx: { bgcolor: '#1e293b', color: '#f1f5f9' } } } }}
              >
                <MenuItem value="">Unassigned</MenuItem>
                {agents.map(ag => (
                  <MenuItem key={ag.id} value={ag.email}>
                    {ag.name} ({ag.email})
                  </MenuItem>
                ))}
              </TextField>
            </Box>
          )}
        </Box>

        {/* Status Transitions — AGENT and ADMIN only */}
        {(isAdmin || isAgent) && transitions.length > 0 && (
          <Box sx={{ display: 'flex', gap: 1, mt: 1.5, flexWrap: 'wrap' }}>
            {transitions.map(t => {
              const tc = STATUS_CONFIG[t];
              return (
                <Button
                  key={t}
                  size="small"
                  variant="outlined"
                  onClick={() => handleStatusChange(t)}
                  sx={{
                    fontSize: '0.72rem', fontWeight: 600, borderRadius: 2, textTransform: 'none', py: 0.3,
                    borderColor: tc?.border, color: tc?.color,
                    '&:hover': { bgcolor: tc?.bg, borderColor: tc?.color },
                  }}
                >
                  Move → {tc?.label}
                </Button>
              );
            })}
          </Box>
        )}

        {/* Expandable Panel */}
        <Collapse in={expanded}>
          <Divider sx={{ borderColor: 'rgba(71,85,105,0.25)', mt: 2, mb: 2 }} />

          {/* Tab Switcher */}
          <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
            {[
              { key: 'comments',    icon: <CommentIcon sx={{ fontSize: '0.9rem' }} />,    label: `Comments (${ticket.comments?.length || 0})` },
              { key: 'attachments', icon: <AttachFileIcon sx={{ fontSize: '0.9rem' }} />, label: `Attachments (${attachments.length})` },
            ].map(tab => (
              <Button
                key={tab.key}
                size="small"
                startIcon={tab.icon}
                onClick={() => handleTabChange(tab.key)}
                sx={{
                  textTransform: 'none', fontSize: '0.78rem',
                  fontWeight: activeTab === tab.key ? 700 : 400,
                  borderRadius: 2, px: 1.5,
                  color: activeTab === tab.key ? '#60a5fa' : '#64748b',
                  bgcolor: activeTab === tab.key ? 'rgba(59,130,246,0.1)' : 'transparent',
                  border: activeTab === tab.key ? '1px solid rgba(59,130,246,0.3)' : '1px solid transparent',
                }}
              >
                {tab.label}
              </Button>
            ))}
          </Box>

          {/* ── COMMENTS TAB ─────────────────────────────────────────────── */}
          {activeTab === 'comments' && (
            <>
              {ticket.comments?.length > 0 ? (
                ticket.comments.map((c, idx) => (
                  <Box
                    key={idx}
                    sx={{
                      bgcolor: 'rgba(30,41,59,0.5)',
                      borderLeft: '3px solid #3b82f6',
                      borderRadius: '0 8px 8px 0',
                      p: 1.5, mb: 1,
                    }}
                  >
                    <Typography variant="caption" sx={{ color: '#60a5fa', fontWeight: 700 }}>{c.author}</Typography>
                    <Typography variant="body2" sx={{ color: '#cbd5e1', mt: 0.25, lineHeight: 1.5 }}>{c.content}</Typography>
                  </Box>
                ))
              ) : (
                <Typography variant="caption" sx={{ color: '#475569' }}>
                  No comments yet. Be the first to comment.
                </Typography>
              )}

              <Box sx={{ display: 'flex', gap: 1, mt: 1.5 }}>
                <TextField
                  fullWidth size="small" placeholder="Write a comment..."
                  value={comment}
                  onChange={e => setComment(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && !e.shiftKey && handleComment()}
                  sx={{
                    '& .MuiOutlinedInput-root': {
                      color: '#f1f5f9', bgcolor: 'rgba(15,23,42,0.8)', borderRadius: 2, fontSize: '0.85rem',
                      '& fieldset': { borderColor: 'rgba(71,85,105,0.4)' },
                      '&:hover fieldset': { borderColor: '#3b82f6' },
                      '&.Mui-focused fieldset': { borderColor: '#3b82f6' },
                    },
                  }}
                />
                <Button
                  variant="contained" size="small"
                  disabled={submitting || !comment.trim()}
                  onClick={handleComment}
                  endIcon={<ReplyIcon fontSize="small" />}
                  sx={{
                    borderRadius: 2, textTransform: 'none', fontWeight: 600, px: 2,
                    background: 'linear-gradient(135deg, #3b82f6, #2563eb)',
                    '&:disabled': { opacity: 0.5 },
                  }}
                >
                  Reply
                </Button>
              </Box>
            </>
          )}

          {/* ── ATTACHMENTS TAB ──────────────────────────────────────────── */}
          {activeTab === 'attachments' && (
            <>
              {/* Upload Button */}
              <Box sx={{ mb: 2 }}>
                <Button
                  component="label"
                  variant="outlined"
                  size="small"
                  startIcon={<CloudUploadIcon />}
                  disabled={uploading}
                  sx={{
                    borderRadius: 2, textTransform: 'none', fontWeight: 600, fontSize: '0.8rem',
                    borderColor: 'rgba(59,130,246,0.4)', color: '#60a5fa',
                    '&:hover': { bgcolor: 'rgba(59,130,246,0.08)', borderColor: '#3b82f6' },
                  }}
                >
                  {uploading ? 'Uploading...' : 'Upload File'}
                  <input type="file" hidden onChange={handleFileUpload} />
                </Button>
                <Typography variant="caption" sx={{ ml: 1.5, color: '#475569' }}>
                  Max 10 MB per file
                </Typography>
              </Box>

              {/* Upload Progress */}
              {uploading && (
                <Box sx={{ mb: 1.5 }}>
                  <LinearProgress
                    variant="determinate"
                    value={uploadPct}
                    sx={{
                      borderRadius: 2, height: 4,
                      bgcolor: 'rgba(59,130,246,0.15)',
                      '& .MuiLinearProgress-bar': { bgcolor: '#3b82f6' },
                    }}
                  />
                  <Typography variant="caption" sx={{ color: '#64748b', mt: 0.5, display: 'block' }}>
                    {uploadPct}%
                  </Typography>
                </Box>
              )}

              {/* Attachment List */}
              {attachLoad ? (
                <Skeleton variant="rounded" height={60} sx={{ bgcolor: 'rgba(255,255,255,0.04)', borderRadius: 2 }} />
              ) : attachments.length > 0 ? (
                <List dense disablePadding>
                  {attachments.map(a => (
                    <ListItem
                      key={a.id}
                      sx={{
                        bgcolor: 'rgba(30,41,59,0.4)',
                        borderRadius: 2, mb: 0.75,
                        border: '1px solid rgba(71,85,105,0.2)',
                        '&:hover': { bgcolor: 'rgba(30,41,59,0.7)' },
                      }}
                    >
                      <AttachFileIcon sx={{ color: '#3b82f6', fontSize: '1rem', mr: 1 }} />
                      <ListItemText
                        primary={
                          <Typography variant="body2" sx={{ color: '#f1f5f9', fontWeight: 500, fontSize: '0.82rem' }}>
                            {a.originalFileName}
                          </Typography>
                        }
                        secondary={
                          <Typography variant="caption" sx={{ color: '#475569' }}>
                            {formatBytes(a.fileSize)} · {a.contentType}
                          </Typography>
                        }
                      />
                      <ListItemSecondaryAction>
                        <Tooltip title="Download">
                          <IconButton
                            size="small"
                            href={ApiService.downloadAttachment(a.id)}
                            target="_blank"
                            rel="noopener noreferrer"
                            sx={{ color: '#60a5fa', '&:hover': { color: '#93c5fd' } }}
                          >
                            <FileDownloadIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton
                            size="small"
                            onClick={() => handleDeleteAttachment(a.id, a.originalFileName)}
                            sx={{ color: '#64748b', '&:hover': { color: '#f87171' } }}
                          >
                            <DeleteOutlineIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </ListItemSecondaryAction>
                    </ListItem>
                  ))}
                </List>
              ) : (
                <Typography variant="caption" sx={{ color: '#475569' }}>
                  No attachments yet. Upload a file to get started.
                </Typography>
              )}
            </>
          )}
        </Collapse>
      </Box>
    </Box>
  );
}

// ── TicketQueue ───────────────────────────────────────────────────────────────
export default function TicketQueue({ tickets, loading, onRefresh, onToast }) {
  const { user, isAdmin, isAgent, isUser } = useAuth();
  const [search,         setSearch]   = useState('');
  const [filterStatus,   setFilter]   = useState('');
  const [filterPriority, setFilterP]  = useState('');
  const [agents,         setAgents]   = useState([]);

  useEffect(() => {
    if (isAdmin) {
      ApiService.getUsers()
        .then(res => {
          if (res.success && Array.isArray(res.data)) {
            setAgents(res.data.filter(u => u.role === 'AGENT'));
          }
        })
        .catch(() => {});
    }
  }, [isAdmin]);

  // Role filtering:
  // Admin -> Sees ALL tickets
  // Agent -> Sees ONLY tickets assigned to them
  // User  -> Sees ONLY tickets created by them
  const filtered = tickets.filter(t => {
    const q = search.toLowerCase();
    const matchesSearch = t.title.toLowerCase().includes(q) || t.description.toLowerCase().includes(q);
    const matchesStatus = filterStatus ? t.status === filterStatus : true;
    const matchesPriority = filterPriority ? t.priority === filterPriority : true;

    let matchesRole = true;
    if (isAgent) {
      matchesRole = t.assignedTo === user?.email || t.assignedTo === user?.name;
    } else if (isUser) {
      matchesRole = t.createdBy === user?.email || t.createdBy === user?.name;
    }

    return matchesSearch && matchesStatus && matchesPriority && matchesRole;
  });

  return (
    <Card
      sx={{
        background: 'linear-gradient(180deg, rgba(19,27,46,0.95) 0%, rgba(15,23,42,0.95) 100%)',
        border: '1px solid rgba(59,130,246,0.15)',
        borderRadius: 4,
        boxShadow: '0 25px 50px rgba(0,0,0,0.4)',
      }}
    >
      <CardContent sx={{ p: 3 }}>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 3 }}>
          <Box sx={{ bgcolor: 'rgba(52,211,153,0.12)', p: 1, borderRadius: 2, display: 'flex' }}>
            <FormatListBulletedIcon sx={{ color: '#34d399', fontSize: '1.3rem' }} />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 700, color: '#f1f5f9', lineHeight: 1 }}>
              {isAgent ? 'Assigned Ticket Queue' : isUser ? 'My Created Tickets' : 'Live Ticket Queue'}
            </Typography>
            <Typography variant="caption" sx={{ color: '#64748b' }}>
              {filtered.length} ticket{filtered.length !== 1 ? 's' : ''} showing
            </Typography>
          </Box>
          {filterStatus && (
            <Chip
              label={filterStatus} size="small" onDelete={() => setFilter('')}
              sx={{ ml: 'auto', ...STATUS_CONFIG[filterStatus] && { bgcolor: STATUS_CONFIG[filterStatus].bg, color: STATUS_CONFIG[filterStatus].color } }}
            />
          )}
        </Box>

        {/* Filter Toolbar */}
        <Box sx={{ display: 'flex', gap: 1.5, mb: 3, flexWrap: 'wrap' }}>
          <TextField
            size="small" placeholder="Search tickets..."
            value={search} onChange={e => setSearch(e.target.value)}
            sx={{ flex: 1, minWidth: 160, ...selectSx }}
            InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon sx={{ color: '#475569', fontSize: '1.1rem' }} /></InputAdornment> }}
          />
          <TextField
            select size="small" value={filterStatus} onChange={e => setFilter(e.target.value)}
            sx={{ width: 150, ...selectSx }}
            SelectProps={{ MenuProps: { PaperProps: { sx: { bgcolor: '#1e293b', color: '#f1f5f9' } } } }}
            label="Status"
          >
            <MenuItem value="">All Status</MenuItem>
            {Object.keys(STATUS_CONFIG).map(s => <MenuItem key={s} value={s}>{s}</MenuItem>)}
          </TextField>
          <TextField
            select size="small" value={filterPriority} onChange={e => setFilterP(e.target.value)}
            sx={{ width: 150, ...selectSx }}
            SelectProps={{ MenuProps: { PaperProps: { sx: { bgcolor: '#1e293b', color: '#f1f5f9' } } } }}
            label="Priority"
          >
            <MenuItem value="">All Priority</MenuItem>
            {Object.keys(PRIORITY_CONFIG).map(p => <MenuItem key={p} value={p}>{p}</MenuItem>)}
          </TextField>
        </Box>

        <Divider sx={{ borderColor: 'rgba(71,85,105,0.25)', mb: 3 }} />

        {/* Ticket List */}
        {loading ? (
          [...Array(3)].map((_, i) => (
            <Skeleton key={i} variant="rounded" height={120} sx={{ bgcolor: 'rgba(255,255,255,0.04)', mb: 2, borderRadius: 3 }} />
          ))
        ) : filtered.length === 0 ? (
          <Box sx={{ textAlign: 'center', py: 6 }}>
            <Typography variant="h6" sx={{ color: '#64748b', mb: 1 }}>No tickets found</Typography>
            <Typography variant="body2" sx={{ color: '#475569' }}>
              {isAgent
                ? 'No tickets currently assigned to you'
                : isUser
                ? 'You have not created any IT support tickets yet'
                : 'Try adjusting your search filters'}
            </Typography>
          </Box>
        ) : (
          filtered.map(t => (
            <TicketCard key={t.id} ticket={t} agents={agents} onRefresh={onRefresh} onToast={onToast} />
          ))
        )}
      </CardContent>
    </Card>
  );
}
