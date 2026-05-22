-- SQL Server security smoke tests for SSMS/sqlcmd.
USE SecureDental;
GO

BEGIN TRY
  EXECUTE AS USER = 'dental_app';
  SELECT 'Direct base table access should fail below' AS test_case;
  SELECT TOP 1 patient_id, full_name, nric_cipher FROM dbo.patient;
  REVERT;
  SELECT 'Unexpected: dental_app could read dbo.patient directly.' AS test_result;
END TRY
BEGIN CATCH
  REVERT;
  SELECT 'Expected: dental_app cannot read dbo.patient directly.' AS test_result, ERROR_MESSAGE() AS error_message;
END CATCH;
GO

DECLARE @reception_id UNIQUEIDENTIFIER;
DECLARE @app_encryption_key NVARCHAR(4000) = N'change-this-demo-key';

SELECT @reception_id = user_id FROM dbo.app_user WHERE email = 'reception@securedental.local';

EXECUTE AS USER = 'dental_app';
EXEC sys.sp_set_session_context @key = N'app.current_user_id', @value = @reception_id;
EXEC sys.sp_set_session_context @key = N'app.current_user_role', @value = N'receptionist';
EXEC sys.sp_set_session_context @key = N'app.encryption_key', @value = @app_encryption_key;
EXEC sys.sp_set_session_context @key = N'app.ip_address', @value = N'127.0.0.1';

EXEC dbo.create_patient
  'SQL Injection Test',
  'safe.injection@example.com',
  '010101-10-9999',
  '+60111111111',
  'Test address',
  'Attempted dental note input: Robert''); DROP TABLE patient; --';

SELECT OBJECT_ID(N'dbo.patient', N'U') AS patient_table_object_id_still_exists;
SELECT TOP 5 action, entity_type, created_at FROM dbo.audit_log ORDER BY created_at DESC;
REVERT;
GO
