/* ============================================================================
   BMMS - Roll back step 39 (role and department history, step UD1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores the procedures as they were before step 39:
     spr_AddEditUser, spr_SetUserStatusByUserId,
     spr_DeleteUserByUserId          the step 13 texts (UserProtection-Stage1)
     spr_DeleteDepartmentByDeptId    the step 2 text (Result only)
     spr_sys_ResetDatabase           the step 30 text (SmtpDefault-Step30)
   and drops fn_ManagerReleaseRefusal, spr_GetUserDepartmentMap and
   spr_SetDepartmentManagerRule.

   KEPT (Consultant, 2026-11-09): the tables User_Role and User_Department
   with all their rows, and the App_Setting row DeptNoManagerAction. No
   history is lost. Running BMMS-Fix-UserHistory-Step39.sql again re-syncs the
   rows with Users and prints the counts.

   While step 39 is rolled back and the history rows exist:
     - nothing writes the tables: a change made meanwhile is caught up by the
       re-sync when step 39 is installed again (dated that day);
     - deleting a user who has history rows is refused by the foreign keys of
       the two tables: User Master says "other data still refers to them"
       (Reason 9, written to the error log);
     - Reset Database fails with the same foreign key error and, as since step
       29, changes nothing. Install step 39 again before a reset.
   Roll back the application build of step UD1a too: it works without step
   39 (the departments list is hidden), but the database must not be left
   half way.

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 39 Missing (the tables and the setting row stay).

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Plain ASCII.

   QUOTED_IDENTIFIER and ANSI_NULLS are set ON (as the older scripts were
   installed). From the command line use sqlcmd -I.
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
ELSE IF (OBJECT_ID('dbo.spr_sys_SetSmtpDefault', 'P') IS NULL OR COL_LENGTH('dbo.Users', 'IsSystem') IS NULL)
BEGIN
    RAISERROR('Steps 18 and 30 are not installed in "%s"; this is not a database that step 39 was installed on. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
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

-- 3. Department - referenced by Agenda and Users
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteDepartmentByDeptId]
@DeptId INT
AS
DECLARE @Result INT;
DECLARE @CountRec INT;
BEGIN
	SET @Result = 0;

	SET @CountRec = (SELECT COUNT(*) FROM Agenda WHERE DepartmentId = @DeptId);

	IF (@CountRec <= 0)
	BEGIN
		SET @CountRec = (SELECT COUNT(*) FROM Users WHERE DepartmentId = @DeptId);

		IF (@CountRec <= 0)
		BEGIN
			SET @Result = 1;
		END
	END

	IF (@Result = 1)
	BEGIN
		DELETE FROM Department WHERE DepartmentId = @DeptId;
	END

	SELECT @Result AS Result;
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

IF (OBJECT_ID('dbo.spr_SetDepartmentManagerRule', 'P') IS NOT NULL)
    DROP PROCEDURE dbo.spr_SetDepartmentManagerRule;
IF (OBJECT_ID('dbo.spr_GetUserDepartmentMap', 'P') IS NOT NULL)
    DROP PROCEDURE dbo.spr_GetUserDepartmentMap;
IF (OBJECT_ID('dbo.fn_ManagerReleaseRefusal') IS NOT NULL)
    DROP FUNCTION dbo.fn_ManagerReleaseRefusal;
GO

DECLARE @Left INT = (SELECT COUNT(*) FROM (VALUES ('fn_ManagerReleaseRefusal'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId'),
                                                  ('spr_DeleteUserByUserId'), ('spr_DeleteDepartmentByDeptId'), ('spr_sys_ResetDatabase'),
                                                  ('spr_GetUserDepartmentMap'), ('spr_SetDepartmentManagerRule')) o(Name)
                     WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UserHistory-Step39%');
DECLARE @RoleRows INT = 0;
DECLARE @DeptRows INT = 0;
DECLARE @Text VARCHAR(400);

IF (OBJECT_ID('dbo.User_Role', 'U') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.User_Role', N'@n INT OUTPUT', @n = @RoleRows OUTPUT;
IF (OBJECT_ID('dbo.User_Department', 'U') IS NOT NULL)
    EXEC sp_executesql N'SELECT @n = COUNT(*) FROM dbo.User_Department', N'@n INT OUTPUT', @n = @DeptRows OUTPUT;

IF (@Left = 0)
BEGIN
    SET @Text = 'Step 39 rolled back: the procedures of steps 2, 13 and 30 are back; kept: User_Role (' + CAST(@RoleRows AS VARCHAR(12))
              + ' rows), User_Department (' + CAST(@DeptRows AS VARCHAR(12)) + ' rows) and the setting DeptNoManagerAction.';
    PRINT @Text;
END
ELSE
BEGIN
    SET @Text = CAST(@Left AS VARCHAR(2)) + ' objects still carry UserHistory-Step39.';
    RAISERROR('Step 39 is not fully rolled back: %s Read the messages above and run the script again.', 16, 1, @Text);
END
GO

SET NOEXEC OFF;
GO
