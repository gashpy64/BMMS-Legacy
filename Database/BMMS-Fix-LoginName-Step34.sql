/* ============================================================================
   BMMS - The access log carries the login ID (step 34, step UN2)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Before this step a row of Audit_Trial_Login (the login and logout record)
   held only the user's id (User_Id): neither the login ID nor the name.
   Users.LoginName is the login ID; Users.UserName is the person's name.

   Rules
     Audit_Trial_Login.Login_Name  NEW column, VARCHAR(50) NULL (the size of
                                   Users.LoginName): the login ID of the
                                   user at the time of the login.
                                   The rows that exist before this step stay
                                   NULL (they are not filled in).
     spr_RecordLoginByUserId       (called at a successful login only) as
                                   before: closes every earlier row of the
                                   user (Login_Status 'C') and writes a new
                                   row with status 'O'; the new row also
                                   carries Login_Name, read from Users by
                                   @UserId inside the procedure. The
                                   parameters do not change, so the build
                                   before step UN2 keeps working with it.
                                   An id with no user row writes the row
                                   with Login_Name NULL, as before.
     Logout and session end        unchanged (spr_AddEditAuditTrialLogin
                                   closes the user's open rows by User_Id).
     Wrong password, unknown login unchanged: no row is written.

   Objects
     Audit_Trial_Login.Login_Name  ADDED when missing.
     spr_RecordLoginByUserId       REPLACED (text of
                                   BMMS-Fix-Login-Procedures.sql, step 1);
                                   marker LoginName-Step34.
   Re-running step 1 (BMMS-Fix-Login-Procedures.sql) afterwards brings back
   the old procedure: the new rows then have Login_Name NULL and
   BMMS-Check-InstalledSteps.sql shows step 34 Partly (the column stays);
   run step 34 again.
   spr_sys_ResetDatabase deletes the rows of Audit_Trial_Login and keeps the
   column.

   Changes no data (it adds a column; it writes no row). Safe to re-run.
   BMMS-Rollback-LoginName-Step34.sql restores the step 1 procedure and keeps
   the column. It can run before or after the build of step UN2 is deployed.

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
ELSE IF (OBJECT_ID('dbo.Audit_Trial_Login', 'U') IS NULL OR COL_LENGTH('dbo.Audit_Trial_Login', 'User_Id') IS NULL
         OR COL_LENGTH('dbo.Users', 'LoginName') IS NULL)
BEGIN
    RAISERROR('Audit_Trial_Login (User_Id) or Users.LoginName is missing in "%s". This is not a BMMS database of the expected version. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.spr_RecordLoginByUserId', 'P') IS NULL)
BEGIN
    RAISERROR('spr_RecordLoginByUserId is missing in "%s": step 1 (BMMS-Fix-Login-Procedures.sql) is not installed. Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF (COL_LENGTH('dbo.Audit_Trial_Login', 'Login_Name') IS NULL)
BEGIN
    ALTER TABLE dbo.Audit_Trial_Login ADD Login_Name VARCHAR(50) NULL;
    PRINT 'Audit_Trial_Login.Login_Name added (the existing rows stay NULL).';
END
ELSE
    PRINT 'Audit_Trial_Login.Login_Name already exists: kept as it is.';
GO

-- Successful login (LoginName-Step34): closes every earlier row of the user and writes a new open row, as in
-- step 1; the new row also carries the user's login ID (Users.LoginName, read here by @UserId; NULL when the id
-- has no user row). The parameters are those of step 1.
CREATE OR ALTER PROCEDURE [dbo].[spr_RecordLoginByUserId]
	@UserId INT,
	@User_IP_Address VARCHAR(250),
	@Server_Url VARCHAR(250)
AS
BEGIN
	DECLARE @LoginName VARCHAR(50);

	SET @LoginName = (SELECT LoginName FROM Users WHERE UserId = @UserId);

	UPDATE [Audit_Trial_Login] SET [Login_Status] = 'C' WHERE [User_Id] = @UserId;

	INSERT INTO [Audit_Trial_Login]
		([User_Id], [Login_DateTime], [Login_Status], [User_IP_Address], [Server_Url], [Login_Name])
	VALUES
		(@UserId, GETDATE(), 'O', @User_IP_Address, @Server_Url, @LoginName);
END
GO

DECLARE @Installed INT = 0;
IF (COL_LENGTH('dbo.Audit_Trial_Login', 'Login_Name') IS NOT NULL)
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RecordLoginByUserId')), '') LIKE '%LoginName-Step34%')
    SET @Installed = @Installed + 1;

IF (@Installed = 2)
    PRINT 'Step 34 installed: Audit_Trial_Login.Login_Name and spr_RecordLoginByUserId (LoginName-Step34).';
ELSE
    RAISERROR('Step 34 is not complete: %d of 2 parts are present (Audit_Trial_Login.Login_Name, spr_RecordLoginByUserId with the marker LoginName-Step34). Read the messages above and run the script again.', 16, 1, @Installed);
GO

SET NOEXEC OFF;
GO
