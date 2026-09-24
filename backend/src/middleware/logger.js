/**
 * Request Logger Middleware
 */
function logger(req, res, next) {
  const start = Date.now();
  
  // Capture response finish event
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${res.statusCode} - ${duration}ms`);
  });

  next();
}

module.exports = logger;
