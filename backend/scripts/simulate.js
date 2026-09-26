/**
 * Realistic Bus Movement Simulator for Testing
 * Simulates Bus 1 driving at realistic city speed (~30 km/h) along Kokrajhar roads.
 * Smoothly interpolates coordinates every 3.5 seconds with accurate headings and distances.
 * 
 * Usage:
 *   node scripts/simulate.js
 */

const http = require('http');

const BUS_ID = 1;
const TOKEN = '69f3179b0e888eaeea1fbc7467304990ea0823e9afd6ef1fe7f4a1aa22f99226';
const BACKEND_HOST = 'localhost';
const BACKEND_PORT = 3000;

// Simulation parameters
const SPEED_KMH = 30; // Realistic city bus speed in km/h (~8.3 meters/second)
const UPDATE_INTERVAL_MS = 3500; // 3.5 seconds per GPS update (adheres to 3s rate limit)
const METERS_PER_STEP = (SPEED_KMH * 1000 / 3600) * (UPDATE_INTERVAL_MS / 1000); // ~29.1 meters

// Key landmarks and stops in Kokrajhar (PIN: 783370)
const stops = [
  { lat: 26.3911, lng: 90.2647, name: "Girls College, Kokrajhar" },
  { lat: 26.3993, lng: 90.2670, name: "Kokrajhar Police Station" },
  { lat: 26.4022, lng: 90.2721, name: "Kokrajhar Railway Station" },
  { lat: 26.4050, lng: 90.2730, name: "Flyover Point" },
  { lat: 26.4082, lng: 90.2741, name: "JD Road / Daily Bazar" },
  { lat: 26.4135, lng: 90.2755, name: "Tengapara Bus Stop" },
  { lat: 26.4210, lng: 90.2770, name: "Bhatarmari Chowk" },
  { lat: 26.4275, lng: 90.2790, name: "Balagaon Chariali" },
  { lat: 26.4320, lng: 90.2800, name: "CIT Road Junction" },
  { lat: 26.4355, lng: 90.2818, name: "CIT Kokrajhar Main Gate" },
  { lat: 26.4420, lng: 90.2865, name: "Bodoland University Campus" },
  { lat: 26.4650, lng: 90.2970, name: "NH / Simbargaon Approach" },
  { lat: 26.4865, lng: 90.3056, name: "Simbargaon Rd Junction" },
  // Return route
  { lat: 26.4650, lng: 90.2970, name: "NH / Simbargaon Approach" },
  { lat: 26.4420, lng: 90.2865, name: "Bodoland University Campus" },
  { lat: 26.4355, lng: 90.2818, name: "CIT Kokrajhar Main Gate" },
  { lat: 26.4320, lng: 90.2800, name: "CIT Road Junction" },
  { lat: 26.4275, lng: 90.2790, name: "Balagaon Chariali" },
  { lat: 26.4210, lng: 90.2770, name: "Bhatarmari Chowk" },
  { lat: 26.4135, lng: 90.2755, name: "Tengapara Bus Stop" },
  { lat: 26.4082, lng: 90.2741, name: "JD Road / Daily Bazar" },
  { lat: 26.4050, lng: 90.2730, name: "Flyover Point" },
  { lat: 26.4022, lng: 90.2721, name: "Kokrajhar Railway Station" },
  { lat: 26.3993, lng: 90.2670, name: "Kokrajhar Police Station" },
  { lat: 26.3911, lng: 90.2647, name: "Girls College, Kokrajhar" },
];

// Calculate distance between two GPS coordinates in meters (Haversine formula)
function getDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

// Calculate bearing/heading angle in degrees (0 = North, 90 = East, 180 = South, 270 = West)
function getBearing(lat1, lon1, lat2, lon2) {
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const y = Math.sin(deltaLambda) * Math.cos(phi2);
  const x =
    Math.cos(phi1) * Math.sin(phi2) -
    Math.sin(phi1) * Math.cos(phi2) * Math.cos(deltaLambda);
  const theta = Math.atan2(y, x);
  return Math.round(((theta * 180) / Math.PI + 360) % 360);
}

