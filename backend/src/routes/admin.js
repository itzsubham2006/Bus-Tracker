const express = require('express');
const router = express.Router();
const config = require('../config');
const { db, generateToken } = require('../db');

/**
 * POST /api/admin/regenerate-token
 * Regenerates the token for a specific bus.
 */
router.post('/regenerate-token', (req, res) => {
  const { adminSecret, busId } = req.body;

  if (adminSecret !== config.adminSecret) {
    return res.status(403).json({ error: 'Forbidden: Invalid admin secret' });
  }

  if (!busId) {
    return res.status(400).json({ error: 'Bad Request: busId is required' });
  }

  const id = parseInt(busId, 10);
  
  // Check if bus exists
  const bus = db.prepare('SELECT id, name FROM buses WHERE id = ?').get(id);
  if (!bus) {
    return res.status(404).json({ error: 'Bus not found' });
  }

  // Generate and save new token
  const newToken = generateToken();
  db.prepare('UPDATE buses SET token = ? WHERE id = ?').run(newToken, id);

  console.log('\n--- ADMIN ACTION: TOKEN REGENERATED ---');
  console.log(`Bus: ${bus.name} (ID: ${bus.id})`);
  console.log(`New Token: ${newToken}`);
  console.log('---------------------------------------\n');

  res.json({
    success: true,
    busId: id,
    newToken
  });
});

module.exports = router;
