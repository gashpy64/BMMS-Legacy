/* ============================================================================
   BMMS - Rollback of step 56 (step GM1a, the Governance Matrix and the
   governance change log)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Puts back, letter for letter, the texts that BMMS-Fix-GovernanceLog-
   Step56.sql replaced:
     spr_AddEditUser                  the step 54 text
     spr_SetUserStatusByUserId        the step 53 text
     spr_DeleteUserByUserId           the step 47 text
     spr_AddEditDepartment            the baseline text
     spr_SetDepartmentManagerRule     the step 39 text
     spr_SetAppSetting                the step 16 text
     spr_sys_ResetDatabase            the step 39 text
   and drops the 19 functions and procedures step 56 added. It KEEPS the
   table Governance_Change_Log, its rows, its key to Users, the DENY on it
   and the setting row GovernanceLogFrom: no history is lost, and
   BMMS-Check-InstalledSteps.sql then shows step 56 Partly (the table, the
   key and the setting, 1 of 27). At its end the seven texts are compared
   with the texts step 56 was built from (SHA-1 without carriage returns).

   While rolled back with rows in the log:
     - a user who changed something recorded in the log (ChangedBy) cannot
       be deleted: the older delete procedure does not know the table, and
       its key refuses the delete (Reason 9, "other data still refers to
       them");
     - Reset Database fails and changes nothing (the older text does not
       clear the log before Users): install step 56 again first;
     - the changes made meanwhile are not recorded, and installing step 56
       again does not back-fill them (the back-fill runs only while the log
       is empty).

   Roll back the build of step GM1a FIRST: the Governance Matrix page calls
   the procedures this script drops, and Department Master passes
   @ActingUserId, which the baseline spr_AddEditDepartment does not have.
   It refuses when step 56 is not installed (none of its objects carries
   GovernanceLog-Step56).

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Written for
   compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF NOT EXISTS (SELECT 1 FROM sys.sql_modules m
                    WHERE m.object_id IN (OBJECT_ID('dbo.spr_WriteGovernanceChange'), OBJECT_ID('dbo.spr_GetGovernanceMatrix'),
                                          OBJECT_ID('dbo.spr_AddEditUser'), OBJECT_ID('dbo.spr_SetUserStatusByUserId'),
                                          OBJECT_ID('dbo.spr_DeleteUserByUserId'), OBJECT_ID('dbo.spr_AddEditDepartment'),
                                          OBJECT_ID('dbo.spr_SetDepartmentManagerRule'), OBJECT_ID('dbo.spr_SetAppSetting'),
                                          OBJECT_ID('dbo.spr_sys_ResetDatabase'))
                      AND m.definition LIKE '%GovernanceLog-Step56%')
BEGIN
    RAISERROR('Step 56 is not installed in "%s" (none of its objects carries GovernanceLog-Step56): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- spr_AddEditUser: the step 54 text
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - add / edit (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- Save checks Create (acting user = @CreatedBy); Update checks Edit and, when the role really
-- changes, RoleChange (acting user = @UpdatedBy) (UserProtection-Stage1).
-- UserHistory-Step39: @DepartmentIds (optional, last) is the comma list of the user's departments:
-- digits and commas only, at most 2000 characters, each id at most 9 digits and a department that
-- exists; a department added by the list must be active. Only a Manager may have several; the home
-- department (@DepartmentId) must be in the list (Reason 23). NULL = not passed: a new user gets the
-- home department; an edit keeps the Manager's mappings and adds the home department. Every change is
-- written to User_Role / User_Department in the same transaction (rows dated today, by the acting
-- user). An inactive user's rows are left closed: only Users changes, Activate opens the rows.
-- A role change away from Manager closes his other departments (R) and is refused (Reason 24) when he
-- is the last active Manager of one of his departments with items waiting for a Manager, or when items
-- waiting at AC are routed to him; an edit that removes a department of a Manager checks that
-- department only. On success ReasonDetail is 'MappingsClosed:<names>' when departments were closed
-- by a role change away from Manager, otherwise ''.
-- ManagerRelease-Step52 (step MR1): the items routed to him are those fn_AgendaWaitingFor lets him approve, counted
-- apart by the meeting date (fn_ManagerReleaseRefusal Kinds 'P' and 'Q'). The Reason 24 ReasonDetail is
-- 'open:<n>|past:<n>|<department part>', the department part as before ('last active Manager of ...' or nothing).
-- DepartmentApprovers-Step53 (step UD1b): rule 12 refuses only for the items no other Manager of the department could
-- decide (fn_ManagerReleaseRefusal). When the change is allowed, his rows on the alerts of items at AC of the
-- departments he leaves are marked 'N' (no longer Manager of the department) in the same transaction, and the
-- successful ReasonDetail ends with '|Released:<n>:<department names>'. A Manager after the save (a new user, a role
-- changed to Manager, a department added) gets a row on the alert of every item waiting at AC in his departments
-- (spr_SetManagerAlertRows; his own 'N' row is opened again).
-- ManagerScope-Step54 (step UD1c): the Reporting Person (@ManagerId) must be one of fn_ReportingPersonAllowed for the
-- user's (home) department @DepartmentId: an active Controller or an active Manager of that department, never the
-- user himself; none (NULL or 0, "- Select -") stays allowed. Otherwise Reason 31 and nothing is saved, on Create
-- and on every Update (also when the Reporting Person is not changed).
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
@OutReason INT = NULL OUTPUT,
@DepartmentIds VARCHAR(MAX) = NULL
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @ActingUserId INT;
DECLARE @OldRoleId INT;
DECLARE @OldActive INT;
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @NewUserId INT;
DECLARE @IsManager INT;
DECLARE @WasManager INT;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @Rest VARCHAR(MAX);
DECLARE @Pos INT;
DECLARE @Token VARCHAR(20);
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Posted TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Wanted TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL);
DECLARE @OpenNow TABLE (DepartmentId INT NOT NULL PRIMARY KEY, IsHome BIT NOT NULL, IsVirtual BIT NOT NULL);
DECLARE @OldDepartmentId INT;
DECLARE @Lost TABLE (DepartmentId INT NOT NULL PRIMARY KEY);
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
DECLARE @Rel TABLE (DepartmentId INT NOT NULL PRIMARY KEY);   -- DepartmentApprovers-Step53
DECLARE @RelDept INT;
DECLARE @RelCount INT;
DECLARE @RelTotal INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @RelTotal = 0;
	SET @ActingUserId = CASE WHEN @Code = 'Save' THEN @CreatedBy ELSE @UpdatedBy END;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();
	SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

	-- The posted list, read as numbers only (UserHistory-Step39)
	IF (@DepartmentIds IS NOT NULL)
	BEGIN
		IF (LEN(@DepartmentIds) = 0 OR LEN(@DepartmentIds) > 2000 OR @DepartmentIds LIKE '%[^0-9,]%')
			SET @Detail = N'ListNotValid';
		ELSE
		BEGIN
			SET @Rest = @DepartmentIds + ',';
			WHILE (LEN(@Rest) > 0 AND @Detail = N'')
			BEGIN
				SET @Pos = CHARINDEX(',', @Rest);
				IF (@Pos <= 1 OR @Pos > 10)
					SET @Detail = N'ListNotValid';
				ELSE
				BEGIN
					SET @Token = LEFT(@Rest, @Pos - 1);
					SET @Rest = SUBSTRING(@Rest, @Pos + 1, LEN(@Rest));
					IF NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = CAST(@Token AS INT))
						INSERT INTO @Posted (DepartmentId) VALUES (CAST(@Token AS INT));
				END
			END
		END

		IF (@Detail = N'' AND EXISTS (SELECT 1 FROM @Posted p WHERE NOT EXISTS (SELECT 1 FROM Department d WHERE d.DepartmentId = p.DepartmentId)))
			SET @Detail = N'DepartmentNotFound';
		ELSE IF (@Detail = N'' AND @IsManager = 0 AND (SELECT COUNT(*) FROM @Posted) > 1)
			SET @Detail = N'OneDepartmentOnly';
		ELSE IF (@Detail = N'' AND NOT EXISTS (SELECT 1 FROM @Posted WHERE DepartmentId = @DepartmentId))
			SET @Detail = N'HomeNotTicked';
	END

	IF (@ActingUserId IS NULL OR @ActingUserId = 0)
	BEGIN
		SET @Reason = 8;
		SET @Detail = N'';
	END
	ELSE IF (@Code = 'Save')
	BEGIN
		SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, NULL, 'Create', @RoleId);

		IF (@Reason <> 0)
			SET @Detail = N'';
		ELSE IF (@Detail <> N'')
			SET @Reason = 23;
		ELSE IF (EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId WHERE ISNULL(d.StatusId, 0) <> 1))
		BEGIN
			SET @Reason = 23;
			SET @Detail = N'DepartmentInactive';
		END
		-- ManagerScope-Step54: the Reporting Person (Reason 31)
		ELSE IF (ISNULL(@ManagerId, 0) > 0
		         AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, NULL) rp WHERE rp.UserId = @ManagerId))
		BEGIN
			SET @Reason = 31;
			SET @Detail = N'';
		END

		IF (@Reason = 0)
		BEGIN
			IF (@@TRANCOUNT = 0)
				SET @OwnTransaction = 1;
			ELSE
				SET @OwnTransaction = 0;

			BEGIN TRY
				IF (@OwnTransaction = 1)
					BEGIN TRANSACTION;
				ELSE
					SAVE TRANSACTION AddUser;

				INSERT INTO Users
				(UserName, DepartmentId, DesignationId, ManagerId,
					RoleId, EmailId, LoginName, Password, AccountStatus, CreatedOn, CreatedBy)
				VALUES
				(@UserName, @DepartmentId, @DesignationId, @ManagerId,
					@RoleId, @EmailId, @LoginName, @Password, 1, @CreatedOn, @CreatedBy);

				SET @NewUserId = SCOPE_IDENTITY();

				INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @RoleId, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				VALUES (@NewUserId, @DepartmentId, 1, @Today, @Now, @ActingUserId);

				INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
				SELECT @NewUserId, p.DepartmentId, 0, @Today, @Now, @ActingUserId
				FROM @Posted p
				WHERE p.DepartmentId <> @DepartmentId;

				-- DepartmentApprovers-Step53: a new Manager gets his rows of the items waiting at AC in his departments
				IF (@IsManager = 1)
					EXEC dbo.spr_SetManagerAlertRows @UserId = @NewUserId, @ActingUserId = @ActingUserId;

				SET @Result = 1;

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
					ROLLBACK TRANSACTION AddUser;

				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END CATCH
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

			SELECT @OldRoleId = RoleId, @OldDepartmentId = DepartmentId, @OldActive = ISNULL(AccountStatus, 0)
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			SET @WasManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @OldRoleId AND RoleCode = 'manager') THEN 1 ELSE 0 END;

			-- Rule 2 under concurrency (only a role change can break it here)
			IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SELECT @Locked = COUNT(*) FROM Users WITH (UPDLOCK, HOLDLOCK)
				WHERE AccountStatus = 1
				AND RoleId IN (SELECT RoleId FROM Roles WHERE RoleCode IN ('admin', 'controller'));

			SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'Edit', NULL);

			IF (@Reason = 0 AND ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
				SET @Reason = dbo.fn_UserChangeRefusal(@ActingUserId, @UserId, 'RoleChange', @RoleId);

			IF (@Reason <> 0)
				SET @Detail = N'';
			ELSE IF (@Detail <> N'' AND @OldActive = 1)
				SET @Reason = 23;
			ELSE IF (@OldActive <> 1)
				-- An inactive user keeps closed rows: the list is not used (Activate opens the rows)
				SET @Detail = N'';

			IF (@Reason = 0 AND @OldActive = 1)
			BEGIN
				-- The open rows today, and the rows wanted after the save
				INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual)
				SELECT DepartmentId, MAX(CAST(IsHome AS INT)), 0 FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE UserId = @UserId AND EffectiveTo IS NULL
				GROUP BY DepartmentId;

				-- A user without an open department row (inserted directly, as the older test scripts do) counts
				-- as mapped to the department in Users: a row is written only when it changes
				IF NOT EXISTS (SELECT 1 FROM @OpenNow) AND @OldDepartmentId IS NOT NULL
					INSERT INTO @OpenNow (DepartmentId, IsHome, IsVirtual) VALUES (@OldDepartmentId, 1, 1);

				IF (@DepartmentIds IS NOT NULL)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @Posted;
				ELSE IF (@IsManager = 1)
					INSERT INTO @Wanted (DepartmentId, IsHome)
					SELECT DepartmentId, CASE WHEN DepartmentId = @DepartmentId THEN 1 ELSE 0 END FROM @OpenNow
					UNION
					SELECT @DepartmentId, 1 WHERE NOT EXISTS (SELECT 1 FROM @OpenNow WHERE DepartmentId = @DepartmentId);
				ELSE
					INSERT INTO @Wanted (DepartmentId, IsHome) VALUES (@DepartmentId, 1);

				-- A department added by the list must be active
				IF EXISTS (SELECT 1 FROM @Posted p JOIN Department d ON d.DepartmentId = p.DepartmentId
				           WHERE ISNULL(d.StatusId, 0) <> 1
				             AND NOT EXISTS (SELECT 1 FROM @OpenNow o WHERE o.DepartmentId = p.DepartmentId))
				BEGIN
					SET @Reason = 23;
					SET @Detail = N'DepartmentInactive';
				END
			END

			-- ManagerScope-Step54: the Reporting Person (Reason 31), checked on every Update
			IF (@Reason = 0 AND ISNULL(@ManagerId, 0) > 0
			    AND NOT EXISTS (SELECT 1 FROM dbo.fn_ReportingPersonAllowed(@DepartmentId, @UserId) rp WHERE rp.UserId = @ManagerId))
			BEGIN
				SET @Reason = 31;
				SET @Detail = N'';
			END

			-- Rule 12: a Manager who leaves departments
			IF (@Reason = 0 AND @OldActive = 1 AND @WasManager = 1)
			BEGIN
				IF (@IsManager = 0)
					INSERT INTO @Lost (DepartmentId) SELECT DepartmentId FROM @OpenNow;
				ELSE
					INSERT INTO @Lost (DepartmentId)
					SELECT o.DepartmentId FROM @OpenNow o WHERE NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId);

				IF (EXISTS (SELECT 1 FROM @Lost) OR @IsManager = 0)
				BEGIN
					-- Two Managers of one department changing at the same time are serialised here
					SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
					WHERE EffectiveTo IS NULL AND DepartmentId IN (SELECT DepartmentId FROM @Lost);

					IF (@IsManager = 0)
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);
					ELSE
						INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
						SELECT f.Kind, f.DepartmentId, f.DepartmentName, f.Items
						FROM @Lost l
						CROSS APPLY dbo.fn_ManagerReleaseRefusal(@UserId, l.DepartmentId, 0) f;

					IF EXISTS (SELECT 1 FROM @Refusal)
					BEGIN
						SET @Reason = 24;
						-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
						-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
						SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
						            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
						            + N'|'
						            + ISNULL(N'last active Manager of '
						              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
						                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
						                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
						SET @Detail = LEFT(@Detail, 2000);
					END
				END
			END

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

				-- History (UserHistory-Step39): active users only
				IF (@Result = 1 AND @OldActive = 1)
				BEGIN
					IF (ISNULL(@OldRoleId, -1) <> ISNULL(@RoleId, -1))
					BEGIN
						UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'C'
						WHERE UserId = @UserId AND EffectiveTo IS NULL;

						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleId, @Today, @Now, @ActingUserId);
					END

					IF (@WasManager = 1 AND @IsManager = 0)
						SET @Detail = ISNULL(N'MappingsClosed:'
						              + STUFF((SELECT N', ' + d.DepartmentName FROM @OpenNow o JOIN Department d ON d.DepartmentId = o.DepartmentId
						                       WHERE o.IsVirtual = 0
						                         AND NOT EXISTS (SELECT 1 FROM @Wanted w WHERE w.DepartmentId = o.DepartmentId)
						                       ORDER BY d.DepartmentName
						                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');

					-- Close the rows that go away or whose home flag changes
					UPDATE ud SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId,
					       CloseReason = CASE WHEN @WasManager = 1 AND @IsManager = 0 AND w.DepartmentId IS NULL THEN 'R' ELSE 'C' END
					FROM User_Department ud
					LEFT JOIN @Wanted w ON w.DepartmentId = ud.DepartmentId
					WHERE ud.UserId = @UserId AND ud.EffectiveTo IS NULL
					  AND (w.DepartmentId IS NULL OR w.IsHome <> ud.IsHome);

					-- Open the rows that are wanted and not open (nor unchanged in Users, for a user without rows)
					INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
					SELECT @UserId, w.DepartmentId, w.IsHome, @Today, @Now, @ActingUserId
					FROM @Wanted w
					WHERE NOT EXISTS (SELECT 1 FROM User_Department ud
					                  WHERE ud.UserId = @UserId AND ud.DepartmentId = w.DepartmentId AND ud.EffectiveTo IS NULL)
					  AND NOT EXISTS (SELECT 1 FROM @OpenNow o
					                  WHERE o.IsVirtual = 1 AND o.DepartmentId = w.DepartmentId AND o.IsHome = w.IsHome);

					-- DepartmentApprovers-Step53: his waiting approval alerts of the departments he leaves are closed for him
					-- ('N'); rule 12 above has made sure another Manager of the department still has them
					IF (@WasManager = 1)
					BEGIN
						INSERT INTO @Rel (DepartmentId)
						SELECT DISTINCT a.DepartmentId
						FROM Alert_User_Map m
						JOIN Alert_Master am ON am.AlertId = m.AlertId
						JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
						WHERE m.UserId = @UserId AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC'
						  AND a.DepartmentId IS NOT NULL
						  AND (@IsManager = 0 OR a.DepartmentId IN (SELECT l.DepartmentId FROM @Lost l));

						SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel);
						WHILE (@RelDept IS NOT NULL)
						BEGIN
							EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @DepartmentId = @RelDept, @Release = 1,
							     @ActingUserId = @ActingUserId, @Released = @RelCount OUTPUT;
							SET @RelTotal = @RelTotal + ISNULL(@RelCount, 0);
							SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel WHERE DepartmentId > @RelDept);
						END
					END

					-- DepartmentApprovers-Step53: a Manager (new role, or a department added) gets his rows of the items
					-- waiting at AC in his departments
					IF (@IsManager = 1)
						EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @ActingUserId = @ActingUserId;
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
				ROLLBACK TRANSACTION EditUser;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END

	IF (@Result <> 1 AND @Reason = 0)
		SET @Detail = N'';

	-- DepartmentApprovers-Step53: '|Released:<n>:<department names>' at the end of a successful detail
	IF (@Result = 1 AND @RelTotal > 0)
		SET @Detail = LEFT(@Detail + N'|Released:' + CAST(@RelTotal AS NVARCHAR(12)) + N':'
		              + ISNULL(STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200)) FROM @Rel r
		                              JOIN Department d ON d.DepartmentId = r.DepartmentId ORDER BY d.DepartmentName
		                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_SetUserStatusByUserId: the step 53 text
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - deactivate / activate (UserProtection-Stage1; UserHistory-Step39)
-------------------------------------------------------------------------------
-- UserHistory-Step39: Deactivate closes every open role and department row (D). Activate of an
-- inactive user is refused while the home department is inactive (Reason 23,
-- 'HomeDepartmentInactive:<name>'); otherwise it opens the role row (Users.RoleId) and the home
-- department, and for a Manager the other departments closed by the last deactivation; one that is
-- inactive now is skipped and named in ReasonDetail ('NotRestored:<names>'). Rows that are already
-- open are kept (an active user's Activate opens nothing).
-- ManagerRelease-Step52 (step MR1, owner 2026-11-19; UD1a had no check here): Deactivate of an active Manager is
-- refused by rule 12 as a role change away from Manager is (fn_ManagerReleaseRefusal, the department part and the
-- personal part): Reason 24, ReasonDetail 'open:<n>|past:<n>|<department part>', the same as spr_AddEditUser.
-- DepartmentApprovers-Step53 (step UD1b): rule 12 refuses only for the items no other Manager of the department could
-- decide. An allowed Deactivate of a Manager marks his rows on the alerts of items at AC 'N' (no longer Manager of the
-- department) in the same transaction; the successful ReasonDetail ends with '|Released:<n>:<department names>'. An
-- Activate of a Manager gives him a row on the alert of every item waiting at AC in his departments
-- (spr_SetManagerAlertRows; his own 'N' row is opened again).
CREATE OR ALTER PROCEDURE [dbo].[spr_SetUserStatusByUserId]
@UserId INT,
@AccountStatus INT,
@ActingUserId INT,
@OutResult INT = NULL OUTPUT,
@OutReason INT = NULL OUTPUT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @Locked INT;
DECLARE @OldActive INT;
DECLARE @HomeId INT;
DECLARE @RoleIdNow INT;
DECLARE @IsManager INT;
DECLARE @LastClosed DATETIME;
DECLARE @Today DATE;
DECLARE @Now DATETIME;
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @Restore TABLE (DepartmentId INT NOT NULL PRIMARY KEY, Active INT NOT NULL, DepartmentName NVARCHAR(200));
DECLARE @Refusal TABLE (Kind CHAR(1), DepartmentId INT NULL, DepartmentName NVARCHAR(200), Items INT);
DECLARE @Rel TABLE (DepartmentId INT NOT NULL PRIMARY KEY);   -- DepartmentApprovers-Step53
DECLARE @RelDept INT;
DECLARE @RelCount INT;
DECLARE @RelTotal INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';
	SET @RelTotal = 0;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @Now = GETDATE();

	IF (@AccountStatus IS NULL OR @AccountStatus NOT IN (0, 1))
	BEGIN
		RAISERROR('spr_SetUserStatusByUserId: @AccountStatus must be 0 (inactive) or 1 (active).', 16, 1);
		RETURN;
	END

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

			SELECT @OldActive = ISNULL(AccountStatus, 0), @HomeId = DepartmentId, @RoleIdNow = RoleId
			FROM Users WITH (UPDLOCK, HOLDLOCK) WHERE UserId = @UserId;

			-- ManagerRelease-Step52: rule 12 on Deactivate of an active Manager, under the same lock as a role change
			IF (@Reason = 0 AND @AccountStatus = 0 AND @OldActive = 1
			    AND EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager'))
			BEGIN
				SELECT @Locked = COUNT(*) FROM User_Department WITH (UPDLOCK, HOLDLOCK)
				WHERE EffectiveTo IS NULL
				AND DepartmentId IN (SELECT DepartmentId FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL);

				INSERT INTO @Refusal (Kind, DepartmentId, DepartmentName, Items)
				SELECT Kind, DepartmentId, DepartmentName, Items FROM dbo.fn_ManagerReleaseRefusal(@UserId, NULL, 1);

				IF EXISTS (SELECT 1 FROM @Refusal)
				BEGIN
					SET @Reason = 24;
					-- ManagerRelease-Step52: 'open:<n>|past:<n>|' and then the department part as before ('last active
					-- Manager of <names with counts>', or nothing). open: Kind 'P', past: Kind 'Q'. The page builds the message.
					SET @Detail = N'open:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'P'), 0) AS NVARCHAR(12))
					            + N'|past:' + CAST(ISNULL((SELECT SUM(Items) FROM @Refusal WHERE Kind = 'Q'), 0) AS NVARCHAR(12))
					            + N'|'
					            + ISNULL(N'last active Manager of '
					              + STUFF((SELECT N', ' + r.DepartmentName + N' (' + CAST(r.Items AS NVARCHAR(12))
					                              + CASE WHEN r.Items = 1 THEN N' item waiting)' ELSE N' items waiting)' END
					                       FROM @Refusal r WHERE r.Kind = 'D' ORDER BY r.DepartmentName
					                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N'');
					SET @Detail = LEFT(@Detail, 2000);
				END
			END

			-- UserHistory-Step39: no activation into an inactive home department
			IF (@Reason = 0 AND @AccountStatus = 1 AND @OldActive = 0
			    AND EXISTS (SELECT 1 FROM Department WHERE DepartmentId = @HomeId AND ISNULL(StatusId, 0) <> 1))
			BEGIN
				SET @Reason = 23;
				SET @Detail = LEFT(N'HomeDepartmentInactive:' + ISNULL((SELECT CAST(DepartmentName AS NVARCHAR(200)) FROM Department WHERE DepartmentId = @HomeId), N''), 2000);
			END

			IF (@Reason = 0)
			BEGIN
				UPDATE Users SET
				AccountStatus = @AccountStatus,
				UpdatedOn = GETDATE(),
				UpdatedBy = @ActingUserId
				WHERE
				UserId = @UserId;

				SET @Result = CASE WHEN @@ROWCOUNT = 1 THEN 1 ELSE 0 END;

				-- History (UserHistory-Step39)
				IF (@Result = 1 AND @AccountStatus = 0)
				BEGIN
					UPDATE User_Role SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;

					UPDATE User_Department SET EffectiveTo = @Today, ClosedOn = @Now, ClosedBy = @ActingUserId, CloseReason = 'D'
					WHERE UserId = @UserId AND EffectiveTo IS NULL;

					-- DepartmentApprovers-Step53: a deactivated Manager's waiting approval alerts are closed for him ('N')
					IF (@OldActive = 1 AND EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager'))
					BEGIN
						INSERT INTO @Rel (DepartmentId)
						SELECT DISTINCT a.DepartmentId
						FROM Alert_User_Map m
						JOIN Alert_Master am ON am.AlertId = m.AlertId
						JOIN Agenda a ON am.SourceType = 'Agenda' AND a.AgendaId = am.SourceTypeId
						WHERE m.UserId = @UserId AND m.HandledReason IS NULL AND a.AgendaStatusCode = 'AC'
						  AND a.DepartmentId IS NOT NULL;

						SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel);
						WHILE (@RelDept IS NOT NULL)
						BEGIN
							EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @DepartmentId = @RelDept, @Release = 1,
							     @ActingUserId = @ActingUserId, @Released = @RelCount OUTPUT;
							SET @RelTotal = @RelTotal + ISNULL(@RelCount, 0);
							SET @RelDept = (SELECT MIN(DepartmentId) FROM @Rel WHERE DepartmentId > @RelDept);
						END
					END
				END

				-- DepartmentApprovers-Step53: an activated Manager gets his rows of the items waiting at AC in his departments
				-- (after his department rows are opened below)
				IF (@Result = 1 AND @AccountStatus = 1)
				BEGIN
					IF NOT EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Role WHERE UserId = @UserId)
						INSERT INTO User_Role (UserId, RoleId, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @RoleIdNow, @Today, @Now, @ActingUserId);

					IF NOT EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId AND EffectiveTo IS NULL)
					   AND EXISTS (SELECT 1 FROM User_Department WHERE UserId = @UserId)
					BEGIN
						INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
						VALUES (@UserId, @HomeId, 1, @Today, @Now, @ActingUserId);

						SET @IsManager = CASE WHEN EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager') THEN 1 ELSE 0 END;

						IF (@IsManager = 1)
						BEGIN
							SET @LastClosed = (SELECT MAX(ClosedOn) FROM User_Department WHERE UserId = @UserId AND CloseReason = 'D');

							INSERT INTO @Restore (DepartmentId, Active, DepartmentName)
							SELECT DISTINCT ud.DepartmentId, CASE WHEN ISNULL(d.StatusId, 0) = 1 THEN 1 ELSE 0 END, CAST(d.DepartmentName AS NVARCHAR(200))
							FROM User_Department ud
							JOIN Department d ON d.DepartmentId = ud.DepartmentId
							WHERE ud.UserId = @UserId AND ud.CloseReason = 'D' AND ud.ClosedOn = @LastClosed
							  AND ud.DepartmentId <> @HomeId;

							INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, CreatedOn, CreatedBy)
							SELECT @UserId, r.DepartmentId, 0, @Today, @Now, @ActingUserId
							FROM @Restore r WHERE r.Active = 1;

							IF EXISTS (SELECT 1 FROM @Restore WHERE Active = 0)
								SET @Detail = LEFT(N'NotRestored:'
								              + STUFF((SELECT N', ' + r.DepartmentName FROM @Restore r WHERE r.Active = 0 ORDER BY r.DepartmentName
								                       FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), 2000);
						END
					END

					IF EXISTS (SELECT 1 FROM Roles WHERE RoleId = @RoleIdNow AND RoleCode = 'manager')
						EXEC dbo.spr_SetManagerAlertRows @UserId = @UserId, @ActingUserId = @ActingUserId;   -- DepartmentApprovers-Step53
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
				ROLLBACK TRANSACTION SetUserStatus;

			RAISERROR('%s', 16, 1, @ErrMsg);
			RETURN;
		END CATCH
	END


	-- DepartmentApprovers-Step53: '|Released:<n>:<department names>' at the end of a successful detail
	IF (@Result = 1 AND @RelTotal > 0)
		SET @Detail = LEFT(@Detail + N'|Released:' + CAST(@RelTotal AS NVARCHAR(12)) + N':'
		              + ISNULL(STUFF((SELECT N', ' + CAST(d.DepartmentName AS NVARCHAR(200)) FROM @Rel r
		                              JOIN Department d ON d.DepartmentId = r.DepartmentId ORDER BY d.DepartmentName
		                              FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(2000)'), 1, 2, N''), N''), 2000);

	SET @OutResult = @Result;
	SET @OutReason = @Reason;

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_DeleteUserByUserId: the step 47 text
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Users - delete (UserHistory-Step39)
-------------------------------------------------------------------------------
-- Users - delete (FK #5, FK#5-UserDelete-AllColumns, UserProtection-Stage1)
-- UserHistory-Step39: rows the user wrote in another user's role or department history (CreatedBy /
-- ClosedBy) are history: Reason 6, group 'user changes'. The user's own User_Role and User_Department
-- rows go with an otherwise unused user.
-- FollowupFinal-Step47: rows the user wrote in Action_Item_Status_History (ActedBy: a Confirm or a Reopen on the
-- Followup page) are history in the group 'minutes' (Reason 6); its foreign key to Users would refuse the delete otherwise.
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
DECLARE @ErrMsg NVARCHAR(2048);
DECLARE @ErrNo INT;
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
				   OR EXISTS (SELECT 1 FROM Action_Item_Status_History WHERE ActedBy = @UserId)   -- FollowupFinal-Step47
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
				IF EXISTS (SELECT 1 FROM User_Role WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
				   OR EXISTS (SELECT 1 FROM User_Department WHERE UserId <> @UserId AND (CreatedBy = @UserId OR ClosedBy = @UserId))
					SET @Detail = @Detail + N', user changes';

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

				-- The user's own role and department history (UserHistory-Step39)
				DELETE FROM User_Department WHERE UserId = @UserId;

				DELETE FROM User_Role WHERE UserId = @UserId;

				DELETE FROM Users WHERE UserId = @UserId;

				SET @Result = 1;
			END

			-- A refusal changed nothing, so there is nothing to roll back.
			IF (@OwnTransaction = 1)
				COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			SET @ErrMsg = ERROR_MESSAGE();
			SET @ErrNo = ERROR_NUMBER();

			IF (@OwnTransaction = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
					ROLLBACK TRANSACTION;
			END
			ELSE IF (XACT_STATE() = 1)
				ROLLBACK TRANSACTION DeleteUser;

			-- 547 = a foreign key the checks above do not know still points at
			-- the user. Anything else is a real error and is passed on.
			IF (@ErrNo <> 547)
			BEGIN
				RAISERROR('%s', 16, 1, @ErrMsg);
				RETURN;
			END

			SET @Result = 0;
			SET @Reason = 9;
			SET @Detail = LEFT(@ErrMsg, 2000);
		END CATCH
	END

	SET @OutResult = @Result;
	SET @OutReason = @Reason;
	SET @OutReasonDetail = @Detail;

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_AddEditDepartment: the baseline text
-------------------------------------------------------------------------------
GO




ALTER PROCEDURE [dbo].[spr_AddEditDepartment]
@Code VARCHAR(50),
@DepartmentId INT,
@DepartmentCode VARCHAR(10),
@DepartmentName VARCHAR(50), 
@OrderNo INT,
@StatusId INT,
@CreatedOn DATETIME,
@CreatedBy INT,
@UpdatedOn DATETIME,
@UpdatedBy INT
AS
BEGIN
	IF (@Code = 'Save') 
	BEGIN
		INSERT INTO Department
		(DepartmentCode, DepartmentName, OrderNo,
			StatusId, CreatedOn, CreatedBy)
		VALUES
		(@DepartmentCode, @DepartmentName, @OrderNo,
			@StatusId, @CreatedOn, @CreatedBy);
		
	END
	IF (@Code = 'Update') 
	BEGIN
		UPDATE Department SET
		DepartmentCode = @DepartmentCode,
		DepartmentName = @DepartmentName, 
		OrderNo = @OrderNo,
		StatusId = @StatusId,
		UpdatedOn = @UpdatedOn, 
		UpdatedBy = @UpdatedBy
		WHERE
		DepartmentId = @DepartmentId;
	END

END




GO

-------------------------------------------------------------------------------
-- spr_SetDepartmentManagerRule: the step 39 text
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Settings - DeptNoManagerAction, rule 6 (UserHistory-Step39); only an active Admin.
-------------------------------------------------------------------------------
-- Values 'refuse' (default) and 'controller'. Stored only: nothing reads it until a later step.
-- One row Result, Reason, ReasonDetail as spr_SetAppSetting: 8 acting user missing or inactive,
-- 4 not an Admin, 3 value not valid (ReasonDetail the value). A change writes one Audit_Trail_Master
-- row (Audit_Table 'App_Setting'); saving the same value writes none.
CREATE OR ALTER PROCEDURE [dbo].[spr_SetDepartmentManagerRule]
@SettingValue VARCHAR(250),
@ActingUserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldValue VARCHAR(250);
DECLARE @ErrMsg NVARCHAR(2048);
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = N'';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION DeptRuleSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@SettingValue, '') NOT IN ('refuse', 'controller'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = LEFT(ISNULL(@SettingValue, 'NULL'), 250);
		END
		ELSE
		BEGIN
			SET @OldValue = (SELECT SettingValue FROM App_Setting WITH (UPDLOCK, HOLDLOCK) WHERE SettingCode = 'DeptNoManagerAction');

			IF (@OldValue IS NULL)
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				VALUES ('DeptNoManagerAction', @SettingValue, 'When a department has no active Manager: refuse the item (refuse, default) or send it to the Controllers (controller). Stored now, used from a later step (step 39)');
			ELSE
				UPDATE App_Setting SET SettingValue = @SettingValue WHERE SettingCode = 'DeptNoManagerAction';

			IF (ISNULL(@OldValue, '') <> @SettingValue)
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', 'DeptNoManagerAction', 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

			SET @Result = 1;
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
			ROLLBACK TRANSACTION DeptRuleSave;

		RAISERROR('%s', 16, 1, @ErrMsg);
		RETURN;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, @Detail AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_SetAppSetting: the step 16 text
-------------------------------------------------------------------------------
GO

-- Settings - change one; only an active Admin (MeetingLocks-Step16)
CREATE OR ALTER PROCEDURE [dbo].[spr_SetAppSetting]
@SettingCode VARCHAR(50),
@SettingValue VARCHAR(250),
@ActingUserId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail NVARCHAR(2000);
DECLARE @OwnTransaction INT;
DECLARE @ActingRole VARCHAR(50);
DECLARE @OldValue VARCHAR(250);
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
			SAVE TRANSACTION AppSettingSave;

		SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
		                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);

		IF (@ActingRole IS NULL)
			SET @Reason = 8;
		ELSE IF (@ActingRole <> 'admin')
			SET @Reason = 4;
		ELSE IF (ISNULL(@SettingCode, '') <> 'AgendaControllerBypass' OR ISNULL(@SettingValue, '') NOT IN ('0', '1'))
		BEGIN
			SET @Reason = 3;
			SET @Detail = ISNULL(@SettingValue, 'NULL');
		END
		ELSE
		BEGIN
			SET @OldValue = (SELECT SettingValue FROM App_Setting WITH (UPDLOCK, HOLDLOCK) WHERE SettingCode = @SettingCode);

			IF (@OldValue IS NULL)
				INSERT INTO App_Setting (SettingCode, SettingValue, Description)
				VALUES (@SettingCode, @SettingValue, 'Controller can add, edit and delete agenda items after the agenda is finalized (until the minutes are finalized)');
			ELSE
				UPDATE App_Setting SET SettingValue = @SettingValue WHERE SettingCode = @SettingCode;

			IF (ISNULL(@OldValue, '') <> @SettingValue)
				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				VALUES
					('UP', 'App_Setting', 'SettingCode', @SettingCode, 'SettingValue', ISNULL(@OldValue, ''), @SettingValue, @ActingUserId, GETDATE());

			SET @Result = 1;
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
			ROLLBACK TRANSACTION AppSettingSave;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

-------------------------------------------------------------------------------
-- spr_sys_ResetDatabase: the step 39 text
-------------------------------------------------------------------------------
GO

-------------------------------------------------------------------------------
-- Reset Database (UserHistory-Step39), the step 30 text plus the history tables
-------------------------------------------------------------------------------
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
-- UserHistory-Step39: User_Role and User_Department are cleared before Users, their counters start again
-- at the seed (as the five tables TRUNCATE used to clear), and each seed user gets one open row in each,
-- dated today, created by user 1 (the system account), the home department marked IsHome = 1.
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
	DELETE FROM User_Department;
	DELETE FROM User_Role;
	DELETE FROM Users;
	DELETE FROM Department;
	DELETE FROM Designation;
	DELETE FROM Subject_Type;
	DELETE FROM Roles;

	---------------------------------------------------------------------------
	-- 2. Identity counters, all after the clearing
	---------------------------------------------------------------------------
	-- The five tables TRUNCATE used to clear: a used counter starts again at its seed, as TRUNCATE did;
	-- the two history tables of step 39 the same way (UserHistory-Step39)
	DECLARE SeedCursor CURSOR LOCAL FAST_FORWARD FOR
		SELECT TableName, SeedValue, IncrementValue FROM @Ident
		WHERE SavedValue IS NOT NULL
		  AND TableName IN ('ActionItem_User_Map', 'Alert_User_Map', 'Meeting_Member', 'Committee_Member', 'Attendance',
		                    'User_Role', 'User_Department');

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

-- UserHistory-Step39: one open role row and one open home department row per seed user
INSERT INTO [User_Role] ([UserId], [RoleId], [EffectiveFrom], [CreatedOn], [CreatedBy])
SELECT u.UserId, u.RoleId, CAST(GETDATE() AS DATE), GETDATE(), 1 FROM Users u;

INSERT INTO [User_Department] ([UserId], [DepartmentId], [IsHome], [EffectiveFrom], [CreatedOn], [CreatedBy])
SELECT u.UserId, u.DepartmentId, 1, CAST(GETDATE() AS DATE), GETDATE(), 1 FROM Users u;


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

-------------------------------------------------------------------------------
-- The functions and procedures of step 56 (the table, its rows and the setting row stay)
-------------------------------------------------------------------------------
IF OBJECT_ID('dbo.spr_GetGovernanceLogUsers', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetGovernanceLogUsers;
IF OBJECT_ID('dbo.spr_GetGovernanceChangeLog', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetGovernanceChangeLog;
IF OBJECT_ID('dbo.spr_GetGovernanceDepartments', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetGovernanceDepartments;
IF OBJECT_ID('dbo.spr_GetGovernanceSettings', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetGovernanceSettings;
IF OBJECT_ID('dbo.spr_GetGovernanceMatrix', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_GetGovernanceMatrix;
IF OBJECT_ID('dbo.spr_WriteGovernanceUserChanges', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_WriteGovernanceUserChanges;
IF OBJECT_ID('dbo.spr_WriteGovernanceChange', 'P') IS NOT NULL DROP PROCEDURE dbo.spr_WriteGovernanceChange;
IF OBJECT_ID('dbo.fn_GovernanceRefusal', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceRefusal;
IF OBJECT_ID('dbo.fn_GovernanceMatrixPeople', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceMatrixPeople;
IF OBJECT_ID('dbo.fn_GovernanceRoleHolders', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceRoleHolders;
IF OBJECT_ID('dbo.fn_DepartmentActiveOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_DepartmentActiveOn;
IF OBJECT_ID('dbo.fn_SettingOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_SettingOn;
IF OBJECT_ID('dbo.fn_ReportingPersonOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_ReportingPersonOn;
IF OBJECT_ID('dbo.fn_DepartmentManagersOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_DepartmentManagersOn;
IF OBJECT_ID('dbo.fn_UserDepartmentsOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_UserDepartmentsOn;
IF OBJECT_ID('dbo.fn_UserRoleOn', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_UserRoleOn;
IF OBJECT_ID('dbo.fn_GovernanceHistoryStart', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceHistoryStart;
IF OBJECT_ID('dbo.fn_GovernanceUserSummary', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceUserSummary;
IF OBJECT_ID('dbo.fn_GovernanceDeptList', 'FN') IS NOT NULL DROP FUNCTION dbo.fn_GovernanceDeptList;
GO

-------------------------------------------------------------------------------
-- Compare the seven texts with those step 56 was built from
-------------------------------------------------------------------------------
DECLARE @D NVARCHAR(MAX), @I INT, @H VARCHAR(400), @Name SYSNAME, @Bad NVARCHAR(400), @Left INT;
DECLARE @Texts TABLE (Name SYSNAME, Hash VARCHAR(400) NULL, BuiltFrom VARCHAR(400));

INSERT INTO @Texts (Name, BuiltFrom) VALUES
('spr_AddEditUser', 'B7B728AECA90F66BC2B8BF260367087E8163D4BAED1D0B4D6F988CFD57AAE69E97780A47B4FEC048E893F07F33E7A83575408407BB7CB230E1F08F8D3973EC5A4971EE4E7EA5007668C3B4333630BEE62629469F19159239D87F3E1AA8A02C96C62C94D8'),
('spr_SetUserStatusByUserId', 'CBA0ECF3B91A1EB7FCFD85DDA18EF98D919A8C5EC1560A285DF4D8EFFDA1E134AE708FAF985133B070649ED0C78131B7B012E830BEBE99723B0773C0'),
('spr_DeleteUserByUserId', '33692C6B212590B65700F968F0A17A4B77C6B62A52180DD11D96D7C1057372273F1392791D25C595'),
('spr_AddEditDepartment', 'A286A255ADC713F7AAD861F5EDB32DAB11724F45'),
('spr_SetDepartmentManagerRule', '9E1F423421452F943E15EE9D341A323FA9AA6D8F'),
('spr_SetAppSetting', '66592EA6229BE421FC71A8DB14CB2005B2735DED'),
('spr_sys_ResetDatabase', 'ACFC620D8AA0877942AB02B40F21FBA97737EEB0F61B05B73F436CEDD14467D16E3E8107E1AFE27BC598AD998CEABED6CC4D072F69EC8B1667E36D2EDF19405C7F1FFB81A77F9123CC1CD66C8D9786AFAC752FAD72B8CDC83232763038760E6150C65498');

SET @Name = (SELECT MIN(Name) FROM @Texts);
WHILE (@Name IS NOT NULL)
BEGIN
    SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.' + @Name)), CHAR(13), ''); SET @H = ''; SET @I = 1;
    WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
    BEGIN
        SET @H = @H + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
        SET @I = @I + 4000;
    END
    UPDATE @Texts SET Hash = @H WHERE Name = @Name;
    SET @Name = (SELECT MIN(Name) FROM @Texts WHERE Name > @Name);
END

SET @Bad = STUFF((SELECT N', ' + t.Name FROM @Texts t WHERE ISNULL(t.Hash, '') <> t.BuiltFrom ORDER BY t.Name
                  FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(400)'), 1, 2, N'');
SET @Left = (SELECT COUNT(*) FROM sys.sql_modules m WHERE m.definition LIKE '%GovernanceLog-Step56%');

DECLARE @Rows INT;
SET @Rows = (SELECT COUNT(*) FROM dbo.Governance_Change_Log);
SET @Bad = ISNULL(@Bad, N'none');

IF (@Bad <> N'none' OR @Left > 0)
    RAISERROR('Rollback of step 56 NOT complete: texts not equal to those step 56 was built from: %s; objects still carrying GovernanceLog-Step56: %d. Tell the Consultant.', 16, 1, @Bad, @Left);
ELSE
    PRINT 'Step 56 rolled back: the seven texts are letter for letter those step 56 was built from; the 19 new objects are dropped. The table Governance_Change_Log ('
          + CAST(@Rows AS VARCHAR(12)) + ' rows) and the setting GovernanceLogFrom are kept.';
GO

SET NOEXEC OFF;
GO
