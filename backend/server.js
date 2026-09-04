const app = require('./src/app');

const PORT = 3002; // Hardcoded to 3002 to prevent PM2 env port conflicts
let server;

// Graceful shutdown function
const gracefulShutdown = () => {
  console.log('\n🛑 Received shutdown signal, closing server...');
  
  if (server) {
    server.close(() => {
      console.log('✅ Server closed successfully');
      process.exit(0);
    });
    
    // Force close after 10 seconds if server doesn't close
    setTimeout(() => {
      console.error('⚠️ Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  } else {
    process.exit(0);
  }
};

// Start server
const startServer = async () => {
  try {
    server = app.listen(PORT, () => {
      console.log('\n═══════════════════════════════════════════════════');
      console.log('🚀 Temenin Ajaa Backend Server');
      console.log('═══════════════════════════════════════════════════');
      console.log(`✅ Server running on port ${PORT}`);
      console.log(`📍 Local: http://localhost:${PORT}`);
      console.log(`📍 Health: http://localhost:${PORT}/health`);
      console.log(`📍 API: http://localhost:${PORT}/api`);
      console.log('═══════════════════════════════════════════════════\n');
    });
    
    // Handle server errors
    server.on('error', (error) => {
      if (error.code === 'EADDRINUSE') {
        console.error(`❌ Port ${PORT} is already in use. Please free the port or use a different port.`);
        process.exit(1);
      } else {
        console.error('❌ Server error:', error);
        process.exit(1);
      }
    });
    
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

// Global error handlers
process.on('uncaughtException', (err) => {
  console.error('\n═══════════════════════════════════════════════════');
  console.error('💥 UNCAUGHT EXCEPTION');
  console.error('═══════════════════════════════════════════════════');
  console.error('Error:', err.message);
  console.error('Stack:', err.stack);
  console.error('═══════════════════════════════════════════════════\n');
  
  gracefulShutdown();
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('\n═══════════════════════════════════════════════════');
  console.error('💥 UNHANDLED REJECTION');
  console.error('═══════════════════════════════════════════════════');
  console.error('Reason:', reason);
  console.error('Promise:', promise);
  console.error('═══════════════════════════════════════════════════\n');
  
  gracefulShutdown();
});

// Handle process signals
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Handle uncaught exceptions in promises
process.on('warning', (warning) => {
  console.warn('⚠️ Warning:', warning.name, warning.message);
});

// Monitor memory usage
setInterval(() => {
  const memoryUsage = process.memoryUsage();
  const memoryUsageMB = {
    rss: Math.round(memoryUsage.rss / 1024 / 1024),
    heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
    heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024),
    external: Math.round(memoryUsage.external / 1024 / 1024)
  };
  
  console.log('📊 Memory Usage (MB):', memoryUsageMB);
}, 60000); // Log every minute

// Start the server
startServer();

// Export for testing purposes
module.exports = { server };