const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
}));
app.use(express.json());

// Environment & TiDB Configuration
const JWT_SECRET = process.env.JWT_SECRET || '8f3c1a9e2b74d0c56e18a4f7b92d35c01e6a88f4b27c9d15e03a76b4c8f12d90';
const DEFAULT_BEACON_UUID = 'f7826da6-4fa2-4e98-8024-bc5b71e0893e';

let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: 'gateway01.ap-southeast-1.prod.aws.tidbcloud.com',
      port: 4000,
      user: '32PdWPMcGnu68aK.root',
      password: 'nJKzl3nLCDjmIQiD',
      database: 'boat',
      ssl: { minVersion: 'TLSv1.2', rejectUnauthorized: true },
      enableKeepAlive: true,
      connectTimeout: 20000,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
    });
  }
  return pool;
}

async function query(sql, params = []) {
  const p = getPool();
  const [rows] = await p.query(sql, params);
  return rows;
}

// Generate random publicId (8 chars)
function generatePublicId() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  let out = '';
  for (let i = 0; i < 8; i++) {
    out += alphabet[crypto.randomInt(alphabet.length)];
  }
  return out;
}

// Authentication Middleware
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  let token = null;

  if (authHeader && authHeader.toLowerCase().startsWith('bearer ')) {
    token = authHeader.substring(7).trim();
  }

  if (!token) {
    return res.status(401).json({ error: 'Authentication required.' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const userId = decoded.uid;
    if (!userId) {
      return res.status(401).json({ error: 'Invalid token payload.' });
    }

    const rows = await query(
      'SELECT id, email, display_name, phone, hostel, room FROM users WHERE id = ? LIMIT 1',
      [userId]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'User no longer exists.' });
    }

    req.user = rows[0];
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Session expired or invalid.' });
  }
}

