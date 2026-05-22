let state = {
  user: null,
  csrfToken: null,
  patients: [],
  dentists: [],
  appointments: [],
  highlightedPatientId: null
};

const $ = (selector) => document.querySelector(selector);

const ROLE_UI = {
  admin: {
    title: 'Administration workspace',
    description: 'Full operational access with audit visibility.',
    permissions: ['patient:read', 'patient:create', 'patient:delete', 'appointment:read', 'appointment:create', 'appointment:cancel', 'audit:read']
  },
  dentist: {
    title: 'Dentist workspace',
    description: 'Dental treatment review and appointment management without deletion controls.',
    permissions: ['patient:read', 'patient:create', 'appointment:read', 'appointment:create', 'appointment:cancel']
  },
  receptionist: {
    title: 'Front desk workspace',
    description: 'Patient registration, dental scheduling, and entry maintenance.',
    permissions: ['patient:read', 'patient:create', 'patient:delete', 'appointment:read', 'appointment:create', 'appointment:cancel']
  },
  auditor: {
    title: 'Audit workspace',
    description: 'Read-only review of dental records and compliance logs.',
    permissions: ['audit:read']
  }
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(state.csrfToken ? { 'x-csrf-token': state.csrfToken } : {}),
      ...(options.headers || {})
    }
  });
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(data.error || 'Request failed.');
  }

  return data;
}

function setMessage(text) {
  $('#message').textContent = text;
}

function formData(form) {
  return Object.fromEntries(new FormData(form).entries());
}

function nextDemoNumber() {
  return String(Date.now()).slice(-6);
}

function toDateTimeLocal(date) {
  const offsetDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return offsetDate.toISOString().slice(0, 16);
}

function fillEmptyPatientFields(form) {
  const demoNumber = nextDemoNumber();
  const defaults = {
    fullName: `Demo Patient ${demoNumber}`,
    email: `patient${demoNumber}@example.com`,
    nric: `990101-10-${demoNumber.slice(-4)}`,
    phone: `+6012${demoNumber}`,
    address: 'Cyberjaya, Selangor',
    treatmentNotes: 'Auto-added demo dental check-up record'
  };

  Object.entries(defaults).forEach(([name, value]) => {
    if (!form.elements[name].value.trim()) {
      form.elements[name].value = value;
    }
  });
}

function fillEmptyAppointmentFields(form) {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(9, 0, 0, 0);

  if (!form.elements.patientId.value && state.patients[0]) {
    form.elements.patientId.value = state.patients[0].patient_id;
  }

  if (!form.elements.dentistId.value && state.dentists[0]) {
    form.elements.dentistId.value = state.dentists[0].user_id;
  }

  if (!form.elements.scheduledAt.value) {
    form.elements.scheduledAt.value = toDateTimeLocal(tomorrow);
  }

  if (!form.elements.reason.value.trim()) {
    form.elements.reason.value = 'Auto-scheduled dental check-up';
  }
}

function renderShell() {
  const signedIn = Boolean(state.user);
  const roleUi = ROLE_UI[state.user?.role] || { title: 'Workspace', description: 'Role-based controls are active.', permissions: [] };
  $('#loginPanel').classList.toggle('hidden', signedIn);
  $('#appPanel').classList.toggle('hidden', !signedIn);
  $('#logoutButton').classList.toggle('hidden', !signedIn);
  $('#auditPanel').classList.toggle('hidden', !can('audit:read'));
  // Auditor sessions are audit-only; hide operational panels that contain personal data.
  $('#summaryPanel').classList.toggle('hidden', !can('patient:read') && !can('appointment:read'));
  $('#patientsPanel').classList.toggle('hidden', !can('patient:read'));
  $('#appointmentsPanel').classList.toggle('hidden', !can('appointment:read'));
  $('#entryPanels').classList.toggle('hidden', !can('patient:create') && !can('appointment:create'));
  $('#patientEntryPanel').classList.toggle('hidden', !can('patient:create'));
  $('#appointmentEntryPanel').classList.toggle('hidden', !can('appointment:create'));

  $('#sessionLabel').textContent = signedIn
    ? `${state.user.full_name} (${state.user.role})`
    : 'Sign in to manage dental records.';
  $('#roleSummary').textContent = signedIn ? displayRole(state.user.role) : '-';
  $('#accessRole').textContent = signedIn ? displayRole(state.user.role) : 'Role';
  $('#accessTitle').textContent = roleUi.title;
  $('#accessDescription').textContent = roleUi.description;
}

