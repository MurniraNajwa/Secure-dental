const crypto = require('crypto');

const ROLE_PERMISSIONS = {
  // Read permissions are explicit so auditor accounts cannot reach patient or appointment APIs.
  admin: ['patients:read', 'patients:write', 'patients:delete', 'appointments:read', 'appointments:write', 'audit:read', 'users:read'],
  dentist: ['patients:read', 'patients:write', 'appointments:read', 'appointments:write', 'users:read'],
  receptionist: ['patients:read', 'patients:write', 'patients:delete', 'appointments:read', 'appointments:write', 'users:read'],
  auditor: ['audit:read']
};

function requireAuth(req, res, next) {
  if (!req.session.user) {
    return res.status(401).json({ error: 'Authentication required.' });
  }
  next();
}

function requirePermission(permission) {
  return (req, res, next) => {
    const user = req.session.user;
    const permissions = ROLE_PERMISSIONS[user?.role] || [];

    if (!permissions.includes(permission)) {
      return res.status(403).json({ error: 'Permission denied.' });
    }

    next();
  };
}

function issueCsrfToken(req) {
  req.session.csrfToken = crypto.randomBytes(32).toString('hex');
  return req.session.csrfToken;
}

function requireCsrf(req, res, next) {
  const token = req.get('x-csrf-token');

  if (!token || token !== req.session.csrfToken) {
    return res.status(403).json({ error: 'Invalid CSRF token.' });
  }

  next();
}

function clientIp(req) {
  return req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.socket.remoteAddress || '127.0.0.1';
}

async function verifyPassword(password, hash) {
  const [scheme, cost, salt, expected] = String(hash).split('$');
  if (scheme !== 'scrypt' || !cost || !salt || !expected) {
    return false;
  }

  const derived = await new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, 64, { N: Number(cost) }, (error, key) => {
      if (error) reject(error);
      else resolve(key);
    });
  });
  const expectedBuffer = Buffer.from(expected, 'hex');

  return expectedBuffer.length === derived.length
    && crypto.timingSafeEqual(expectedBuffer, derived);
}

module.exports = {
  issueCsrfToken,
  requireAuth,
  requireCsrf,
  requirePermission,
  clientIp,
  verifyPassword
};
