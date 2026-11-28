/* ============================================================================
   BMMS - Role access: user accounts and member types for Admin only
   (step 40, step RA1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Owner decision RA1 (2026-11-10): User Master, Reset Password, Backup
   Database, Audit Trail and the code masters (Department, Designation,
   Member Type, Subject Type, Decision Type) are Admin tasks. The Controller
   keeps the committee and meeting masters (Member, Committee, Committee
   Member, Meeting, Meeting Member, Attendance). The application build of
   step RA1a hides the pages from the Controller and refuses them by address;
   this script makes the database refuse the same changes.

   Rules
     fn_UserChangeRefusal          the Controller has the rule of every role
                                   other than Admin: only its own Edit and
                                   ResetPassword (Change Password). Creating,
                                   editing, giving a role, deactivating,
                                   activating, deleting and resetting the
                                   password of another account is refused
                                   with Reason 4 for the Controller as for a
                                   User or a Manager. Admin unchanged; rules
                                   7 (system account), 1 (own account) and 2
                                   and 3 (last active Admin / Controller)
                                   unchanged. Every caller follows it:
                                   spr_AddEditUser, spr_CheckUserChange,
                                   spr_DeleteUserByUserId,
                                   spr_GetUserListForUserPage,
                                   spr_ResetPasswordByUserId and
                                   spr_SetUserStatusByUserId.
     spr_AddEditMemberType,        an active Admin only; the Controller is
     spr_DeleteMemberTypeByMember- refused with Reason 4 like the other
     TypeId                        roles. A database error is re-raised with
                                   RAISERROR instead of THROW (compatibility
                                   level 100 rule); nothing else changes.
   Parameters and result sets are unchanged, so the build before step RA1a
   keeps working (its Controller then sees the refusal message of Reason 4).

   Objects
     fn_UserChangeRefusal               REPLACED (text of step 18; the markers
                                        of steps 13, 14 and 18 are kept)
     spr_AddEditMemberType              REPLACED (text of step 21; marker
     spr_DeleteMemberTypeByMemberTypeId kept)
   Marker RoleAccess-Step40 in each. Re-running step 13, 14, 18 or 21
   afterwards brings back an older text: BMMS-Check-InstalledSteps.sql then
   shows step 40 Partly or Missing; run step 40 again.

   Installed after step 39 (it stops if step 39 is not installed). Changes no
   data. Safe to re-run. BMMS-Rollback-RoleAccess-Step40.sql restores the
   texts of steps 18 and 21.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%MemberTypes-Step21%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')), '') NOT LIKE '%MemberTypes-Step21%')
BEGIN
    RAISERROR('fn_UserChangeRefusal does not have the text of step 18 (marker SystemAccount3-Step18), or spr_AddEditMemberType or spr_DeleteMemberTypeByMemberTypeId does not have the text of step 21 (marker MemberTypes-Step21), in "%s". Run those steps first (BMMS-Check-InstalledSteps.sql shows which steps are installed), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')), '') NOT LIKE '%UserHistory-Step39%')
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". The steps are installed in order: run step 39 first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Users - who may change which user account (UserProtection-Stage1, UserStatus-Stage2a: acting user must be active;
-- SystemAccount3-Step18: Reason 7 for the protected system account, Reason 2 counts ordinary Admins only;
-- RoleAccess-Step40: only an Admin changes other accounts; the Controller has the rule of the other roles)
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
	DECLARE @TargetSystem INT;
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

	SELECT @TargetRole = r.RoleCode, @TargetActive = ISNULL(u.AccountStatus, 0), @TargetSystem = ISNULL(CAST(u.IsSystem AS INT), 0)
	FROM Users u LEFT JOIN Roles r ON r.RoleId = u.RoleId
	WHERE u.UserId = @TargetUserId;

	SET @NewRole = (SELECT RoleCode FROM Roles WHERE RoleId = @NewRoleId);

	-- 7. protected system account (stage 3): nobody edits, deletes, deactivates it or changes
	--    its role; only the account itself may change its password
	IF (@TargetSystem = 1
	    AND (@Action IN ('Edit', 'Delete', 'Deactivate', 'RoleChange')
	         OR (@Action = 'ResetPassword' AND ISNULL(@ActingUserId, -1) <> @TargetUserId)))
		RETURN 7;

	-- 1. own account
	IF (@ActingUserId = @TargetUserId AND @Action IN ('Delete', 'Deactivate', 'RoleChange'))
		RETURN 1;

	-- 3. what the acting user's role may do: an Admin anything (rules 7, 1 and 2 still apply);
	--    every other role, the Controller included since RoleAccess-Step40 (step RA1a), only its
	--    own Edit and ResetPassword
	IF (@ActingRole IS NOT NULL AND @ActingRole <> 'admin')
	BEGIN
		IF NOT (@TargetUserId = @ActingUserId AND @Action IN ('Edit', 'ResetPassword'))
			RETURN 4;
	END

	-- 2. last active Admin / Controller (the system account does not count as an Admin here)
	IF (@Action IN ('Delete', 'Deactivate', 'RoleChange') AND @TargetActive = 1)
	BEGIN
		IF (@TargetRole = 'admin'
		    AND NOT EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                    WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 AND u.IsSystem = 0 AND u.UserId <> @TargetUserId))
			RETURN 2;

		IF (@TargetRole = 'controller'
		    AND NOT EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                    WHERE r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.UserId <> @TargetUserId))
			RETURN 3;
	END

	RETURN 0;
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

-- 5. Member_Type - referenced by Committee_Member and Meeting_Member
-- Delete: an active Admin; not a reserved type, not a type in use (MemberTypes-Step21;
-- RoleAccess-Step40: Admin only since step RA1a, the error re-raised with RAISERROR)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMemberTypeByMemberTypeId]
@MemberTypeId INT,
@ActingUserId INT = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Reserved BIT;
DECLARE @CmCount INT;
DECLARE @MmCount INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MemberTypeDelete;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE
		BEGIN
			SET @Reserved = (SELECT IsReserved FROM Member_Type WITH (UPDLOCK, HOLDLOCK) WHERE MemberTypeId = @MemberTypeId);

			IF (@Reserved IS NULL)
			BEGIN
				SET @Reason = 3;
				SET @Detail = 'NotFound';
			END
			ELSE IF (@Reserved = 1)
				SET @Reason = 7;
			ELSE
			BEGIN
				SET @CmCount = (SELECT COUNT(*) FROM Committee_Member WITH (HOLDLOCK) WHERE MemberTypeId = @MemberTypeId);
				SET @MmCount = (SELECT COUNT(*) FROM Meeting_Member WITH (HOLDLOCK) WHERE MemberTypeId = @MemberTypeId);

				IF (@CmCount + @MmCount > 0)
				BEGIN
					SET @Reason = 5;
					SET @Detail = CAST(@CmCount AS VARCHAR(12)) + ' committee, ' + CAST(@MmCount AS VARCHAR(12)) + ' meeting';
				END
				ELSE
				BEGIN
					DELETE FROM Member_Type WHERE MemberTypeId = @MemberTypeId AND IsReserved = 0;
					SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;
				END
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
			ROLLBACK TRANSACTION MemberTypeDelete;

		RAISERROR('%s', 16, 1, @ErrMsg);
		RETURN;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

DECLARE @Installed INT = 0;
DECLARE @Kept INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') LIKE '%RoleAccess-Step40%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%RoleAccess-Step40%')
    SET @Installed = @Installed + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')), '') LIKE '%RoleAccess-Step40%')
    SET @Installed = @Installed + 1;

-- the older markers that BMMS-Check-InstalledSteps.sql reads for steps 13, 14, 18 and 21
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') LIKE '%UserProtection-Stage1%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') LIKE '%UserStatus-Stage2a%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') LIKE '%SystemAccount3-Step18%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%MemberTypes-Step21%')
    SET @Kept = @Kept + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')), '') LIKE '%MemberTypes-Step21%')
    SET @Kept = @Kept + 1;

IF (@Installed = 3 AND @Kept = 5)
    PRINT 'Step 40 installed: fn_UserChangeRefusal, spr_AddEditMemberType and spr_DeleteMemberTypeByMemberTypeId (RoleAccess-Step40); the markers of steps 13, 14, 18 and 21 kept.';
ELSE
    RAISERROR('Step 40 is not complete: %d of 3 objects carry the marker RoleAccess-Step40, %d of 5 older markers kept. Read the messages above and run the script again.', 16, 1, @Installed, @Kept);
GO

SET NOEXEC OFF;
GO