function renderPatients() {
  const rows = state.patients.map((patient) => `
    <tr data-patient-id="${patient.patient_id}" class="${patient.patient_id === state.highlightedPatientId ? 'rowHighlight' : ''}">
      <td>
        <span class="cellMain">${escapeHtml(patient.full_name)}</span>
        <span class="cellSub">${escapeHtml(patient.nric)}</span>
      </td>
      <td>
        <span class="cellMain">${escapeHtml(patient.email)}</span>
        <span class="cellSub">${escapeHtml(patient.address)}</span>
      </td>
      <td>${escapeHtml(patient.phone)}</td>
      <td>${escapeHtml(patient.treatment_notes)}</td>
      <td>${can('patient:delete')
        ? `<button class="danger compact" data-delete-patient="${patient.patient_id}" type="button">Delete</button>`
        : '<span class="badge neutral">View only</span>'}
      </td>
    </tr>
  `).join('');

  $('#patientsTable').innerHTML = rows || '<tr><td class="emptyState" colspan="5">No patients yet.</td></tr>';
  $('#appointmentForm select[name="patientId"]').innerHTML = state.patients
    .map((patient) => `<option value="${patient.patient_id}">${escapeHtml(patient.full_name)}</option>`)
    .join('');
}

function scrollToPatient(patientId) {
  const row = document.querySelector(`[data-patient-id="${patientId}"]`);
  const target = row || $('#patientsPanel');

  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
}

function renderDentists() {
  $('#appointmentForm select[name="dentistId"]').innerHTML = state.dentists
    .map((dentist) => `<option value="${dentist.user_id}">${escapeHtml(dentist.full_name)}</option>`)
    .join('');
}

function renderAppointments() {
  const rows = state.appointments.map((appointment) => `
    <tr>
      <td>
        <span class="cellMain">${escapeHtml(appointment.patient_name)}</span>
        <span class="cellSub">${escapeHtml(appointment.patient_email)}</span>
      </td>
      <td>${escapeHtml(appointment.dentist_name)}</td>
      <td>
        <span class="cellMain">${new Date(appointment.scheduled_at).toLocaleDateString()}</span>
        <span class="cellSub">${new Date(appointment.scheduled_at).toLocaleTimeString()}</span>
      </td>
      <td>${statusPill(appointment.status)}</td>
      <td>
        ${appointment.status === 'scheduled'
          ? can('appointment:cancel')
            ? `<button class="compact" data-cancel-appointment="${appointment.appointment_id}" type="button">Cancel</button>`
            : '<span class="badge neutral">Locked</span>'
          : ''}
      </td>
    </tr>
  `).join('');

  $('#appointmentsTable').innerHTML = rows || '<tr><td class="emptyState" colspan="5">No appointments yet.</td></tr>';
}

function renderAudit(entries) {
  const rows = entries.map((entry) => `
    <tr>
      <td>${new Date(entry.created_at).toLocaleString()}</td>
      <td><span class="badge">${escapeHtml(entry.actor_role || 'system')}</span></td>
      <td><span class="cellMain">${escapeHtml(entry.action)}</span></td>
      <td>${escapeHtml(entry.entity_type)}</td>
    </tr>
  `).join('');

  $('#auditTable').innerHTML = rows || '<tr><td class="emptyState" colspan="4">No audit records.</td></tr>';
}

