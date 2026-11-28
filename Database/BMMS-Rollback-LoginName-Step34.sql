/* ============================================================================
   BMMS - Rollback of step 34 (BMMS-Fix-LoginName-Step34.sql)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores spr_RecordLoginByUserId with the text of step 1
   (BMMS-Fix-Login-Procedures.sql), as installed on BMMS_Test before step 34:
   a successful login closes the user's earlier rows and writes a new open
   row without the login ID.

   The column Audit_Trial_Login.Login_Name is KEPT, with the login IDs it
   already holds; the rows written after this rollback have it NULL. The
   build of step UN2 does not read the column, so it runs on either text.

   Changes no data. Safe to re-run, also where step 34 was never installed
   (the procedure of step 1 must exist).

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
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
ELSE IF (OBJECT_ID('dbo.spr_RecordLoginByUserId', 'P') IS NULL)
BEGIN
    RAISERROR('spr_RecordLoginByUserId is missing in "%s": step 1 (BMMS-Fix-Login-Procedures.sql) is not installed, so there is nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

CREATE OR ALTER PROCEDURE [dbo].[spr_RecordLoginByUserId]
	@UserId INT,
	@User_IP_Address VARCHAR(250),
	@Server_Url VARCHAR(250)
AS
BEGIN
	-- Same behaviour as the block that used to live inside
	-- spr_GetUserByLoginName: close any earlier sessions, open a new one.
	UPDATE [Audit_Trial_Login] SET [Login_Status] = 'C' WHERE [User_Id] = @UserId;

	INSERT INTO [Audit_Trial_Login]
		([User_Id], [Login_DateTime], [Login_Status], [User_IP_Address], [Server_Url])
	VALUES
		(@UserId, GETDATE(), 'O', @User_IP_Address, @Server_Url);
END
GO

DECLARE @Left INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_RecordLoginByUserId')), '') LIKE '%LoginName-Step34%')
    SET @Left = 1;

IF (@Left = 0)
    PRINT 'Step 34 rolled back: spr_RecordLoginByUserId has the text of step 1. Audit_Trial_Login.Login_Name is kept.';
ELSE
    RAISERROR('Rollback of step 34 is not complete: spr_RecordLoginByUserId still carries the marker LoginName-Step34. Read the messages above and run the script again.', 16, 1);
GO

SET NOEXEC OFF;
GO
