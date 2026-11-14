/* ============================================================================
   BMMS - Safe SMTP default (step 30)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   The mail settings are the row of table SMTP_Master (SMTPServer,
   SMTPServerPort, UserName, Password, FromMailId, Bcc). Reset Database left
   that row as it was, so a reset or newly restored database kept mailing
   through whatever server the old row named. No script owned the table.

   Decision (Consultant, 2026-10-22): a new or reset database gets a safe
   default that cannot send real mail:
       server localhost, port 25, user empty, password empty,
       From Mail Id noreply@example.invalid, Bcc empty.
   With nothing listening on localhost port 25 every mail fails (and a new
   agenda item is not saved, because its mail fails) until real settings are
   entered on SMTP Configuration or a local mail catcher runs.

   Objects
     spr_sys_SetSmtpDefault  NEW. Replaces every SMTP_Master row by the one
                             default row, in one transaction (or in the
                             caller's). Refused with Result 0, Reason 3,
                             ReasonDetail 'DatabaseName' unless
                             @ConfirmDatabaseName is the name of the current
                             database (compared ignoring case). Returns one
                             row Result, Reason, ReasonDetail unless
                             @ReturnRow = 0; also @Result and @Reason OUTPUT.
                             Run it by hand on a NEW database only, never on
                             BMMS (see Database/README.md, step 30).
     spr_UpdateSMTPMaster    REPLACED (legacy). Saves as before and inserts
                             the row when the table is empty (before, an empty
                             table saved nothing). Parameters unchanged.
     spr_sys_ResetDatabase   REPLACED (step 29; earlier steps 3, 18 and 21).
                             The step 29 text unchanged, plus one call of
                             spr_sys_SetSmtpDefault inside the transaction,
                             before the default rows.
   Marker SmtpDefault-Step30 in all three.

   This script only installs the procedures. It does NOT run them and changes
   no data. Executing spr_sys_ResetDatabase wipes the whole database.

   Needs steps 18 and 21 (as step 29) and stops otherwise. Steps 3, 18, 21 and
   29 each contain an older spr_sys_ResetDatabase: if one of them is re-run,
   run this script again afterwards, as the last step. It contains the whole
   step 29 text, so step 29 itself need not be run again.

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
ELSE IF (COL_LENGTH('dbo.Users', 'IsSystem') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s". Run it first (then step 21), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (COL_LENGTH('dbo.Member_Type', 'MemberScope') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetMemberTypeForTagging')), '') NOT LIKE '%MemberTypes-Step21%')
BEGIN
    RAISERROR('Step 21 (BMMS-Fix-MemberTypes-Step21.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.Audit_Trail_SendMail', 'U') IS NULL)
BEGIN
    RAISERROR('Table Audit_Trail_SendMail is missing in "%s". Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.SMTP_Master', 'U') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'SMTPServer') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'SMTPServerPort') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'UserName') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'Password') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'FromMailId') IS NULL
         OR COL_LENGTH('dbo.SMTP_Master', 'Bcc') IS NULL)
BEGIN
    RAISERROR('Table SMTP_Master or one of its columns SMTPServer, SMTPServerPort, UserName, Password, FromMailId, Bcc is missing in "%s". Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Another column that needs a value would make the default insert fail
ELSE IF EXISTS (SELECT 1 FROM sys.columns c
                WHERE c.object_id = OBJECT_ID('dbo.SMTP_Master')
                  AND c.name NOT IN ('SMTPServer', 'SMTPServerPort', 'UserName', 'Password', 'FromMailId', 'Bcc')
                  AND c.is_nullable = 0 AND c.default_object_id = 0 AND c.is_identity = 0 AND c.is_computed = 0)
BEGIN
    RAISERROR('Table SMTP_Master in "%s" has another column that needs a value; the default row cannot be inserted. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- The default values must fit (localhost: 9 characters, noreply@example.invalid: 23)
ELSE IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SMTP_Master'
                  AND ((COLUMN_NAME = 'SMTPServer' AND CHARACTER_MAXIMUM_LENGTH BETWEEN 0 AND 8)
                    OR (COLUMN_NAME = 'FromMailId' AND CHARACTER_MAXIMUM_LENGTH BETWEEN 0 AND 22)))
BEGIN
    RAISERROR('Column SMTPServer or FromMailId of SMTP_Master in "%s" is too short for the default values. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

-- Read only: what this database has today (the script changes no data)
DECLARE @Columns NVARCHAR(1000);
DECLARE @SmtpRows INT;

SELECT @Columns = STUFF((SELECT N', ' + COLUMN_NAME + N' ' + DATA_TYPE
                         + CASE WHEN CHARACTER_MAXIMUM_LENGTH = -1 THEN N'(max)'
                                WHEN CHARACTER_MAXIMUM_LENGTH IS NOT NULL THEN N'(' + CAST(CHARACTER_MAXIMUM_LENGTH AS NVARCHAR(12)) + N')'
                                ELSE N'' END
                         + CASE WHEN IS_NULLABLE = 'NO' THEN N' NOT NULL' ELSE N'' END
                         FROM INFORMATION_SCHEMA.COLUMNS
                         WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'SMTP_Master'
                         ORDER BY ORDINAL_POSITION
                         FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(1000)'), 1, 2, N'');
SELECT @SmtpRows = COUNT(*) FROM dbo.SMTP_Master;

PRINT 'Database: ' + DB_NAME();
PRINT 'SMTP_Master columns: ' + @Columns;
PRINT 'SMTP_Master rows today: ' + CAST(@SmtpRows AS VARCHAR(12)) + ' (not changed by this script)';
GO

-- SmtpDefault-Step30: the safe mail settings of a new or reset database, one row that cannot send real mail:
-- server localhost, port 25, no user name or password, From noreply@example.invalid, no Bcc. Every existing
-- row is replaced. Only when @ConfirmDatabaseName is the current database (Reason 3, DatabaseName).
-- Runs in the caller's transaction when there is one (Reset Database), otherwise in its own.
-- Run by hand on a new database only, never on BMMS.
CREATE OR ALTER PROCEDURE [dbo].[spr_sys_SetSmtpDefault]
	@ConfirmDatabaseName NVARCHAR(128),
	@ReturnRow BIT = 1,
	@Result INT = NULL OUTPUT,
	@Reason INT = NULL OUTPUT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Detail VARCHAR(100);
DECLARE @OwnTransaction BIT;

SET @Result = 0;
SET @Reason = 0;
SET @Detail = '';
SET @OwnTransaction = 0;

IF (UPPER(LTRIM(RTRIM(ISNULL(@ConfirmDatabaseName, N'')))) <> UPPER(DB_NAME()))
BEGIN
	SET @Reason = 3;
	SET @Detail = 'DatabaseName';
END
ELSE
BEGIN
	IF (@@TRANCOUNT = 0)
	BEGIN
		BEGIN TRANSACTION;
		SET @OwnTransaction = 1;
	END

	DELETE FROM SMTP_Master;

	INSERT INTO SMTP_Master (SMTPServer, SMTPServerPort, UserName, [Password], FromMailId, Bcc)
	VALUES ('localhost', '25', '', '', 'noreply@example.invalid', '');

	IF (@OwnTransaction = 1)
		COMMIT TRANSACTION;

	SET @Result = 1;
END

IF (@ReturnRow = 1)
	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- SMTP Configuration page, Update: saves the mail settings. Inserts the row when the table is empty
-- (SmtpDefault-Step30; before, an empty table saved nothing and the page still said "Successfully
-- updated."). With several rows every row is updated, as before. Parameter sizes unchanged: a From or
-- Bcc longer than 50 characters is cut (known item). An empty password is saved as empty (the page
-- protects a non-empty one).
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateSMTPMaster]
(
@SMTPServer VARCHAR(50),
@SMTPServerPort VARCHAR(50),
@UserName VARCHAR(50),
@Password VARCHAR(MAX),
@FromMailId VARCHAR(50),
@Bcc VARCHAR(50)
)
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

	-- TABLOCKX until COMMIT: two saves at the same time on an empty table cannot both insert
	UPDATE SMTP_Master WITH (TABLOCKX) SET
	SMTPServer = @SMTPServer,
	SMTPServerPort = @SMTPServerPort,
	UserName = @UserName,
	Password = @Password,
	FromMailId = @FromMailId,
	Bcc = @Bcc;

	IF (@@ROWCOUNT = 0)
		INSERT INTO SMTP_Master (SMTPServer, SMTPServerPort, UserName, [Password], FromMailId, Bcc)
		VALUES (@SMTPServer, @SMTPServerPort, @UserName, @Password, @FromMailId, @Bcc);

COMMIT TRANSACTION;

END
GO

-- Reset Database: wipes all data and seeds the defaults. The "admin" user is seeded as the protected
-- system account (IsSystem = 1), the other three with IsSystem = 0; the seed e-mail addresses are
-- placeholders (SystemAccount3-Step18). Seeded passwords are hashes of the application's default password,
-- Common.DefaultPassword in BMMSBAL/Common.cs (DefaultPassword-Step29).
-- Member types are seeded with their scope (C committee, M meeting), display order and the reserved
-- flag: 2 Invitee, 3 In Attendance and 6 Special Invitee are reserved (MemberTypes-Step21).
-- ResetSafe-Step29: only an active Admin who names the current database; prechecks before anything is
-- cleared; one transaction (XACT_ABORT ON), identity counters put back after a rollback; the send-mail
-- audit is cleared too; one audit row records who reset the database.
-- SmtpDefault-Step30: the mail settings (SMTP_Master) are replaced inside the transaction by the one safe
-- default row of spr_sys_SetSmtpDefault (localhost, port 25, no login, From noreply@example.invalid, no Bcc).
CREATE OR ALTER PROCEDURE [dbo].[spr_sys_ResetDatabase]
	@ActingUserId INT,
	@ConfirmDatabaseName NVARCHAR(128),
	@Result INT = NULL OUTPUT,
	@Reason INT = NULL OUTPUT
AS
BEGIN
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Detail VARCHAR(100);
DECLARE @ActingRole VARCHAR(50);
DECLARE @ActingLogin VARCHAR(50);
DECLARE @Sql NVARCHAR(400);
DECLARE @TableName SYSNAME;
DECLARE @SavedValue BIGINT;
DECLARE @SeedValue BIGINT;
DECLARE @IncrementValue BIGINT;
DECLARE @Ident TABLE (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
DECLARE @DbName NVARCHAR(128);
DECLARE @SmtpResult INT;
DECLARE @SmtpReason INT;

SET @Result = 0;
SET @Reason = 0;
SET @Detail = '';
SET @DbName = DB_NAME();

-------------------------------------------------------------------------------
-- Prechecks: nothing has been changed yet
-------------------------------------------------------------------------------
SELECT @ActingRole = r.RoleCode, @ActingLogin = CAST(u.LoginName AS VARCHAR(50))
FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1;

IF (@ActingRole IS NULL)
	SET @Reason = 8;
ELSE IF (LTRIM(RTRIM(@ActingRole)) <> 'admin')
	SET @Reason = 4;
ELSE IF (UPPER(LTRIM(RTRIM(ISNULL(@ConfirmDatabaseName, N'')))) <> UPPER(DB_NAME()))
BEGIN
	SET @Reason = 3;
	SET @Detail = 'DatabaseName';
END

IF (@Reason = 0)
BEGIN
	-- Every identity counter as it is now (a counter never used has no saved value)
	INSERT INTO @Ident (TableName, SavedValue, SeedValue, IncrementValue)
	SELECT t.name,
	       CASE WHEN ic.last_value IS NULL THEN NULL ELSE CAST(IDENT_CURRENT('dbo.' + QUOTENAME(t.name)) AS BIGINT) END,
	       CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
	FROM sys.identity_columns ic
	INNER JOIN sys.tables t ON t.object_id = ic.object_id
	WHERE t.is_ms_shipped = 0 AND SCHEMA_NAME(t.schema_id) = 'dbo';

	BEGIN TRY
	BEGIN TRANSACTION;

	---------------------------------------------------------------------------
	-- 1. Clear (DELETE only, child tables first)
	---------------------------------------------------------------------------
	DELETE FROM ActionItem_User_Map;
	DELETE FROM Alert_User_Map;
	DELETE FROM Meeting_Member;
	DELETE FROM Committee_Member;
	DELETE FROM Attendance;

	DELETE FROM SysCodeSetting;
	DELETE FROM Audit_Trail_Master;
	DELETE FROM Audit_Trail_SqlBackup;
	DELETE FROM Audit_Trial_Login;
	DELETE FROM Audit_Trail_SendMail;
	DELETE FROM Action_Item;
	DELETE FROM Alert_Master;
	DELETE FROM Minutes;
	DELETE FROM Agenda;
	DELETE FROM Agenda_Status;
	DELETE FROM Meeting;
	DELETE FROM Committee;
	DELETE FROM Member;
	DELETE FROM Member_Type;
	DELETE FROM Alert_Type;
	DELETE FROM Decision_Type;
	DELETE FROM Users;
	DELETE FROM Department;
	DELETE FROM Designation;
	DELETE FROM Subject_Type;
	DELETE FROM Roles;

	---------------------------------------------------------------------------
	-- 2. Identity counters, all after the clearing
	---------------------------------------------------------------------------
	-- The five tables TRUNCATE used to clear: a used counter starts again at its seed, as TRUNCATE did
	DECLARE SeedCursor CURSOR LOCAL FAST_FORWARD FOR
		SELECT TableName, SeedValue, IncrementValue FROM @Ident
		WHERE SavedValue IS NOT NULL
		  AND TableName IN ('ActionItem_User_Map', 'Alert_User_Map', 'Meeting_Member', 'Committee_Member', 'Attendance');

	OPEN SeedCursor;
	FETCH NEXT FROM SeedCursor INTO @TableName, @SeedValue, @IncrementValue;

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, '
		         + CAST(@SeedValue - @IncrementValue AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
		EXEC sp_executesql @Sql;
		FETCH NEXT FROM SeedCursor INTO @TableName, @SeedValue, @IncrementValue;
	END

	CLOSE SeedCursor;
	DEALLOCATE SeedCursor;

	DBCC CHECKIDENT (Audit_Trail_Master, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trail_SqlBackup, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trial_Login, RESEED, 0);
	DBCC CHECKIDENT (Audit_Trail_SendMail, RESEED, 0);
	DBCC CHECKIDENT (Action_Item, RESEED, 0);
	DBCC CHECKIDENT (Alert_Master, RESEED, 0);
	DBCC CHECKIDENT (Minutes, RESEED, 0);
	DBCC CHECKIDENT (Agenda, RESEED, 0);
	DBCC CHECKIDENT (Meeting, RESEED, 0);
	DBCC CHECKIDENT (Committee, RESEED, 0);
	DBCC CHECKIDENT (Member, RESEED, 0);
	DBCC CHECKIDENT (Member_Type, RESEED, 0);
	DBCC CHECKIDENT (Decision_Type, RESEED, 0);
	DBCC CHECKIDENT (Users, RESEED, 0);
	DBCC CHECKIDENT (Department, RESEED, 0);
	DBCC CHECKIDENT (Designation, RESEED, 0);
	DBCC CHECKIDENT (Subject_Type, RESEED, 0);
	DBCC CHECKIDENT (Roles, RESEED, 0);

	---------------------------------------------------------------------------
	-- 3. The mail settings: one row with the safe default, so a reset database sends no real mail
	--    (SmtpDefault-Step30). Before the default rows: a failure in them rolls this back too.
	---------------------------------------------------------------------------
	EXEC dbo.spr_sys_SetSmtpDefault @ConfirmDatabaseName = @DbName, @ReturnRow = 0,
	     @Result = @SmtpResult OUTPUT, @Reason = @SmtpReason OUTPUT;

	IF (ISNULL(@SmtpResult, 0) <> 1)
		THROW 50030, 'Reset Database: the mail settings could not be set to the default (spr_sys_SetSmtpDefault).', 1;

	---------------------------------------------------------------------------
	-- 4. The default rows
	---------------------------------------------------------------------------
INSERT INTO [SysCodeSetting]
([SysCodeId], [MainCode],[SubCode],[DisplayName],[Remarks],[DisplayOrder],[IsActive])
SELECT 1, 'Status', '1', 'Active', 'Status', 1, 1
UNION ALL
SELECT 2, 'Status', '0', 'InActive', 'Status', 2, 1
UNION ALL
SELECT 3, 'Sex', '1', 'Male', 'Sex', 1, 1
UNION ALL
SELECT 4, 'Sex', '0', 'Female', 'Sex', 2, 1;

INSERT INTO [Agenda_Status]
([AgendaStatusCode],[AgendaStatusName])
SELECT 'AC', 'Agenda Creation'
UNION ALL
SELECT 'AMA', 'Manager Approved'
UNION ALL
SELECT 'ACA', 'Controller Approved'
UNION ALL
SELECT 'AMR', 'Manager Rejected'
UNION ALL
SELECT 'ACR', 'Controller Rejected'
UNION ALL
SELECT 'AF', 'Finalized';


INSERT INTO [Alert_Type]
([AlertTypeCode],[AlertTypeName],[AlertTypeDescription],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'CC', 'Creation', 'Committee Creation', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MC', 'Creation', 'Meeting Creation', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AC', 'Creation', 'Agenda Creation', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMA', 'Manager Approved', 'Agenda Manager Approved', 4, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACA', 'Controller Approved', 'Agenda Controller Approved', 5, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMR', 'Manager Rejected', 'Agenda Manager Rejected', 6, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACR', 'Controller Rejected', 'Agenda Controller Rejected', 7, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AF', 'Finalized', 'Agenda Finalized', 8, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MF', 'Finalized', 'Minutes Finalized', 9, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MU', 'Updated', 'Meeting Updated', 10, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'CU', 'Updated', 'Committee Updated', 11, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Member_Type]
([MemberTypeCode],[MemberTypeName],[StatusId],[IsDelete],[MemberScope],[DisplayOrder],[IsReserved],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'Member', 'Member', 1, 1, 'C', 1, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Invitee', 'Invitee', 1, 1, 'M', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'InAttendance', 'In Attendance', 1, 1, 'M', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Chairman', 'Chairman', 1, 1, 'C', 4, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MD', 'Managing Director', 1, 1, 'C', 5, 0, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Special Invitee', 'Special Invitee', 1, 1, 'M', 6, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Decision_Type]
([DecisionTypeCode],[DecisionTypeName],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DT001', 'Followup', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT002', 'Pending', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT003', 'Sanctioned', 1, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Subject_Type]
([SubjectTypeCode],[SubjectTypeName],[OrderNo],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'ST001', 'Ratification', 1, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST002', 'Information', 2, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST003', 'Sanction', 3, 1, 1, GETDATE(), 1, GETDATE(), 1;


INSERT INTO [Department]
([DepartmentCode],[DepartmentName],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'D001', 'Admin', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D002', 'Secretarial', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D003', 'HRD', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D004', 'Credit', 4, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Designation]
([DesignationCode],[DesignationName],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DESIGN001', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN002', 'Company Secretary', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN003', 'Chairman', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN004', 'Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN005', 'Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN006', 'Assistant Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN007', 'General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN008', 'Assistant General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN009', 'Deputy General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN010', 'Managing Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN011', 'Executive Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN012', 'Chief Operating Officer', 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Roles]
([RoleCode],[RoleName],[RoleDescription],[OrderNo],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'admin', 'Admin', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'controller', 'Controller', 'Controller', 2, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'manager', 'Manager', 'Manager', 3, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'user', 'User', 'User', 4, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'mgmt', 'Management', 'Management', 5, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'md_sect', 'MD Secretariat', 'MD Secretariat', 6, GETDATE(), 1, GETDATE(), 1;


-- FK#5-ManagerId-NULL: no manager is stored as NULL, never 0
INSERT INTO [Users]
([UserName],[DepartmentId],[DesignationId],[ManagerId],[RoleId],[EmailId],[LoginName],[Password]
           ,[AccountStatus],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy],[IsSystem])
SELECT 'admin', 1, 1, NULL, 1, '', 'admin', '100000.gURba0Xwa3iXhBwkFEi/hA==.yxFedi3Cfs3FLcDlU7oWXp94eY15AGoU4AN+c3tf8j0=', 1, GETDATE(), 1, GETDATE(), 1, 1
UNION ALL
SELECT 'Controller', 2, 3, NULL, 2, 'con@example.invalid', 'secuser', '100000.QcDvazIat4fcHJw+tivVTg==.dLQDFP7A1cYcAcaYsIvwlXFsZv8lAYDJIVqwDUWNBJ8=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'Manager', 4, 4, NULL, 3, 'mgr@example.invalid', 'credmanager', '100000.pJ5r7xUvCSnGHp+32dpp4w==.ity6i4nc8MrUUoy2nnHfxy17AZp61+bNYkvs1gYQLhI=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'User', 4, 5, 3, 4, 'usr@example.invalid', 'creduser', '100000.UfrmZn5v9zOs6DlxPdFy9Q==.qHS0QM1qZuYJfnITWbrNUucDryAyVLNz1HdnnDcxLbc=', 1, GETDATE(), 1, GETDATE(), 1, 0;


INSERT INTO [Committee]
([CommitteeCode],[CommitteeName],[Board],[IncorporationDate],[StatusId],[IsDelete],
	[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'C01', 'Board of Directors',1, GETDATE(), 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'C02', 'Audit Committee',0, GETDATE(), 1, 0, GETDATE(), 1, GETDATE(), 1;

	---------------------------------------------------------------------------
	-- 5. Who reset the database (by user 1: the acting user no longer exists)
	---------------------------------------------------------------------------
	INSERT INTO [Audit_Trail_Master]
	   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
	VALUES
		('UP', 'Database', 'Database', CAST(LEFT(DB_NAME(), 23) AS VARCHAR(23)), 'Reset', '',
		 'Reset by ' + ISNULL(@ActingLogin, ''), 1, GETDATE());

	COMMIT TRANSACTION;
	SET @Result = 1;
	END TRY
	BEGIN CATCH
		IF (XACT_STATE() <> 0)
			ROLLBACK TRANSACTION;

		-- Put every counter back: a counter that was used gets its saved value; one that was never used and
		-- is used now goes back to its seed (the same rule as BMMS-Test-ResetDatabase.sql)
		DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
			SELECT TableName, SavedValue, SeedValue, IncrementValue FROM @Ident;

		OPEN IdentCursor;
		FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			IF (@SavedValue IS NOT NULL
			    OR EXISTS (SELECT 1 FROM sys.identity_columns ic
			               WHERE ic.object_id = OBJECT_ID('dbo.' + QUOTENAME(@TableName)) AND ic.last_value IS NOT NULL))
			BEGIN
				SET @Sql = N'DBCC CHECKIDENT (''dbo.' + QUOTENAME(@TableName) + N''', RESEED, '
				         + CAST(ISNULL(@SavedValue, @SeedValue - @IncrementValue) AS NVARCHAR(20)) + N') WITH NO_INFOMSGS';
				-- Best effort: a counter that cannot be set back must not hide the error that is re-raised below
				BEGIN TRY
					EXEC sp_executesql @Sql;
				END TRY
				BEGIN CATCH
				END CATCH
			END

			FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
		END

		CLOSE IdentCursor;
		DEALLOCATE IdentCursor;

		THROW;
	END CATCH
END

SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

DECLARE @ResetDef NVARCHAR(MAX) = ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_ResetDatabase')), '');
DECLARE @Marker INT = CASE WHEN @ResetDef LIKE '%SmtpDefault-Step30%' THEN 1 ELSE 0 END
                    + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_sys_SetSmtpDefault')), '') LIKE '%SmtpDefault-Step30%' THEN 1 ELSE 0 END
                    + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateSMTPMaster')), '') LIKE '%SmtpDefault-Step30%' THEN 1 ELSE 0 END;
DECLARE @Older INT = CASE WHEN @ResetDef LIKE '%FK#5-ManagerId-NULL%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%SystemAccount3-Step18%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%MemberTypes-Step21%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%ResetSafe-Step29%' THEN 1 ELSE 0 END
                   + CASE WHEN @ResetDef LIKE '%DefaultPassword-Step29%' THEN 1 ELSE 0 END;
DECLARE @Params INT = (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_sys_ResetDatabase')
                           AND name IN ('@ActingUserId', '@ConfirmDatabaseName', '@Result', '@Reason'));

IF (@Marker = 3 AND @Older = 5 AND @Params = 4)
    PRINT 'Safe SMTP default (step 30) installed: spr_sys_SetSmtpDefault, spr_UpdateSMTPMaster inserts into an empty table, spr_sys_ResetDatabase sets the default; the texts of steps 3, 18, 21 and 29 kept (SmtpDefault-Step30). No data was changed.';
ELSE
    PRINT 'Safe SMTP default (step 30): markers ' + CAST(@Marker AS VARCHAR(1)) + ' of 3, older texts ' + CAST(@Older AS VARCHAR(1))
        + ' of 5, parameters ' + CAST(@Params AS VARCHAR(1)) + ' of 4. Check the messages above.';
GO

SET NOEXEC OFF;
GO
