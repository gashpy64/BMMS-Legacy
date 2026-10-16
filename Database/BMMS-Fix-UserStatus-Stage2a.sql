/* ============================================================================
   BMMS - User status, stage 2a (inactive users)
   ----------------------------------------------------------------------------
   An inactive user (Users.AccountStatus = 0) cannot log in, is logged out on
   the next page request, cannot act through the user procedures, and is left
   out of the pick lists below. The user and all their history are kept.

   What this script does:
     Users.AccountStatus      NOT NULL, DEFAULT 1 (DF_Users_AccountStatus),
                              CHECK IN (0, 1) (CK_Users_AccountStatus).
                              The script stops, changing nothing, if any row
                              is NULL or holds another value.
     fn_UserChangeRefusal     Reason 8 now also when the acting user is NOT
                              ACTIVE (before: only when missing). Otherwise the
                              same as stage 1. NULL acting user is still only
                              for testing the function itself.
     spr_GetUserStatusByUserId     NEW, AccountStatus of one user (no row if
                                   the user does not exist). The application
                                   calls it on every page request.
     spr_GetActiveUserList         NEW, the rows of spr_GetUser for active
                                   users only (same admin-name filter). For
                                   the Committee / Meeting mail Bcc and the
                                   Agenda manager mail. spr_GetUser itself is
                                   unchanged (Audit Trail, Reset Password).
     spr_GetMgrControllerByDeptId  active Managers / Controllers only, plus
                                   @IncludeUserId (the edited user's current
                                   manager) even if inactive. New column
                                   ManagerText = LoginName, + ' (inactive)'.
     spr_GetUserListForUserPage    + Status ('Active' / 'Inactive'),
                                   CanDeactivate, CanActivate and
                                   ManagedCount (ACTIVE users who have this
                                   user as manager).
     spr_LockUserByUserId          retired: raises error 50002 and changes
                                   nothing. Use spr_SetUserStatusByUserId,
                                   which applies the stage 1 rules.

   Not changed here: the alert / action-item / mail procedures (stage 2b),
   spr_SetUserStatusByUserId, spr_DeleteUserByUserId, spr_AddEditUser,
   spr_GetUser and spr_sys_ResetDatabase (its seed users are inserted with
   AccountStatus = 1).

   Needs BMMS-Fix-UserProtection-Stage1.sql (step 13) first; it stops
   otherwise. If step 13 is ever re-run, run this script again afterwards:
   step 13 contains the older fn_UserChangeRefusal.

   Run it BEFORE deploying the build that calls spr_GetUserStatusByUserId.

   Safe to re-run. It has no USE line: select the database in SSMS first (the
   test copy, then BMMS). It stops if the current database name does not
   start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @BadRows NVARCHAR(2000);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_UserChangeRefusal') IS NULL
         OR OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteUserByUserId')) NOT LIKE '%UserProtection-Stage1%')
BEGIN
    RAISERROR('User protection stage 1 is not installed in "%s". Run BMMS-Fix-UserProtection-Stage1.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF EXISTS (SELECT 1 FROM Users WHERE AccountStatus IS NULL OR AccountStatus NOT IN (0, 1))
BEGIN
    SELECT @BadRows = STUFF((SELECT TOP 20 ', ' + CAST(UserId AS VARCHAR(12)) + '=' + ISNULL(CAST(AccountStatus AS VARCHAR(12)), 'NULL')
                             FROM Users WHERE AccountStatus IS NULL OR AccountStatus NOT IN (0, 1)
                             ORDER BY UserId FOR XML PATH('')), 1, 2, '');
    RAISERROR('Users.AccountStatus must be 0 or 1 in every row. Fix these rows (UserId=AccountStatus) and run again: %s. Nothing was changed.', 16, 1, @BadRows);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Users.AccountStatus: default 1, NOT NULL, only 0 or 1 (UserStatus-Stage2a)
IF NOT EXISTS (SELECT 1 FROM sys.columns c
               JOIN sys.default_constraints d ON d.object_id = c.default_object_id
               WHERE c.object_id = OBJECT_ID('dbo.Users') AND c.name = 'AccountStatus')
    ALTER TABLE dbo.Users ADD CONSTRAINT DF_Users_AccountStatus DEFAULT (1) FOR AccountStatus;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'AccountStatus' AND is_nullable = 1)
    ALTER TABLE dbo.Users ALTER COLUMN AccountStatus INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_AccountStatus')
    ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT CK_Users_AccountStatus CHECK (AccountStatus IN (0, 1));
GO

-- Users - who may change which user account (UserProtection-Stage1, UserStatus-Stage2a: acting user must be active)
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
		-- missing or inactive acting user (stage 2a)
		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

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

-- Users - status of one user, read on every page request (UserStatus-Stage2a)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetUserStatusByUserId]
@UserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT AccountStatus FROM Users WHERE UserId = @UserId;
END
GO

-- Users - active users only, same rows and columns as spr_GetUser otherwise (UserStatus-Stage2a)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetActiveUserList]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	*
	FROM View_Users
	WHERE
	UserName NOT LIKE 'admin'
	AND AccountStatus = 1;
END
GO

-- Users - Manager pick list: active Managers / Controllers of the department,
-- plus the edited user's current manager even if inactive (UserStatus-Stage2a)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMgrControllerByDeptId]
@DepartmentId INT,
@IncludeUserId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	v.*,
	v.LoginName + CASE WHEN v.AccountStatus = 1 THEN '' ELSE ' (inactive)' END AS ManagerText
	FROM View_Users v
	WHERE
	(v.DepartmentId = @DepartmentId
	 AND (v.RoleId = 2 OR v.RoleId = 3)
	 AND v.AccountStatus = 1)
	OR v.UserId = @IncludeUserId;
END
GO

-- Users - list for the User page, with what the acting user may do per row (UserProtection-Stage1, UserStatus-Stage2a)
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
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'Delete', NULL) = 0 THEN 1 ELSE 0 END AS CanDelete,
	CASE WHEN v.AccountStatus = 1 THEN 'Active' ELSE 'Inactive' END AS Status,
	CASE WHEN ISNULL(@ActingUserId, 0) <> 0 AND v.AccountStatus = 1
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'Deactivate', NULL) = 0 THEN 1 ELSE 0 END AS CanDeactivate,
	CASE WHEN ISNULL(@ActingUserId, 0) <> 0 AND v.AccountStatus = 0
	      AND dbo.fn_UserChangeRefusal(@ActingUserId, v.UserId, 'Activate', NULL) = 0 THEN 1 ELSE 0 END AS CanActivate,
	(SELECT COUNT(*) FROM Users m WHERE m.ManagerId = v.UserId AND m.AccountStatus = 1) AS ManagedCount
	FROM View_Users v
	WHERE
	v.UserName NOT LIKE 'admin';
END
GO

-- Users - lock: retired (UserStatus-Stage2a). It bypassed the stage 1 rules.
CREATE OR ALTER PROCEDURE [dbo].[spr_LockUserByUserId]
@UserId INT
AS
BEGIN
	SET NOCOUNT ON;

	THROW 50002, 'spr_LockUserByUserId is retired. Use spr_SetUserStatusByUserId (it applies the user protection rules).', 1;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE parent_object_id = OBJECT_ID('dbo.Users') AND name = 'CK_Users_AccountStatus')
   AND EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'AccountStatus' AND is_nullable = 0)
   AND OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')) LIKE '%UserStatus-Stage2a%'
    PRINT 'User status stage 2a installed: AccountStatus NOT NULL / DEFAULT 1 / CHECK, fn_UserChangeRefusal and 5 procedures.';
GO

SET NOEXEC OFF;
GO
