/* ============================================================================
   BMMS - No reference to another database: the control-character list of
   two procedures (step 57, step AZ2)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Why: the SSMS "Deploy Database to Microsoft Azure SQL Database" of
   BMMS_Test failed with SQL71562: spr_AddEditMemberType and
   spr_SetOrganisationSettings read the numbers 0 to 31 and 127 from
   master.dbo.spt_values, and an Azure SQL database cannot name another
   database.

   Owner decisions 2026-11-26 (requirement AZ2): the marker
   DatabaseLocal-Step57; a numbers list (common table expression) inside
   each procedure, no new object and no catalog view; Fix 19, Fix 21, Fix 40
   and Rollback 40 are not changed (README note); spr_SetOrganisationSettings
   keeps its re-raise as it is, spr_AddEditMemberType keeps RAISERROR.

   Objects (each gets the text DatabaseLocal-Step57 and keeps the markers of
   its earlier steps)
     spr_SetOrganisationSettings   REPLACED (step 19 text,
                                   OrganisationSettings-Step19)
     spr_AddEditMemberType         REPLACED (step 40 text, MemberTypes-Step21
                                   and RoleAccess-Step40)
   Each text is the earlier text word for word, except the fill of the
   control-character list (the same 33 characters: 0 to 31 and 127) and one
   comment line. Parameters, result sets, Reasons, ReasonDetail and messages
   are unchanged. Changes no data. No change to the application build.

   Order: installed after step 56. Needs step 56 (spr_sys_ResetDatabase
   carries GovernanceLog-Step56), spr_SetOrganisationSettings with the step
   19 marker and spr_AddEditMemberType with the step 40 marker (both keep
   them after step 57, so a re-run is safe); it stops otherwise.

   Re-running BMMS-Fix-OrganisationSettings-Step19.sql,
   BMMS-Fix-MemberTypes-Step21.sql, BMMS-Fix-RoleAccess-Step40.sql or
   BMMS-Rollback-RoleAccess-Step40.sql after this step brings the reference
   to master.dbo.spt_values back: step 57 reads Partly or Missing; run step
   57 again (after step 56).

   The end of the script counts the references to another database or
   server in this database (sys.sql_expression_dependencies). It leaves out
   one row only: spr_SaveFollowupConfirmed's x.n.value, an XML method call
   that SQL Server lists as database x, schema n, object value. A correct
   install prints 0.

   BMMS-Rollback-DatabaseLocal-Step57.sql puts the step 19 and step 40 texts
   back unchanged (not on Azure SQL Database, where they cannot run).

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '') NOT LIKE '%GovernanceLog-Step56%')
BEGIN
    RAISERROR('Step 56 (BMMS-Fix-GovernanceLog-Step56.sql) is not installed in "%s". The steps are installed in order: run step 56 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') NOT LIKE '%OrganisationSettings-Step19%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%RoleAccess-Step40%')
BEGIN
    RAISERROR('spr_SetOrganisationSettings does not have the text of step 19 (marker OrganisationSettings-Step19), or spr_AddEditMemberType does not have the text of step 40 (marker RoleAccess-Step40), in "%s". Run those steps first (BMMS-Check-InstalledSteps.sql shows which steps are installed), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
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
	-- DatabaseLocal-Step57: the numbers 0 to 255 are made here; no other database is read
	;WITH d (n) AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),
	                (13),(14),(15)) v (n)),
	      num (number) AS (SELECT a.n * 16 + b.n FROM d a CROSS JOIN d b)
	INSERT INTO @Ctrl (Ch)
	SELECT NCHAR(number) FROM num WHERE number BETWEEN 0 AND 31 OR number = 127;

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

-- Member type - add / edit; an active Admin; a reserved type cannot be edited (MemberTypes-Step21;
-- RoleAccess-Step40: Admin only since step RA1a, the error re-raised with RAISERROR)
-- @CreatedOn, @CreatedBy, @UpdatedOn and @UpdatedBy are kept for the older build and not used:
-- the acting user and the server time are stored. Code and name are trimmed.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMemberType]
@Code VARCHAR(50),
@MemberTypeId INT,
@MemberTypeCode NVARCHAR(400),
@MemberTypeName NVARCHAR(400),
@StatusId INT,
@CreatedOn DATETIME = NULL,
@CreatedBy INT = NULL,
@UpdatedOn DATETIME = NULL,
@UpdatedBy INT = NULL,
@MemberScope VARCHAR(10) = NULL,
@DisplayOrder INT = NULL,
@ActingUserId INT = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @NewCode NVARCHAR(400);
DECLARE @NewName NVARCHAR(400);
DECLARE @Scope VARCHAR(10);
DECLARE @Exists INT;
DECLARE @OldReserved BIT;
DECLARE @OldScope CHAR(1);
DECLARE @CmCount INT;
DECLARE @MmCount INT;
DECLARE @Ctrl TABLE (Ch NCHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @NewCode = LTRIM(RTRIM(ISNULL(@MemberTypeCode, '')));
	SET @NewName = LTRIM(RTRIM(ISNULL(@MemberTypeName, '')));
	SET @Scope = UPPER(LTRIM(RTRIM(ISNULL(@MemberScope, ''))));

	-- Control characters 0 to 31 and 127
	-- DatabaseLocal-Step57: the numbers 0 to 255 are made here; no other database is read
	;WITH d (n) AS (SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),
	                (13),(14),(15)) v (n)),
	      num (number) AS (SELECT a.n * 16 + b.n FROM d a CROSS JOIN d b)
	INSERT INTO @Ctrl (Ch)
	SELECT NCHAR(number) FROM num WHERE number BETWEEN 0 AND 31 OR number = 127;

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MemberTypeSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@Code, '') NOT IN ('Save', 'Update'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = 'Code';
		END
		ELSE
		BEGIN
			-- Every row is locked, so two saves of the same code or name run one after the other
			SET @Exists = (SELECT COUNT(*) FROM Member_Type WITH (UPDLOCK, HOLDLOCK));

			IF (@Code = 'Update')
			BEGIN
				SELECT @OldReserved = IsReserved, @OldScope = MemberScope
				FROM Member_Type WHERE MemberTypeId = @MemberTypeId;

				IF (@OldScope IS NULL)
				BEGIN
					SET @Reason = 3;
					SET @Detail = 'NotFound';
				END
				ELSE IF (@OldReserved = 1)
					SET @Reason = 7;
			END

			IF (@Reason = 0)
			BEGIN
				SET @Detail =
					CASE
					WHEN @NewCode = '' OR LEN(@NewCode) > 50
					  OR EXISTS (SELECT 1 FROM @Ctrl c WHERE CHARINDEX(c.Ch, @NewCode COLLATE Latin1_General_BIN) > 0)
					  -- characters the database code page cannot hold come back changed
					  OR CAST(CAST(@NewCode AS VARCHAR(400)) AS NVARCHAR(400)) COLLATE Latin1_General_BIN <> @NewCode COLLATE Latin1_General_BIN
						THEN 'MemberTypeCode'
					WHEN @NewName = '' OR LEN(@NewName) > 50
					  OR EXISTS (SELECT 1 FROM @Ctrl c WHERE CHARINDEX(c.Ch, @NewName COLLATE Latin1_General_BIN) > 0)
					  OR CAST(CAST(@NewName AS VARCHAR(400)) AS NVARCHAR(400)) COLLATE Latin1_General_BIN <> @NewName COLLATE Latin1_General_BIN
						THEN 'MemberTypeName'
					WHEN @Scope NOT IN ('C', 'M')
						THEN 'MemberScope'
					WHEN ISNULL(@DisplayOrder, 0) NOT BETWEEN 0 AND 9999
						THEN 'DisplayOrder'
					WHEN ISNULL(@StatusId, -1) NOT IN (0, 1)
						THEN 'StatusId'
					WHEN EXISTS (SELECT 1 FROM Member_Type WHERE LTRIM(RTRIM(MemberTypeCode)) = @NewCode
					             AND (@Code = 'Save' OR MemberTypeId <> @MemberTypeId))
						THEN 'DuplicateCode'
					WHEN EXISTS (SELECT 1 FROM Member_Type WHERE LTRIM(RTRIM(MemberTypeName)) = @NewName
					             AND (@Code = 'Save' OR MemberTypeId <> @MemberTypeId))
						THEN 'DuplicateName'
					ELSE '' END;

				IF (@Detail <> '')
					SET @Reason = 3;
			END

			IF (@Reason = 0 AND @Code = 'Update' AND @OldScope <> @Scope)
			BEGIN
				-- A type in use keeps its scope: its rows would be on the wrong page
				SET @CmCount = (SELECT COUNT(*) FROM Committee_Member WITH (HOLDLOCK) WHERE MemberTypeId = @MemberTypeId);
				SET @MmCount = (SELECT COUNT(*) FROM Meeting_Member WITH (HOLDLOCK) WHERE MemberTypeId = @MemberTypeId);
				IF (@CmCount + @MmCount > 0)
				BEGIN
					SET @Reason = 5;
					SET @Detail = CAST(@CmCount AS VARCHAR(12)) + ' committee, ' + CAST(@MmCount AS VARCHAR(12)) + ' meeting';
				END
			END

			IF (@Reason = 0 AND @Code = 'Save')
			BEGIN
				INSERT INTO Member_Type
				(MemberTypeCode, MemberTypeName, StatusId, IsDelete, MemberScope, DisplayOrder, IsReserved,
					CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
				VALUES
				(CAST(@NewCode AS VARCHAR(50)), CAST(@NewName AS VARCHAR(50)), @StatusId, 0, @Scope, ISNULL(@DisplayOrder, 0), 0,
					GETDATE(), @ActingUserId, GETDATE(), @ActingUserId);
				SET @Result = 1;
			END
			ELSE IF (@Reason = 0 AND @Code = 'Update')
			BEGIN
				UPDATE Member_Type SET
				MemberTypeCode = CAST(@NewCode AS VARCHAR(50)),
				MemberTypeName = CAST(@NewName AS VARCHAR(50)),
				StatusId = @StatusId,
				MemberScope = @Scope,
				DisplayOrder = ISNULL(@DisplayOrder, 0),
				UpdatedOn = GETDATE(),
				UpdatedBy = @ActingUserId
				WHERE MemberTypeId = @MemberTypeId AND IsReserved = 0;
				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
			END
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		SET @ErrMsg = ERROR_MESSAGE();

		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MemberTypeSave;

		RAISERROR('%s', 16, 1, @ErrMsg);
		RETURN;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

DECLARE @Installed INT = 0;
DECLARE @Kept INT = 0;
DECLARE @Outside INT;

IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') LIKE '%DatabaseLocal-Step57%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%DatabaseLocal-Step57%')
    SET @Installed = @Installed + 1;

-- the older markers that BMMS-Check-InstalledSteps.sql and the older Test scripts read for steps 19, 21 and 40
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') LIKE '%OrganisationSettings-Step19%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%MemberTypes-Step21%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%RoleAccess-Step40%')
    SET @Kept = @Kept + 1;

-- References to another database or server; only the x.n.value row of spr_SaveFollowupConfirmed (an XML method call) is left out
SET @Outside = (SELECT COUNT(*) FROM sys.sql_expression_dependencies d
                WHERE (d.referenced_database_name IS NOT NULL OR d.referenced_server_name IS NOT NULL)
                  AND NOT (d.referencing_id = OBJECT_ID('dbo.spr_SaveFollowupConfirmed')
                           AND d.referenced_server_name IS NULL
                           AND d.referenced_database_name = 'x'
                           AND d.referenced_schema_name = 'n'
                           AND d.referenced_entity_name = 'value'));

IF (@Installed = 2 AND @Kept = 3)
    PRINT 'Step 57 installed: spr_SetOrganisationSettings and spr_AddEditMemberType (DatabaseLocal-Step57); the markers of steps 19, 21 and 40 kept. References to another database or server: ' + CAST(@Outside AS VARCHAR(12)) + ' (0 expected).';
ELSE
    RAISERROR('Step 57 is not complete: %d of 2 procedures carry the marker DatabaseLocal-Step57, %d of 3 older markers kept. Read the messages above and run the script again.', 16, 1, @Installed, @Kept);
GO

SET NOEXEC OFF;
GO
