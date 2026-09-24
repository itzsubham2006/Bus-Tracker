const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const config = require('./config');
const logger = require('./middleware/logger');
const errorHandler = require('./middleware/errorHandler');

// Initialize DB (creates tables + generates tokens on first run)
require('./db');

// Import routes
const busesRoutes = require('./routes/buses');
const driverRoutes = require('./routes/driver');
const adminRoutes = require('./routes/admin');

const app = express();

// --- Middleware ---
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(logger);

// --- Health check ---
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// --- Routes ---
// GET /api/buses  — public bus list
// GET /api/stream — SSE stream for live updates
app.use('/api', busesRoutes);

// POST /api/bus/:id/location  — driver sends GPS
// POST /api/bus/:id/toggle    — driver starts/ends trip
app.use('/api/bus', driverRoutes.busRouter);

// POST /api/driver/verify     — verify a token, return busId
app.use('/api/driver', driverRoutes.driverRouter);

// POST /api/admin/regenerate-token
app.use('/api/admin', adminRoutes);

// --- Global Error Handler ---
app.use(errorHandler);

// --- Start ---
app.listen(config.port, () => {
  console.log(`\n🚌 College Bus Tracker API running on port ${config.port}`);
  console.log(`   Health check: http://localhost:${config.port}/health`);
  console.log(`   Bus list:     http://localhost:${config.port}/api/buses`);
  console.log(`   SSE stream:   http://localhost:${config.port}/api/stream\n`);
});
