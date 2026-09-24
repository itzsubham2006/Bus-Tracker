const Database = require('better-sqlite3');
const crypto = require('crypto');
const config = require('./config');
const path = require('path');

// Initialize database
const dbPath = path.resolve(__dirname, '..', config.dbPath);
const db = new Database(dbPath);

// Create table if not exists
db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS buses (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT 0
  )
`);

/**
 * Generates a random 32-byte hex token
 * @returns {string} 64-character hex string
 */
function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Initializes the database with 4 default buses if it's empty
 */
function initDb() {
  const count = db.prepare('SELECT COUNT(*) as count FROM buses').get().count;

  if (count === 0) {
    console.log('Database is empty. Initializing with default buses...');
    const insert = db.prepare('INSERT INTO buses (id, name, token, is_active) VALUES (?, ?, ?, 0)');
    
    const defaultBuses = [
      { id: 1, name: 'Bus 1 (North Route)' },
      { id: 2, name: 'Bus 2 (South Route)' },
      { id: 3, name: 'Bus 3 (East Route)' },
      { id: 4, name: 'Bus 4 (West Route)' }
    ];

    const insertMany = db.transaction((buses) => {
      for (const bus of buses) {
        insert.run(bus.id, bus.name, bus.token);
      }
    });

    const busesToInsert = defaultBuses.map(bus => ({
      ...bus,
      token: generateToken()
    }));

    insertMany(busesToInsert);

    console.log('\n--- NEW BUS TOKENS GENERATED ---');
    console.log('IMPORTANT: Save these tokens securely. They are required for drivers to authenticate.');
    busesToInsert.forEach(bus => {
      console.log(`[${bus.name} (ID: ${bus.id})]: ${bus.token}`);
    });
    console.log('--------------------------------\n');
  } else {
    console.log(`Database initialized. Found ${count} buses.`);
  }
}

// Run initialization immediately
initDb();

module.exports = {
  db,
  generateToken
};
