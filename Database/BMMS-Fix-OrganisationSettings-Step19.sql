/* ============================================================================
   BMMS - Organisation details as settings (step 19)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   BMMS ships neutral. Each company that uses it sets its own name, office
   address and contact details on System Settings (Admin only); the printed
   and mailed output (notices, minutes, reports, sitting-fee certificates)
   reads them from here instead of fixed text in the code.

   Settings (table App_Setting of step 16, one row each, default '' = not set):
     OrganisationName          legal name                       150
     OrganisationShortName     short name for mail headers      100
     OrganisationTerm          "Bank", "Company", ...           30, letters and spaces
     CertificateSignOff        text after "For"                 150
     RegisteredOfficeLabel     e.g. "Regd. & Admin. Office"     60
     RegisteredOfficeLine1     street                           100
     RegisteredOfficeLine2     locality                         100
     RegisteredOfficeCity      city                             60
     RegisteredOfficePinCode   PIN / postcode                   12, digits, space, hyphen
     OrganisationPhone         phone                            60, digits, space, + - ( ) / ,
     OrganisationFax           fax                              60, as phone
     OrganisationEmail         e-mail                           100, one address
   Every value is trimmed; control characters (line breaks included) and
   characters outside the database code page (Windows-1252) are refused. An
   empty value is allowed: the printed output leaves that line out.

   Objects (each carries the text OrganisationSettings-Step19)
     spr_GetOrganisationSettings   NEW, the 12 settings in a fixed order, ''
                                   for a missing row, with the last change
     spr_SetOrganisationSettings   NEW, saves all 12 in one transaction or
                                   none; only an active Admin; one
                                   Audit_Trail_Master row per changed value
     spr_RecordOrganisationLogo    NEW, only an active Admin; writes the
                                   audit row for a logo upload or removal
                                   (the file itself is kept by the
                                   application in ~/Files/Branding)

   They return ONE row: Result (1 done, 0 refused), Reason, ReasonDetail
     Reason 0 done
            3 value not valid; ReasonDetail = the setting code (or the action)
            4 not allowed for your role (only an Admin)
            8 acting user missing or inactive
   (the same codes as spr_SetAppSetting of step 16).

   Replaces nothing: step 16 and its spr_GetAppSetting / spr_SetAppSetting
   are unchanged (spr_SetAppSetting still accepts AgendaControllerBypass
   only). Reset Database (step 18) does not touch App_Setting, so the
   organisation details survive a reset.

   Changes no existing data. Adds the 12 rows only if they are missing, so a
   re-run keeps the Admin's values. Safe to re-run. Needs steps 16 and 18 and
   stops otherwise. Run it BEFORE deploying the build that prints from these
   settings; the older build never calls the new procedures.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.App_Setting', 'U') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetAppSetting')), '') NOT LIKE '%MeetingLocks-Step16%')
BEGIN
    RAISERROR('Step 16 (BMMS-Fix-MeetingLocks-Step16.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- The 12 rows (OrganisationSettings-Step19). Missing rows only: a re-run keeps
-- the values the Admin has set.
-------------------------------------------------------------------------------
INSERT INTO App_Setting (SettingCode, SettingValue, Description)
SELECT d.SettingCode, '', d.Description
FROM (VALUES
    ('OrganisationName',        'Organisation legal name (printed on notices, minutes, reports and certificates)'),
    ('OrganisationShortName',   'Short name for mail headers (empty: the legal name)'),
    ('OrganisationTerm',        'Word for the organisation in certificates, e.g. Bank or Company (empty: Company)'),
    ('CertificateSignOff',      'Text after "For" in letters and certificates (empty: the legal name)'),
    ('RegisteredOfficeLabel',   'Office label, e.g. Regd. & Admin. Office'),
    ('RegisteredOfficeLine1',   'Registered office: street'),
    ('RegisteredOfficeLine2',   'Registered office: locality'),
    ('RegisteredOfficeCity',    'Registered office: city'),
    ('RegisteredOfficePinCode', 'Registered office: PIN / postcode'),
    ('OrganisationPhone',       'Phone (certificate footer)'),
    ('OrganisationFax',         'Fax (certificate footer)'),
    ('OrganisationEmail',       'E-mail (certificate footer)')
) d (SettingCode, Description)
WHERE NOT EXISTS (SELECT 1 FROM App_Setting s WHERE s.SettingCode = d.SettingCode);

PRINT CAST(@@ROWCOUNT AS VARCHAR(4)) + ' organisation setting row(s) added.';
GO

-- Organisation settings - all 12 in a fixed order, with the last change (OrganisationSettings-Step19)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetOrganisationSettings]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	d.Seq,
	d.SettingCode,
	ISNULL(s.SettingValue, '') AS SettingValue,
	l.Update_On AS LastChangedOn,
	ISNULL(u.UserName, '') AS LastChangedBy
	FROM (VALUES
		(1, 'OrganisationName'), (2, 'OrganisationShortName'), (3, 'OrganisationTerm'), (4, 'CertificateSignOff'),
		(5, 'RegisteredOfficeLabel'), (6, 'RegisteredOfficeLine1'), (7, 'RegisteredOfficeLine2'), (8, 'RegisteredOfficeCity'),
		(9, 'RegisteredOfficePinCode'), (10, 'OrganisationPhone'), (11, 'OrganisationFax'), (12, 'OrganisationEmail')
	) d (Seq, SettingCode)
	LEFT JOIN App_Setting s ON s.SettingCode = d.SettingCode
	OUTER APPLY (SELECT TOP 1 t.Update_On, t.Update_By FROM Audit_Trail_Master t
	             WHERE t.Audit_Table = 'App_Setting' AND t.Key_Value = d.SettingCode
	             ORDER BY t.Update_On DESC, t.Audit_Trail_Maser_Id DESC) l
	LEFT JOIN Users u ON u.UserId = l.Update_By
	ORDER BY d.Seq;
END
GO

-- Organisation settings - save all 12, or none; only an active Admin (OrganisationSettings-Step19)
-- NULL counts as '' (not set). Values are trimmed before they are checked.
CREATE OR ALTER PROCEDURE [dbo].[spr_SetOrganisationSettings]
@ActingUserId INT,
@OrganisationName NVARCHAR(400),
@OrganisationShortName NVARCHAR(400),
@OrganisationTerm NVARCHAR(400),
@CertificateSignOff NVARCHAR(400),
@RegisteredOfficeLabel NVARCHAR(400),
@RegisteredOfficeLine1 NVARCHAR(400),
@RegisteredOfficeLine2 NVARCHAR(400),
@RegisteredOfficeCity NVARCHAR(400),
@RegisteredOfficePinCode NVARCHAR(400),
@OrganisationPhone NVARCHAR(400),
@OrganisationFax NVARCHAR(400),
@OrganisationEmail NVARCHAR(400)
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @V TABLE (Seq INT, SettingCode VARCHAR(50), NewValue NVARCHAR(400), MaxLen INT, Kind CHAR(1));
DECLARE @Ctrl TABLE (Ch NCHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	-- Kind: T text, W letters and spaces, N PIN, P phone / fax, E e-mail
	INSERT INTO @V VALUES
	(1,  'OrganisationName',        LTRIM(RTRIM(ISNULL(@OrganisationName, ''))),        150, 'T'),
	(2,  'OrganisationShortName',   LTRIM(RTRIM(ISNULL(@OrganisationShortName, ''))),   100, 'T'),
	(3,  'OrganisationTerm',        LTRIM(RTRIM(ISNULL(@OrganisationTerm, ''))),        30,  'W'),
	(4,  'CertificateSignOff',      LTRIM(RTRIM(ISNULL(@CertificateSignOff, ''))),      150, 'T'),
	(5,  'RegisteredOfficeLabel',   LTRIM(RTRIM(ISNULL(@RegisteredOfficeLabel, ''))),   60,  'T'),
	(6,  'RegisteredOfficeLine1',   LTRIM(RTRIM(ISNULL(@RegisteredOfficeLine1, ''))),   100, 'T'),
	(7,  'RegisteredOfficeLine2',   LTRIM(RTRIM(ISNULL(@RegisteredOfficeLine2, ''))),   100, 'T'),
	(8,  'RegisteredOfficeCity',    LTRIM(RTRIM(ISNULL(@RegisteredOfficeCity, ''))),    60,  'T'),
	(9,  'RegisteredOfficePinCode', LTRIM(RTRIM(ISNULL(@RegisteredOfficePinCode, ''))), 12,  'N'),
	(10, 'OrganisationPhone',       LTRIM(RTRIM(ISNULL(@OrganisationPhone, ''))),       60,  'P'),
	(11, 'OrganisationFax',         LTRIM(RTRIM(ISNULL(@OrganisationFax, ''))),         60,  'P'),
	(12, 'OrganisationEmail',       LTRIM(RTRIM(ISNULL(@OrganisationEmail, ''))),       100, 'E');

	-- Control characters 0 to 31 and 127
	INSERT INTO @Ctrl (Ch)
	SELECT NCHAR(number) FROM master.dbo.spt_values WHERE type = 'P' AND (number BETWEEN 0 AND 31 OR number = 127);

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION OrganisationSettingsSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE
		BEGIN
			SET @Detail = ISNULL((SELECT TOP 1 v.SettingCode FROM @V v
				WHERE LEN(v.NewValue) > v.MaxLen
				   OR EXISTS (SELECT 1 FROM @Ctrl c WHERE CHARINDEX(c.Ch, v.NewValue COLLATE Latin1_General_BIN) > 0)
				   -- characters the database code page cannot hold come back changed
				   OR CAST(CAST(v.NewValue AS VARCHAR(400)) AS NVARCHAR(400)) COLLATE Latin1_General_BIN <> v.NewValue COLLATE Latin1_General_BIN
				   OR (v.Kind = 'W' AND v.NewValue COLLATE Latin1_General_BIN LIKE '%[^A-Za-z ]%')
				   OR (v.Kind = 'N' AND (v.NewValue COLLATE Latin1_General_BIN LIKE '%[^-0-9 ]%'
				                         OR (v.NewValue <> '' AND v.NewValue NOT LIKE '%[0-9]%')))
				   OR (v.Kind = 'P' AND (v.NewValue COLLATE Latin1_General_BIN LIKE '%[^-0-9 +()/,]%'
				                         OR (v.NewValue <> '' AND v.NewValue NOT LIKE '%[0-9]%')))
				   OR (v.Kind = 'E' AND v.NewValue <> ''
				       AND (v.NewValue NOT LIKE '%_@_%._%' OR v.NewValue LIKE '%@%@%'
				            OR v.NewValue LIKE '%[ ,;:<>()"''\]%' OR v.NewValue LIKE '%[[]%'
				            OR v.NewValue LIKE '%..%' OR v.NewValue LIKE '%.' OR v.NewValue LIKE '.%'))
				ORDER BY v.Seq), '');

			IF (@Detail <> '')
				SET @Reason = 3;
			ELSE
			BEGIN
				-- Lock the existing rows first, so two saves run one after the other
				DECLARE @Locked INT = (SELECT COUNT(*) FROM App_Setting WITH (UPDLOCK, HOLDLOCK)
				                       WHERE SettingCode IN (SELECT SettingCode FROM @V));

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT 'UP', 'App_Setting', 'SettingCode', v.SettingCode, 'SettingValue', ISNULL(s.SettingValue, ''), CAST(v.NewValue AS VARCHAR(400)), @ActingUserId, GETDATE()
				FROM @V v
				LEFT JOIN App_Setting s ON s.SettingCode = v.SettingCode
				WHERE CAST(ISNULL(s.SettingValue, '') AS NVARCHAR(400)) COLLATE Latin1_General_BIN <> v.NewValue COLLATE Latin1_General_BIN
				ORDER BY v.Seq;

				UPDATE s SET SettingValue = CAST(v.NewValue AS VARCHAR(250))
				FROM App_Setting s
				JOIN @V v ON v.SettingCode = s.SettingCode
				WHERE CAST(s.SettingValue AS NVARCHAR(400)) COLLATE Latin1_General_BIN <> v.NewValue COLLATE Latin1_General_BIN;

				-- A row removed by hand comes back
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				SELECT v.SettingCode, CAST(v.NewValue AS VARCHAR(250)), 'Organisation setting'
				FROM @V v
				WHERE NOT EXISTS (SELECT 1 FROM App_Setting s WHERE s.SettingCode = v.SettingCode);

				SET @Result = 1;
			END
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION OrganisationSettingsSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Organisation logo - audit row for an upload or removal; only an active Admin (OrganisationSettings-Step19)
-- @Action 'Upload' or 'Remove'. @FileDetail is what was stored (for example "PNG 600 x 120, 18 KB").
-- The application keeps the file; it writes or deletes it only after Result = 1.
CREATE OR ALTER PROCEDURE [dbo].[spr_RecordOrganisationLogo]
@ActingUserId INT,
@Action VARCHAR(10),
@FileDetail NVARCHAR(200)
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @ActingRole VARCHAR(50);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole <> 'admin')
		SET @Reason = 4;
	ELSE IF (ISNULL(@Action, '') NOT IN ('Upload', 'Remove'))
	BEGIN
		SET @Reason = 3;
		SET @Detail = ISNULL(@Action, 'NULL');
	END
	ELSE
	BEGIN
		INSERT INTO [Audit_Trail_Master]
		   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
		VALUES
			('UP', 'App_Setting', 'SettingCode', 'OrganisationLogo', 'LogoFile', '',
			 CASE WHEN @Action = 'Upload' THEN 'Uploaded: ' + CAST(LEFT(LTRIM(RTRIM(ISNULL(@FileDetail, ''))), 150) AS VARCHAR(150)) ELSE 'Removed' END,
			 @ActingUserId, GETDATE());

		SET @Result = 1;
	END

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

DECLARE @Installed INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%OrganisationSettings-Step19%'
    AND object_id IN (OBJECT_ID('dbo.spr_GetOrganisationSettings'), OBJECT_ID('dbo.spr_SetOrganisationSettings'),
                      OBJECT_ID('dbo.spr_RecordOrganisationLogo')));
DECLARE @Rows INT = (SELECT COUNT(*) FROM App_Setting WHERE SettingCode IN
    ('OrganisationName', 'OrganisationShortName', 'OrganisationTerm', 'CertificateSignOff', 'RegisteredOfficeLabel',
     'RegisteredOfficeLine1', 'RegisteredOfficeLine2', 'RegisteredOfficeCity', 'RegisteredOfficePinCode',
     'OrganisationPhone', 'OrganisationFax', 'OrganisationEmail'));

IF (@Installed = 3 AND @Rows = 12)
    PRINT 'Organisation settings (step 19) installed: 3 procedures, 12 settings.';
ELSE
    PRINT 'Organisation settings (step 19): ' + CAST(@Installed AS VARCHAR(4)) + ' of 3 procedures carry the marker, '
        + CAST(@Rows AS VARCHAR(4)) + ' of 12 settings. Check the messages above.';
GO

SET NOEXEC OFF;
GO
