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

// Waypoints simulating a route in Kokrajhar 783370 (Station <-> Town <-> CIT / Bodoland Univ)
const waypoints = [
  { lat: 26.4022, lng: 90.2721, heading: 10, note: "Kokrajhar Railway Station" },
  { lat: 26.4065, lng: 90.2735, heading: 15, note: "JD Road / Town Center" },
  { lat: 26.4120, lng: 90.2750, heading: 18, note: "Tengapara" },
  { lat: 26.4190, lng: 90.2768, heading: 22, note: "Bhatarmari" },
  { lat: 26.4265, lng: 90.2785, heading: 25, note: "Balagaon" },
  { lat: 26.4340, lng: 90.2810, heading: 30, note: "CIT Kokrajhar Campus" },
  { lat: 26.4415, lng: 90.2860, heading: 35, note: "Bodoland University / Deborgaon" },
  { lat: 26.4340, lng: 90.2810, heading: 210, note: "Returning via CIT Kokrajhar" },
  { lat: 26.4265, lng: 90.2785, heading: 205, note: "Returning via Balagaon" },
  { lat: 26.4190, lng: 90.2768, heading: 200, note: "Returning via Bhatarmari" },
  { lat: 26.4120, lng: 90.2750, heading: 195, note: "Returning via Tengapara" },
  { lat: 26.4065, lng: 90.2735, heading: 190, note: "Returning via JD Road" },
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
