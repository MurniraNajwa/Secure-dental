-- SQL Server schema for SecureDental.
IF DB_ID(N'SecureDental') IS NULL
BEGIN
  CREATE DATABASE SecureDental;
END
GO

USE SecureDental;
GO

IF OBJECT_ID(N'dbo.app_user', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.app_user (
    user_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_app_user PRIMARY KEY DEFAULT NEWID(),
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) NOT NULL CONSTRAINT uq_app_user_email UNIQUE,
    role VARCHAR(30) NOT NULL CONSTRAINT ck_app_user_role CHECK (role IN ('admin', 'dentist', 'receptionist', 'auditor')),
    password_hash VARCHAR(300) NOT NULL,
    is_active BIT NOT NULL CONSTRAINT df_app_user_is_active DEFAULT 1,
    created_at DATETIME NOT NULL CONSTRAINT df_app_user_created_at DEFAULT GETDATE()
  );
END
GO

IF OBJECT_ID(N'dbo.patient', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.patient (
    patient_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_patient PRIMARY KEY DEFAULT NEWID(),
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) NOT NULL CONSTRAINT uq_patient_email UNIQUE,
    nric_cipher VARBINARY(MAX) NOT NULL,
    phone_cipher VARBINARY(MAX) NOT NULL,
    address_cipher VARBINARY(MAX) NOT NULL,
    treatment_notes_cipher VARBINARY(MAX) NOT NULL,
    created_by UNIQUEIDENTIFIER NULL CONSTRAINT fk_patient_created_by REFERENCES dbo.app_user(user_id),
    created_at DATETIME NOT NULL CONSTRAINT df_patient_created_at DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL CONSTRAINT df_patient_updated_at DEFAULT GETDATE()
  );
END
GO

IF OBJECT_ID(N'dbo.appointment', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.appointment (
    appointment_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_appointment PRIMARY KEY DEFAULT NEWID(),
    patient_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT fk_appointment_patient REFERENCES dbo.patient(patient_id) ON DELETE CASCADE,
    dentist_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT fk_appointment_dentist REFERENCES dbo.app_user(user_id),
    scheduled_at DATETIME NOT NULL,
    reason VARCHAR(MAX) NOT NULL,
    status VARCHAR(30) NOT NULL CONSTRAINT df_appointment_status DEFAULT 'scheduled' CONSTRAINT ck_appointment_status CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    created_by UNIQUEIDENTIFIER NULL CONSTRAINT fk_appointment_created_by REFERENCES dbo.app_user(user_id),
    created_at DATETIME NOT NULL CONSTRAINT df_appointment_created_at DEFAULT GETDATE(),
    updated_at DATETIME NOT NULL CONSTRAINT df_appointment_updated_at DEFAULT GETDATE()
  );
END
GO

IF OBJECT_ID(N'dbo.audit_log', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.audit_log (
    audit_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_audit_log PRIMARY KEY,
    actor_id UNIQUEIDENTIFIER NULL,
    actor_role VARCHAR(30) NULL,
    action VARCHAR(20) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UNIQUEIDENTIFIER NULL,
    before_data VARCHAR(MAX) NULL,
    after_data VARCHAR(MAX) NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL CONSTRAINT df_audit_log_created_at DEFAULT GETDATE()
  );
END
GO

IF OBJECT_ID(N'dbo.security_event', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.security_event (
    event_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_security_event PRIMARY KEY,
    actor_id UNIQUEIDENTIFIER NULL,
    event_type VARCHAR(80) NOT NULL,
    detail VARCHAR(MAX) NOT NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL CONSTRAINT df_security_event_created_at DEFAULT GETDATE()
  );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_patient_email' AND object_id = OBJECT_ID(N'dbo.patient'))
  CREATE INDEX idx_patient_email ON dbo.patient(email);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_appointment_patient' AND object_id = OBJECT_ID(N'dbo.appointment'))
  CREATE INDEX idx_appointment_patient ON dbo.appointment(patient_id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_appointment_dentist_time' AND object_id = OBJECT_ID(N'dbo.appointment'))
  CREATE INDEX idx_appointment_dentist_time ON dbo.appointment(dentist_id, scheduled_at);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_audit_created_at' AND object_id = OBJECT_ID(N'dbo.audit_log'))
  CREATE INDEX idx_audit_created_at ON dbo.audit_log(created_at DESC);
GO
