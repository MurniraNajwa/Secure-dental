# SecureDental SQL Assignment

SecureDental is a small dental appointment and patient-record system built for CCS6344 Assignment 1. It uses Microsoft SQL Server and demonstrates security controls that are easy to prove in the report: SQL Server logins/users, encrypted personal data, audit logs, least-privilege access, parameterized queries, RBAC, CSRF protection, session hardening, input validation, and security tests.

## Recommended Stack

- Frontend: HTML, CSS, JavaScript.
- Web server: Node.js with Express.
- SQL database server: Microsoft SQL Server 2022 or SQL Server Developer Edition.
- Database management: SQL Server Management Studio.
- Server OS: Windows 11 for local development.

## Main Features

- Login with role-based access control: admin, dentist, receptionist, auditor.
- Patient creation, listing, and deletion.
- Appointment scheduling and cancellation.
- Dentist selection includes four seeded dentists for appointment scheduling.
- New patient inserts scroll to the patient table and highlight the newly created row.
- Audit log viewer for the auditor role.
- Encrypted sensitive fields in SQL Server using `ENCRYPTBYPASSPHRASE`.
- Stored procedures and limited grants so the application login cannot directly read or alter protected base tables.

## Quick Start With SQL Server And SSMS

1. Install Node.js 20+, Microsoft SQL Server, SQL Server Management Studio, and the `sqlcmd` command-line tool.
2. In SQL Server Configuration Manager, make sure TCP/IP is enabled for SQL Server and that SQL Server is listening on port `1433`.
3. Open SSMS and connect as a Windows administrator or SQL Server administrator.
4. Open and run these scripts in order:

```text
db/00_schema.sql
db/01_security.sql
db/02_seed.sql
```

5. Copy `.env.example` to `.env` and adjust the SQL Server settings if your local instance is not `localhost:1433`.
6. Install dependencies:

```powershell
npm install
```

7. Start the web app:

```powershell
npm start
```

If PowerShell blocks the `npm` script shim, use:

```powershell
npm.cmd start
```

8. Open `http://localhost:3000`.

You can also initialize the database with Windows authentication if `sqlcmd` is installed and your Windows account has SQL Server admin rights:

```powershell
npm run db:init
```

Seed accounts:

| Role | Email | Password |
| --- | --- | --- |
| Admin | admin@securedental.local | AdminPass123! |
| Dentist | dentist@securedental.local | DentistPass123! |
| Receptionist | reception@securedental.local | ReceptionPass123! |
| Auditor | auditor@securedental.local | AuditorPass123! |

Additional seeded dentists for appointment selection:

| Dentist | Email | Password |
| --- | --- | --- |
| Dr Farid Hassan | farid.hassan@securedental.local | DentistPass123! |
| Dr Mei Ling Tan | mei.tan@securedental.local | DentistPass123! |
| Dr Ravi Kumar | ravi.kumar@securedental.local | DentistPass123! |

For the class demo, keep `APP_ENCRYPTION_KEY=change-this-demo-key` so the seeded sample patient can be decrypted. For a real deployment, replace it before inserting production data.

## Local MSSQL Configuration

The app reads SQL Server settings from `.env`:

```text
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=SecureDental
DB_USER=dental_app
DB_PASSWORD=dental_app_password
DB_ENCRYPT=false
DB_TRUST_SERVER_CERTIFICATE=true
```

The SQL scripts create the `SecureDental` database and these SQL Server logins:

| Login | Purpose |
| --- | --- |
| `dental_app` | Used by the Node.js application. |
| `dental_auditor` | Read-only audit/security-event access. |
| `dental_readonly` | Read-only access to safe views. |

## Managing The Database In SSMS

1. Connect to the SQL Server instance in SSMS.
2. Expand `Databases`, then open `SecureDental`.
3. Use `Tables` to inspect base tables such as `dbo.app_user`, `dbo.patient`, and `dbo.appointment`.
4. Use `Views` to inspect `dbo.patient_safe_view` and `dbo.appointment_view`.
5. Use `Programmability > Stored Procedures` to inspect CRUD procedures such as `dbo.create_patient`, `dbo.delete_patient`, `dbo.create_appointment`, and `dbo.cancel_appointment`.
6. Use `Security > Users` to inspect database users and permissions.


## Project Structure

```text
db/
  00_schema.sql
  01_security.sql
  02_seed.sql
  03_security_tests.sql
docs/
  report-draft.md
  screenshot-checklist.md
  presentation-script.md
public/
  index.html
  styles.css
  app.js
src/
  db.js
  security.js
  server.js
  validators.js
```
