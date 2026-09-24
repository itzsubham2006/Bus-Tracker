/**
 * Bus Movement Simulator for Testing
 * Simulates Bus 1 driving along a route, posting GPS coordinates to the backend every 3.5 seconds.
 * 
 * Usage:
 *   node scripts/simulate.js
 */

const http = require('http');

const BUS_ID = 1;
const TOKEN = '69f3179b0e888eaeea1fbc7467304990ea0823e9afd6ef1fe7f4a1aa22f99226';
const BACKEND_HOST = 'localhost';
const BACKEND_PORT = 3000;

// Waypoints simulating a route (College <-> Town)
const waypoints = [
  { lat: 12.9715987, lng: 77.5945627, heading: 45 },
  { lat: 12.9723000, lng: 77.5952000, heading: 50 },
  { lat: 12.9731000, lng: 77.5961000, heading: 55 },
  { lat: 12.9740000, lng: 77.5973000, heading: 60 },
  { lat: 12.9749000, lng: 77.5985000, heading: 65 },
  { lat: 12.9758000, lng: 77.5998000, heading: 70 },
  { lat: 12.9765000, lng: 77.6012000, heading: 75 },
  { lat: 12.9772000, lng: 77.6025000, heading: 80 },
  { lat: 12.9765000, lng: 77.6012000, heading: 255 },
  { lat: 12.9758000, lng: 77.5998000, heading: 250 },
  { lat: 12.9749000, lng: 77.5985000, heading: 245 },
  { lat: 12.9740000, lng: 77.5973000, heading: 240 },
  { lat: 12.9731000, lng: 77.5961000, heading: 235 },
  { lat: 12.9723000, lng: 77.5952000, heading: 230 },
];

function sendPost(path, data) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const req = http.request({
      hostname: BACKEND_HOST,
      port: BACKEND_PORT,
      path: path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let respBody = '';
      res.on('data', chunk => respBody += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: respBody }));
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function startSimulation() {
  console.log('🚀 Starting Bus 1 Simulation...');
  
  // 1. Activate Bus 1
  try {
    const res = await sendPost(`/api/bus/${BUS_ID}/toggle`, { token: TOKEN, active: true });
    console.log(`✅ Bus 1 activated on backend: ${res.body}`);
  } catch (err) {
    console.error('❌ Failed to connect to backend:', err.message);
    process.exit(1);
  }

  let index = 0;
  console.log('📡 Broadcasting live GPS coordinates every 3.5s (Press Ctrl+C to stop)...');

  const interval = setInterval(async () => {
    const wp = waypoints[index];
    try {
      await sendPost(`/api/bus/${BUS_ID}/location`, {
        token: TOKEN,
        lat: wp.lat,
        lng: wp.lng,
        heading: wp.heading,
      });
      console.log(`[Step ${index + 1}/${waypoints.length}] Bus 1 at: Lat ${wp.lat.toFixed(5)}, Lng ${wp.lng.toFixed(5)}, Heading ${wp.heading}°`);
    } catch (err) {
      console.error('Error posting location:', err.message);
    }

    index = (index + 1) % waypoints.length;
  }, 3500);

  // Clean shutdown
  process.on('SIGINT', async () => {
    clearInterval(interval);
    console.log('\n🛑 Stopping simulation and deactivating Bus 1...');
    try {
      await sendPost(`/api/bus/${BUS_ID}/toggle`, { token: TOKEN, active: false });
      console.log('✅ Bus 1 deactivated.');
    } catch (e) {
      // ignore
    }
    process.exit(0);
  });
}

startSimulation();