function renderSummary() {
  $('#patientCount').textContent = state.patients.length;
  $('#appointmentCount').textContent = state.appointments.length;
  $('#activeAppointmentCount').textContent = state.appointments
    .filter((appointment) => appointment.status === 'scheduled')
    .length;
}

function statusPill(status) {
  const normalized = String(status || '').toLowerCase();
  const className = {
    scheduled: 'statusScheduled',
    completed: 'statusCompleted',
    cancelled: 'statusCancelled'
  }[normalized] || 'statusScheduled';

  return `<span class="statusPill ${className}">${escapeHtml(status)}</span>`;
}

function can(permission) {
  return ROLE_UI[state.user?.role]?.permissions.includes(permission) || false;
}

function displayRole(role) {
  return String(role || '-').replace(/^\w/, (letter) => letter.toUpperCase());
}

async function loadData() {
  // Fetch only the datasets the signed-in role is allowed to view.
  state.patients = can('patient:read') ? await api('/api/patients') : [];
  state.appointments = can('appointment:read') ? await api('/api/appointments') : [];
  state.dentists = state.user?.role !== 'auditor' ? await api('/api/users/dentists') : [];

  renderPatients();
  renderAppointments();
  renderDentists();
  renderSummary();

  if (state.user?.role === 'admin' || state.user?.role === 'auditor') {
    renderAudit(await api('/api/audit'));
  }
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  })[char]);
}

$('#loginForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  try {
    const data = await api('/api/login', {
      method: 'POST',
      body: JSON.stringify(formData(event.currentTarget))
    });
    state.user = data.user;
    state.csrfToken = data.csrfToken;
    renderShell();
    await loadData();
    setMessage('Login successful.');
  } catch (error) {
    setMessage(error.message);
  }
});

$('#logoutButton').addEventListener('click', async () => {
  await api('/api/logout', { method: 'POST', body: '{}' });
  state = { user: null, csrfToken: null, patients: [], dentists: [], appointments: [], highlightedPatientId: null };
  renderShell();
  setMessage('Logged out.');
});

$('#patientForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;

  try {
    // Auto-add helper: empty patient fields are filled before the insert is sent to SQL Server.
    fillEmptyPatientFields(form);
    const created = await api('/api/patients', {
      method: 'POST',
      body: JSON.stringify(formData(form))
    });
    state.highlightedPatientId = created.patientId;
    form.reset();
    await loadData();
    setMessage('Patient inserted and audit log recorded.');
    requestAnimationFrame(() => scrollToPatient(created.patientId));
  } catch (error) {
    setMessage(error.message);
  }
});

$('#appointmentForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.currentTarget;

  try {
    // Auto-schedule helper: empty appointment fields are filled before the insert is sent to SQL Server.
    fillEmptyAppointmentFields(form);
    await api('/api/appointments', {
      method: 'POST',
      body: JSON.stringify(formData(form))
    });
    form.reset();
    await loadData();
    setMessage('Appointment scheduled.');
  } catch (error) {
    setMessage(error.message);
  }
});

$('#refreshButton').addEventListener('click', loadData);

document.addEventListener('click', async (event) => {
  const patientId = event.target.dataset.deletePatient;
  const appointmentId = event.target.dataset.cancelAppointment;

  try {
    if (patientId) {
      await api(`/api/patients/${patientId}`, { method: 'DELETE' });
      await loadData();
      setMessage('Patient deleted.');
    }

    if (appointmentId) {
      await api(`/api/appointments/${appointmentId}/cancel`, { method: 'POST', body: '{}' });
      await loadData();
      setMessage('Appointment cancelled.');
    }
  } catch (error) {
    setMessage(error.message);
  }
});

api('/api/session')
  .then(async (session) => {
    state.user = session.user;
    state.csrfToken = session.csrfToken;
    renderShell();
    if (state.user) await loadData();
  })
  .catch(() => renderShell());
