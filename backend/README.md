# College Bus Tracker — Backend API

Node.js + Express backend for the College Bus Live Tracker app.  
Manages bus state, authenticates drivers via per-bus tokens, and pushes live location updates to student apps via Server-Sent Events (SSE).

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Copy environment config
cp .env.example .env
# Edit .env to set a real ADMIN_SECRET for production

# 3. Start the server
npm start
```

On **first run**, the server will:
1. Create a `buses.db` SQLite database
2. Insert 4 buses (Bus 1–Bus 4)
3. Generate random secure tokens for each bus
4. **Print all tokens to the console** — copy these and give each to the corresponding driver

### Example first-run output:
```
--- NEW BUS TOKENS GENERATED ---
IMPORTANT: Save these tokens securely. They are required for drivers to authenticate.
[Bus 1 (North Route) (ID: 1)]: a3f7c9...
[Bus 2 (South Route) (ID: 2)]: b8d2e1...
[Bus 3 (East Route)  (ID: 3)]: c4a6f0...
[Bus 4 (West Route)  (ID: 4)]: d1b5e3...
--------------------------------
```

On **subsequent runs**, the existing tokens are preserved (stored in SQLite).

---

## API Reference

### Public Endpoints (no auth required)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check → `{ status: "ok" }` |
| `GET` | `/api/buses` | Returns all 4 buses (public fields only, never tokens) |
| `GET` | `/api/stream` | SSE stream for live updates |

### Driver Endpoints (token required)

| Method | Path | Body | Description |
|--------|------|------|-------------|
| `POST` | `/api/driver/verify` | `{ token }` | Validate token → `{ valid, busId, busName }` |
| `POST` | `/api/bus/:id/location` | `{ token, lat, lng, heading? }` | Update bus GPS position (rate limited: 1/3s) |
| `POST` | `/api/bus/:id/toggle` | `{ token, active }` | Start/end a bus trip |

### Admin Endpoints

| Method | Path | Body | Description |
|--------|------|------|-------------|
| `POST` | `/api/admin/regenerate-token` | `{ adminSecret, busId }` | Regenerate a leaked token |

---

## Resetting a Leaked Token

If a driver's token is compromised:

```bash
curl -X POST http://localhost:3000/api/admin/regenerate-token \
  -H "Content-Type: application/json" \
  -d '{"adminSecret": "YOUR_ADMIN_SECRET", "busId": 2}'
```

The new token is returned in the response AND printed to the server console.  
Give the new token to the driver; the old one stops working immediately.

---

## SSE Stream Details

Connect to `GET /api/stream` — the server sends:

1. **On connect**: `event: buses` with full bus array
2. **On any change**: `event: update` with the changed bus object
3. **Every 30s**: heartbeat comment (`:heartbeat`) to keep the connection alive

### Bus object shape:
```json
{
  "id": 1,
  "name": "Bus 1 (North Route)",
  "is_active": true,
  "lat": 12.9716,
  "lng": 77.5946,
  "heading": 180.5,
  "last_updated": 1695551234567,
  "stale": false
}
```

- `stale: true` means the bus is marked active but hasn't sent a location update in >45 seconds (driver may have lost signal)
- When `is_active: false`, `lat`/`lng`/`heading` will be `null`

---

## Deployment

### Railway / Render / Fly.io

1. Push this `backend/` directory to a Git repo
2. Connect to your hosting platform
3. Set environment variables:
   - `PORT` — usually set automatically by the platform
   - `ADMIN_SECRET` — set to a secure random string
4. Build command: `npm install`
5. Start command: `npm start`

The server respects the `PORT` env var and works behind a reverse proxy (TLS is handled by the platform).

### Notes
- The SQLite database file (`buses.db`) is created in the backend root directory
- On platforms with ephemeral filesystems (like Railway), tokens regenerate on each deploy — use a persistent volume or switch to a managed DB for production
- CORS is set to allow all origins (`*`) for the Flutter app

---

## Project Structure

```
backend/
├── .env.example        # Environment variable template
├── .env                # Local config (git-ignored)
├── .gitignore
├── package.json
├── buses.db            # SQLite database (auto-created on first run)
├── README.md
└── src/
    ├── server.js       # Express app entry point
    ├── config.js       # Environment config loader
    ├── db.js           # SQLite init + token generation
    ├── state.js        # In-memory bus state + SSE broadcast manager
    ├── routes/
    │   ├── buses.js    # GET /api/buses, GET /api/stream
    │   ├── driver.js   # POST /api/bus/:id/location, toggle, verify
    │   └── admin.js    # POST /api/admin/regenerate-token
    └── middleware/
        ├── logger.js       # Request logging
        └── errorHandler.js # Global error handler
```
