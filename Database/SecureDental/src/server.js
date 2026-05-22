require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const session = require('express-session');
const path = require('path');
const { pool, withActor } = require('./db');
const {
  issueCsrfToken,
  requireAuth,
  requireCsrf,
  requirePermission,
  clientIp,
  verifyPassword
} = require('./security');
const { validateLogin, validatePatient, validateAppointment } = require('./validators');

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'"],
      imgSrc: ["'self'", 'data:'],
      connectSrc: ["'self'"]
    }
  }
}));
app.use(express.json({ limit: '32kb' }));
app.use(session({
  name: 'securedental.sid',
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    sameSite: 'strict',
    secure: process.env.NODE_ENV === 'production',
    maxAge: 1000 * 60 * 30
  }
}));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.get('/api/session', (req, res) => {
  res.json({
    user: req.session.user || null,
    csrfToken: req.session.user ? req.session.csrfToken : null
  });
});

app.post('/api/login', async (req, res, next) => {
  try {
    const { email, password } = validateLogin(req.body);
    const result = await pool.query(
      'SELECT user_id, full_name, email, role, password_hash FROM dbo.app_user WHERE email = $1 AND is_active = 1',
      [email]
    );
    const user = result.rows[0];

    if (!user || !(await verifyPassword(password, user.password_hash))) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    req.session.regenerate((error) => {
      if (error) return next(error);

      req.session.user = {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        role: user.role
      };
      const csrfToken = issueCsrfToken(req);
      res.json({ user: req.session.user, csrfToken });
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/logout', requireAuth, requireCsrf, (req, res, next) => {
  req.session.destroy((error) => {
    if (error) return next(error);
    res.clearCookie('securedental.sid');
    res.json({ ok: true });
  });
});

app.get('/api/users/dentists', requireAuth, requirePermission('users:read'), async (req, res, next) => {
  try {
    const result = await pool.query(
      "SELECT user_id, full_name FROM dbo.app_user WHERE role = 'dentist' AND is_active = 1 ORDER BY full_name"
    );
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

app.get('/api/patients', requireAuth, requirePermission('patients:read'), async (req, res, next) => {
  try {
    const result = await withActor(req.session.user, clientIp(req), (client) => client.query(
      'SELECT TOP 50 patient_id, full_name, email, nric, phone, address, treatment_notes, created_at FROM dbo.patient_safe_view ORDER BY created_at DESC'
    ));
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

app.post('/api/patients', requireAuth, requirePermission('patients:write'), requireCsrf, async (req, res, next) => {
  try {
    const patient = validatePatient(req.body);
    const result = await withActor(req.session.user, clientIp(req), (client) => client.query(
      'EXEC dbo.create_patient $1, $2, $3, $4, $5, $6',
      [patient.fullName, patient.email, patient.nric, patient.phone, patient.address, patient.treatmentNotes]
    ));
    res.status(201).json({ patientId: result.rows[0].patient_id });
  } catch (error) {
    next(error);
  }
});

app.delete('/api/patients/:patientId', requireAuth, requirePermission('patients:delete'), requireCsrf, async (req, res, next) => {
  try {
    await withActor(req.session.user, clientIp(req), (client) => client.query(
      'EXEC dbo.delete_patient $1',
      [req.params.patientId]
    ));
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.get('/api/appointments', requireAuth, requirePermission('appointments:read'), async (req, res, next) => {
  try {
    const result = await withActor(req.session.user, clientIp(req), (client) => client.query(
      'SELECT TOP 50 * FROM dbo.appointment_view ORDER BY scheduled_at DESC'
    ));
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

app.post('/api/appointments', requireAuth, requirePermission('appointments:write'), requireCsrf, async (req, res, next) => {
  try {
    const appointment = validateAppointment(req.body);
    const result = await withActor(req.session.user, clientIp(req), (client) => client.query(
      'EXEC dbo.create_appointment $1, $2, $3, $4',
      [appointment.patientId, appointment.dentistId, appointment.scheduledAt, appointment.reason]
    ));
    res.status(201).json({ appointmentId: result.rows[0].appointment_id });
  } catch (error) {
    next(error);
  }
});

app.post('/api/appointments/:appointmentId/cancel', requireAuth, requirePermission('appointments:write'), requireCsrf, async (req, res, next) => {
  try {
    await withActor(req.session.user, clientIp(req), (client) => client.query(
      'EXEC dbo.cancel_appointment $1',
      [req.params.appointmentId]
    ));
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.get('/api/audit', requireAuth, requirePermission('audit:read'), async (req, res, next) => {
  try {
    const result = await withActor(req.session.user, clientIp(req), (client) => client.query(
      `SELECT TOP 50 audit_id, actor_role, action, entity_type, entity_id, created_at
       FROM dbo.audit_log
       ORDER BY created_at DESC`
    ));
    res.json(result.rows);
  } catch (error) {
    next(error);
  }
});

app.use(async (error, req, res, next) => {
  if (res.headersSent) return next(error);

  const message = error.message || 'Unexpected server error.';
  if (req.session?.user) {
    try {
      await withActor(req.session.user, clientIp(req), (client) => client.query(
        'EXEC dbo.log_security_event $1, $2, $3',
        ['application_error', message.slice(0, 250), clientIp(req)]
      ));
    } catch {
      // Do not hide the original application error if security logging fails.
    }
  }

  const status = /permission denied|csrf/i.test(message) ? 403 : 400;
  res.status(status).json({ error: message });
});

app.listen(port, () => {
  console.log(`SecureDental is running at http://localhost:${port}`);
});
