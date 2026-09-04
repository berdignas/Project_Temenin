const app = require('./app');

const PORT = 3004; // Hardcoded to 3004 to prevent PM2 env port conflicts

const server = app.listen(PORT, () => {
  console.log('\n═══════════════════════════════════════════════════');
  console.log('🚀 Temenin Ajaa DRIVER Backend Server');
  console.log('═══════════════════════════════════════════════════');
  console.log(`✅ Running on port ${PORT}`);
  console.log(`📍 Local: http://localhost:${PORT}`);
  console.log(`📍 Health: http://localhost:${PORT}/health`);
  console.log('═══════════════════════════════════════════════════\n');
});

// Process signal handlers for graceful shutdown
const shutdown = () => {
  console.log('\n🛑 Shutting down server gracefully...');
  server.close(() => {
    console.log('✅ Server stopped');
    process.exit(0);
  });
  
  setTimeout(() => {
    console.error('⚠️ Forcefully shutting down');
    process.exit(1);
  }, 5000);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