// --- Health ---
app.get('/api/health', (req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

// --- Auth APIs ---
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, displayName, phone, hostel, room } = req.body;
    if (!email || !password || !displayName) {
      return res.status(400).json({ error: 'Email, password, and displayName are required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const existing = await query('SELECT id FROM users WHERE email = ? LIMIT 1', [cleanEmail]);
    if (existing.length > 0) {
      return res.status(409).json({ error: 'Email already registered.' });
    }

    const hash = await bcrypt.hash(password, 12);
    const result = await query(
      'INSERT INTO users (email, password_hash, display_name, phone, hostel, room) VALUES (?, ?, ?, ?, ?, ?)',
      [cleanEmail, hash, displayName.trim(), phone?.trim() || null, hostel?.trim() || null, room?.trim() || null]
    );

    const userId = result.insertId;
    const token = jwt.sign({ uid: userId }, JWT_SECRET, { expiresIn: '14d' });

    res.json({
      ok: true,
      token,
      user: {
        id: userId,
        email: cleanEmail,
        display_name: displayName.trim(),
        phone: phone?.trim() || null,
        hostel: hostel?.trim() || null,
        room: room?.trim() || null,
      },
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const rows = await query('SELECT id, password_hash FROM users WHERE email = ? LIMIT 1', [cleanEmail]);
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Email or password is incorrect.' });
    }

    const user = rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({ error: 'Email or password is incorrect.' });
    }

    const token = jwt.sign({ uid: user.id }, JWT_SECRET, { expiresIn: '14d' });
    const userRows = await query(
      'SELECT id, email, display_name, phone, hostel, room FROM users WHERE id = ? LIMIT 1',
      [user.id]
    );

    res.json({
      ok: true,
      token,
      user: userRows[0] || null,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/auth/me', authenticateToken, (req, res) => {
  res.json({ user: req.user });
});

// --- Bikes APIs ---
app.get('/api/bikes', authenticateToken, async (req, res) => {
  try {
    const bikes = await query(
      'SELECT * FROM bikes WHERE owner_id = ? ORDER BY created_at DESC',
      [req.user.id]
    );

    // Fetch latest location fix for each bike
    const bikesWithLocation = await Promise.all(
      bikes.map(async (bike) => {
        const locs = await query(
          'SELECT * FROM location_reports WHERE bike_id = ? ORDER BY recorded_at DESC LIMIT 1',
          [bike.id]
        );
        return {
          ...bike,
          lastLocation: locs[0] || null,
        };
      })
    );

    res.json({ bikes: bikesWithLocation });
  } catch (err) {
    console.error('Get bikes error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/bikes', authenticateToken, async (req, res) => {
  try {
    const { name, color, model } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Bike name is required.' });
    }

    const publicId = generatePublicId();
    const tagId = `TAG-${publicId.toUpperCase()}`;
    const beaconUuid = DEFAULT_BEACON_UUID;
    const beaconMajor = 1;

    // Next minor integer
    const maxMinorRow = await query(
      'SELECT COALESCE(MAX(beacon_minor), 0) as max_minor FROM bikes WHERE beacon_uuid = ? AND beacon_major = ?',
      [beaconUuid, beaconMajor]
    );
    const beaconMinor = (maxMinorRow[0]?.max_minor || 0) + 1;

    const result = await query(
      'INSERT INTO bikes (owner_id, public_id, name, color, model, tag_id, status, beacon_uuid, beacon_major, beacon_minor) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [req.user.id, publicId, name.trim(), color?.trim() || null, model?.trim() || null, tagId, 'active', beaconUuid, beaconMajor, beaconMinor]
    );

    res.json({
      ok: true,
      bike: {
        id: result.insertId,
        publicId,
        tagId,
        beaconUuid,
        beaconMajor,
        beaconMinor,
      },
    });
  } catch (err) {
    console.error('Register bike error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/bikes/:id', authenticateToken, async (req, res) => {
  try {
    const bikeId = Number(req.params.id);
    const bikes = await query('SELECT * FROM bikes WHERE id = ? AND owner_id = ? LIMIT 1', [bikeId, req.user.id]);
    if (bikes.length === 0) {
      return res.status(404).json({ error: 'Bicycle not found.' });
    }

    const bike = bikes[0];
    const latestFixes = await query(
      'SELECT * FROM location_reports WHERE bike_id = ? ORDER BY recorded_at DESC LIMIT 1',
      [bikeId]
    );
    const trail = await query(
      'SELECT * FROM location_reports WHERE bike_id = ? ORDER BY recorded_at DESC LIMIT 30',
      [bikeId]
    );
    const missing = await query(
      'SELECT * FROM missing_reports WHERE bike_id = ? AND status = "active" LIMIT 1',
      [bikeId]
    );

    res.json({
      bike,
      lastLocation: latestFixes[0] || null,
      trail,
      activeMissingReport: missing[0] || null,
    });
  } catch (err) {
    console.error('Bike detail error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/bikes/:id', authenticateToken, async (req, res) => {
  try {
    const bikeId = Number(req.params.id);
    const { status, notes } = req.body;

    const bikes = await query('SELECT * FROM bikes WHERE id = ? AND owner_id = ? LIMIT 1', [bikeId, req.user.id]);
    if (bikes.length === 0) {
      return res.status(404).json({ error: 'Bicycle not found.' });
    }

    if (status === 'missing') {
      const activeMissing = await query(
        'SELECT id FROM missing_reports WHERE bike_id = ? AND status = "active" LIMIT 1',
        [bikeId]
      );
      if (activeMissing.length > 0) {
        return res.status(409).json({ error: 'Bicycle is already reported as missing.', alreadyMissing: true });
      }

      await query('UPDATE bikes SET status = "missing" WHERE id = ?', [bikeId]);
      await query('INSERT INTO missing_reports (bike_id, status, notes) VALUES (?, "active", ?)', [
        bikeId,
        notes?.trim() || null,
      ]);

      return res.json({ ok: true, status: 'missing', message: 'Bicycle reported as missing successfully.' });
    } else if (status === 'active') {
      await query('UPDATE bikes SET status = "active" WHERE id = ?', [bikeId]);
      await query('UPDATE missing_reports SET status = "resolved", resolved_at = CURRENT_TIMESTAMP WHERE bike_id = ? AND status = "active"', [
        bikeId,
      ]);

      return res.json({ ok: true, status: 'active', message: 'Bicycle marked as found and active.' });
    }

    res.status(400).json({ error: 'Invalid status provided.' });
  } catch (err) {
    console.error('Update bike status error:', err);
    res.status(500).json({ error: err.message });
  }
});

// --- Location Ingestion ---
app.post('/api/location', async (req, res) => {
  try {
    const { publicId, tagId, beaconUuid, beaconMajor, beaconMinor, lat, lng, accuracyM, source, note } = req.body;

    if (lat == null || lng == null) {
      return res.status(400).json({ error: 'lat and lng coordinates required.' });
    }

    let bikeId = null;

    if (publicId) {
      const rows = await query('SELECT id FROM bikes WHERE public_id = ? LIMIT 1', [publicId.toLowerCase().trim()]);
      if (rows.length > 0) bikeId = rows[0].id;
    } else if (tagId) {
      const rows = await query('SELECT id FROM bikes WHERE tag_id = ? LIMIT 1', [tagId.trim()]);
      if (rows.length > 0) bikeId = rows[0].id;
    } else if (beaconUuid && beaconMinor != null) {
      const major = beaconMajor != null ? Number(beaconMajor) : 1;
      const rows = await query(
        'SELECT id FROM bikes WHERE beacon_uuid = ? AND beacon_major = ? AND beacon_minor = ? LIMIT 1',
        [beaconUuid.toLowerCase().trim(), major, Number(beaconMinor)]
      );
      if (rows.length > 0) bikeId = rows[0].id;
    }

    if (!bikeId) {
      return res.status(404).json({ error: 'No matching bicycle found for identifier.' });
    }

    const reportSource = source || 'manual';
    const accuracy = accuracyM != null ? Number(accuracyM) : null;

    await query(
      'INSERT INTO location_reports (bike_id, lat, lng, accuracy_m, source, reporter_note) VALUES (?, ?, ?, ?, ?, ?)',
      [bikeId, Number(lat), Number(lng), accuracy, reportSource, note?.trim() || null]
    );

    res.json({
      ok: true,
      bikeId,
      location: {
        lat: Number(lat),
        lng: Number(lng),
        source: reportSource,
        recordedAt: new Date().toISOString(),
      },
    });
  } catch (err) {
    console.error('Location ingestion error:', err);
    res.status(500).json({ error: err.message });
  }
});

// --- Public Bicycle Profile ---
app.get('/api/public/bikes/:publicId', async (req, res) => {
  try {
    const publicId = req.params.publicId.toLowerCase().trim();
    const bikes = await query('SELECT * FROM bikes WHERE public_id = ? LIMIT 1', [publicId]);
    if (bikes.length === 0) {
      return res.status(404).json({ error: 'Bicycle not found.' });
    }

    const bike = bikes[0];
    const owners = await query(
      'SELECT id, display_name, phone, hostel, room, email FROM users WHERE id = ? LIMIT 1',
      [bike.owner_id]
    );
    const owner = owners[0] || {};

    const latestFixes = await query(
      'SELECT * FROM location_reports WHERE bike_id = ? ORDER BY recorded_at DESC LIMIT 1',
      [bike.id]
    );

    res.json({
      bike: {
        publicId: bike.public_id,
        name: bike.name,
        color: bike.color,
        model: bike.model,
        tagId: bike.tag_id,
        status: bike.status,
        registeredAt: bike.created_at,
        owner: {
          displayName: owner.display_name,
          phone: owner.phone,
          hostel: owner.hostel,
          room: owner.room,
          email: owner.email,
        },
        lastLocation: latestFixes[0]
          ? {
              lat: Number(latestFixes[0].lat),
              lng: Number(latestFixes[0].lng),
              accuracyM: latestFixes[0].accuracy_m,
              source: latestFixes[0].source,
              recordedAt: latestFixes[0].recorded_at,
            }
          : null,
      },
    });
  } catch (err) {
    console.error('Public bike error:', err);
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`BOAT Backend Server listening on http://0.0.0.0:${PORT}`);
});
