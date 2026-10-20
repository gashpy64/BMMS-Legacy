/* ============================================================================
   BMMS - Member Type Master: scope, display order and reserved types (step 21)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Each company keeps its own member types (for example Director, Member,
   Independent Director) on the Member Type Master (Admin and Controller).
   A member type is either a committee role (tagged on Committee Member) or a
   meeting role (tagged on Meeting Member); the two tagging pages offer only
   the active types of their own scope.

   Table Member_Type, new columns (MemberTypes-Step21)
     IsReserved   bit NOT NULL DEFAULT 0   1 = used by the application by id;
                                           cannot be edited, deactivated or
                                           deleted
     MemberScope  char(1) NOT NULL DEFAULT 'C'   C committee, M meeting
     DisplayOrder (existing column) shown on the master; orders the drop-downs
                  and the minutes PRESENT list
   Constraints CK_Member_Type_MemberScope (C or M), CK_Member_Type_Reserved
   (a reserved type is active), unique indexes UX_Member_Type_Code and
   UX_Member_Type_Name.

   Reserved types (by id, where the row exists):
     2 Invitee           meeting   minutes "ON INVITATION" (Report/Reports.aspx.cs)
     3 In Attendance     meeting   spr_GetCompanySecretary: the signer of notices,
                                   minutes and follow-up letters
     6 Special Invitee   meeting   minutes (Report/Reports.aspx.cs)
   Type 2 exists only on a database that was reset after the original
   install; it is not re-created where it is missing.

   Data set on every run (changes nothing that is already right):
     * ids 2, 3, 6: IsReserved 1, MemberScope M, active
     * a type used only on Meeting Member: MemberScope M; used only on
       Committee Member: MemberScope C (a type in use cannot change scope,
       so this only repairs rows; an unused type keeps the scope it has)
     * DisplayOrder NULL becomes 0
   On the first run only, DisplayOrder 0 becomes the id, which is the order
   the rows came out in before.

   Objects (each carries the text MemberTypes-Step21)
     spr_GetMemberType                  REPLACED, same parameter; adds scope,
                                        order, reserved, use counts, CanEdit,
                                        CanDelete
     spr_GetMemberTypeByMemberTypeId    REPLACED, the same columns for one type
     spr_AddEditMemberType              REPLACED, adds @MemberScope,
                                        @DisplayOrder, @ActingUserId
     spr_DeleteMemberTypeByMemberTypeId REPLACED (step 2), adds @ActingUserId
     spr_GetMemberTypeForTagging        NEW, the drop-down of a tagging page
     spr_AddEditCommitteeMember         REPLACED, refuses a type that is not an
                                        active committee type (Reason 13)
     spr_AddEditMeetingMember           REPLACED (step 15; keeps its locks and
                                        its marker MeetingLocks-Step15), refuses
                                        a type that is not an active meeting
                                        type (Reason 13)
     spr_sys_ResetDatabase              REPLACED (steps 3 and 18; keeps their
                                        markers), seeds the new columns

   The member type procedures return ONE row: Result (1 done, 0 refused),
   Reason, ReasonDetail
     Reason 0 done
            3 value not valid; ReasonDetail = MemberTypeCode, MemberTypeName,
              MemberScope, DisplayOrder, StatusId, Code, DuplicateCode,
              DuplicateName or NotFound
            4 not allowed for your role (only an Admin or a Controller)
            5 in use: the scope cannot change / the type cannot be deleted;
              ReasonDetail = "<n> committee, <m> meeting"
            7 a reserved type
            8 acting user missing or inactive
   The two tagging procedures return Result, Reason, ReasonDetail with the
   meeting codes of steps 15 to 18 plus
            13 member type not allowed here (inactive, other scope or
               missing); ReasonDetail = the type name. An edit that keeps
               the row's current type is allowed.
   spr_AddEditCommitteeMember keeps SET NOCOUNT OFF, so the build before
   step 21 (which reads the row count) still sees 1 for a saved row.

   Needs steps 18 and 19 and stops otherwise. It does not need step 20.
   Stops, changing nothing, if two member types have the same code or name
   (ignoring case and outer spaces), if a type is used on both Committee
   Member and Meeting Member, or if type 2, 3 or 6 is used on Committee
   Member.

   Safe to re-run. Run it BEFORE deploying the build that calls the new
   parameters, and the build straight after: the older Member Type page
   passes no acting user, so its saves are refused (Reason 8) until then.

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();
DECLARE @List NVARCHAR(2000);

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%SystemAccount3-Step18%')
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetOrganisationSettings')), '') NOT LIKE '%OrganisationSettings-Step19%')
BEGIN
    RAISERROR('Step 19 (BMMS-Fix-OrganisationSettings-Step19.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeetingMember')), '') NOT LIKE '%MeetingLocks-Step15%')
BEGIN
    RAISERROR('Step 15 (BMMS-Fix-MeetingLocks.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE
BEGIN
    -- Same code or name twice (the unique indexes would fail)
    SET @List = STUFF((SELECT ', "' + k + '"' FROM (
                    SELECT LTRIM(RTRIM(MemberTypeCode)) AS k FROM Member_Type GROUP BY LTRIM(RTRIM(MemberTypeCode)) HAVING COUNT(*) > 1
                    UNION
                    SELECT LTRIM(RTRIM(MemberTypeName)) FROM Member_Type GROUP BY LTRIM(RTRIM(MemberTypeName)) HAVING COUNT(*) > 1) d
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, '');
    IF (@List IS NOT NULL)
    BEGIN
        RAISERROR('Member types with the same code or name in "%s": %s. Give each type its own code and name on the Member Type Master, then run again. Nothing was changed.', 16, 1, @CurrentDatabase, @List);
        SET NOEXEC ON;
    END
    ELSE
    BEGIN
        -- A type is either a committee role or a meeting role
        SET @List = STUFF((SELECT ', ' + CAST(mt.MemberTypeId AS VARCHAR(12)) + ' ' + mt.MemberTypeName FROM Member_Type mt
                    WHERE EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.MemberTypeId = mt.MemberTypeId)
                      AND (mt.MemberTypeId IN (2, 3, 6)
                           OR EXISTS (SELECT 1 FROM Meeting_Member mm WHERE mm.MemberTypeId = mt.MemberTypeId))
                    ORDER BY mt.MemberTypeId
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, '');
        IF (@List IS NOT NULL)
        BEGIN
            RAISERROR('Member types used on Committee Member that are meeting roles (used on Meeting Member as well, or type 2, 3 or 6) in "%s": %s. Change those committee member rows to a committee type, then run again. Nothing was changed.', 16, 1, @CurrentDatabase, @List);
            SET NOEXEC ON;
        END
    END
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- Columns (MemberTypes-Step21). #Step21 remembers whether this is the first run.
-------------------------------------------------------------------------------
IF (OBJECT_ID('tempdb..#Step21') IS NOT NULL)
    DROP TABLE #Step21;
SELECT CASE WHEN COL_LENGTH('dbo.Member_Type', 'IsReserved') IS NULL THEN 1 ELSE 0 END AS FirstRun INTO #Step21;

IF (COL_LENGTH('dbo.Member_Type', 'IsReserved') IS NULL)
    ALTER TABLE dbo.Member_Type ADD IsReserved BIT NOT NULL CONSTRAINT DF_Member_Type_IsReserved DEFAULT 0;
IF (COL_LENGTH('dbo.Member_Type', 'MemberScope') IS NULL)
    ALTER TABLE dbo.Member_Type ADD MemberScope CHAR(1) NOT NULL CONSTRAINT DF_Member_Type_MemberScope DEFAULT 'C';
GO

-------------------------------------------------------------------------------
-- Data (see the header)
-------------------------------------------------------------------------------
DECLARE @FirstRun INT = ISNULL((SELECT TOP 1 FirstRun FROM #Step21), 0);
DECLARE @Changed INT;

UPDATE Member_Type SET DisplayOrder = 0 WHERE DisplayOrder IS NULL;

IF (@FirstRun = 1)
BEGIN
    UPDATE Member_Type SET DisplayOrder = MemberTypeId WHERE DisplayOrder = 0;
    PRINT CAST(@@ROWCOUNT AS VARCHAR(12)) + ' member type(s): display order set to the id (first run).';
END

UPDATE Member_Type SET IsReserved = 1, MemberScope = 'M', StatusId = 1
WHERE MemberTypeId IN (2, 3, 6) AND (IsReserved <> 1 OR MemberScope <> 'M' OR StatusId <> 1);
SET @Changed = @@ROWCOUNT;
UPDATE Member_Type SET MemberScope = 'M'
WHERE MemberScope <> 'M'
  AND EXISTS (SELECT 1 FROM Meeting_Member mm WHERE mm.MemberTypeId = Member_Type.MemberTypeId)
  AND NOT EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.MemberTypeId = Member_Type.MemberTypeId);
SET @Changed = @Changed + @@ROWCOUNT;
UPDATE Member_Type SET MemberScope = 'C'
WHERE MemberScope <> 'C' AND IsReserved = 0
  AND EXISTS (SELECT 1 FROM Committee_Member cm WHERE cm.MemberTypeId = Member_Type.MemberTypeId)
  AND NOT EXISTS (SELECT 1 FROM Meeting_Member mm WHERE mm.MemberTypeId = Member_Type.MemberTypeId);
SET @Changed = @Changed + @@ROWCOUNT;

PRINT CAST(@Changed AS VARCHAR(12)) + ' member type row change(s) for the reserved flag and the scope.';
GO

-------------------------------------------------------------------------------
-- Constraints
-------------------------------------------------------------------------------
IF (OBJECT_ID('dbo.CK_Member_Type_MemberScope', 'C') IS NULL)
    ALTER TABLE dbo.Member_Type ADD CONSTRAINT CK_Member_Type_MemberScope CHECK (MemberScope IN ('C', 'M'));
IF (OBJECT_ID('dbo.CK_Member_Type_Reserved', 'C') IS NULL)
    ALTER TABLE dbo.Member_Type ADD CONSTRAINT CK_Member_Type_Reserved CHECK (IsReserved = 0 OR StatusId = 1);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'UX_Member_Type_Code')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Member_Type_Code ON dbo.Member_Type (MemberTypeCode);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type') AND name = 'UX_Member_Type_Name')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Member_Type_Name ON dbo.Member_Type (MemberTypeName);
GO

-------------------------------------------------------------------------------
-- Procedures
-------------------------------------------------------------------------------

-- Member types for the Member Type Master; @StatusId -1 = all (MemberTypes-Step21)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMemberType]
@StatusId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	mt.MemberTypeId, mt.MemberTypeCode, mt.MemberTypeName,
	mt.StatusId,
	(SELECT DisplayName FROM SysCodeSetting WHERE SubCode = mt.StatusId
		AND MainCode = 'Status') AS StatusName,
	mt.MemberScope,
	CASE mt.MemberScope WHEN 'M' THEN 'Meeting' ELSE 'Committee' END AS ScopeName,
	ISNULL(mt.DisplayOrder, 0) AS DisplayOrder,
	CAST(mt.IsReserved AS INT) AS IsReserved,
	u.CommitteeUseCount, u.MeetingUseCount,
	CASE WHEN mt.IsReserved = 1 THEN 0 ELSE 1 END AS CanEdit,
	CASE WHEN mt.IsReserved = 0 AND u.CommitteeUseCount = 0 AND u.MeetingUseCount = 0 THEN 1 ELSE 0 END AS CanDelete
	FROM Member_Type mt
	CROSS APPLY (SELECT
		(SELECT COUNT(*) FROM Committee_Member cm WHERE cm.MemberTypeId = mt.MemberTypeId) AS CommitteeUseCount,
		(SELECT COUNT(*) FROM Meeting_Member mm WHERE mm.MemberTypeId = mt.MemberTypeId) AS MeetingUseCount) u
	WHERE @StatusId = -1 OR mt.StatusId = @StatusId
	ORDER BY mt.MemberScope, ISNULL(mt.DisplayOrder, 0), mt.MemberTypeName;
END
GO

-- One member type, the same columns as spr_GetMemberType (MemberTypes-Step21)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMemberTypeByMemberTypeId]
@MemberTypeId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
	mt.MemberTypeId, mt.MemberTypeCode, mt.MemberTypeName,
	mt.StatusId,
	(SELECT DisplayName FROM SysCodeSetting WHERE SubCode = mt.StatusId
		AND MainCode = 'Status') AS StatusName,
	mt.MemberScope,
	CASE mt.MemberScope WHEN 'M' THEN 'Meeting' ELSE 'Committee' END AS ScopeName,
	ISNULL(mt.DisplayOrder, 0) AS DisplayOrder,
	CAST(mt.IsReserved AS INT) AS IsReserved,
	u.CommitteeUseCount, u.MeetingUseCount,
	CASE WHEN mt.IsReserved = 1 THEN 0 ELSE 1 END AS CanEdit,
	CASE WHEN mt.IsReserved = 0 AND u.CommitteeUseCount = 0 AND u.MeetingUseCount = 0 THEN 1 ELSE 0 END AS CanDelete
	FROM Member_Type mt
	CROSS APPLY (SELECT
		(SELECT COUNT(*) FROM Committee_Member cm WHERE cm.MemberTypeId = mt.MemberTypeId) AS CommitteeUseCount,
		(SELECT COUNT(*) FROM Meeting_Member mm WHERE mm.MemberTypeId = mt.MemberTypeId) AS MeetingUseCount) u
	WHERE mt.MemberTypeId = @MemberTypeId;
END
GO

-- Member types for the drop-down of a tagging page: the active types of the scope (C committee,
-- M meeting) and, on an edit, the row's current type marked when it is not one of them (MemberTypes-Step21)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetMemberTypeForTagging]
@MemberScope VARCHAR(10),
@CurrentMemberTypeId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SELECT x.MemberTypeId, x.MemberTypeName, x.DisplayName
	FROM (
		SELECT mt.MemberTypeId, mt.MemberTypeName, mt.MemberTypeName AS DisplayName,
		       0 AS Extra, ISNULL(mt.DisplayOrder, 0) AS DisplayOrder
		FROM Member_Type mt
		WHERE mt.MemberScope = @MemberScope AND mt.StatusId = 1
		UNION ALL
		SELECT mt.MemberTypeId, mt.MemberTypeName,
		       mt.MemberTypeName + CASE WHEN mt.StatusId <> 1 THEN ' (inactive)'
		                                WHEN mt.MemberScope = 'M' THEN ' (meeting type)'
		                                ELSE ' (committee type)' END,
		       1, ISNULL(mt.DisplayOrder, 0)
		FROM Member_Type mt
		WHERE mt.MemberTypeId = @CurrentMemberTypeId
		  AND NOT (mt.MemberScope = ISNULL(@MemberScope, '') AND mt.StatusId = 1)
	) x
	ORDER BY x.Extra, x.DisplayOrder, x.MemberTypeName;
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

-- Committee_Member - add / edit; the type must be an active committee type, unless an edit keeps the
-- row's current type (Reason 13) (MemberTypes-Step21). NOCOUNT stays OFF: the build before step 21 reads
-- the row count of the insert / update.
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditCommitteeMember]
@Code VARCHAR(50),
@CommitteeMemberId INT,
@CommitteeId INT,
@MemberId INT,
@MemberTypeId INT,
@AppointmentDate DATETIME,
@CessationDate VARCHAR(50),
@IsFeeApplicable INT,
@ApplicableFee DECIMAL,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @OldMemberTypeId INT;
DECLARE @RowFound INT;
DECLARE @TypeScope CHAR(1);
DECLARE @TypeStatus INT;
DECLARE @TypeName VARCHAR(50);
BEGIN
	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @RowFound = 0;

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION CommitteeMemberSave;

		IF (@Code = 'Update')
			SELECT @OldMemberTypeId = MemberTypeId, @RowFound = 1
			FROM Committee_Member WITH (UPDLOCK, HOLDLOCK)
			WHERE CommitteeMemberId = @CommitteeMemberId;

		-- The type row is locked, so the Member Type Master cannot change its scope meanwhile
		SELECT @TypeScope = MemberScope, @TypeStatus = StatusId, @TypeName = MemberTypeName
		FROM Member_Type WITH (UPDLOCK, HOLDLOCK)
		WHERE MemberTypeId = @MemberTypeId;

		IF (ISNULL(@Code, '') NOT IN ('Save', 'Update') OR (@Code = 'Update' AND @RowFound = 0))
			SET @Reason = 4;
		ELSE IF (NOT (@Code = 'Update' AND @OldMemberTypeId = @MemberTypeId)
		         AND (@TypeScope IS NULL OR @TypeScope <> 'C' OR @TypeStatus <> 1))
		BEGIN
			SET @Reason = 13;
			SET @Detail = ISNULL(@TypeName, CAST(@MemberTypeId AS VARCHAR(12)));
		END
		ELSE IF (@Code = 'Save')
		BEGIN
			INSERT INTO Committee_Member
			(CommitteeId, MemberId, MemberTypeId, AppointmentDate, IsFeeApplicable,
				ApplicableFee, CessationDate, CreatedOn, CreatedBy)
			VALUES
			(@CommitteeId, @MemberId, @MemberTypeId, @AppointmentDate, @IsFeeApplicable,
				@ApplicableFee, @CessationDate, @CreatedOn, @CreatedBy);
			SET @Result = 1;
		END
		ELSE
		BEGIN
			UPDATE Committee_Member SET
			MemberId = @MemberId,
			MemberTypeId = @MemberTypeId,
			AppointmentDate = @AppointmentDate,
			CessationDate = @CessationDate,
			IsFeeApplicable = @IsFeeApplicable,
			ApplicableFee = @ApplicableFee,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy
			WHERE
			CommitteeMemberId = @CommitteeMemberId;
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
			ROLLBACK TRANSACTION CommitteeMemberSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Meeting_Member - add / edit, refused once the minutes are finalized (MeetingLocks-Step15)
-- The type must be an active meeting type, unless an edit keeps the row's current type (Reason 13) (MemberTypes-Step21)
CREATE OR ALTER PROCEDURE [dbo].[spr_AddEditMeetingMember]
@Code VARCHAR(50),
@MeetingMemberId INT,
@MeetingId INT,
@MemberId INT,
@MemberTypeId INT,
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @LockMeetingId INT;
DECLARE @MinutesStatus VARCHAR(50);
DECLARE @OldMemberTypeId INT;
DECLARE @TypeScope CHAR(1);
DECLARE @TypeStatus INT;
DECLARE @TypeName VARCHAR(50);
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
			SAVE TRANSACTION MeetingMemberSave;

		-- An edit stays on the meeting of the existing row
		IF (@Code = 'Update')
			SELECT @LockMeetingId = MeetingId, @OldMemberTypeId = MemberTypeId
			FROM Meeting_Member WITH (UPDLOCK, HOLDLOCK)
			WHERE MeetingMemberId = @MeetingMemberId;
		ELSE
			SET @LockMeetingId = @MeetingId;

		SELECT @MinutesStatus = ISNULL(MinutesStatus, 'Open')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- The type row is locked, so the Member Type Master cannot change its scope meanwhile
		SELECT @TypeScope = MemberScope, @TypeStatus = StatusId, @TypeName = MemberTypeName
		FROM Member_Type WITH (UPDLOCK, HOLDLOCK)
		WHERE MemberTypeId = @MemberTypeId;

		IF (@MinutesStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@MinutesStatus IN ('F', 'C'))
			SET @Reason = 1;
		ELSE IF (NOT (@Code = 'Update' AND @OldMemberTypeId = @MemberTypeId)
		         AND (@TypeScope IS NULL OR @TypeScope <> 'M' OR @TypeStatus <> 1))
		BEGIN
			SET @Reason = 13;
			SET @Detail = ISNULL(@TypeName, CAST(@MemberTypeId AS VARCHAR(12)));
		END
		ELSE IF (@Code = 'Save')
		BEGIN
			INSERT INTO Meeting_Member
			(MeetingId, MemberId, MemberTypeId,  StatusId, CreatedOn, CreatedBy)
			VALUES
			(@MeetingId, @MemberId, @MemberTypeId, @StatusId, @CreatedOn, @CreatedBy);
			SET @Result = 1;
		END
		ELSE IF (@Code = 'Update')
		BEGIN
			UPDATE Meeting_Member SET
			MemberId = @MemberId,
			MemberTypeId = @MemberTypeId,
			StatusId = @StatusId,
			UpdatedOn = @UpdatedOn,
			UpdatedBy = @UpdatedBy
			WHERE
			MeetingMemberId = @MeetingMemberId;
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
			ROLLBACK TRANSACTION MeetingMemberSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-- Reset Database: wipes all data and seeds the defaults. The "admin" user is seeded as the protected
-- system account (IsSystem = 1), the other three with IsSystem = 0; the seed e-mail addresses are
-- placeholders (SystemAccount3-Step18). Seeded passwords are hashes of the application's default password.
-- Member types are seeded with their scope (C committee, M meeting), display order and the reserved
-- flag: 2 Invitee, 3 In Attendance and 6 Special Invitee are reserved (MemberTypes-Step21).
CREATE OR ALTER PROCEDURE [dbo].[spr_sys_ResetDatabase]
AS
BEGIN

TRUNCATE TABLE ActionItem_User_Map;
TRUNCATE TABLE Alert_User_Map;
TRUNCATE TABLE Meeting_Member;
TRUNCATE TABLE Committee_Member;
TRUNCATE TABLE Attendance;

DELETE FROM SysCodeSetting;
DELETE FROM Audit_Trail_Master;
DELETE FROM Audit_Trail_SqlBackup;
DELETE FROM Audit_Trial_Login;

DELETE FROM Audit_Trail_Master;
DBCC CHECKIDENT (Audit_Trail_Master, RESEED, 0);

DELETE FROM Audit_Trail_SqlBackup;
DBCC CHECKIDENT (Audit_Trail_SqlBackup, RESEED, 0);

DELETE FROM Audit_Trial_Login;
DBCC CHECKIDENT (Audit_Trial_Login, RESEED, 0);

DELETE FROM Action_Item;
DBCC CHECKIDENT (Action_Item, RESEED, 0);

DELETE FROM Alert_Master;
DBCC CHECKIDENT (Alert_Master, RESEED, 0);

DELETE FROM Minutes;
DBCC CHECKIDENT (Minutes, RESEED, 0);

DELETE FROM Agenda;
DBCC CHECKIDENT (Agenda, RESEED, 0);

DELETE FROM Agenda_Status;

DELETE FROM Meeting;
DBCC CHECKIDENT (Meeting, RESEED, 0);

DELETE FROM Committee;
DBCC CHECKIDENT (Committee, RESEED, 0);

DELETE FROM Member;
DBCC CHECKIDENT (Member, RESEED, 0);

DELETE FROM Member_Type;
DBCC CHECKIDENT (Member_Type, RESEED, 0);

DELETE FROM Alert_Type;

DELETE FROM Decision_Type;
DBCC CHECKIDENT (Decision_Type, RESEED, 0);

DELETE FROM Users;
DBCC CHECKIDENT (Users, RESEED, 0);

DELETE FROM Department;
DBCC CHECKIDENT (Department, RESEED, 0);

DELETE FROM Designation;
DBCC CHECKIDENT (Designation, RESEED, 0);

DELETE FROM Subject_Type;
DBCC CHECKIDENT (Subject_Type, RESEED, 0);


DELETE FROM Roles;
DBCC CHECKIDENT (Roles, RESEED, 0);

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
SELECT 'admin', 1, 1, NULL, 1, '', 'admin', '100000.WADOkeW3PD8T+KGnhd13NA==.ykPBZLhjry5KbA3hGEQsf8hdO3yY8C23RTHKeAOfXWU=', 1, GETDATE(), 1, GETDATE(), 1, 1
UNION ALL
SELECT 'Controller', 2, 3, NULL, 2, 'con@example.invalid', 'secuser', '100000.M/UxC7LnMnNnEZFfpnw6mg==.BjFpjTZvVXXXGN0NOfAyBgtqgpaTbE4rH41LJyBONSc=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'Manager', 4, 4, NULL, 3, 'mgr@example.invalid', 'credmanager', '100000.PsM4vZJAAQ9wtc5TyVtBcg==.g2/yOexqH1W/RQ33t0LmQ0eZYFQl6gPN7buM+M1bbqY=', 1, GETDATE(), 1, GETDATE(), 1, 0
UNION ALL
SELECT 'User', 4, 5, 3, 4, 'usr@example.invalid', 'creduser', '100000.VqhtwYgekpXELBK53d/DLg==.haI/Qxp3EbSWTlfeUjLiqWbR30WATDUW5pazcR8k7tA=', 1, GETDATE(), 1, GETDATE(), 1, 0;


INSERT INTO [Committee]
([CommitteeCode],[CommitteeName],[Board],[IncorporationDate],[StatusId],[IsDelete],
	[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'C01', 'Board of Directors',1, GETDATE(), 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'C02', 'Audit Committee',0, GETDATE(), 1, 0, GETDATE(), 1, GETDATE(), 1;


END
GO

DECLARE @Installed INT = (SELECT COUNT(*) FROM sys.sql_modules
    WHERE definition LIKE '%MemberTypes-Step21%'
    AND object_id IN (OBJECT_ID('dbo.spr_GetMemberType'), OBJECT_ID('dbo.spr_GetMemberTypeByMemberTypeId'),
                      OBJECT_ID('dbo.spr_GetMemberTypeForTagging'), OBJECT_ID('dbo.spr_AddEditMemberType'),
                      OBJECT_ID('dbo.spr_DeleteMemberTypeByMemberTypeId'), OBJECT_ID('dbo.spr_AddEditCommitteeMember'),
                      OBJECT_ID('dbo.spr_AddEditMeetingMember'), OBJECT_ID('dbo.spr_sys_ResetDatabase')));
DECLARE @Constraints INT = (SELECT COUNT(*) FROM sys.objects WHERE parent_object_id = OBJECT_ID('dbo.Member_Type')
                                AND name IN ('CK_Member_Type_MemberScope', 'CK_Member_Type_Reserved'))
                         + (SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Member_Type')
                                AND name IN ('UX_Member_Type_Code', 'UX_Member_Type_Name'));
DECLARE @Reserved NVARCHAR(400) = ISNULL(STUFF((SELECT ', ' + CAST(MemberTypeId AS VARCHAR(12)) + ' ' + MemberTypeName
    FROM Member_Type WHERE IsReserved = 1 ORDER BY MemberTypeId FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, ''), 'none');

IF (@Installed = 8 AND @Constraints = 4)
    PRINT 'Member types (step 21) installed: 8 procedures, 4 constraints. Reserved: ' + @Reserved + '.';
ELSE
    PRINT 'Member types (step 21): ' + CAST(@Installed AS VARCHAR(4)) + ' of 8 procedures carry the marker, '
        + CAST(@Constraints AS VARCHAR(4)) + ' of 4 constraints. Check the messages above.';
GO

IF (OBJECT_ID('tempdb..#Step21') IS NOT NULL)
    DROP TABLE #Step21;
GO

SET NOEXEC OFF;
GO
