-- SQL Server security setup for SecureDental.
-- Creates logins/users, session-context helpers, stored procedures, views, triggers,
-- and encryption controls for protected patient data.
USE SecureDental;
GO

IF SUSER_ID(N'dental_app') IS NULL
  CREATE LOGIN dental_app WITH PASSWORD = 'dental_app_password', CHECK_POLICY = OFF;
GO

ALTER LOGIN dental_app ENABLE;
ALTER LOGIN dental_app WITH PASSWORD = 'dental_app_password', CHECK_POLICY = OFF;
GO

IF SUSER_ID(N'dental_auditor') IS NULL
  CREATE LOGIN dental_auditor WITH PASSWORD = 'dental_auditor_password', CHECK_POLICY = OFF;
GO

ALTER LOGIN dental_auditor ENABLE;
ALTER LOGIN dental_auditor WITH PASSWORD = 'dental_auditor_password', CHECK_POLICY = OFF;
GO

IF SUSER_ID(N'dental_readonly') IS NULL
  CREATE LOGIN dental_readonly WITH PASSWORD = 'dental_readonly_password', CHECK_POLICY = OFF;
GO

ALTER LOGIN dental_readonly ENABLE;
ALTER LOGIN dental_readonly WITH PASSWORD = 'dental_readonly_password', CHECK_POLICY = OFF;
GO

IF USER_ID(N'dental_app') IS NULL
  CREATE USER dental_app FOR LOGIN dental_app WITH DEFAULT_SCHEMA = dbo;
GO

IF USER_ID(N'dental_auditor') IS NULL
  CREATE USER dental_auditor FOR LOGIN dental_auditor WITH DEFAULT_SCHEMA = dbo;
GO

IF USER_ID(N'dental_readonly') IS NULL
  CREATE USER dental_readonly FOR LOGIN dental_readonly WITH DEFAULT_SCHEMA = dbo;
GO

CREATE OR ALTER FUNCTION dbo.current_actor_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
  RETURN TRY_CONVERT(UNIQUEIDENTIFIER, NULLIF(CONVERT(VARCHAR(36), SESSION_CONTEXT(N'app.current_user_id')), ''));
END;
GO

