require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs-extra');
const routes = require('./routes');

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Ensure public directory exists
fs.ensureDirSync(path.join(__dirname, '..', 'public'));

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // For JSON body parsing with large payloads

// Static file serving for public files
// This is isolated and simple - no directory listing
app.use('/public', (req, res, next) => {
  // Only allow access to files through the /public/:folder/:filename route
  // This prevents directory listing and direct access to files
  if (req.path.split('/').length <= 2) {
    return res.status(404).json({
      status: 'error',
      message: 'Not found'
    });
  }
  next();
}, express.static(path.join(__dirname, '..', 'public'), {
  dotfiles: 'deny',
  index: false,
  maxAge: '1d',
  redirect: false
}));

// API routes
app.use('/', routes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    status: 'error',
    message: 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`File API Microservice running on port ${PORT}`);
  console.log(`Public URL: ${process.env.PUBLIC_URL}`);
});

module.exports = app;
