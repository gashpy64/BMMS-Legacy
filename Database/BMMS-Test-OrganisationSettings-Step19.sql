/* ============================================================================
   BMMS - Tests for BMMS-Fix-OrganisationSettings-Step19.sql (step 19)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-OrganisationSettings-Step19.sql, on the TEST COPY. It
   stops if step 19 is not installed.

   Creates its own users (an Admin, an inactive Admin, a Controller) and
   checks, through the real procedures, with made-up sample values only:
     * the markers, the 12 rows, the fixed order, '' for a missing row
     * an Admin saves all 12 (trimmed), one audit row per changed value, no
       audit row when nothing changed, clearing and NULL store ''
     * a missing row comes back on save; the system account may save
     * refusals change nothing: Controller (Reason 4), inactive Admin and
       unknown user (Reason 8), and Reason 3 naming the first bad setting
       for: too long, letters-only term, PIN, phone, e-mail, line break,
       tab, characters outside Windows-1252
     * Windows-1252 characters such as "&" and accented letters are kept
     * the logo audit procedure: upload and removal rows, Controller,
       inactive Admin and an unknown action refused
     * step 16 is unchanged: spr_SetAppSetting still refuses the new codes,
       the AgendaControllerBypass row is untouched
     * Reset Database does not touch App_Setting (procedure text only; it is
       not run here)

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') NOT LIKE '%OrganisationSettings-Step19%')
BEGIN
    RAISERROR('The organisation settings (step 19) are not installed in "%s". Run BMMS-Fix-OrganisationSettings-Step19.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @G TABLE (Seq INT, SettingCode VARCHAR(50), SettingValue VARCHAR(250), LastChangedOn DATETIME, LastChangedBy VARCHAR(100));
DECLARE @Codes TABLE (Seq INT, SettingCode VARCHAR(50));
INSERT INTO @Codes VALUES
(1, 'OrganisationName'), (2, 'OrganisationShortName'), (3, 'OrganisationTerm'), (4, 'CertificateSignOff'),
(5, 'RegisteredOfficeLabel'), (6, 'RegisteredOfficeLine1'), (7, 'RegisteredOfficeLine2'), (8, 'RegisteredOfficeCity'),
(9, 'RegisteredOfficePinCode'), (10, 'OrganisationPhone'), (11, 'OrganisationFax'), (12, 'OrganisationEmail');

DECLARE @Now DATETIME = GETDATE();
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @AdminRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin');
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @DepartmentId INT = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

DECLARE @Adm INT, @AdmOff INT, @Ctl INT;
DECLARE @AuditBefore INT, @Snap VARCHAR(MAX), @Snap2 VARCHAR(MAX), @Expected VARCHAR(MAX);
DECLARE @Bypass VARCHAR(250);
DECLARE @Long151 NVARCHAR(400) = REPLICATE(N'x', 151);
DECLARE @Long150 NVARCHAR(400) = REPLICATE(N'y', 150);
DECLARE @Accented NVARCHAR(400) = N'Example & Soci' + NCHAR(233) + N't' + NCHAR(233);

IF (@Sys IS NULL OR @AdminRoleId IS NULL OR @CtrlRoleId IS NULL OR @DepartmentId IS NULL OR @DesignationId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, the Admin or Controller role, a department or a designation is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures
    ---------------------------------------------------------------------------
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ19 admin', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz19adm@example.invalid', 'zz19adm', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ19 admin off', @DepartmentId, @DesignationId, NULL, @AdminRoleId, 'zz19off@example.invalid', 'zz19off', 'not-a-login', 0, @Now, @Sys, @Now, @Sys);
    SET @AdmOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ19 controller', @DepartmentId, @DesignationId, NULL, @CtrlRoleId, 'zz19ctl@example.invalid', 'zz19ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();

    SET @Bypass = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass');

    ---------------------------------------------------------------------------
    -- Installation
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Markers: 3 procedures carry OrganisationSettings-Step19', '3',
           CAST(COUNT(*) AS VARCHAR(4)) FROM sys.sql_modules WHERE definition LIKE '%OrganisationSettings-Step19%'
           AND object_id IN (OBJECT_ID('dbo.spr_GetOrganisationSettings'), OBJECT_ID('dbo.spr_SetOrganisationSettings'), OBJECT_ID('dbo.spr_RecordOrganisationLogo'));
    INSERT INTO @T SELECT 'The 12 setting rows exist', '12',
           CAST(COUNT(*) AS VARCHAR(4)) FROM App_Setting WHERE SettingCode IN (SELECT SettingCode FROM @Codes);

    -- A known starting point: every value empty (rolled back)
    UPDATE App_Setting SET SettingValue = '' WHERE SettingCode IN (SELECT SettingCode FROM @Codes);

    DELETE FROM @G; INSERT INTO @G EXEC spr_GetOrganisationSettings;
    INSERT INTO @T SELECT 'Get: 12 rows in the fixed order', 'OrganisationName,OrganisationShortName,OrganisationTerm,CertificateSignOff,RegisteredOfficeLabel,RegisteredOfficeLine1,RegisteredOfficeLine2,RegisteredOfficeCity,RegisteredOfficePinCode,OrganisationPhone,OrganisationFax,OrganisationEmail',
           STUFF((SELECT ',' + SettingCode FROM @G ORDER BY Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'Get: every value empty by default', '12', CAST(SUM(CASE WHEN SettingValue = '' THEN 1 ELSE 0 END) AS VARCHAR(4)) FROM @G;

    DELETE FROM App_Setting WHERE SettingCode = 'OrganisationFax';
    DELETE FROM @G; INSERT INTO @G EXEC spr_GetOrganisationSettings;
    INSERT INTO @T SELECT 'Get: a missing row still listed, as empty', '12 1',
           CAST(COUNT(*) AS VARCHAR(4)) + ' ' + CAST(SUM(CASE WHEN SettingCode = 'OrganisationFax' AND SettingValue = '' THEN 1 ELSE 0 END) AS VARCHAR(4)) FROM @G;

    ---------------------------------------------------------------------------
    -- Save by an Admin (sample values only)
    ---------------------------------------------------------------------------
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = N'  Example Company Limited  ', @OrganisationShortName = N'Example Company', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Example Company Ltd.,', @RegisteredOfficeLabel = N'Regd. & Admin. Office',
        @RegisteredOfficeLine1 = N'12 Sample Road', @RegisteredOfficeLine2 = N'Sample Nagar', @RegisteredOfficeCity = N'Sampletown',
        @RegisteredOfficePinCode = N'600001', @OrganisationPhone = N'+91 44 1234 5678', @OrganisationFax = N'044-1234 5679',
        @OrganisationEmail = N'office@example.com';
    INSERT INTO @T SELECT 'Admin saves all 12', 'Result 1, Reason 0', Txt FROM @R;

    SET @Expected = 'Example Company Limited|Example Company|Company|Example Company Ltd.,|Regd. & Admin. Office|12 Sample Road|Sample Nagar|Sampletown|600001|+91 44 1234 5678|044-1234 5679|office@example.com';
    SET @Snap = STUFF((SELECT '|' + ISNULL(s.SettingValue, '<missing>') FROM @Codes c LEFT JOIN App_Setting s ON s.SettingCode = c.SettingCode
                       ORDER BY c.Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'Stored values, trimmed; the missing row is back', @Expected, @Snap;
    INSERT INTO @T SELECT 'One audit row per changed value', '12',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore AND Audit_Table = 'App_Setting';
    INSERT INTO @T SELECT 'Audit row: old and new value, by whom', '|Example Company Limited|1',
           ISNULL(MAX(Old_Value + '|' + New_Value + '|' + CASE WHEN Update_By = @Adm THEN '1' ELSE '0' END), 'none')
           FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore AND Key_Value = 'OrganisationName';
    DELETE FROM @G; INSERT INTO @G EXEC spr_GetOrganisationSettings;
    INSERT INTO @T SELECT 'Get: last changed by the Admin', 'ZZ19 admin', ISNULL(MAX(LastChangedBy), '') FROM @G WHERE SettingCode = 'OrganisationEmail';

    -- The same values again: nothing changes, no audit row
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = N'Example Company Limited', @OrganisationShortName = N'Example Company', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Example Company Ltd.,', @RegisteredOfficeLabel = N'Regd. & Admin. Office',
        @RegisteredOfficeLine1 = N'12 Sample Road', @RegisteredOfficeLine2 = N'Sample Nagar', @RegisteredOfficeCity = N'Sampletown',
        @RegisteredOfficePinCode = N'600001', @OrganisationPhone = N'+91 44 1234 5678', @OrganisationFax = N'044-1234 5679',
        @OrganisationEmail = N'office@example.com';
    INSERT INTO @T SELECT 'Save unchanged values: done, no audit row', 'Result 1, Reason 0 / 0',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    -- One value changed, one cleared, one NULL: three audit rows; case change counts
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = N'Example Company Limited', @OrganisationShortName = N'EXAMPLE COMPANY', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Example Company Ltd.,', @RegisteredOfficeLabel = N'Regd. & Admin. Office',
        @RegisteredOfficeLine1 = N'12 Sample Road', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'Sampletown',
        @RegisteredOfficePinCode = N'600001', @OrganisationPhone = N'+91 44 1234 5678', @OrganisationFax = NULL,
        @OrganisationEmail = N'office@example.com';
    INSERT INTO @T SELECT 'Change one (case only), clear one, NULL one: 3 audit rows', 'Result 1, Reason 0 / 3',
           (SELECT Txt FROM @R) + ' / ' + CAST(COUNT(*) AS VARCHAR(4)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;
    INSERT INTO @T SELECT 'Cleared and NULL values stored as empty', 'EXAMPLE COMPANY||',
           (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'OrganisationShortName') + '|'
         + (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'RegisteredOfficeLine2') + '|'
         + (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'OrganisationFax');

    -- Windows-1252 punctuation and accented letters are kept; exactly 150 characters is allowed
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = @Long150, @OrganisationShortName = @Accented, @OrganisationTerm = N'Sample Company',
        @CertificateSignOff = N'Example Company Ltd.,', @RegisteredOfficeLabel = N'Regd. & Admin. Office',
        @RegisteredOfficeLine1 = N'12 Sample Road', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'Sampletown',
        @RegisteredOfficePinCode = N'600 001', @OrganisationPhone = N'(044) 1234-5678 / 79', @OrganisationFax = N'',
        @OrganisationEmail = N'first.last@mail.example.com';
    INSERT INTO @T SELECT '150 characters, "&", accented letters, spaced PIN, phone signs', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Accented letters stored unchanged', '1',
           CASE WHEN (SELECT CAST(SettingValue AS NVARCHAR(250)) FROM App_Setting WHERE SettingCode = 'OrganisationShortName') COLLATE Latin1_General_BIN
                     = @Accented COLLATE Latin1_General_BIN THEN '1' ELSE '0' END;

    -- The system account is an active Admin: it may save
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Sys,
        @OrganisationName = N'Example Company Limited', @OrganisationShortName = N'Example Company', @OrganisationTerm = N'Company',
        @CertificateSignOff = N'Example Company Ltd.,', @RegisteredOfficeLabel = N'Regd. & Admin. Office',
        @RegisteredOfficeLine1 = N'12 Sample Road', @RegisteredOfficeLine2 = N'Sample Nagar', @RegisteredOfficeCity = N'Sampletown',
        @RegisteredOfficePinCode = N'600001', @OrganisationPhone = N'+91 44 1234 5678', @OrganisationFax = N'044-1234 5679',
        @OrganisationEmail = N'office@example.com';
    INSERT INTO @T SELECT 'The system account (an active Admin) may save', 'Result 1, Reason 0', Txt FROM @R;

    ---------------------------------------------------------------------------
    -- Refusals: nothing changes, no audit row
    ---------------------------------------------------------------------------
    SET @Snap = STUFF((SELECT '|' + s.SettingValue FROM @Codes c JOIN App_Setting s ON s.SettingCode = c.SettingCode
                       ORDER BY c.Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Ctl,
        @OrganisationName = N'Changed', @OrganisationShortName = N'', @OrganisationTerm = N'', @CertificateSignOff = N'',
        @RegisteredOfficeLabel = N'', @RegisteredOfficeLine1 = N'', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'',
        @RegisteredOfficePinCode = N'', @OrganisationPhone = N'', @OrganisationFax = N'', @OrganisationEmail = N'';
    INSERT INTO @T SELECT 'Controller refused', 'Result 0, Reason 4', Txt FROM @R;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @AdmOff,
        @OrganisationName = N'Changed', @OrganisationShortName = N'', @OrganisationTerm = N'', @CertificateSignOff = N'',
        @RegisteredOfficeLabel = N'', @RegisteredOfficeLine1 = N'', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'',
        @RegisteredOfficePinCode = N'', @OrganisationPhone = N'', @OrganisationFax = N'', @OrganisationEmail = N'';
    INSERT INTO @T SELECT 'Inactive Admin refused', 'Result 0, Reason 8', Txt FROM @R;

    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = 0,
        @OrganisationName = N'Changed', @OrganisationShortName = N'', @OrganisationTerm = N'', @CertificateSignOff = N'',
        @RegisteredOfficeLabel = N'', @RegisteredOfficeLine1 = N'', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'',
        @RegisteredOfficePinCode = N'', @OrganisationPhone = N'', @OrganisationFax = N'', @OrganisationEmail = N'';
    INSERT INTO @T SELECT 'Unknown acting user refused', 'Result 0, Reason 8', Txt FROM @R;

    -- Reason 3: each bad value, with every other value valid
    DECLARE @Bad TABLE (No INT IDENTITY(1,1), Label VARCHAR(100), Field VARCHAR(50), Value NVARCHAR(400));
    INSERT INTO @Bad (Label, Field, Value) VALUES
    ('Name of 151 characters', 'OrganisationName', @Long151),
    ('Term with a digit', 'OrganisationTerm', N'Bank1'),
    ('Term with a full stop', 'OrganisationTerm', N'Co.'),
    ('PIN with letters', 'RegisteredOfficePinCode', N'AB12'),
    ('PIN without a digit', 'RegisteredOfficePinCode', N'---'),
    ('PIN of 13 characters', 'RegisteredOfficePinCode', N'6000016000016'),
    ('Phone with letters', 'OrganisationPhone', N'call 1234'),
    ('Phone with capital letters', 'OrganisationPhone', N'CALL 1234'),
    ('Fax without a digit', 'OrganisationFax', N'+ -'),
    ('E-mail without @', 'OrganisationEmail', N'office.example.com'),
    ('E-mail with two @', 'OrganisationEmail', N'a@b@example.com'),
    ('E-mail with a space', 'OrganisationEmail', N'office @example.com'),
    ('E-mail without a domain dot', 'OrganisationEmail', N'office@example'),
    ('E-mail with two addresses', 'OrganisationEmail', N'a@example.com,b@example.com'),
    ('E-mail with markup', 'OrganisationEmail', N'<a@example.com>'),
    ('Line break in office line 1', 'RegisteredOfficeLine1', N'12 Sample Road' + NCHAR(13) + NCHAR(10) + N'Sampletown'),
    ('Tab in the city', 'RegisteredOfficeCity', N'Sample' + NCHAR(9) + N'town'),
    ('Letter outside Windows-1252 (a with macron)', 'OrganisationName', N'Ex' + NCHAR(257) + N'mple Company Limited'),
    ('Tamil letter', 'RegisteredOfficeLine2', N'Sample ' + NCHAR(2949)),
    ('Sign-off of 151 characters', 'CertificateSignOff', @Long151),
    ('Label of 61 characters', 'RegisteredOfficeLabel', REPLICATE(N'z', 61));

    DECLARE @No INT = 1, @Max INT = (SELECT MAX(No) FROM @Bad), @Field VARCHAR(50), @Value NVARCHAR(400), @Label VARCHAR(100);
    DECLARE @p1 NVARCHAR(400), @p2 NVARCHAR(400), @p3 NVARCHAR(400), @p4 NVARCHAR(400), @p5 NVARCHAR(400), @p6 NVARCHAR(400),
            @p7 NVARCHAR(400), @p8 NVARCHAR(400), @p9 NVARCHAR(400), @p10 NVARCHAR(400), @p11 NVARCHAR(400), @p12 NVARCHAR(400);
    WHILE (@No <= @Max)
    BEGIN
        SELECT @Field = Field, @Value = Value, @Label = Label FROM @Bad WHERE No = @No;
        SELECT @p1 = N'Changed Company Limited', @p2 = N'Changed', @p3 = N'Company', @p4 = N'Changed Ltd.,', @p5 = N'Office',
               @p6 = N'1 Other Road', @p7 = N'Other Nagar', @p8 = N'Othertown', @p9 = N'600002', @p10 = N'1234', @p11 = N'5678',
               @p12 = N'other@example.com';
        IF (@Field = 'OrganisationName') SET @p1 = @Value;
        IF (@Field = 'OrganisationTerm') SET @p3 = @Value;
        IF (@Field = 'CertificateSignOff') SET @p4 = @Value;
        IF (@Field = 'RegisteredOfficeLabel') SET @p5 = @Value;
        IF (@Field = 'RegisteredOfficeLine1') SET @p6 = @Value;
        IF (@Field = 'RegisteredOfficeLine2') SET @p7 = @Value;
        IF (@Field = 'RegisteredOfficeCity') SET @p8 = @Value;
        IF (@Field = 'RegisteredOfficePinCode') SET @p9 = @Value;
        IF (@Field = 'OrganisationPhone') SET @p10 = @Value;
        IF (@Field = 'OrganisationFax') SET @p11 = @Value;
        IF (@Field = 'OrganisationEmail') SET @p12 = @Value;

        DELETE FROM @R;
        INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
            @OrganisationName = @p1, @OrganisationShortName = @p2, @OrganisationTerm = @p3, @CertificateSignOff = @p4,
            @RegisteredOfficeLabel = @p5, @RegisteredOfficeLine1 = @p6, @RegisteredOfficeLine2 = @p7, @RegisteredOfficeCity = @p8,
            @RegisteredOfficePinCode = @p9, @OrganisationPhone = @p10, @OrganisationFax = @p11, @OrganisationEmail = @p12;
        INSERT INTO @T SELECT 'Refused: ' + @Label, 'Result 0, Reason 3, ' + @Field, Txt FROM @R;

        SET @No = @No + 1;
    END

    -- Two bad values: the first in the fixed order is named
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetOrganisationSettings @ActingUserId = @Adm,
        @OrganisationName = N'Changed', @OrganisationShortName = N'', @OrganisationTerm = N'Bank1', @CertificateSignOff = N'',
        @RegisteredOfficeLabel = N'', @RegisteredOfficeLine1 = N'', @RegisteredOfficeLine2 = N'', @RegisteredOfficeCity = N'',
        @RegisteredOfficePinCode = N'', @OrganisationPhone = N'', @OrganisationFax = N'', @OrganisationEmail = N'bad';
    INSERT INTO @T SELECT 'Two bad values: the first is named', 'Result 0, Reason 3, OrganisationTerm', Txt FROM @R;

    SET @Snap2 = STUFF((SELECT '|' + s.SettingValue FROM @Codes c JOIN App_Setting s ON s.SettingCode = c.SettingCode
                        ORDER BY c.Seq FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 1, '');
    INSERT INTO @T SELECT 'After every refusal: values unchanged, no audit row', '1 0',
           CASE WHEN @Snap2 = @Snap THEN '1' ELSE '0' END + ' '
         + CAST((SELECT COUNT(*) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore) AS VARCHAR(4));

    ---------------------------------------------------------------------------
    -- Logo audit
    ---------------------------------------------------------------------------
    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_RecordOrganisationLogo @ActingUserId = @Adm, @Action = 'Upload', @FileDetail = N'PNG 600 x 120, 18 KB';
    INSERT INTO @T SELECT 'Logo upload recorded', 'Result 1, Reason 0', Txt FROM @R;
    INSERT INTO @T SELECT 'Logo upload audit row', 'OrganisationLogo|LogoFile|Uploaded: PNG 600 x 120, 18 KB|1',
           ISNULL(MAX(Key_Value + '|' + Field_Name + '|' + New_Value + '|' + CASE WHEN Update_By = @Adm THEN '1' ELSE '0' END), 'none')
           FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_RecordOrganisationLogo @ActingUserId = @Adm, @Action = 'Remove', @FileDetail = N'';
    INSERT INTO @T SELECT 'Logo removal recorded', 'Result 1, Reason 0 / Removed',
           (SELECT Txt FROM @R) + ' / ' + ISNULL(MAX(New_Value), 'none') FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    SET @AuditBefore = ISNULL((SELECT MAX(Audit_Trail_Maser_Id) FROM Audit_Trail_Master), 0);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_RecordOrganisationLogo @ActingUserId = @Ctl, @Action = 'Upload', @FileDetail = N'PNG';
    INSERT INTO @T SELECT 'Logo: Controller refused', 'Result 0, Reason 4', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_RecordOrganisationLogo @ActingUserId = @AdmOff, @Action = 'Remove', @FileDetail = N'';
    INSERT INTO @T SELECT 'Logo: inactive Admin refused', 'Result 0, Reason 8', Txt FROM @R;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_RecordOrganisationLogo @ActingUserId = @Adm, @Action = 'Delete', @FileDetail = N'';
    INSERT INTO @T SELECT 'Logo: unknown action refused', 'Result 0, Reason 3, Delete', Txt FROM @R;
    INSERT INTO @T SELECT 'Logo refusals: no audit row', '0',
           CAST(COUNT(*) AS VARCHAR(4)) FROM Audit_Trail_Master WHERE Audit_Trail_Maser_Id > @AuditBefore;

    ---------------------------------------------------------------------------
    -- Step 16 and Reset Database unchanged
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetAppSetting @SettingCode = 'OrganisationName', @SettingValue = '1', @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'spr_SetAppSetting still refuses the organisation codes', 'Result 0, Reason 3, 1', Txt FROM @R;
    INSERT INTO @T SELECT 'AgendaControllerBypass row untouched', ISNULL(@Bypass, '<missing>'),
           ISNULL((SELECT SettingValue FROM App_Setting WHERE SettingCode = 'AgendaControllerBypass'), '<missing>');
    INSERT INTO @T SELECT 'Reset Database does not touch App_Setting (procedure text)', '0',
           CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') LIKE '%App_Setting%' THEN '1' ELSE '0' END;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual <> Expected THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0 and 12
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz19%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM App_Setting WHERE SettingCode IN ('OrganisationName', 'OrganisationShortName', 'OrganisationTerm',
            'CertificateSignOff', 'RegisteredOfficeLabel', 'RegisteredOfficeLine1', 'RegisteredOfficeLine2', 'RegisteredOfficeCity',
            'RegisteredOfficePinCode', 'OrganisationPhone', 'OrganisationFax', 'OrganisationEmail')) AS OrganisationSettingRows;
GO

SET NOEXEC OFF;
GO