CREATE OR ALTER FUNCTION dbo.current_actor_role()
RETURNS VARCHAR(30)
AS
BEGIN
  RETURN NULLIF(CONVERT(VARCHAR(30), SESSION_CONTEXT(N'app.current_user_role')), '');
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_patient_audit
ON dbo.patient
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'UPDATE',
      'patient',
      i.patient_id,
      (SELECT d.patient_id, d.full_name, d.email, d.created_by, d.created_at, d.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      (SELECT i.patient_id, i.full_name, i.email, i.created_by, i.created_at, i.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM inserted i
    JOIN deleted d ON d.patient_id = i.patient_id;
  END
  ELSE IF EXISTS (SELECT 1 FROM inserted)
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'INSERT',
      'patient',
      i.patient_id,
      NULL,
      (SELECT i.patient_id, i.full_name, i.email, i.created_by, i.created_at, i.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM inserted i;
  END
  ELSE
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'DELETE',
      'patient',
      d.patient_id,
      (SELECT d.patient_id, d.full_name, d.email, d.created_by, d.created_at, d.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      NULL,
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM deleted d;
  END
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_appointment_audit
ON dbo.appointment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;

  IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'UPDATE',
      'appointment',
      i.appointment_id,
      (SELECT d.appointment_id, d.patient_id, d.dentist_id, d.scheduled_at, d.reason, d.status, d.created_by, d.created_at, d.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      (SELECT i.appointment_id, i.patient_id, i.dentist_id, i.scheduled_at, i.reason, i.status, i.created_by, i.created_at, i.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM inserted i
    JOIN deleted d ON d.appointment_id = i.appointment_id;
  END
  ELSE IF EXISTS (SELECT 1 FROM inserted)
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'INSERT',
      'appointment',
      i.appointment_id,
      NULL,
      (SELECT i.appointment_id, i.patient_id, i.dentist_id, i.scheduled_at, i.reason, i.status, i.created_by, i.created_at, i.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM inserted i;
  END
  ELSE
  BEGIN
    INSERT INTO dbo.audit_log(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, ip_address)
    SELECT
      dbo.current_actor_id(),
      dbo.current_actor_role(),
      'DELETE',
      'appointment',
      d.appointment_id,
      (SELECT d.appointment_id, d.patient_id, d.dentist_id, d.scheduled_at, d.reason, d.status, d.created_by, d.created_at, d.updated_at FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
      NULL,
      CONVERT(VARCHAR(45), SESSION_CONTEXT(N'app.ip_address'))
    FROM deleted d;
  END
END;
GO

CREATE OR ALTER VIEW dbo.patient_safe_view AS
SELECT
  patient_id,
  full_name,
  email,
  CONVERT(VARCHAR(MAX), DECRYPTBYPASSPHRASE(CONVERT(NVARCHAR(4000), SESSION_CONTEXT(N'app.encryption_key')), nric_cipher)) AS nric,
  CONVERT(VARCHAR(MAX), DECRYPTBYPASSPHRASE(CONVERT(NVARCHAR(4000), SESSION_CONTEXT(N'app.encryption_key')), phone_cipher)) AS phone,
  CONVERT(VARCHAR(MAX), DECRYPTBYPASSPHRASE(CONVERT(NVARCHAR(4000), SESSION_CONTEXT(N'app.encryption_key')), address_cipher)) AS address,
  CASE
    WHEN dbo.current_actor_role() IN ('dentist', 'admin')
      THEN CONVERT(VARCHAR(MAX), DECRYPTBYPASSPHRASE(CONVERT(NVARCHAR(4000), SESSION_CONTEXT(N'app.encryption_key')), treatment_notes_cipher))
    ELSE '[restricted]'
  END AS treatment_notes,
  created_at,
  updated_at
FROM dbo.patient;
GO

CREATE OR ALTER VIEW dbo.appointment_view AS
SELECT
  a.appointment_id,
  a.patient_id,
  p.full_name AS patient_name,
  p.email AS patient_email,
  a.dentist_id,
  u.full_name AS dentist_name,
  a.scheduled_at,
  a.reason,
  a.status,
  a.created_at,
  a.updated_at
FROM dbo.appointment a
JOIN dbo.patient p ON p.patient_id = a.patient_id
JOIN dbo.app_user u ON u.user_id = a.dentist_id;
GO

CREATE OR ALTER PROCEDURE dbo.create_patient
  @p_full_name VARCHAR(MAX),
  @p_email VARCHAR(MAX),
  @p_nric VARCHAR(MAX),
  @p_phone VARCHAR(MAX),
  @p_address VARCHAR(MAX),
  @p_treatment_notes VARCHAR(MAX)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @encryption_key NVARCHAR(4000) = CONVERT(NVARCHAR(4000), SESSION_CONTEXT(N'app.encryption_key'));
  DECLARE @new_ids TABLE (patient_id UNIQUEIDENTIFIER);

  IF dbo.current_actor_role() NOT IN ('admin', 'dentist', 'receptionist')
    THROW 50001, 'permission denied', 1;

  IF NULLIF(@encryption_key, N'') IS NULL
    THROW 50002, 'missing encryption key', 1;

  INSERT INTO dbo.patient (
    full_name,
    email,
    nric_cipher,
    phone_cipher,
    address_cipher,
    treatment_notes_cipher,
    created_by
  )
  OUTPUT INSERTED.patient_id INTO @new_ids
  VALUES (
    LTRIM(RTRIM(@p_full_name)),
    LOWER(LTRIM(RTRIM(@p_email))),
    ENCRYPTBYPASSPHRASE(@encryption_key, @p_nric),
    ENCRYPTBYPASSPHRASE(@encryption_key, @p_phone),
    ENCRYPTBYPASSPHRASE(@encryption_key, @p_address),
    ENCRYPTBYPASSPHRASE(@encryption_key, @p_treatment_notes),
    dbo.current_actor_id()
  );

  SELECT patient_id FROM @new_ids;
END;
GO

CREATE OR ALTER PROCEDURE dbo.delete_patient
  @p_patient_id UNIQUEIDENTIFIER
AS
BEGIN
  SET NOCOUNT ON;

  IF dbo.current_actor_role() NOT IN ('admin', 'receptionist')
    THROW 50001, 'permission denied', 1;

  DELETE FROM dbo.patient WHERE patient_id = @p_patient_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.create_appointment
  @p_patient_id UNIQUEIDENTIFIER,
  @p_dentist_id UNIQUEIDENTIFIER,
  @p_scheduled_at DATETIME,
  @p_reason VARCHAR(MAX)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @new_ids TABLE (appointment_id UNIQUEIDENTIFIER);

  IF dbo.current_actor_role() NOT IN ('admin', 'dentist', 'receptionist')
    THROW 50001, 'permission denied', 1;

  INSERT INTO dbo.appointment (patient_id, dentist_id, scheduled_at, reason, created_by)
  OUTPUT INSERTED.appointment_id INTO @new_ids
  VALUES (@p_patient_id, @p_dentist_id, @p_scheduled_at, LTRIM(RTRIM(@p_reason)), dbo.current_actor_id());

  SELECT appointment_id FROM @new_ids;
END;
GO

CREATE OR ALTER PROCEDURE dbo.cancel_appointment
  @p_appointment_id UNIQUEIDENTIFIER
AS
BEGIN
  SET NOCOUNT ON;

  IF dbo.current_actor_role() NOT IN ('admin', 'dentist', 'receptionist')
    THROW 50001, 'permission denied', 1;

  UPDATE dbo.appointment
  SET status = 'cancelled',
      updated_at = GETDATE()
  WHERE appointment_id = @p_appointment_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.log_security_event
  @p_event_type VARCHAR(80),
  @p_detail VARCHAR(MAX),
  @p_ip_address VARCHAR(45)
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO dbo.security_event(actor_id, event_type, detail, ip_address)
  VALUES (dbo.current_actor_id(), @p_event_type, @p_detail, @p_ip_address);
END;
GO

GRANT SELECT ON OBJECT::dbo.app_user TO dental_app;
GRANT SELECT ON OBJECT::dbo.patient_safe_view TO dental_app;
GRANT SELECT ON OBJECT::dbo.appointment_view TO dental_app;
GRANT SELECT ON OBJECT::dbo.audit_log TO dental_app;
GRANT SELECT ON OBJECT::dbo.security_event TO dental_app;
GRANT EXECUTE ON OBJECT::dbo.create_patient TO dental_app;
GRANT EXECUTE ON OBJECT::dbo.delete_patient TO dental_app;
GRANT EXECUTE ON OBJECT::dbo.create_appointment TO dental_app;
GRANT EXECUTE ON OBJECT::dbo.cancel_appointment TO dental_app;
GRANT EXECUTE ON OBJECT::dbo.log_security_event TO dental_app;
GO

GRANT SELECT ON OBJECT::dbo.patient_safe_view TO dental_readonly;
GRANT SELECT ON OBJECT::dbo.appointment_view TO dental_readonly;
GRANT SELECT ON OBJECT::dbo.audit_log TO dental_auditor;
GRANT SELECT ON OBJECT::dbo.security_event TO dental_auditor;
GO
