const express = require('express');
const { db } = require('../db');
const { updateBusState, broadcastSSE, isStale, busState } = require('../state');

// Two separate routers:
// busRouter   → mounted at /api/bus    → handles /:id/location and /:id/toggle
// driverRouter → mounted at /api/driver → handles /verify
const busRouter = express.Router();
const driverRouter = express.Router();

// --- Rate limiting state ---
// Maps busId → timestamp of last accepted location update.
// This enforces the "max 1 update per 3 seconds per bus" rule.
const lastUpdateTimes = new Map();

/**
 * Looks up a bus by its secret token.
 * Used to validate driver requests without a separate user login system.
 * @param {string} token - The driver's secret token
 * @returns {{ id: number, name: string } | null}
 */
function getBusByToken(token) {
  if (!token) return null;
  const bus = db.prepare('SELECT id, name FROM buses WHERE token = ?').get(token);
  return bus || null;
}

/**
 * Helper to build the public (safe-to-broadcast) version of a bus state object.
 * Strips internal fields and adds the stale flag.
 */
function toPublicBus(bus) {
  return {
    id: bus.id,
    name: bus.name,
    is_active: bus.is_active,
    lat: bus.lat,
    lng: bus.lng,
    heading: bus.heading,
    last_updated: bus.last_updated,
    stale: isStale(bus)
  };
}

// ========================================
// POST /api/driver/verify
// ========================================
// The Flutter app sends the token and gets back which bus it belongs to.
// This lets a single token encode both "who you are" and "which bus" —
// no need for the driver to separately pick their bus ID.
driverRouter.post('/verify', (req, res) => {
  const { token } = req.body;
  const bus = getBusByToken(token);

  if (bus) {
    res.json({ valid: true, busId: bus.id, busName: bus.name });
  } else {
    res.json({ valid: false });
  }
});

// ========================================
// POST /api/bus/:id/location
// ========================================
// Called by the driver's phone every ~7 seconds while a trip is active.
// Validates the token, enforces rate limiting, updates state, and broadcasts.
busRouter.post('/:id/location', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { token, lat, lng, heading } = req.body;

  // --- Auth: token must exist and belong to this specific bus ---
  const bus = getBusByToken(token);
  if (!bus || bus.id !== id) {
    return res.status(401).json({ error: 'Unauthorized: invalid token for this bus.' });
  }

  // --- Rate limiting: max 1 accepted update per 3 seconds per bus ---
  const now = Date.now();
  const lastUpdate = lastUpdateTimes.get(id) || 0;
  if (now - lastUpdate < 3000) {
    return res.status(429).json({ error: 'Too many requests. Max 1 update per 3 seconds.' });
  }
  lastUpdateTimes.set(id, now);

  // --- Validate lat/lng are numbers ---
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return res.status(400).json({ error: 'lat and lng must be numbers.' });
  }

  // --- Update in-memory state ---
  const updates = {
    lat,
    lng,
    heading: typeof heading === 'number' ? heading : null,
    last_updated: now,
    is_active: true
  };

  const updatedBus = updateBusState(id, updates);
  if (!updatedBus) {
    return res.status(404).json({ error: 'Bus not found.' });
  }

  // --- Broadcast to all connected SSE clients ---
  broadcastSSE('update', toPublicBus(updatedBus));

  res.json({ success: true });
});

// ========================================
// POST /api/bus/:id/toggle
// ========================================
// Toggles a bus active/inactive. When turning off:
// - Clears lat/lng/heading so students don't see a stale pin
// - Broadcasts the change so all student UIs update immediately
busRouter.post('/:id/toggle', (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { token, active } = req.body;

  // --- Auth ---
  const bus = getBusByToken(token);
  if (!bus || bus.id !== id) {
    return res.status(401).json({ error: 'Unauthorized: invalid token for this bus.' });
  }

  const isActive = !!active;
  const updates = { is_active: isActive };

  if (!isActive) {
    // Clear location when trip ends — prevents frozen/stale markers
    updates.lat = null;
    updates.lng = null;
    updates.heading = null;
    updates.last_updated = null;
  } else {
    updates.last_updated = Date.now();
  }

  const updatedBus = updateBusState(id, updates);
  if (!updatedBus) {
    return res.status(404).json({ error: 'Bus not found.' });
  }

  // Broadcast state change to all SSE clients
  broadcastSSE('update', toPublicBus(updatedBus));

  res.json({ success: true, is_active: isActive });
});

module.exports = { busRouter, driverRouter };
