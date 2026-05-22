-- Seed users, demo patient data, and a sample appointment for SecureDental.
USE SecureDental;
GO

MERGE dbo.app_user AS target
USING (VALUES
  ('System Administrator', 'admin@securedental.local', 'admin', 'scrypt$16384$557c3f159ca1e76899c8dc3dca485ad9$7e7ed38bb057607ea42c3ac80ebee1cbec830eb2ce9991a0fb89c3c6e5497509162b043761f3c42ac7a6af74245d16842dba76cf960af77aa4525dc823d77ff1'),
  ('Dr Aina Rahman', 'dentist@securedental.local', 'dentist', 'scrypt$16384$68b9b1f3678a00b1fbd628408f66c681$bc8ae3acaf1f65a4b8def01a8ca230bc3d9873fd24462056a75936b58c5bff36d38f4c6df939b21803703666ab5948cab6cc324fec8f2cc82eee48ed9983cb82'),
  ('Dr Farid Hassan', 'farid.hassan@securedental.local', 'dentist', 'scrypt$16384$68b9b1f3678a00b1fbd628408f66c681$bc8ae3acaf1f65a4b8def01a8ca230bc3d9873fd24462056a75936b58c5bff36d38f4c6df939b21803703666ab5948cab6cc324fec8f2cc82eee48ed9983cb82'),
  ('Dr Mei Ling Tan', 'mei.tan@securedental.local', 'dentist', 'scrypt$16384$68b9b1f3678a00b1fbd628408f66c681$bc8ae3acaf1f65a4b8def01a8ca230bc3d9873fd24462056a75936b58c5bff36d38f4c6df939b21803703666ab5948cab6cc324fec8f2cc82eee48ed9983cb82'),
  ('Dr Ravi Kumar', 'ravi.kumar@securedental.local', 'dentist', 'scrypt$16384$68b9b1f3678a00b1fbd628408f66c681$bc8ae3acaf1f65a4b8def01a8ca230bc3d9873fd24462056a75936b58c5bff36d38f4c6df939b21803703666ab5948cab6cc324fec8f2cc82eee48ed9983cb82'),
  ('Reception Counter', 'reception@securedental.local', 'receptionist', 'scrypt$16384$674ac13b3c60feeeeef4a5ebd0220868$9ea66ec98f626843e05c6ef1eeae7cb54ccdac93a6c0eb694a1124e3c9f5c2223a5697b3f9fa842497e5e5b06a3130e11a836f7ee2697ebb8a486ae24831e0c1'),
  ('Internal Auditor', 'auditor@securedental.local', 'auditor', 'scrypt$16384$b994c14eff5548a4469fb0addfec9bbd$5688155609c954f601b0431c877e64e7a50730cb5d2dff873f9c763382b16d7de9563c7486d20572f20e1b8f9c9761320518bc3b20965962c137b5f38f85c27e')
) AS source(full_name, email, role, password_hash)
ON target.email = source.email
WHEN NOT MATCHED THEN
  INSERT (full_name, email, role, password_hash)
  VALUES (source.full_name, source.email, source.role, source.password_hash);
GO

DECLARE @reception_id UNIQUEIDENTIFIER;
DECLARE @dentist_id UNIQUEIDENTIFIER;
DECLARE @patient_id UNIQUEIDENTIFIER;
DECLARE @scheduled_at DATETIME;
DECLARE @created_patient TABLE (patient_id UNIQUEIDENTIFIER);
DECLARE @app_encryption_key NVARCHAR(4000) = N'change-this-demo-key';

SELECT @reception_id = user_id FROM dbo.app_user WHERE email = 'reception@securedental.local';
SELECT @dentist_id = user_id FROM dbo.app_user WHERE email = 'dentist@securedental.local';

EXEC sys.sp_set_session_context @key = N'app.current_user_id', @value = @reception_id;
EXEC sys.sp_set_session_context @key = N'app.current_user_role', @value = N'receptionist';
EXEC sys.sp_set_session_context @key = N'app.encryption_key', @value = @app_encryption_key;
EXEC sys.sp_set_session_context @key = N'app.ip_address', @value = N'127.0.0.1';

IF NOT EXISTS (SELECT 1 FROM dbo.patient WHERE email = 'sample.patient@example.com')
BEGIN
  INSERT INTO @created_patient
  EXEC dbo.create_patient
    'Sample Patient',
    'sample.patient@example.com',
    '990101-10-1234',
    '+60123456789',
    'Cyberjaya, Selangor',
    'Dental check-up and scaling consultation';

  SELECT @patient_id = patient_id FROM @created_patient;
  SET @scheduled_at = DATEADD(DAY, 2, GETDATE());

  EXEC dbo.create_appointment
    @patient_id,
    @dentist_id,
    @scheduled_at,
    'Scaling and oral hygiene check-up';
END
GO
