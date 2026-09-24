const { db } = require('./db');

// In-memory state for buses
const busState = new Map();

// Set of connected SSE clients (Response objects)
const sseClients = new Set();

/**
 * Loads all buses from the database into the in-memory state.
 */
function loadInitialState() {
  const buses = db.prepare('SELECT id, name, is_active FROM buses').all();
  for (const bus of buses) {
    busState.set(bus.id, {
      id: bus.id,
      name: bus.name,
      is_active: !!bus.is_active,
      lat: null,
      lng: null,
      heading: null,
      last_updated: null
    });
  }
}

// Load initial state
loadInitialState();

/**
 * Helper to determine if a bus's location data is stale (older than 45 seconds).
 */
function isStale(bus) {
  if (!bus.is_active || !bus.last_updated) return false;
  return (Date.now() - bus.last_updated) > 45000;
}

/**
 * Gets all buses in a format safe for public consumption.
 * Removes internal properties and adds the `stale` flag.
 */
function getAllBusesPublic() {
  const buses = [];
  for (const bus of busState.values()) {
    buses.push({
      id: bus.id,
      name: bus.name,
      is_active: bus.is_active,
      lat: bus.lat,
      lng: bus.lng,
      heading: bus.heading,
      last_updated: bus.last_updated,
      stale: isStale(bus)
    });
  }
  return buses;
}

/**
 * Updates the state for a given bus.
 * @param {number} id - Bus ID
 * @param {Object} updates - Properties to update
 * @returns {Object} The updated bus state, or null if not found
 */
function updateBusState(id, updates) {
  const bus = busState.get(id);
  if (!bus) return null;

  Object.assign(bus, updates);
  busState.set(id, bus);
  
  // Also update DB if is_active changed
  if (updates.hasOwnProperty('is_active')) {
    db.prepare('UPDATE buses SET is_active = ? WHERE id = ?').run(updates.is_active ? 1 : 0, id);
  }

  return bus;
}

/**
 * Broadcasts an SSE event to all connected clients.
 * @param {string} event - Event name
 * @param {any} data - Event data (will be JSON stringified)
 */
function broadcastSSE(event, data) {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const client of sseClients) {
    try {
      client.write(payload);
    } catch (err) {
      console.error('Error broadcasting to client, removing...', err);
      sseClients.delete(client);
    }
  }
}

/**
 * Adds an SSE client to the broadcast list.
 * @param {Object} res - Express Response object
 */
function addSSEClient(res) {
  sseClients.add(res);
}

/**
 * Removes an SSE client.
 * @param {Object} res - Express Response object
 */
function removeSSEClient(res) {
  sseClients.delete(res);
}

// Heartbeat interval to keep connections alive
setInterval(() => {
  for (const client of sseClients) {
    try {
      client.write(': heartbeat\n\n');
    } catch (err) {
      sseClients.delete(client);
    }
  }
}, 30000);

module.exports = {
  busState,
  getAllBusesPublic,
  updateBusState,
  broadcastSSE,
  addSSEClient,
  removeSSEClient,
  isStale
};
