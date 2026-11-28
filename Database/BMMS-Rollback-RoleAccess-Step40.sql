/* ============================================================================
   BMMS - Roll back step 40 (role access, step RA1a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores the objects as they were before step 40:
     fn_UserChangeRefusal               the step 18 text (SystemAccount3-Step18):
                                        the Controller may again change the
                                        accounts other than Admin and
                                        Controller, and reset their passwords
     spr_AddEditMemberType,             the step 21 texts (MemberTypes-Step21):
     spr_DeleteMemberTypeByMemberTypeId Admin and Controller
   The texts are copied unchanged from BMMS-Fix-SystemAccount-Stage3.sql and
   BMMS-Fix-MemberTypes-Step21.sql.

   Roll back the application build of step RA1a at the same time. The build
   of step RA1a keeps the pages Admin only by itself (menu, PageAccess.xml and
   the page check), so a database rolled back under it lets no Controller in;
   but the two must not be left in different states.

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 40 Missing, and steps 13, 14, 18 and 21 still Installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 40 is not
   installed (nothing to roll back). Plain ASCII.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%RoleAccess-Step40%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') NOT LIKE '%RoleAccess-Step40%'
         AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')), '') NOT LIKE '%RoleAccess-Step40%')
BEGIN
    RAISERROR('Step 40 is not installed in "%s" (no object carries the marker RoleAccess-Step40): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Users - who may change which user account (UserProtection-Stage1, UserStatus-Stage2a: acting user must be active;
-- SystemAccount3-Step18: Reason 7 for the protected system account, Reason 2 counts ordinary Admins only)
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

-- Member type - add / edit; an active Admin or Controller; a reserved type cannot be edited (MemberTypes-Step21)
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
		ELSE IF (@ActingRole NOT IN ('admin', 'controller'))
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
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MemberTypeSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- 5. Member_Type - referenced by Committee_Member and Meeting_Member
-- Delete: an active Admin or Controller; not a reserved type, not a type in use (MemberTypes-Step21)
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMemberTypeByMemberTypeId]
@MemberTypeId INT,
@ActingUserId INT = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
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
		ELSE IF (@ActingRole NOT IN ('admin', 'controller'))
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
		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MemberTypeDelete;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

DECLARE @Left INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') LIKE '%RoleAccess-Step40%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMemberType')), '') LIKE '%RoleAccess-Step40%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId')), '') LIKE '%RoleAccess-Step40%')
    SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 40 rolled back: fn_UserChangeRefusal of step 18 and the member type procedures of step 21 are back.';
ELSE
    RAISERROR('Step 40 is not fully rolled back: %d objects still carry RoleAccess-Step40. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
