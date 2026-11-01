# BOAT Backend Architecture Note

The primary backend for both the Web application and the Mobile Flutter application is located in `d:\core_project\boat\boat`.

### Primary Web + Mobile Backend:
- **Location**: `../boat` (Next.js 15 Node.js full-stack app)
- **Start Command**: `npm run dev` (in the `boat` directory)
- **Endpoints**:
  - `GET  /api/health` — Health check & DB status
  - `POST /api/auth/register` — User registration (returns JWT token + user)
  - `POST /api/auth/login` — User authentication (returns JWT token + user)
  - `GET  /api/auth/me` — Authenticated session check (Bearer token / Cookie)
  - `POST /api/auth/logout` — Logout
  - `GET  /api/bikes` — List user's registered bicycles with their latest GPS fix
  - `POST /api/bikes` — Register a bicycle and assign unique beacon Minor ID
  - `GET  /api/bikes/[id]` — Detail view with 30-point location trail and active missing report
  - `PATCH /api/bikes/[id]` — Toggle status (`active` / `missing`) with single active report enforcement
  - `POST /api/location` — Open community mesh ingestion for BLE, NFC, and web sightings
  - `GET  /api/public/bikes/[publicId]` — Public profile for NFC taps
- **CORS**: Fully enabled for mobile, web, and emulator clients (`OPTIONS` preflight handling + wildcard headers).
- **Network Interfaces**: Bound to `0.0.0.0:3000` so Android emulator (`http://10.0.2.2:3000`), local devices (`http://localhost:3000`), and physical phones (`http://<LAN_IP>:3000`) can connect seamlessly.
