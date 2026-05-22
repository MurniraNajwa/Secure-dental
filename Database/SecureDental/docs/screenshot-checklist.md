# Screenshot Checklist

Use this as the practical evidence list for the report.

## Setup Screenshots

- Project folder showing `src`, `db`, `public`, and `docs`.
- `.env` configuration with secrets hidden or blurred.
- SQL Server running and visible in SSMS.
- Database initialization command.
- Application running at `http://localhost:3000`.

## Task 2 Functional Screenshots

- Login page.
- Successful login as `reception@securedental.local`.
- Insert first patient record.
- Patient table after first insert, including the highlighted newly inserted row.
- Create appointment for the first patient using the dentist dropdown with multiple seeded dentists.
- Appointment table after creation.
- Delete one old patient or cancel one appointment.
- Insert another new patient.
- Final patient and appointment tables.

## Task 5 Security Screenshots

- `db/01_security.sql` showing SQL Server logins, users, grants, views, and stored procedures.
- SQL Server or `sqlcmd` output showing `dental_app` cannot select from base `patient` table.
- SQL injection test input entered as a normal dental treatment note.
- `patient` table still exists after SQL injection test.
- Audit log showing `INSERT`, `DELETE`, or `UPDATE`.
- Auditor login showing audit log access.
- Auditor login showing patient and appointment panels are hidden.
- Auditor API test showing `/api/patients` or `/api/appointments` returns permission denied.
- Attempted unauthorized action returning permission denied.

## Presentation Evidence

- GitHub repository page with code uploaded.
- YouTube upload page or final video page.
- Cover page containing GitHub and YouTube links.
