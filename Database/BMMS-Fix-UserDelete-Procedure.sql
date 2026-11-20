/* ============================================================================
   BMMS - Critical fix #5, step 6: a user with history cannot be deleted
   ----------------------------------------------------------------------------
   Replaces spr_DeleteUserByUserId.

   The old procedure only looked at Agenda.MgrApprovedBy, Agenda.ControllerApprovedBy
   (which the application never writes) and Users.ManagerId. Approvals are
   recorded in Agenda.UpdatedBy and Audit_Trail_Master.Update_By, minutes
   finalize / confirm in Meeting.UpdatedBy, and so on, so a user with real
   history could be deleted and every one of those rows was left pointing at a
   user that no longer existed.

   The new procedure:
     * returns Result = 0 (the page shows the existing "in use" message) when
       the user is referenced by ANY of these 40 columns:
         Users             ManagerId, CreatedBy, UpdatedBy   (of OTHER users)
         Agenda            CreatedBy, UpdatedBy, MgrApprovedBy, ControllerApprovedBy
         Meeting           CreatedBy, UpdatedBy
         Minutes           CreatedBy, UpdatedBy
         Committee         CreatedBy, UpdatedBy
         Committee_Member  CreatedBy, UpdatedBy
         Meeting_Member    CreatedBy, UpdatedBy
         Member            CreatedBy, UpdatedBy
         Attendance        UpdatedBy
         Action_Item       UpdatedBy
         Alert_Master      CreatedBy              (alerts the user raised)
         Audit_Trail_Master      Update_By
         Audit_Trail_SendMail    Mail_Send_By
         Audit_Trail_SqlBackup   User_Id
         Audit_Trial_Login       User_Id          (the user has logged in)
         Department, Designation, Roles, Alert_Type, Decision_Type,
         Member_Type, Subject_Type                CreatedBy, UpdatedBy
     * otherwise removes the user's Alert_User_Map rows (alerts RECEIVED) and
       ActionItem_User_Map rows (per-user read flags) together with the user,
       in one transaction. These two are created automatically for every user
       of a role, so they do not count as history.
     * on an error rolls back everything it did. A foreign key violation
       (error 547) is reported as Result = 0; any other error is raised to the
       caller after the rollback.

   A user's own row may hold its own id in UpdatedBy (set by a password
   change); that does not block the delete.

   Reused ids: Audit_Trail_SendMail and Audit_Trial_Login still hold ids of
   users deleted years ago, and new users are being given some of those same
   ids. A mail or login row dated BEFORE the user was created cannot be that
   user's, so it does not block. If the user's CreatedOn is empty, every row
   with their id blocks.

   This script only replaces the procedure. It changes no data and adds no
   constraint. Safe to re-run.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Users - a user with history cannot be deleted (FK #5, FK#5-UserDelete-AllColumns)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT
AS
DECLARE @Result INT;
DECLARE @InUse INT;
DECLARE @OwnTransaction INT;
DECLARE @ErrorNumber INT;
DECLARE @ErrorMessage NVARCHAR(2048);
DECLARE @UserCreatedOn DATETIME;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @InUse = 0;
	SET @UserCreatedOn = (SELECT CreatedOn FROM Users WHERE UserId = @UserId);

	-- FK #5 / FK#5-UserDelete-AllColumns: every column that stores a user id
	-- as history. Own row excluded for the three Users columns.
	IF EXISTS (SELECT 1 FROM Users WHERE UserId <> @UserId
	           AND (ManagerId = @UserId OR CreatedBy = @UserId OR UpdatedBy = @UserId))
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Agenda WHERE CreatedBy = @UserId OR UpdatedBy = @UserId
	                OR MgrApprovedBy = @UserId OR ControllerApprovedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Meeting WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Minutes WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Committee WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Committee_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Meeting_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Attendance WHERE UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Action_Item WHERE UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Alert_Master WHERE CreatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @UserId)
		SET @InUse = 1;
	-- Rows older than the user belong to an earlier user with the same id.
	ELSE IF EXISTS (SELECT 1 FROM Audit_Trail_SendMail WHERE Mail_Send_By = @UserId
	                AND (@UserCreatedOn IS NULL OR Mail_Send_On IS NULL OR Mail_Send_On >= @UserCreatedOn))
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Audit_Trail_SqlBackup WHERE [User_Id] = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Audit_Trial_Login WHERE [User_Id] = @UserId
	                AND (@UserCreatedOn IS NULL OR Login_DateTime IS NULL OR Login_DateTime >= @UserCreatedOn))
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Department WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Designation WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Roles WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Alert_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Decision_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Member_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;
	ELSE IF EXISTS (SELECT 1 FROM Subject_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
		SET @InUse = 1;

	IF (@InUse = 0)
	BEGIN
		-- Called by the application there is no open transaction, so this
		-- procedure starts and ends its own. Called inside someone else's
		-- transaction (the test scripts) it only uses a savepoint, so a
		-- failure here never rolls back the caller's work.
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION DeleteUser;

			-- Alerts received and action-item read flags go with the user.
			DELETE FROM Alert_User_Map WHERE UserId = @UserId;

			DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

			DELETE FROM Users WHERE UserId = @UserId;

			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;

			SET @Result = 1;
		END TRY
		BEGIN CATCH
			SET @ErrorNumber = ERROR_NUMBER();
			SET @ErrorMessage = ERROR_MESSAGE();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION DeleteUser;

			SET @Result = 0;

			-- 547 = a foreign key still points at the user: same answer as
			-- "in use". Anything else is a real error and is passed on.
			IF (@ErrorNumber <> 547)
				RAISERROR(@ErrorMessage, 16, 1);
		END CATCH
	END

	SELECT @Result AS Result;
END
GO

IF EXISTS (SELECT 1 FROM sys.sql_modules
           WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')
           AND definition LIKE '%FK#5-UserDelete-AllColumns%')
    PRINT 'spr_DeleteUserByUserId: replaced. Next: BMMS-Add-ForeignKeys-Step5.sql';
GO

SET NOEXEC OFF;
GO
