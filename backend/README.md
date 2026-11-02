# BOAT Backend Architecture

The unified backend API serving both the Web application and the Flutter mobile client is built on Next.js 15 (Node.js App Router) with a TiDB / MySQL serverless database.

### Production Deployment
- **Base URL**: `https://boat-eight-lemon.vercel.app`
- **Hosted On**: Vercel Serverless Functions
- **Database**: TiDB Cloud (Serverless MySQL)

### Local Development Backend
- **Location**: `../boat` (or the `boat/` workspace directory)
- **Start Command**: `npm run dev`
- **Port**: `3000`

### Core API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Health check & TiDB connection status |
| `POST` | `/api/auth/register` | User registration (returns JWT session token & user profile) |
| `POST` | `/api/auth/login` | User authentication via Email or Enrollment / ID + Password |
| `GET` | `/api/auth/me` | Authenticated session check (Bearer token / HTTP-only cookie) |
| `POST` | `/api/auth/logout` | Session invalidation and logout |
| `GET` | `/api/bikes` | List user's registered bicycles with their latest GPS fix |
| `POST` | `/api/bikes` | Register a bicycle and assign unique beacon identifiers |
| `GET` | `/api/bikes/[id]` | Bicycle detail view with recent sightings and active missing reports |
| `PATCH` | `/api/bikes/[id]` | Toggle status (`active` / `missing`) with single active report enforcement |
| `POST` | `/api/location` | Open community mesh ingestion for BLE, NFC, and web sightings |
| `GET` | `/api/public/bikes/[publicId]` | Public profile for physical NFC sticker taps |

### Network & Client Compatibility
- **CORS**: Configured with wildcard origin support and `OPTIONS` preflight handling for mobile and web clients.
- **Client Fallback**: Mobile applications point by default to the production cloud endpoint `https://boat-eight-lemon.vercel.app`.
