const express = require('express');
const router = express.Router();
const { getAllBusesPublic, addSSEClient, removeSSEClient } = require('../state');

/**
 * GET /api/buses
 * Returns array of all 4 buses with public fields only.
 * Tokens are NEVER included in this response.
 */
router.get('/buses', (req, res) => {
  const buses = getAllBusesPublic();
  res.json(buses);
});

/**
 * GET /api/stream
 * Server-Sent Events endpoint for real-time bus updates.
 * 
 * Students connect here on app launch. The server:
 * 1. Sends the full bus list immediately on connect ("buses" event)
 * 2. Pushes "update" events whenever any bus changes state
 * 3. Sends heartbeat comments every 30s to keep the connection alive
 * 
 * SSE clients auto-reconnect when the connection drops (built into the protocol).
 */
router.get('/stream', (req, res) => {
  // Set SSE headers — these tell the browser/client to keep the connection open
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
    // Prevent nginx from buffering SSE events
    'X-Accel-Buffering': 'no'
  });

  // Flush headers immediately so the client knows the connection is established
  res.flushHeaders();

  // Send full bus list as the initial payload
  const initialBuses = getAllBusesPublic();
  res.write(`event: buses\ndata: ${JSON.stringify(initialBuses)}\n\n`);

  // Register this client for future broadcasts
  addSSEClient(res);

  // Clean up when the client disconnects
  req.on('close', () => {
    removeSSEClient(res);
  });
});

module.exports = router;
