require('dotenv').config();

const config = {
  port: process.env.PORT || 3000,
  adminSecret: process.env.ADMIN_SECRET || 'change-me-to-a-secure-random-string',
  dbPath: process.env.DB_PATH || 'buses.db'
};

module.exports = config;
