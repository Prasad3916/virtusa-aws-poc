import React from 'react';
import { Grid, Card, CardContent, Typography, Box, Skeleton } from '@mui/material';
import TrendingUpIcon from '@mui/icons-material/TrendingUp';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import SyncIcon from '@mui/icons-material/Sync';
import VerifiedIcon from '@mui/icons-material/Verified';
import LockIcon from '@mui/icons-material/Lock';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';
import PriorityHighIcon from '@mui/icons-material/PriorityHigh';

const CARDS = (stats) => [
  {
    title: 'Total Tickets',
    value: stats?.totalTickets ?? 0,
    color: '#f8fafc',
    glow: '#3b82f6',
    bg: 'linear-gradient(135deg, rgba(59,130,246,0.15), rgba(59,130,246,0.05))',
    border: 'rgba(59,130,246,0.25)',
    icon: <TrendingUpIcon />,
  },
  {
    title: 'Open',
    value: stats?.statusCounts?.OPEN ?? 0,
    color: '#60a5fa',
    glow: '#3b82f6',
    bg: 'linear-gradient(135deg, rgba(59,130,246,0.12), rgba(59,130,246,0.03))',
    border: 'rgba(59,130,246,0.2)',
    icon: <PendingActionsIcon />,
  },
  {
    title: 'In Progress',
    value: stats?.statusCounts?.IN_PROGRESS ?? 0,
    color: '#fbbf24',
    glow: '#f59e0b',
    bg: 'linear-gradient(135deg, rgba(245,158,11,0.12), rgba(245,158,11,0.03))',
    border: 'rgba(245,158,11,0.2)',
    icon: <SyncIcon />,
  },
  {
    title: 'Resolved',
    value: stats?.statusCounts?.RESOLVED ?? 0,
    color: '#34d399',
    glow: '#10b981',
    bg: 'linear-gradient(135deg, rgba(16,185,129,0.12), rgba(16,185,129,0.03))',
    border: 'rgba(16,185,129,0.2)',
    icon: <VerifiedIcon />,
  },
  {
    title: 'Closed',
    value: stats?.statusCounts?.CLOSED ?? 0,
    color: '#94a3b8',
    glow: '#64748b',
    bg: 'linear-gradient(135deg, rgba(100,116,139,0.12), rgba(100,116,139,0.03))',
    border: 'rgba(100,116,139,0.2)',
    icon: <LockIcon />,
  },
  {
    title: 'Urgent',
    value: stats?.priorityCounts?.URGENT ?? 0,
    color: '#f87171',
    glow: '#ef4444',
    bg: 'linear-gradient(135deg, rgba(239,68,68,0.12), rgba(239,68,68,0.03))',
    border: 'rgba(239,68,68,0.2)',
    icon: <ErrorOutlineIcon />,
  },
  {
    title: 'High Priority',
    value: stats?.priorityCounts?.HIGH ?? 0,
    color: '#fb923c',
    glow: '#f97316',
    bg: 'linear-gradient(135deg, rgba(249,115,22,0.12), rgba(249,115,22,0.03))',
    border: 'rgba(249,115,22,0.2)',
    icon: <PriorityHighIcon />,
  },
];

export default function KpiDashboard({ stats, loading }) {
  const cards = CARDS(stats);

  return (
    <Grid container spacing={2} sx={{ mb: 4 }}>
      {cards.map((card, i) => (
        <Grid item xs={6} sm={4} md={12 / 7} key={i}>
          <Card
            sx={{
              background: card.bg,
              border: `1px solid ${card.border}`,
              borderRadius: 3,
              height: '100%',
              transition: 'all 0.3s ease',
              cursor: 'default',
              '&:hover': {
                transform: 'translateY(-4px)',
                boxShadow: `0 8px 32px ${card.glow}30`,
                border: `1px solid ${card.border.replace('0.2', '0.5')}`,
              },
            }}
          >
            <CardContent sx={{ p: 2, '&:last-child': { pb: 2 } }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <Box>
                  <Typography variant="caption" sx={{ color: '#94a3b8', fontWeight: 500, letterSpacing: '0.5px', textTransform: 'uppercase', fontSize: '0.65rem' }}>
                    {card.title}
                  </Typography>
                  {loading ? (
                    <Skeleton variant="text" width={60} height={48} sx={{ bgcolor: 'rgba(255,255,255,0.06)' }} />
                  ) : (
                    <Typography variant="h4" sx={{ fontWeight: 800, color: card.color, mt: 0.25, lineHeight: 1.1 }}>
                      {card.value}
                    </Typography>
                  )}
                </Box>
                <Box
                  sx={{
                    color: card.color,
                    opacity: 0.7,
                    mt: 0.5,
                    '& svg': { fontSize: '1.4rem' },
                  }}
                >
                  {card.icon}
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      ))}
    </Grid>
  );
}
