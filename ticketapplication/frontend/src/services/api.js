import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_BASE || '/api/v1';

const http = axios.create({ baseURL: API_BASE, timeout: 15000 });
const httpMultipart = axios.create({ baseURL: API_BASE, timeout: 30000 });

// Attach JWT + role headers to every request
const attachHeaders = (config) => {
  const token = localStorage.getItem('auth_token');
  const role  = localStorage.getItem('auth_role');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  if (role)  config.headers['X-User-Role'] = role;
  return config;
};
http.interceptors.request.use(attachHeaders);
httpMultipart.interceptors.request.use(attachHeaders);

http.interceptors.response.use(
  r => r,
  e => {
    console.error('[API]', e?.response?.status, e?.config?.url, e?.response?.data?.message || e.message);
    return Promise.reject(e);
  }
);

export const ApiService = {

  // ── Auth ──────────────────────────────────────────────────────────────────
  login: async (email, password) => {
    const res = await http.post('/auth/login', { email, password });
    return res.data;
  },

  // Public: USER self-registration only
  register: async (name, email, password) => {
    const res = await http.post('/auth/register', { name, email, password, role: 'USER' });
    return res.data;
  },

  // Admin only: create an AGENT account
  createAgent: async (name, email, password) => {
    const res = await http.post('/auth/agents', { name, email, password, role: 'AGENT' });
    return res.data;
  },

  // Admin only: list all users
  getUsers: async () => {
    const res = await http.get('/auth/users');
    return res.data;
  },

  // Admin only: list only agents
  getAgents: async () => {
    const res = await http.get('/auth/agents');
    return res.data;
  },

  // Admin only: delete a user/agent
  deleteUser: async (id) => {
    const res = await http.delete(`/auth/users/${id}`);
    return res.data;
  },

  // ── Dashboard ─────────────────────────────────────────────────────────────
  getDashboardSummary: async () => {
    const res = await http.get('/dashboard/summary');
    return res.data;
  },

  // ── Tickets ───────────────────────────────────────────────────────────────
  getTickets: async (params = {}) => {
    const res = await http.get('/tickets', { params });
    return res.data;
  },

  createTicket: async (payload) => {
    const res = await http.post('/tickets', payload);
    return res.data;
  },

  updateStatus: async (id, status) => {
    const res = await http.patch(`/tickets/${id}/status`, { status });
    return res.data;
  },

  assignTicket: async (id, assignedTo) => {
    const res = await http.patch(`/tickets/${id}/assign`, { assignedTo });
    return res.data;
  },

  unassignTicket: async (id) => {
    const res = await http.patch(`/tickets/${id}/assign`, { assignedTo: '' });
    return res.data;
  },

  deleteTicket: async (id) => {
    const res = await http.delete(`/tickets/${id}`);
    return res.data;
  },

  // ── Comments (embedded in ticket-service) ────────────────────────────────
  addComment: async (ticketId, content, author) => {
    const res = await http.post(`/tickets/${ticketId}/comments`, { content, author });
    return res.data;
  },

  // ── Attachments ───────────────────────────────────────────────────────────
  getAttachments: async (ticketId) => {
    const res = await http.get(`/attachments/ticket/${ticketId}`);
    return res.data;
  },

  uploadAttachment: async (ticketId, file) => {
    const form = new FormData();
    form.append('file', file);
    const res = await httpMultipart.post(`/attachments/ticket/${ticketId}/upload`, form);
    return res.data;
  },

  downloadAttachment: (attachmentId) => `${API_BASE}/attachments/${attachmentId}/download`,

  deleteAttachment: async (attachmentId) => {
    const res = await http.delete(`/attachments/${attachmentId}`);
    return res.data;
  },

  // ── Health ────────────────────────────────────────────────────────────────
  checkHealth: async () => {
    const res = await http.get('/actuator/health');
    return res.data;
  },
};