// Generate smooth sub-steps between all key stops
function generateSmoothRoute(keyStops, stepDistanceMeters) {
  const route = [];

  for (let i = 0; i < keyStops.length; i++) {
    const current = keyStops[i];
    const next = keyStops[(i + 1) % keyStops.length];

    const dist = getDistanceMeters(current.lat, current.lng, next.lat, next.lng);
    const stepsCount = Math.max(1, Math.round(dist / stepDistanceMeters));
    const bearing = getBearing(current.lat, current.lng, next.lat, next.lng);

    for (let s = 0; s < stepsCount; s++) {
      const fraction = s / stepsCount;
      const lat = current.lat + (next.lat - current.lat) * fraction;
      const lng = current.lng + (next.lng - current.lng) * fraction;
      route.push({
        lat,
        lng,
        heading: bearing,
        landmark: s === 0 ? current.name : `En route to ${next.name}`,
      });
    }
  }

  return route;
}

function sendPost(path, data) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const req = http.request(
      {
        hostname: BACKEND_HOST,
        port: BACKEND_PORT,
        path: path,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        let respBody = '';
        res.on('data', (chunk) => (respBody += chunk));
        res.on('end', () => resolve({ statusCode: res.statusCode, body: respBody }));
      }
    );

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function startSimulation() {
  console.log('---------------------------------------------------------');
  console.log('🚌 Kokrajhar Bus 1 Realistic Route Simulator');
  console.log(`⚡ Speed: ${SPEED_KMH} km/h (${METERS_PER_STEP.toFixed(1)} meters every ${(UPDATE_INTERVAL_MS / 1000).toFixed(1)}s)`);
  console.log('---------------------------------------------------------');

  const routePoints = generateSmoothRoute(stops, METERS_PER_STEP);
  console.log(`📍 Generated ${routePoints.length} smooth GPS steps along the road.`);

  // 1. Activate Bus 1
  try {
    const res = await sendPost(`/api/bus/${BUS_ID}/toggle`, { token: TOKEN, active: true });
    console.log(`✅ Bus 1 activated on backend: ${res.body}`);
  } catch (err) {
    console.error('❌ Failed to connect to backend server at http://localhost:3000:', err.message);
    console.error('👉 Make sure "npm start" is running in the backend folder first!');
    process.exit(1);
  }

  let index = 0;
  console.log('📡 Broadcasting live GPS coordinates... (Press Ctrl+C to stop)\n');

  const interval = setInterval(async () => {
    const pt = routePoints[index];
    try {
      await sendPost(`/api/bus/${BUS_ID}/location`, {
        token: TOKEN,
        lat: parseFloat(pt.lat.toFixed(6)),
        lng: parseFloat(pt.lng.toFixed(6)),
        heading: pt.heading,
      });

      console.log(
        `[Step ${index + 1}/${routePoints.length}] 🚌 Bus 1: ` +
        `Lat: ${pt.lat.toFixed(5)}, Lng: ${pt.lng.toFixed(5)} | ` +
        `Heading: ${pt.heading.toString().padStart(3, ' ')}° | ${pt.landmark}`
      );
    } catch (err) {
      console.error('Error posting location:', err.message);
    }

    index = (index + 1) % routePoints.length;
  }, UPDATE_INTERVAL_MS);

  // Clean shutdown on Ctrl+C
  const cleanup = async () => {
    clearInterval(interval);
    console.log('\n🛑 Stopping simulation and deactivating Bus 1...');
    try {
      await sendPost(`/api/bus/${BUS_ID}/toggle`, { token: TOKEN, active: false });
      console.log('✅ Bus 1 successfully deactivated (Status: Not running).');
    } catch (e) {
      // ignore
    }
    process.exit(0);
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
}

startSimulation();
