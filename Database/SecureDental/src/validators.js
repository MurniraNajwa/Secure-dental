const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^[+0-9 -]{8,20}$/;
const NRIC_PATTERN = /^[0-9]{6}-[0-9]{2}-[0-9]{4}$/;

function assertString(value, name, min, max) {
  if (typeof value !== 'string') {
    throw new Error(`${name} is required.`);
  }

  const trimmed = value.trim();
  if (trimmed.length < min || trimmed.length > max) {
    throw new Error(`${name} must be between ${min} and ${max} characters.`);
  }

  return trimmed;
}

function validateLogin(body) {
  const email = assertString(body.email, 'Email', 5, 120).toLowerCase();
  const password = assertString(body.password, 'Password', 8, 200);

  if (!EMAIL_PATTERN.test(email)) {
    throw new Error('Email format is invalid.');
  }

  return { email, password };
}

function validatePatient(body) {
  const fullName = assertString(body.fullName, 'Full name', 2, 120);
  const email = assertString(body.email, 'Email', 5, 120).toLowerCase();
  const nric = assertString(body.nric, 'NRIC', 14, 14);
  const phone = assertString(body.phone, 'Phone', 8, 20);
  const address = assertString(body.address, 'Address', 5, 250);
  const treatmentNotes = assertString(body.treatmentNotes, 'Treatment notes', 1, 500);

  if (!EMAIL_PATTERN.test(email)) throw new Error('Email format is invalid.');
  if (!NRIC_PATTERN.test(nric)) throw new Error('NRIC format must be YYMMDD-PB-####.');
  if (!PHONE_PATTERN.test(phone)) throw new Error('Phone number format is invalid.');

  return { fullName, email, nric, phone, address, treatmentNotes };
}

function validateAppointment(body) {
  const patientId = assertString(body.patientId, 'Patient', 36, 36);
  const dentistId = assertString(body.dentistId, 'Dentist', 36, 36);
  const scheduledAt = assertString(body.scheduledAt, 'Scheduled date', 10, 40);
  const reason = assertString(body.reason, 'Reason', 3, 250);

  const date = new Date(scheduledAt);
  if (Number.isNaN(date.getTime())) {
    throw new Error('Scheduled date is invalid.');
  }

  return { patientId, dentistId, scheduledAt: date.toISOString(), reason };
}

module.exports = {
  validateLogin,
  validatePatient,
  validateAppointment
};
