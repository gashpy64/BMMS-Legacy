/* ============================================================================
   BMMS - User account protection, stage 1
   ----------------------------------------------------------------------------
   Who may change which user account, enforced in the database.

   Rules (dbo.fn_UserChangeRefusal, used by every procedure below):
     1. Nobody can delete, deactivate or change the role of their own account.
        Editing your own details and changing your own password is allowed.
     2. The last ACTIVE Admin and the last ACTIVE Controller cannot be
        deleted, deactivated or given another role. Their details can be
        edited.
     3. An Admin may change any user (subject to 1 and 2).
        A Controller may change any user EXCEPT Admin and Controller users
        (their own account excepted for details and password), and may not
        create a user as Admin or Controller nor give anyone those roles.
        Any other role may change only its own details and password.
   Actions: Create, Edit, RoleChange, ResetPassword, Delete, Deactivate,
   Activate.

   Every protected procedure returns ONE row:
     Result        1 = done, 0 = refused (unchanged meaning for the pages)
     Reason        0 done
                   1 own account
                   2 last active Admin
                   3 last active Controller
                   4 not allowed for the acting user's role
                   5 delete: other users have this user as manager or were
                     created / last updated by them (ReasonDetail = names)
                   6 delete: the user has history (ReasonDetail = groups)
                   7 (reserved: protected system account, stage 3)
                   8 acting user missing (NULL, 0 or not a user)
                   9 delete: refused by a database reference the checks do
                     not know (ReasonDetail = the SQL Server message; the
                     page logs it and shows a plain sentence instead)
     ReasonDetail  text for reasons 5, 6 and 9, otherwise ''

   Procedures
     fn_UserChangeRefusal       the rules; returns a Reason (0 = allowed).
                                A NULL acting user skips rules 1 and 3; this
                                is only for testing the function itself, the
                                procedures refuse NULL / 0 with Reason 8.
     spr_CheckUserChange        Result / Reason for a planned change (the
                                Reset Password page checks before resetting).
     spr_DeleteUserByUserId     + @ActingUserId; rules, then the reference
                                checks, then the delete. Error 547 -> Reason
                                9; any other error is re-raised (THROW), never
                                reported as "in use".
     spr_AddEditUser            Save checks Create (acting user = @CreatedBy);
                                Update checks Edit and, when the role really
                                changes, RoleChange (acting user = @UpdatedBy).
                                Signature unchanged.
     spr_ResetPasswordByUserId  checks ResetPassword (acting user =
                                @UpdatedBy). Signature unchanged.
     spr_SetUserStatusByUserId  NEW, deactivate / activate. Stage 1: SQL only,
                                no page calls it.
     spr_GetUserListForUserPage NEW, the rows of spr_GetUser plus CanEdit,
                                CanChangeRole and CanDelete for the acting
                                user (rules only; history is not checked).

   Rule 2 under concurrency: delete, deactivate and role change count the
   active Admins and Controllers with UPDLOCK, HOLDLOCK inside the same
   transaction as the change, so two simultaneous changes are serialised
   and the second one sees the first.

   Optional OUTPUT parameters (@OutResult, @OutReason, @OutReasonDetail) give
   the same values to SQL callers that cannot capture the result row.

   Replaces the spr_DeleteUserByUserId of BMMS-Fix-UserDelete-Procedure.sql
   (step 10). If step 10 (or step 2 or 6) is ever re-run, run this script
   again afterwards.

   This script only replaces / adds a function and procedures. It changes no
   data and adds no constraint. Safe to re-run.

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

-- UserProtection-Stage1: the rules
CREATE OR ALTER FUNCTION [dbo].[fn_UserChangeRefusal]
(
@ActingUserId INT,
@TargetUserId INT,
@Action VARCHAR(20),
@NewRoleId INT
)
RETURNS INT
AS
BEGIN
	DECLARE @ActingRole VARCHAR(50);
	DECLARE @TargetRole VARCHAR(50);
	DECLARE @TargetActive INT;
	DECLARE @NewRole VARCHAR(50);

	IF (@ActingUserId = 0)
		RETURN 8;

	IF (@ActingUserId IS NOT NULL)
	BEGIN
		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId);

		IF (@ActingRole IS NULL)
			RETURN 8;
	END

	SELECT @TargetRole = r.RoleCode, @TargetActive = ISNULL(u.AccountStatus, 0)
	FROM Users u LEFT JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @TargetUserId;

	SET @NewRole = (SELECT RoleCode FROM Roles WHERE RoleId = @NewRoleId);

	-- 1. own account
	IF (@ActingUserId = @TargetUserId AND @Action IN ('Delete', 'Deactivate', 'RoleChange'))
		RETURN 1;

	-- 3. what the acting user's role may do
	IF (@ActingRole = 'controller')
	BEGIN
		IF (@Action IN ('Create', 'RoleChange') AND @NewRole IN ('admin', 'controller'))
			RETURN 4;

		IF (@Action <> 'Create' AND @TargetUserId <> @ActingUserId AND @TargetRole IN ('admin', 'controller'))
			RETURN 4;
	END
	ELSE IF (@ActingRole IS NOT NULL AND @ActingRole <> 'admin')
	BEGIN
		IF NOT (@TargetUserId = @ActingUserId AND @Action IN ('Edit', 'ResetPassword'))
			RETURN 4;
	END

	-- 2. last active Admin / Controller
	IF (@Action IN ('Delete', 'Deactivate', 'RoleChange') AND @TargetActive = 1)
	BEGIN
		IF (@TargetRole = 'admin'
		    AND NOT EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                    WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 AND u.UserId <> @TargetUserId))
			RETURN 2;

		IF (@TargetRole = 'controller'
		    AND NOT EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                    WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.UserId <> @TargetUserId))
			RETURN 3;
	END

	RETURN 0;
END
GO

-- UserProtection-Stage1: check a planned change without making it
CREATE OR ALTER PROCEDURE [dbo].[spr_CheckUserChange]
@ActingUserId INT,
@TargetUserId INT,
@Action VARCHAR(20),
@NewRoleId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Reason INT;

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
		SET @Reason = 8;
	ELSE
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @TargetUserId, @Action, @NewRoleId);

	SELECT CASE WHEN @Reason = 0 THEN 1 ELSE 0 END AS Result, @Reason AS Reason, CAST('' AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteUserByUserId]
@UserId INT,
@ActingUserId INT = NULL,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT,
@OutReasonDetail NVARCHAR(2000) = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @UserCreatedOn DATETIME;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		-- Called by the application there is no open transaction, so this
		-- procedure starts and ends its own. Called inside someone else's
		-- transaction (the test scripts) it only uses a savepoint.
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION DeleteUser;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Delete', NULL);

			-- 5. other users point at this user
			IF (@Reason = 0)
			BEGIN
				SET @Detail = ISNULL(STUFF((SELECT N', ' + u.UserName
				                            FROM Users u
				                            WHERE u.UserId <> @UserId
				                            AND (u.ManagerId = @UserId OR u.CreatedBy = @UserId OR u.UpdatedBy = @UserId)
				                            ORDER BY u.UserName
				                            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

				IF (@Detail <> N'')
					SET @Reason = 5;
			END

			-- 6. history, every group that applies
			IF (@Reason = 0)
			BEGIN
				SET @UserCreatedOn = (SELECT CreatedOn FROM Users WHERE UserId = @UserId);

				IF EXISTS (SELECT 1 FROM Agenda WHERE CreatedBy = @UserId OR UpdatedBy = @UserId
				           OR MgrApprovedBy = @UserId OR ControllerApprovedBy = @UserId)
					SET @Detail = @Detail + N', agendas/approvals';
				IF EXISTS (SELECT 1 FROM Meeting WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Meeting_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', meetings';
				IF EXISTS (SELECT 1 FROM Minutes WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Action_Item WHERE UpdatedBy = @UserId)
					SET @Detail = @Detail + N', minutes';
				IF EXISTS (SELECT 1 FROM Committee WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Committee_Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', committees/members';
				IF EXISTS (SELECT 1 FROM Attendance WHERE UpdatedBy = @UserId)
					SET @Detail = @Detail + N', attendance';
				IF EXISTS (SELECT 1 FROM Alert_Master WHERE CreatedBy = @UserId)
					SET @Detail = @Detail + N', alerts sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_Master WHERE Update_By = @UserId)
					SET @Detail = @Detail + N', audit trail';
				-- Rows older than the user belong to an earlier user with the same id.
				IF EXISTS (SELECT 1 FROM Audit_Trail_SendMail WHERE Mail_Send_By = @UserId
				           AND (@UserCreatedOn IS NULL OR Mail_Send_On IS NULL OR Mail_Send_On >= @UserCreatedOn))
					SET @Detail = @Detail + N', mail sent';
				IF EXISTS (SELECT 1 FROM Audit_Trail_SqlBackup WHERE [User_Id] = @UserId)
					SET @Detail = @Detail + N', backups';
				IF EXISTS (SELECT 1 FROM Audit_Trial_Login WHERE [User_Id] = @UserId
				           AND (@UserCreatedOn IS NULL OR Login_DateTime IS NULL OR Login_DateTime >= @UserCreatedOn))
					SET @Detail = @Detail + N', login history';
				IF EXISTS (SELECT 1 FROM Department WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Designation WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Roles WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Alert_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Decision_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Member_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
				   OR EXISTS (SELECT 1 FROM Subject_Type WHERE CreatedBy = @UserId OR UpdatedBy = @UserId)
					SET @Detail = @Detail + N', master data';

				IF (@Detail <> N'')
				BEGIN
					SET @Detail = STUFF(@Detail, 1, 2, N'');
					SET @Reason = 6;
				END
			END

			IF (@Reason = 0)
			BEGIN
				-- Alerts received and action-item read flags go with the user.
				DELETE FROM Alert_User_Map WHERE UserId = @UserId;

				DELETE FROM ActionItem_User_Map WHERE UserId = @UserId;

				DELETE FROM Users WHERE UserId = @UserId;

				SET @Result = 1;
			END

			-- A refusal changed nothing, so there is nothing to roll back.
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
				ROLLBACK TRANSACTION DeleteUser;

			-- 547 = a foreign key the checks above do not know still points at
			-- the user. Anything else is a real error and is passed on.
			IF (ERROR_NUMBER() <> 547)
				THROW;

			SET @Result = 0;
			SET @Reason = 9;
			SET @Detail = LEFT(ERROR_MESSAGE(), 2000);
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;
	SET @OutReasonDetail = @Detail;

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-- Users - add / edit (UserProtection-Stage1)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditUser]
@Code VARCHAR(50),
@UserId INT,
@UserName VARCHAR(50),
@DepartmentId INT,
@DesignationId INT,
@ManagerId INT,
@RoleId INT,
@EmailId VARCHAR(50),
@LoginName VARCHAR(50),
@Password VARCHAR(MAX),
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @ActingUserId INT;
DECLARE @OldRoleId INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @ActingUserId = CASE WHEN @Code = 'Save' THEN @CreatedBy ELSE @UpdatedBy END;

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE IF (@Code = 'Save')
	BEGIN
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, NULL, 'Create', @RoleId);

		IF (@Reason = 0)
		BEGIN
			INSERT INTO Users
			(UserName, DepartmentId, DesignationId, ManagerId,
				RoleId, EmailId, LoginName, Password, AccountStatus, CreatedOn, CreatedBy)
			VALUES
			(@UserName, @DepartmentId, @DesignationId, @ManagerId,
				@RoleId, @EmailId, @LoginName, @Password, 1, @CreatedOn, @CreatedBy);

			SET @Result = 1;
		END
	END
	ELSE IF (@Code = 'Update')
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION EditUser;

			SET @OldRoleId = (SELECT RoleId FROM Users WHERE UserId = @UserId);

			-- Rule 2 under concurrency (only a role change can break it here)
			IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
				WHERE AccountStatus = 1
				AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Edit', NULL);

			IF (@Reason = 0 AND ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'RoleChange', @RoleId);

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				UserName = @UserName,
				DepartmentId = @DepartmentId,
				DesignationId = @DesignationId,
				ManagerId = @ManagerId,
				RoleId = @RoleId,
				EmailId = @EmailId,
				LoginName = @LoginName,
				UpdatedOn = @UpdatedOn,
				UpdatedBy = @UpdatedBy
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
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
				ROLLBACK TRANSACTION EditUser;

			THROW;
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST('' AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Users - reset / change password (UserProtection-Stage1)
CREATE OR ALTER PROCEDURE [dbo].[spr_ResetPasswordByUserId]
@UserId INT,
@Password VARCHAR(MAX),
@UpdatedBy INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;

	IF (@UpdatedBy IS NULL OR @UpdatedBy = 0)
		SET @Reason = 8;
	ELSE
		SET @Reason = dbo.fn_UserChangeRefusal(@UpdatedBy, @UserId, 'ResetPassword', NULL);

	IF (@Reason = 0)
	BEGIN
		UPDATE Users SET
		Password = @Password,
		UpdatedOn = GETDATE(),
		UpdatedBy = @UpdatedBy
		WHERE
		UserId = @UserId;

		SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST('' AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Users - deactivate / activate (UserProtection-Stage1; no page calls it until stage 2)
CREATE OR ALTER PROCEDURE [dbo].[spr_SetUserStatusByUserId]
@UserId INT,
@AccountStatus INT,
@ActingUserId INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;

	IF (@AccountStatus IS NULL OR @AccountStatus NOT IN (0, 1))
		THROW 50001, 'spr_SetUserStatusByUserId: @AccountStatus must be 0 (inactive) or 1 (active).', 1;

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
	END
	ELSE
	BEGIN
		IF (@@TRANCOUNT = 0)
			SET @OwnTransaction = 1;
		ELSE
			SET @OwnTransaction = 0;

		BEGIN TRY
			IF (@OwnTransaction = 1)
				BEGIN TRANSACTION;
			ELSE
				SAVE TRANSACTION SetUserStatus;

			-- Rule 2 under concurrency: hold the active Admin / Controller rows
			-- until this transaction ends.
			SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
			WHERE AccountStatus = 1
			AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId,
			                  CASE WHEN @AccountStatus = 0 THEN 'Deactivate' ELSE 'Activate' END, NULL);

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				AccountStatus = @AccountStatus,
				UpdatedOn = GETDATE(),
				UpdatedBy = @ActingUserId
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
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
				ROLLBACK TRANSACTION SetUserStatus;

			THROW;
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST('' AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Users - list for the User page, with what the acting user may do per row (UserProtection-Stage1)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetUserListForUserPage]
@ActingUserId INT
AS
BEGIN
	SET NOCOUNT ON;

	-- Same rows as spr_GetUser. Rules only: history is checked on delete.
	SELECT
	v.*,
	CASE WHEN ISNULL(@ActingUserId, 0) <> 0
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'Edit', NULL) = 0 THEN 1 ELSE 0 END AS CanEdit,
	CASE WHEN ISNULL(@ActingUserId, 0) <> 0
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'RoleChange', NULL) = 0 THEN 1 ELSE 0 END AS CanChangeRole,
	CASE WHEN ISNULL(@ActingUserId, 0) <> 0
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'Delete', NULL) = 0 THEN 1 ELSE 0 END AS CanDelete
	FROM View_Users v
	WHERE
	v.UserName NOT LIKE 'admin';
END
GO

IF EXISTS (SELECT 1 FROM sys.sql_modules
           WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')
           AND definition LIKE '%UserProtection-Stage1%')
    PRINT 'User protection stage 1 installed: fn_UserChangeRefusal and 6 procedures.';
GO

SET NOEXEC OFF;
GO
