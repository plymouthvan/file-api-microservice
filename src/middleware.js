/**
 * Authentication middleware
 * Validates the bearer token in the Authorization header
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      status: 'error',
      message: 'Unauthorized'
    });
  }
  
  const token = authHeader.split(' ')[1];
  
  if (token !== process.env.API_TOKEN) {
    return res.status(401).json({
      status: 'error',
      message: 'Invalid token'
    });
  }
  
  next();
}

module.exports = {
  authMiddleware
};
