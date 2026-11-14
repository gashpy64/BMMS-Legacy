/* ============================================================================
   BMMS - Test of step 44 (Dashboard My approvals and Waiting for me,
   step UN6c2a)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 44
   is not installed.

   Run it in a NEW query window (it uses temporary tables of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS (the row about the login itmgruser reads SKIPPED in a
   database that does not have that account).

   Part 1 reads only: the markers (those of step 44 and those of the earlier
   steps in the two replaced procedures), parameters and result columns; that
   the objects step 44 does not change carry no marker; that every database
   user who can run step 42's procedure can run the procedures of this step.

   Part 2:
     - on the data of the database, read only: for every active user and every
       agenda item, fn_AgendaWaitingFor gives what the rule of step 20 gives;
     - inside ONE transaction that is rolled back:
       * the approval procedure as it was before step 44 is installed under a
         temporary name, and both procedures are run on the same cases (every
         kind of acting user, every status, routing by manager, by an alert
         row, by a REMOVED alert row and no routing, approve and reject by the
         Manager and by the Controller, an open and a finalised agenda, a
         passed meeting date, an unknown item): Result, Reason, ReasonDetail
         and everything written must be the same in every case;
       * the items of the departments of the login itmgruser that are not
         routed to him: the new procedure refuses each with Reason 14;
       * the function's flags, the My approvals procedure (roles, filters,
         paging, refusals), the approval state for the Agenda Alert panel;
       * the meeting list: every column of before unchanged (the earlier text
         beside the new one), and WaitingForMe;
       * the Rollback's two batches (the texts of steps 35 and 42) run here,
         and their SHA-1 is compared with the texts step 44 was built from;
         the rollback of the transaction puts step 44 back.

   Afterwards: nothing of ZZ44 is left, the agenda and alert tables are
   unchanged and every identity counter is put back.

   It has no USE line: select the TEST database in SSMS first. Written for
   compatibility level 100. Plain ASCII. From the command line use sqlcmd -I.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.fn_AgendaWaitingFor', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_GetAgendaApprovalState', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardApprovals', 'P') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%AgendaWaitingFor-Step44%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), '') NOT LIKE '%AgendaWaitingFor-Step44%')
BEGIN
    RAISERROR('Step 44 (BMMS-Fix-AgendaWaitingFor-Step44.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('tempdb..#T') IS NOT NULL OR OBJECT_ID('tempdb..#Ident') IS NOT NULL OR OBJECT_ID('tempdb..#AP') IS NOT NULL
         OR OBJECT_ID('tempdb..#MT') IS NOT NULL OR OBJECT_ID('tempdb..#MO') IS NOT NULL)
BEGIN
    RAISERROR('This query window still has temporary tables of an earlier run. Open a NEW query window and run the script there. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #AP (RowNo INT, AgendaId INT, AgendaNo VARCHAR(50), SubjectNo INT, ShortText NVARCHAR(MAX), AgendaStatusCode VARCHAR(50),
                  CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingId INT, MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, DepartmentId INT, DepartmentName NVARCHAR(200), AlertId INT);
CREATE TABLE #MT (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, MeetingTime VARCHAR(50), AgendaSubmissionDate DATETIME, ListCode CHAR(1), StateCode VARCHAR(50),
                  StateLabel VARCHAR(100), Items INT, Approved INT, Rejected INT, Pending INT, WaitingForMe INT);
CREATE TABLE #MO (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), MeetingNo VARCHAR(50),
                  MeetingDate DATETIME, MeetingTime VARCHAR(50), AgendaSubmissionDate DATETIME, ListCode CHAR(1), StateCode VARCHAR(50),
                  StateLabel VARCHAR(100), Items INT, Approved INT, Rejected INT, Pending INT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T SELECT 'Marker AgendaWaitingFor-Step44 in the three new objects and the two replaced procedures', '5',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_AgendaWaitingFor'), ('spr_GetAgendaApprovalState'), ('spr_GetDashboardApprovals'),
                                          ('spr_UpdateAgendaByAgendaId'), ('spr_GetDashboardMeetings')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%AgendaWaitingFor-Step44%') AS VARCHAR(12));

INSERT INTO #T SELECT 'spr_UpdateAgendaByAgendaId keeps the markers of steps 16, 17, 18, 20, 31 and 35; spr_GetDashboardMeetings that of step 42', '6 of 6, 1 of 1',
       CAST((SELECT COUNT(*) FROM (VALUES ('MeetingLocks-Step16'), ('UserStatus2b-Step17'), ('SystemAccount3-Step18'), ('AgendaRouting-Step20'),
                                          ('UnicodeText-Step31'), ('CommentAuthor-Step35')) k(Marker)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) LIKE '%' + k.Marker + '%') AS VARCHAR(12)) + ' of 6, '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')) LIKE '%DashboardMeetings-Step42%' THEN '1' ELSE '0' END + ' of 1';

INSERT INTO #T SELECT 'Parameters (all, OUTPUT): function 2 0, state 8 6, approvals 8 4, approve 8 0, meetings 8 5', '2 0, 8 6, 8 4, 8 0, 8 5',
       STUFF((SELECT ', ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.parameter_id > 0) AS VARCHAR(12))
                     + ' ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.is_output = 1 AND p.parameter_id > 0) AS VARCHAR(12))
              FROM (VALUES (1, 'fn_AgendaWaitingFor'), (2, 'spr_GetAgendaApprovalState'), (3, 'spr_GetDashboardApprovals'),
                           (4, 'spr_UpdateAgendaByAgendaId'), (5, 'spr_GetDashboardMeetings')) o(Seq, Name)
              ORDER BY o.Seq FOR XML PATH('')), 1, 2, '');

INSERT INTO #T SELECT 'spr_UpdateAgendaByAgendaId: the eight parameters of before, in their order', '@AgendaId,@ShortText,@ProposedResolution,@MgrComments,@ControllerComments,@ControllerApprovedStatus,@MgrApprovedStatus,@UpdatedBy',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

INSERT INTO #T SELECT 'spr_GetDashboardMeetings: the seven parameters of before in their order, then @WaitingShown', '@ActingUserId,@CommitteeId,@DepartmentId,@Result,@Reason,@StatisticsShown,@ActingRoleCode,@WaitingShown',
       STUFF((SELECT ',' + p.name FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.spr_GetDashboardMeetings') ORDER BY p.parameter_id FOR XML PATH('')), 1, 1, '');

DECLARE @Cols VARCHAR(MAX);
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardMeetings'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardMeetings: the fifteen result columns of before in their order, then WaitingForMe',
       'MeetingId,CommitteeId,CommitteeCode,CommitteeName,MeetingNo,MeetingDate,MeetingTime,AgendaSubmissionDate,ListCode,StateCode,StateLabel,Items,Approved,Rejected,Pending,WaitingForMe',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardApprovals'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardApprovals: the result columns the page reads, in this order',
       'RowNo,AgendaId,AgendaNo,SubjectNo,ShortText,AgendaStatusCode,CommitteeId,CommitteeCode,CommitteeName,MeetingId,MeetingNo,MeetingDate,DepartmentId,DepartmentName,AlertId',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_AgendaWaitingFor') ORDER BY c.column_id;
INSERT INTO #T SELECT 'fn_AgendaWaitingFor: its columns',
       'AgendaId,MeetingId,CommitteeId,DepartmentId,AgendaStatusCode,UserId,CanApprove,CanReject,AgendaOpen,DateOpen,IsWaiting',
       ISNULL(@Cols, 'none');

INSERT INTO #T SELECT 'Not changed by step 44 (no marker): the functions of step 42, the department list, the three procedures that save an item, the alert list and count, spr_UpdateAlertByUserId', '0 of 10',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_UserDepartmentScope'), ('fn_AgendaStatusGroup'), ('fn_MeetingDashboardState'), ('spr_GetDashboardDepartments'),
                                          ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'),
                                          ('fn_DashboardAlerts'), ('spr_GetAlertCount'), ('spr_UpdateAlertByUserId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), 'AgendaWaitingFor-Step44') LIKE '%AgendaWaitingFor-Step44%') AS VARCHAR(12)) + ' of 10';

INSERT INTO #T SELECT 'No DENY of EXECUTE or SELECT on the five objects', '0',
       CAST((SELECT COUNT(*) FROM sys.database_permissions pe
             WHERE pe.class = 1 AND pe.state = 'D'
             AND pe.major_id IN (OBJECT_ID('dbo.fn_AgendaWaitingFor'), OBJECT_ID('dbo.spr_GetAgendaApprovalState'), OBJECT_ID('dbo.spr_GetDashboardApprovals'),
                                 OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_GetDashboardMeetings'))) AS VARCHAR(12));
GO

-- The two replaced procedures are no longer the earlier texts (SHA-1 in pieces of 4,000 characters)
DECLARE @D NVARCHAR(MAX), @I INT;
DECLARE @AgendaHash VARCHAR(400), @MeetHash VARCHAR(400);

-- The two procedures as they are now: SHA-1 of the text without carriage returns, in pieces of 4,000 characters
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), CHAR(13), ''); SET @AgendaHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @AgendaHash = @AgendaHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END
SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''); SET @MeetHash = ''; SET @I = 1;
WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
BEGIN
    SET @MeetHash = @MeetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
    SET @I = @I + 4000;
END

INSERT INTO #T SELECT 'The two replaced procedures are not the earlier texts any more (SHA-1 differs from steps 35 and 42)', 'differs, differs',
       CASE WHEN @AgendaHash = '763564301F411D7CC3D94064BB115F4C23EC028A757040AD9F753B4E63B8652C378D7B74305741E8A4D1FE63C03B201B1FEDB06B4DA27D7EB55874F4' THEN 'same' ELSE 'differs' END + ', '
     + CASE WHEN @MeetHash = 'A174C0B06EA28F9C2B914B6C581F74D2D1F4788A4BDBA6D90C4878E28B72831FFC6C1866F007CE47' THEN 'same' ELSE 'differs' END;
GO

-- Every database user who can run step 42's spr_GetDashboardMeetings (the application login among them) can run the
-- four procedures of this step. Asked of the server as that user (EXECUTE AS USER), so a schema grant counts.
DECLARE @Name SYSNAME, @Can INT, @Users INT = 0, @Cannot INT = 0, @Names VARCHAR(500) = '';
DECLARE UserCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT dp.name FROM sys.database_principals dp
    WHERE dp.type IN ('S', 'U', 'G') AND dp.name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA');
OPEN UserCursor;
FETCH NEXT FROM UserCursor INTO @Name;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    BEGIN TRY
        EXECUTE AS USER = @Name;
        SET @Can = CASE WHEN HAS_PERMS_BY_NAME('dbo.spr_GetDashboardDepartments', 'OBJECT', 'EXECUTE') = 1 THEN
                        HAS_PERMS_BY_NAME('dbo.spr_GetAgendaApprovalState', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardApprovals', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_UpdateAgendaByAgendaId', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardMeetings', 'OBJECT', 'EXECUTE') ELSE -1 END;
        REVERT;
        IF (@Can >= 0) SET @Users = @Users + 1;
        IF (@Can >= 0 AND @Can < 4)
        BEGIN
            SET @Cannot = @Cannot + 1;
            SET @Names = LEFT(@Names + ' ' + @Name, 500);
        END
    END TRY
    BEGIN CATCH
        -- a user that cannot be impersonated (no login behind it) cannot sign in either: not counted
        SET @Can = -1;
    END CATCH
    FETCH NEXT FROM UserCursor INTO @Name;
END
CLOSE UserCursor;
DEALLOCATE UserCursor;
INSERT INTO #T SELECT 'EXECUTE: database users who can run step 42''s department procedure but not all four procedures of step 44 (' + CAST(@Users AS VARCHAR(12)) + ' such users asked)',
       '0', CAST(@Cannot AS VARCHAR(12)) + CASE WHEN @Cannot > 0 THEN ':' + @Names ELSE '' END;
GO

-------------------------------------------------------------------------------
-- Part 2
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(300), Expected VARCHAR(1000), Actual VARCHAR(1000));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @Actors TABLE (Label VARCHAR(20) PRIMARY KEY, UserId INT NULL);
DECLARE @Items TABLE (Label VARCHAR(20) PRIMARY KEY, AgendaId INT);
DECLARE @Actions TABLE (Label VARCHAR(30) PRIMARY KEY, M VARCHAR(50) NULL, C VARCHAR(50) NULL);
DECLARE @Case TABLE (Actor VARCHAR(20), Item VARCHAR(20), Act VARCHAR(30), OldRR VARCHAR(60), NewRR VARCHAR(60), OldOut NVARCHAR(MAX), NewOut NVARCHAR(MAX));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DA INT, @DB INT, @Com INT, @MOpen INT, @MPast INT, @MFin INT, @MNull INT;
DECLARE @Ctl INT, @Mg1 INT, @Mg2 INT, @Mg3 INT, @Mg4 INT, @Usr INT, @Gmt INT, @Mds INT, @Adm INT, @Off INT;
DECLARE @Res INT, @Rsn INT, @Total INT, @Page INT, @Shown INT, @Wait INT, @CanA INT, @CanR INT, @AgOpen INT, @DtOpen INT;
DECLARE @Role VARCHAR(50), @Txt VARCHAR(1000), @Id INT, @N INT, @Refused INT;
DECLARE @cActor VARCHAR(20), @cUser INT, @cItem VARCHAR(20), @cAgenda INT, @cAct VARCHAR(30), @cM VARCHAR(50), @cC VARCHAR(50);
DECLARE @OldRR VARCHAR(60), @NewRR VARCHAR(60), @OldOut NVARCHAR(MAX), @NewOut NVARCHAR(MAX);
DECLARE @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60), @AuditBefore VARCHAR(60), @AuditAfter VARCHAR(60);
DECLARE @D NVARCHAR(MAX), @I INT, @AgendaHash VARCHAR(400), @MeetHash VARCHAR(400);
DECLARE @OldAgenda NVARCHAR(MAX), @OldMeet NVARCHAR(MAX), @OldAgendaTmp NVARCHAR(MAX), @OldMeetTmp NVARCHAR(MAX);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus, UpdatedBy, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @AuditBefore = CAST(COUNT(*) AS VARCHAR(12)) FROM Audit_Trail_Master;

-- The earlier texts (steps 35 and 42): as the Rollback script has them, and under temporary names
SET @OldAgenda = N'

-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16). New alert rows go to
-- active users only; an inactive creator''s saved row is left as it is (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account; the system account cannot
-- approve or reject (Reason 12) (SystemAccount3-Step18)
-- Who may act at which stage (AgendaRouting-Step20): a Manager approves or rejects at AC an item routed
-- to them (or of whom they are the creator''s manager); a Controller approves at AMA and rejects at AC or
-- AMA; anything else is refused (Reason 14, ReasonDetail the status name). An inactive or unknown acting
-- user is refused (Reason 8). A Controller may approve an item they created.
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX))
-- CommentAuthor-Step35: Approve and Reject record who decided and when, also with an empty comment: MgrApprovedBy and
-- MgrApprovedDate (Manager), ControllerApprovedBy and ControllerApprovedDate (Controller) are @UpdatedBy and GETDATE()
CREATE OR ALTER PROCEDURE [dbo].[spr_UpdateAgendaByAgendaId]
@AgendaId INT,
@ShortText NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@ControllerApprovedStatus varchar(50),
@MgrApprovedStatus varchar(50),
@UpdatedBy INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
	DECLARE @ControllerCommentsOld NVARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @AgendaStatus VARCHAR(50);
	DECLARE @ActingRole VARCHAR(50);
	DECLARE @StatusCode VARCHAR(50);
	DECLARE @StatusName VARCHAR(100);
	DECLARE @CreatorManagerId INT;
	DECLARE @MgrAction INT;
	DECLARE @CtlAction INT;
	DECLARE @Allowed INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '''';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaApprove;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @AgendaStatus = ISNULL(AgendaStatus, ''Open'')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- The protected system account takes no part in the workflow (SystemAccount3-Step18)
		IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND IsSystem = 1)
			SET @Reason = 12;
		-- Acting user missing or inactive (AgendaRouting-Step20)
		ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND AccountStatus = 1)
			SET @Reason = 8;
		ELSE IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> ''Open'')
		BEGIN
			SET @Reason = 5;
			SET @Detail = ''Finalized'';
		END
		ELSE
		BEGIN
			-- Who may act at which stage (AgendaRouting-Step20)
			SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @UpdatedBy);

			SELECT @StatusCode = a.AgendaStatusCode, @CreatorManagerId = c.ManagerId,
			       @StatusName = ISNULL(st.AgendaStatusName, ISNULL(a.AgendaStatusCode, ''''))
			FROM Agenda a
			LEFT JOIN Users c ON c.UserId = a.CreatedBy
			LEFT JOIN Agenda_Status st ON st.AgendaStatusCode = a.AgendaStatusCode
			WHERE a.AgendaId = @AgendaId;

			SET @MgrAction = CASE WHEN ISNULL(@MgrApprovedStatus, '''') IN (''Approved'', ''Rejected'') THEN 1 ELSE 0 END;
			SET @CtlAction = CASE WHEN ISNULL(@ControllerApprovedStatus, '''') IN (''Approved'', ''Rejected'') THEN 1 ELSE 0 END;

			-- Allowed only when a rule says so: a NULL anywhere counts as not allowed
			SET @Allowed = CASE
				WHEN @MgrAction = 1 AND @CtlAction = 0 AND ISNULL(@ActingRole, '''') = ''manager'' AND ISNULL(@StatusCode, '''') = ''AC''
				     AND (@UpdatedBy = ISNULL(@CreatorManagerId, 0)
				          OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
				                     WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = @AgendaId AND m.UserId = @UpdatedBy))
				THEN 1
				WHEN @CtlAction = 1 AND @MgrAction = 0 AND ISNULL(@ActingRole, '''') = ''controller''
				     AND (ISNULL(@StatusCode, '''') = ''AMA''
				          OR (ISNULL(@StatusCode, '''') = ''AC'' AND @ControllerApprovedStatus = ''Rejected''))
				THEN 1
				ELSE 0 END;

			IF (@Allowed = 0)
			BEGIN
				SET @Reason = 14;
				SET @Detail = ISNULL(@StatusName, '''');
			END
		END

		IF (@Reason = 0)
		BEGIN
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			IF @MgrApprovedStatus = ''Rejected''
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = ''AMR'' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = ''AMR'' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrComments'', '''', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrApprovedStatus'', '''', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @MgrApprovedStatus = ''Approved''
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = ''AMA'' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = ''AMA'' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrComments'', '''', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrApprovedStatus'', '''', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @ControllerApprovedStatus = ''Approved'' OR @ControllerApprovedStatus = ''Rejected''
			BEGIN
				UPDATE Agenda SET
					ShortText = @ShortText, ProposedResolution = @ProposedResolution,
					ControllerComments = @ControllerComments, ControllerApprovedStatus = @ControllerApprovedStatus,
					ControllerApprovedBy = @UpdatedBy, ControllerApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				IF @ControllerApprovedStatus = ''Approved''
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = ''ACA'' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = ''ACA'' WHERE AgendaId = @AgendaId;
				END
				IF @ControllerApprovedStatus = ''Rejected''
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = ''ACR'' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = ''ACR'' WHERE AgendaId = @AgendaId;
				END

				-- The creator''s row is renewed only while the creator is active (UserStatus2b-Step17)
				IF EXISTS (SELECT 1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0)
				BEGIN
					DELETE FROM Alert_User_Map WHERE UserId = @User_Id AND AlertId = @AlertId;

					INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
						VALUES (@AlertId, @User_Id, 0, 1);
				END

				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;
				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''ControllerApprovedStatus'', '''', @ControllerApprovedStatus, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''ControllerComments'', '''', @ControllerComments, @UpdatedBy, GETDATE();
			END

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
			ROLLBACK TRANSACTION AgendaApprove;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
';
SET @OldMeet = N'
-- Dashboard meeting list (DashboardMeetings-Step42, step UN6b), for all six roles. The role and the departments come
-- from the database (the acting user id); the two filters are checked against them:
--   @CommitteeId   0: every committee; otherwise it must exist (any role), else Reason 4
--   @DepartmentId  0: all of a Manager''s or a User''s departments; otherwise it must be one of them (Manager and User
--                  only), else Reason 4
-- Reason 8: acting user missing or inactive; Reason 4: a role outside the six or a filter outside the scope; then
-- no rows. Rows: every scheduled meeting (no cap), then the last 10 completed meetings for EVERY role (for a Manager
-- and a User only completed meetings with an item of the chosen department(s)). Statistics (fn_AgendaStatusGroup,
-- Pending = AC + AMA) for the Controller, Management, the Manager and the User (for the last two over the chosen
-- department(s) only); NULL and @StatisticsShown 0 for MD Secretariat and Admin.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetDashboardMeetings]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@StatisticsShown INT = NULL OUTPUT,
@ActingRoleCode VARCHAR(50) = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @Today DATE;
DECLARE @DeptScoped INT;
DECLARE @Dept TABLE (DepartmentId INT PRIMARY KEY);
DECLARE @List TABLE (MeetingId INT PRIMARY KEY, ListCode CHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @StatisticsShown = 0;
	SET @ActingRoleCode = NULL;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);
	SET @DeptScoped = CASE WHEN @ActingRole IN (''manager'', ''user'') THEN 1 ELSE 0 END;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Result = 1;
		SET @StatisticsShown = CASE WHEN @ActingRole IN (''controller'', ''mgmt'', ''manager'', ''user'') THEN 1 ELSE 0 END;
	END

	-- The role of an active user is returned even when a filter is refused (the page words its message by it)
	IF (@ActingRole IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @ActingRoleCode = @ActingRole;

	IF (@Result = 1 AND @DeptScoped = 1)
		INSERT INTO @Dept (DepartmentId)
		SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
		WHERE @DepartmentId = 0 OR s.DepartmentId = @DepartmentId;

	-- Scheduled: every one (no cap)
	INSERT INTO @List (MeetingId, ListCode)
	SELECT m.MeetingId, ''S''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 1
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId);

	-- Completed: the last 10, for every role
	INSERT INTO @List (MeetingId, ListCode)
	SELECT TOP (10) m.MeetingId, ''C''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 0
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId)
	AND (@DeptScoped = 0
	     OR EXISTS (SELECT 1 FROM Agenda a INNER JOIN @Dept d ON d.DepartmentId = a.DepartmentId
	                WHERE a.MeetingId = m.MeetingId))
	ORDER BY m.MeetingDate DESC, m.MeetingTime DESC, m.MeetingId DESC;

	SELECT
	m.MeetingId,
	m.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	m.MeetingNo,
	m.MeetingDate,
	m.MeetingTime,
	m.AgendaSubmissionDate,
	l.ListCode,
	st.StateCode,
	st.StateLabel,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Items, 0) END AS INT) AS Items,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Approved, 0) END AS INT) AS Approved,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Rejected, 0) END AS INT) AS Rejected,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Pending, 0) END AS INT) AS Pending
	FROM @List l
	INNER JOIN Meeting m ON m.MeetingId = l.MeetingId
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	LEFT JOIN (SELECT ag.MeetingId,
	                  COUNT(*) AS Items,
	                  SUM(CASE WHEN ag.StatusGroup = ''approved'' THEN 1 ELSE 0 END) AS Approved,
	                  SUM(CASE WHEN ag.StatusGroup = ''rejected'' THEN 1 ELSE 0 END) AS Rejected,
	                  SUM(CASE WHEN ag.StatusGroup = ''in progress'' THEN 1 ELSE 0 END) AS Pending
	           FROM dbo.fn_AgendaStatusGroup() ag
	           INNER JOIN @List gl ON gl.MeetingId = ag.MeetingId
	           WHERE @StatisticsShown = 1
	           AND (@DeptScoped = 0 OR ag.DepartmentId IN (SELECT DepartmentId FROM @Dept))
	           GROUP BY ag.MeetingId) g ON g.MeetingId = m.MeetingId
	ORDER BY
	CASE l.ListCode WHEN ''S'' THEN 0 ELSE 1 END,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingDate END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingTime END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingId END ASC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingDate END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingTime END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingId END DESC;
END
';
SET @OldAgendaTmp = N'

-- Agenda - manager / controller approve or reject; refused once the agenda is finalized,
-- for every role: no Minutes row would be created for it (MeetingLocks-Step16). New alert rows go to
-- active users only; an inactive creator''s saved row is left as it is (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account; the system account cannot
-- approve or reject (Reason 12) (SystemAccount3-Step18)
-- Who may act at which stage (AgendaRouting-Step20): a Manager approves or rejects at AC an item routed
-- to them (or of whom they are the creator''s manager); a Controller approves at AMA and rejects at AC or
-- AMA; anything else is refused (Reason 14, ReasonDetail the status name). An inactive or unknown acting
-- user is refused (Reason 8). A Controller may approve an item they created.
-- UnicodeText-Step31: the text parameters and old-value variables are NVARCHAR(MAX) (were VARCHAR(MAX))
-- CommentAuthor-Step35: Approve and Reject record who decided and when, also with an empty comment: MgrApprovedBy and
-- MgrApprovedDate (Manager), ControllerApprovedBy and ControllerApprovedDate (Controller) are @UpdatedBy and GETDATE()
CREATE OR ALTER PROCEDURE [dbo].[spr_ZZ44_UpdateAgendaOld]
@AgendaId INT,
@ShortText NVARCHAR(MAX),
@ProposedResolution NVARCHAR(MAX),
@MgrComments NVARCHAR(MAX),
@ControllerComments NVARCHAR(MAX),
@ControllerApprovedStatus varchar(50),
@MgrApprovedStatus varchar(50),
@UpdatedBy INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
	DECLARE @MgrCommentsOld NVARCHAR(MAX)
	DECLARE @ControllerCommentsOld NVARCHAR(MAX)
	DECLARE @AgendaNo VARCHAR(50)
	DECLARE @Result INT;
	DECLARE @Reason INT;
	DECLARE @Detail NVARCHAR(2000);
	DECLARE @OwnTransaction INT;
	DECLARE @LockMeetingId INT;
	DECLARE @AgendaStatus VARCHAR(50);
	DECLARE @ActingRole VARCHAR(50);
	DECLARE @StatusCode VARCHAR(50);
	DECLARE @StatusName VARCHAR(100);
	DECLARE @CreatorManagerId INT;
	DECLARE @MgrAction INT;
	DECLARE @CtlAction INT;
	DECLARE @Allowed INT;
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '''';

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION AgendaApprove;

		SET @LockMeetingId = (SELECT MeetingId FROM Agenda WITH (UPDLOCK, HOLDLOCK) WHERE AgendaId = @AgendaId);

		SELECT @AgendaStatus = ISNULL(AgendaStatus, ''Open'')
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @LockMeetingId;

		-- The protected system account takes no part in the workflow (SystemAccount3-Step18)
		IF EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND IsSystem = 1)
			SET @Reason = 12;
		-- Acting user missing or inactive (AgendaRouting-Step20)
		ELSE IF NOT EXISTS (SELECT 1 FROM Users WHERE UserId = @UpdatedBy AND AccountStatus = 1)
			SET @Reason = 8;
		ELSE IF (@AgendaStatus IS NULL)
			SET @Reason = 4;
		ELSE IF (@AgendaStatus <> ''Open'')
		BEGIN
			SET @Reason = 5;
			SET @Detail = ''Finalized'';
		END
		ELSE
		BEGIN
			-- Who may act at which stage (AgendaRouting-Step20)
			SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @UpdatedBy);

			SELECT @StatusCode = a.AgendaStatusCode, @CreatorManagerId = c.ManagerId,
			       @StatusName = ISNULL(st.AgendaStatusName, ISNULL(a.AgendaStatusCode, ''''))
			FROM Agenda a
			LEFT JOIN Users c ON c.UserId = a.CreatedBy
			LEFT JOIN Agenda_Status st ON st.AgendaStatusCode = a.AgendaStatusCode
			WHERE a.AgendaId = @AgendaId;

			SET @MgrAction = CASE WHEN ISNULL(@MgrApprovedStatus, '''') IN (''Approved'', ''Rejected'') THEN 1 ELSE 0 END;
			SET @CtlAction = CASE WHEN ISNULL(@ControllerApprovedStatus, '''') IN (''Approved'', ''Rejected'') THEN 1 ELSE 0 END;

			-- Allowed only when a rule says so: a NULL anywhere counts as not allowed
			SET @Allowed = CASE
				WHEN @MgrAction = 1 AND @CtlAction = 0 AND ISNULL(@ActingRole, '''') = ''manager'' AND ISNULL(@StatusCode, '''') = ''AC''
				     AND (@UpdatedBy = ISNULL(@CreatorManagerId, 0)
				          OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
				                     WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = @AgendaId AND m.UserId = @UpdatedBy))
				THEN 1
				WHEN @CtlAction = 1 AND @MgrAction = 0 AND ISNULL(@ActingRole, '''') = ''controller''
				     AND (ISNULL(@StatusCode, '''') = ''AMA''
				          OR (ISNULL(@StatusCode, '''') = ''AC'' AND @ControllerApprovedStatus = ''Rejected''))
				THEN 1
				ELSE 0 END;

			IF (@Allowed = 0)
			BEGIN
				SET @Reason = 14;
				SET @Detail = ISNULL(@StatusName, '''');
			END
		END

		IF (@Reason = 0)
		BEGIN
			SET @AgendaNo = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgendaId);

			IF @MgrApprovedStatus = ''Rejected''
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = ''AMR'' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = ''AMR'' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrComments'', '''', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrApprovedStatus'', '''', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @MgrApprovedStatus = ''Approved''
			BEGIN
				UPDATE Agenda SET MgrComments = @MgrComments, MgrApprovedStatus = @MgrApprovedStatus,
					MgrApprovedBy = @UpdatedBy, MgrApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				UPDATE Alert_Master SET AlertTypeCode = ''AMA'' WHERE AlertId = @AlertId;
				UPDATE Agenda SET AgendaStatusCode = ''AMA'' WHERE AgendaId = @AgendaId;
				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;

				INSERT INTO Alert_User_Map
					(AlertId, [UserId], ReadStatus, StatusId)
					(SELECT @AlertId, [UserId],0,1 FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0);

				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrComments'', '''', @MgrComments, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''MgrApprovedStatus'', '''', @MgrApprovedStatus, @UpdatedBy, GETDATE();
			END

			IF @ControllerApprovedStatus = ''Approved'' OR @ControllerApprovedStatus = ''Rejected''
			BEGIN
				UPDATE Agenda SET
					ShortText = @ShortText, ProposedResolution = @ProposedResolution,
					ControllerComments = @ControllerComments, ControllerApprovedStatus = @ControllerApprovedStatus,
					ControllerApprovedBy = @UpdatedBy, ControllerApprovedDate = GETDATE(),   -- CommentAuthor-Step35
					UpdatedBy = @UpdatedBy, UpdatedOn = GETDATE()
					WHERE AgendaId = @AgendaId;

				SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
				SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

				IF @ControllerApprovedStatus = ''Approved''
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = ''ACA'' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = ''ACA'' WHERE AgendaId = @AgendaId;
				END
				IF @ControllerApprovedStatus = ''Rejected''
				BEGIN
					UPDATE Alert_Master SET AlertTypeCode = ''ACR'' WHERE AlertId = @AlertId;
					UPDATE Agenda SET AgendaStatusCode = ''ACR'' WHERE AgendaId = @AgendaId;
				END

				-- The creator''s row is renewed only while the creator is active (UserStatus2b-Step17)
				IF EXISTS (SELECT 1 FROM Users WHERE UserId = @User_Id AND AccountStatus = 1 AND IsSystem = 0)
				BEGIN
					DELETE FROM Alert_User_Map WHERE UserId = @User_Id AND AlertId = @AlertId;

					INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
						VALUES (@AlertId, @User_Id, 0, 1);
				END

				UPDATE Alert_User_Map SET ReadStatus = 0 WHERE AlertId = @AlertId;
				UPDATE Alert_User_Map SET ReadStatus = 1 WHERE AlertId = @AlertId AND UserId = @UpdatedBy;

				INSERT INTO [Audit_Trail_Master]
				   ([Audit_Type],[Audit_Table], [Key_Field], [Key_Value], [Field_Name],[Old_Value], [New_Value], [Update_By], [Update_On])
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''ControllerApprovedStatus'', '''', @ControllerApprovedStatus, @UpdatedBy, GETDATE()
				UNION ALL
				SELECT ''UP'', ''Agenda'', ''AgendaNo'', @AgendaNo, ''ControllerComments'', '''', @ControllerComments, @UpdatedBy, GETDATE();
			END

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
			ROLLBACK TRANSACTION AgendaApprove;

		THROW;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
';
SET @OldMeetTmp = N'
-- Dashboard meeting list (DashboardMeetings-Step42, step UN6b), for all six roles. The role and the departments come
-- from the database (the acting user id); the two filters are checked against them:
--   @CommitteeId   0: every committee; otherwise it must exist (any role), else Reason 4
--   @DepartmentId  0: all of a Manager''s or a User''s departments; otherwise it must be one of them (Manager and User
--                  only), else Reason 4
-- Reason 8: acting user missing or inactive; Reason 4: a role outside the six or a filter outside the scope; then
-- no rows. Rows: every scheduled meeting (no cap), then the last 10 completed meetings for EVERY role (for a Manager
-- and a User only completed meetings with an item of the chosen department(s)). Statistics (fn_AgendaStatusGroup,
-- Pending = AC + AMA) for the Controller, Management, the Manager and the User (for the last two over the chosen
-- department(s) only); NULL and @StatisticsShown 0 for MD Secretariat and Admin.
CREATE OR ALTER PROCEDURE [dbo].[spr_ZZ44_MeetingsOld]
@ActingUserId INT = NULL,
@CommitteeId INT = 0,
@DepartmentId INT = 0,
@Result INT = NULL OUTPUT,
@Reason INT = NULL OUTPUT,
@StatisticsShown INT = NULL OUTPUT,
@ActingRoleCode VARCHAR(50) = NULL OUTPUT
AS
DECLARE @ActingRole VARCHAR(50);
DECLARE @Today DATE;
DECLARE @DeptScoped INT;
DECLARE @Dept TABLE (DepartmentId INT PRIMARY KEY);
DECLARE @List TABLE (MeetingId INT PRIMARY KEY, ListCode CHAR(1));
BEGIN
	SET NOCOUNT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @StatisticsShown = 0;
	SET @ActingRoleCode = NULL;
	SET @Today = CAST(GETDATE() AS DATE);
	SET @CommitteeId = ISNULL(@CommitteeId, 0);
	SET @DepartmentId = ISNULL(@DepartmentId, 0);

	SET @ActingRole = (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
	                   WHERE u.UserId = @ActingUserId AND u.AccountStatus = 1);
	SET @DeptScoped = CASE WHEN @ActingRole IN (''manager'', ''user'') THEN 1 ELSE 0 END;

	IF (@ActingRole IS NULL)
		SET @Reason = 8;
	ELSE IF (@ActingRole NOT IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @Reason = 4;
	ELSE IF (@CommitteeId < 0
	         OR (@CommitteeId > 0 AND NOT EXISTS (SELECT 1 FROM Committee WHERE CommitteeId = @CommitteeId)))
		SET @Reason = 4;
	ELSE IF (@DepartmentId < 0
	         OR (@DepartmentId > 0 AND @DeptScoped = 0)
	         OR (@DepartmentId > 0 AND NOT EXISTS (SELECT 1 FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
	                                               WHERE s.DepartmentId = @DepartmentId)))
		SET @Reason = 4;
	ELSE
	BEGIN
		SET @Result = 1;
		SET @StatisticsShown = CASE WHEN @ActingRole IN (''controller'', ''mgmt'', ''manager'', ''user'') THEN 1 ELSE 0 END;
	END

	-- The role of an active user is returned even when a filter is refused (the page words its message by it)
	IF (@ActingRole IN (''admin'', ''controller'', ''manager'', ''user'', ''mgmt'', ''md_sect''))
		SET @ActingRoleCode = @ActingRole;

	IF (@Result = 1 AND @DeptScoped = 1)
		INSERT INTO @Dept (DepartmentId)
		SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@ActingUserId, @Today) s
		WHERE @DepartmentId = 0 OR s.DepartmentId = @DepartmentId;

	-- Scheduled: every one (no cap)
	INSERT INTO @List (MeetingId, ListCode)
	SELECT m.MeetingId, ''S''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 1
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId);

	-- Completed: the last 10, for every role
	INSERT INTO @List (MeetingId, ListCode)
	SELECT TOP (10) m.MeetingId, ''C''
	FROM Meeting m
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	WHERE @Result = 1
	AND st.IsScheduled = 0
	AND (@CommitteeId = 0 OR m.CommitteeId = @CommitteeId)
	AND (@DeptScoped = 0
	     OR EXISTS (SELECT 1 FROM Agenda a INNER JOIN @Dept d ON d.DepartmentId = a.DepartmentId
	                WHERE a.MeetingId = m.MeetingId))
	ORDER BY m.MeetingDate DESC, m.MeetingTime DESC, m.MeetingId DESC;

	SELECT
	m.MeetingId,
	m.CommitteeId,
	c.CommitteeCode,
	c.CommitteeName,
	m.MeetingNo,
	m.MeetingDate,
	m.MeetingTime,
	m.AgendaSubmissionDate,
	l.ListCode,
	st.StateCode,
	st.StateLabel,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Items, 0) END AS INT) AS Items,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Approved, 0) END AS INT) AS Approved,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Rejected, 0) END AS INT) AS Rejected,
	CAST(CASE WHEN @StatisticsShown = 1 THEN ISNULL(g.Pending, 0) END AS INT) AS Pending
	FROM @List l
	INNER JOIN Meeting m ON m.MeetingId = l.MeetingId
	INNER JOIN Committee c ON c.CommitteeId = m.CommitteeId
	INNER JOIN dbo.fn_MeetingDashboardState(@Today) st ON st.MeetingId = m.MeetingId
	LEFT JOIN (SELECT ag.MeetingId,
	                  COUNT(*) AS Items,
	                  SUM(CASE WHEN ag.StatusGroup = ''approved'' THEN 1 ELSE 0 END) AS Approved,
	                  SUM(CASE WHEN ag.StatusGroup = ''rejected'' THEN 1 ELSE 0 END) AS Rejected,
	                  SUM(CASE WHEN ag.StatusGroup = ''in progress'' THEN 1 ELSE 0 END) AS Pending
	           FROM dbo.fn_AgendaStatusGroup() ag
	           INNER JOIN @List gl ON gl.MeetingId = ag.MeetingId
	           WHERE @StatisticsShown = 1
	           AND (@DeptScoped = 0 OR ag.DepartmentId IN (SELECT DepartmentId FROM @Dept))
	           GROUP BY ag.MeetingId) g ON g.MeetingId = m.MeetingId
	ORDER BY
	CASE l.ListCode WHEN ''S'' THEN 0 ELSE 1 END,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingDate END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingTime END ASC,
	CASE WHEN l.ListCode = ''S'' THEN m.MeetingId END ASC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingDate END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingTime END DESC,
	CASE WHEN l.ListCode = ''C'' THEN m.MeetingId END DESC;
END
';

---------------------------------------------------------------------------
-- Real data, read only: the function against the rule of step 20, written out here as it stood in the procedure
---------------------------------------------------------------------------
INSERT INTO @T
SELECT 'Data of this database: for every active user that is not the system account and every agenda item, fn_AgendaWaitingFor gives the answer of the step 20 rule (pairs that differ; '
       + CAST((SELECT COUNT(*) FROM Users WHERE AccountStatus = 1 AND IsSystem = 0) AS VARCHAR(12)) + ' users, ' + CAST((SELECT COUNT(*) FROM Agenda) AS VARCHAR(12)) + ' items)', '0',
       CAST((SELECT COUNT(*)
             FROM Users u
             INNER JOIN Roles r ON r.RoleId = u.RoleId
             CROSS JOIN Agenda a
             LEFT JOIN Users c ON c.UserId = a.CreatedBy
             OUTER APPLY (SELECT w.CanApprove, w.CanReject FROM dbo.fn_AgendaWaitingFor(u.UserId, @Today) w WHERE w.AgendaId = a.AgendaId) f
             CROSS APPLY (SELECT
                 CASE WHEN r.RoleCode = 'manager' AND ISNULL(a.AgendaStatusCode, '') = 'AC'
                           AND (u.UserId = ISNULL(c.ManagerId, 0)
                                OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                                           WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND m.UserId = u.UserId)) THEN 1
                      WHEN r.RoleCode = 'controller' AND ISNULL(a.AgendaStatusCode, '') = 'AMA' THEN 1 ELSE 0 END AS OldApprove,
                 CASE WHEN r.RoleCode = 'manager' AND ISNULL(a.AgendaStatusCode, '') = 'AC'
                           AND (u.UserId = ISNULL(c.ManagerId, 0)
                                OR EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                                           WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND m.UserId = u.UserId)) THEN 1
                      WHEN r.RoleCode = 'controller' AND ISNULL(a.AgendaStatusCode, '') IN ('AC', 'AMA') THEN 1 ELSE 0 END AS OldReject) o
             WHERE u.AccountStatus = 1 AND u.IsSystem = 0
             AND (ISNULL(f.CanApprove, 0) <> o.OldApprove OR ISNULL(f.CanReject, 0) <> o.OldReject)) AS VARCHAR(12));

INSERT INTO @T
SELECT 'Data of this database: the function has no row for an inactive user or the system account', '0',
       CAST((SELECT COUNT(*) FROM Users u CROSS APPLY dbo.fn_AgendaWaitingFor(u.UserId, @Today) w WHERE u.AccountStatus <> 1 OR u.IsSystem = 1) AS VARCHAR(12));

BEGIN TRANSACTION;

BEGIN TRY
    EXEC (@OldAgendaTmp);
    EXEC (@OldMeetTmp);

    -- What a call leaves behind for one item: the item, its alert, the alert's rows, the audit rows of the test
    EXEC ('CREATE FUNCTION dbo.fn_ZZ44_State (@AgendaId INT) RETURNS NVARCHAR(MAX) AS
BEGIN
    RETURN ISNULL((SELECT ISNULL(a.AgendaStatusCode, ''-'') + ''|'' + ISNULL(a.MgrApprovedStatus, ''-'') + ''|'' + ISNULL(a.ControllerApprovedStatus, ''-'')
                        + ''|'' + ISNULL(CAST(a.MgrApprovedBy AS VARCHAR(12)), ''-'') + ''|'' + ISNULL(CAST(a.ControllerApprovedBy AS VARCHAR(12)), ''-'')
                        + ''|'' + CASE WHEN a.MgrApprovedDate IS NULL THEN ''-'' ELSE ''d'' END + CASE WHEN a.ControllerApprovedDate IS NULL THEN ''-'' ELSE ''d'' END
                        + ''|'' + ISNULL(CAST(a.UpdatedBy AS VARCHAR(12)), ''-'') + ''|'' + ISNULL(CAST(a.MgrComments AS NVARCHAR(50)), ''-'')
                        + ''|'' + ISNULL(CAST(a.ControllerComments AS NVARCHAR(50)), ''-'') + ''|'' + ISNULL(CAST(a.ShortText AS NVARCHAR(60)), ''-'')
                        + ''|'' + ISNULL(CAST(a.ProposedResolution AS NVARCHAR(50)), ''-'')
                   FROM Agenda a WHERE a.AgendaId = @AgendaId), ''no item'')
         + '' alert '' + ISNULL((SELECT TOP 1 am.AlertTypeCode FROM Alert_Master am WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = @AgendaId ORDER BY am.AlertId), ''-'')
         + '' map '' + ISNULL(STUFF((SELECT '','' + ISNULL(CAST(mp.UserId AS VARCHAR(12)), ''-'') + '':'' + ISNULL(CAST(mp.ReadStatus AS VARCHAR(3)), ''-'') + '':'' + CAST(mp.StatusId AS VARCHAR(3))
                                   FROM Alert_User_Map mp INNER JOIN Alert_Master am ON am.AlertId = mp.AlertId
                                   WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = @AgendaId
                                   ORDER BY mp.UserId, mp.ReadStatus, mp.StatusId FOR XML PATH('''')), 1, 1, ''''), ''-'')
         + '' audit '' + ISNULL(STUFF((SELECT '','' + t.Field_Name + ''='' + ISNULL(CAST(t.New_Value AS NVARCHAR(40)), ''-'') + '' by '' + ISNULL(CAST(t.Update_By AS VARCHAR(12)), ''-'')
                                     FROM Audit_Trail_Master t WHERE t.Audit_Table = ''Agenda'' AND t.Key_Value LIKE ''ZZ44%''
                                     ORDER BY t.Field_Name, t.New_Value FOR XML PATH('''')), 1, 1, ''''), ''-'');
END');

    ---------------------------------------------------------------------------
    -- The items of the departments of itmgruser that are not routed to him (owner's test of UN6c: 9 on BMMS_Test)
    ---------------------------------------------------------------------------
    SET @Id = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.LoginName = 'itmgruser' AND r.RoleCode = 'manager' AND u.AccountStatus = 1);
    IF (@Id IS NULL)
        INSERT INTO @T VALUES ('Login itmgruser (an active Manager): the items at AC of his departments that are not routed to him are refused with Reason 14', 'PASS', 'SKIPPED');
    ELSE
    BEGIN
        SET @N = 0; SET @Refused = 0;
        DECLARE ItCursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT a.AgendaId FROM Agenda a
            INNER JOIN Meeting m ON m.MeetingId = a.MeetingId
            LEFT JOIN Users c ON c.UserId = a.CreatedBy
            WHERE a.AgendaStatusCode = 'AC' AND ISNULL(m.AgendaStatus, 'Open') = 'Open'
            AND a.DepartmentId IN (SELECT s.DepartmentId FROM dbo.fn_UserDepartmentScope(@Id, @Today) s)
            AND NOT (ISNULL(c.ManagerId, 0) = @Id
                     OR EXISTS (SELECT 1 FROM Alert_User_Map mp JOIN Alert_Master am ON am.AlertId = mp.AlertId
                                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId AND mp.UserId = @Id));
        OPEN ItCursor;
        FETCH NEXT FROM ItCursor INTO @cAgenda;
        WHILE (@@FETCH_STATUS = 0)
        BEGIN
            SET @N = @N + 1;
            DELETE FROM @R;
            INSERT INTO @R EXEC spr_UpdateAgendaByAgendaId @AgendaId = @cAgenda, @ShortText = N'ZZ44', @ProposedResolution = N'ZZ44', @MgrComments = N'ZZ44',
                @ControllerComments = N'', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Id;
            IF EXISTS (SELECT 1 FROM @R WHERE Result = 0 AND Reason = 14) AND (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @cAgenda) = 'AC'
                SET @Refused = @Refused + 1;
            FETCH NEXT FROM ItCursor INTO @cAgenda;
        END
        CLOSE ItCursor;
        DEALLOCATE ItCursor;
        INSERT INTO @T SELECT 'Login itmgruser: the ' + CAST(@N AS VARCHAR(12)) + ' items at AC (open agenda) of his departments that are not routed to him: each refused with Reason 14 and still at AC; none of them in his function rows',
               CAST(@N AS VARCHAR(12)) + ' of ' + CAST(@N AS VARCHAR(12)) + ' refused, 0 function rows',
               CAST(@Refused AS VARCHAR(12)) + ' of ' + CAST(@N AS VARCHAR(12)) + ' refused, '
             + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@Id, @Today)) AS VARCHAR(12)) + ' function rows';
    END

    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ44A', 'ZZ44 department A', 991, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ44B', 'ZZ44 department B', 992, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 controller', @DA, @Desig, NULL, @rCtl, 'zz44c@example.invalid', 'zz44ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 manager of the creator', @DA, @Desig, NULL, @rMgr, 'zz44m1@example.invalid', 'zz44mg1', 'not-a-login', 1, @Now);
    SET @Mg1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 manager with an alert row', @DB, @Desig, NULL, @rMgr, 'zz44m2@example.invalid', 'zz44mg2', 'not-a-login', 1, @Now);
    SET @Mg2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 manager with a removed alert row', @DB, @Desig, NULL, @rMgr, 'zz44m3@example.invalid', 'zz44mg3', 'not-a-login', 1, @Now);
    SET @Mg3 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 manager not routed', @DA, @Desig, NULL, @rMgr, 'zz44m4@example.invalid', 'zz44mg4', 'not-a-login', 1, @Now);
    SET @Mg4 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 user', @DA, @Desig, @Mg1, @rUser, 'zz44u@example.invalid', 'zz44usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 management', @DA, @Desig, NULL, @rMgmt, 'zz44g@example.invalid', 'zz44gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 md secretariat', @DA, @Desig, NULL, @rMd, 'zz44s@example.invalid', 'zz44mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 admin', @DA, @Desig, NULL, @rAdmin, 'zz44a@example.invalid', 'zz44adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ44 inactive manager', @DA, @Desig, NULL, @rMgr, 'zz44i@example.invalid', 'zz44off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z44', 'ZZ44 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    -- Four meetings: agenda open and to come; agenda open but the date passed; agenda finalised; agenda open, no date
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94401', @Com, 'ZZ44 test', 'ZZ', DATEADD(DAY, 10, @Day), '10:00', DATEADD(DAY, 5, @Day), 'Open', 'Open', @Now, @Sys);
    SET @MOpen = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94402', @Com, 'ZZ44 test', 'ZZ', DATEADD(DAY, -3, @Day), '10:00', DATEADD(DAY, -8, @Day), 'Open', 'Open', @Now, @Sys);
    SET @MPast = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94403', @Com, 'ZZ44 test', 'ZZ', DATEADD(DAY, 5, @Day), '10:00', DATEADD(DAY, 1, @Day), 'Close', 'Open', @Now, @Sys);
    SET @MFin = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94404', @Com, 'ZZ44 test', 'ZZ', NULL, NULL, NULL, 'Open', 'Open', @Now, @Sys);
    SET @MNull = SCOPE_IDENTITY();

    -- Twelve items; the label says the meeting (o open, p date passed, f finalised, n no date) and the status.
    -- All saved by the user of department A (his manager is "manager of the creator"), but xAC: saved by the
    -- Controller for department B (nobody's manager).
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ44-' + x.Label, @Com, x.MeetingId, x.DepartmentId, @SubjectTypeId, 'ZZ44 ' + x.Label, 'Entry', x.Code, 'New', @Now, x.CreatedBy
    FROM (SELECT 'oAC' AS Label, @MOpen AS MeetingId, 'AC' AS Code, @DA AS DepartmentId, @Usr AS CreatedBy
          UNION ALL SELECT 'oAMA', @MOpen, 'AMA', @DA, @Usr
          UNION ALL SELECT 'oAMR', @MOpen, 'AMR', @DA, @Usr
          UNION ALL SELECT 'oACA', @MOpen, 'ACA', @DA, @Usr
          UNION ALL SELECT 'oACR', @MOpen, 'ACR', @DA, @Usr
          UNION ALL SELECT 'oAF', @MOpen, 'AF', @DA, @Usr
          UNION ALL SELECT 'pAC', @MPast, 'AC', @DA, @Usr
          UNION ALL SELECT 'pAMA', @MPast, 'AMA', @DA, @Usr
          UNION ALL SELECT 'fAC', @MFin, 'AC', @DA, @Usr
          UNION ALL SELECT 'fAMA', @MFin, 'AMA', @DA, @Usr
          UNION ALL SELECT 'nAC', @MNull, 'AC', @DA, @Usr
          UNION ALL SELECT 'xAC', @MOpen, 'AC', @DB, @Ctl) x;

    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    SELECT 'Agenda', a.AgendaId, a.DepartmentId, a.ShortText, a.AgendaStatusCode, 3, @Com, @Now, a.CreatedBy
    FROM Agenda a WHERE a.CommitteeId = @Com;

    -- Alert rows of every item: the manager with an alert row; the manager who REMOVED his row from his list
    -- (StatusId 0, read); the inactive manager; the Controller, the user, Management and the Admin
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT am.AlertId, u.UserId, u.ReadStatus, u.StatusId
    FROM Alert_Master am
    CROSS JOIN (SELECT @Mg2 AS UserId, 0 AS ReadStatus, 1 AS StatusId
                UNION ALL SELECT @Mg3, 1, 0 UNION ALL SELECT @Off, 0, 1 UNION ALL SELECT @Ctl, 0, 1
                UNION ALL SELECT @Usr, 0, 1 UNION ALL SELECT @Gmt, 0, 1 UNION ALL SELECT @Adm, 0, 1 UNION ALL SELECT @Sys, 0, 1) u
    WHERE am.SourceType = 'Agenda' AND am.CommitteeId = @Com AND am.DisplayText LIKE 'ZZ44 %';

    INSERT INTO @Items (Label, AgendaId) SELECT SUBSTRING(a.AgendaNo, 6, 20), a.AgendaId FROM Agenda a WHERE a.CommitteeId = @Com;
    INSERT INTO @Items (Label, AgendaId) VALUES ('unknown', -1);
    INSERT INTO @Actors (Label, UserId) VALUES ('ctl', @Ctl), ('mg1', @Mg1), ('mg2', @Mg2), ('mg3', @Mg3), ('mg4', @Mg4), ('usr', @Usr), ('gmt', @Gmt),
                                               ('mds', @Mds), ('adm', @Adm), ('off', @Off), ('sys', @Sys), ('unknown', -1), ('none', NULL);
    INSERT INTO @Actions (Label, M, C) VALUES ('mgr approve', 'Approved', ''), ('mgr reject', 'Rejected', ''), ('ctl approve', '', 'Approved'),
                                              ('ctl reject', '', 'Rejected'), ('both approve', 'Approved', 'Approved'), ('nothing', '', ''),
                                              ('mgr other word', 'Hold', ''), ('ctl approve, mgr null', NULL, 'Approved');

    INSERT INTO @T SELECT 'Made-up data: items, actors, actions of the comparison', '13, 13, 8',
           CAST((SELECT COUNT(*) FROM @Items) AS VARCHAR(12)) + ', ' + CAST((SELECT COUNT(*) FROM @Actors) AS VARCHAR(12)) + ', ' + CAST((SELECT COUNT(*) FROM @Actions) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The function's flags on the made-up items (CanApprove CanReject AgendaOpen DateOpen IsWaiting)
    ---------------------------------------------------------------------------
    INSERT INTO @T
    SELECT 'Function rows of ' + x.Name, x.Expected,
           ISNULL(STUFF((SELECT '; ' + i.Label + '=' + CAST(w.CanApprove AS VARCHAR(1)) + CAST(w.CanReject AS VARCHAR(1)) + CAST(w.AgendaOpen AS VARCHAR(1))
                                + CAST(w.DateOpen AS VARCHAR(1)) + CAST(w.IsWaiting AS VARCHAR(1))
                         FROM dbo.fn_AgendaWaitingFor(x.UserId, @Today) w INNER JOIN @Items i ON i.AgendaId = w.AgendaId
                         ORDER BY i.Label FOR XML PATH('')), 1, 2, ''), 'no rows')
    FROM (SELECT 1 AS Seq, 'the manager of the creator: the creator''s four items at AC; waiting only where the agenda is open and the date has not passed' AS Name, @Mg1 AS UserId,
                 'fAC=11010; nAC=11111; oAC=11111; pAC=11100' AS Expected
          UNION ALL SELECT 2, 'the manager with an alert row: every item at AC, also the one of nobody''s manager', @Mg2, 'fAC=11010; nAC=11111; oAC=11111; pAC=11100; xAC=11111'
          UNION ALL SELECT 3, 'the manager who removed his alert row from his list: the same (the row still counts)', @Mg3, 'fAC=11010; nAC=11111; oAC=11111; pAC=11100; xAC=11111'
          UNION ALL SELECT 4, 'the manager not routed (same department as the items): nothing', @Mg4, 'no rows'
          UNION ALL SELECT 5, 'the Controller: AMA approve and reject, AC reject only', @Ctl, 'fAC=01010; fAMA=11010; nAC=01110; oAC=01110; oAMA=11111; pAC=01100; pAMA=11100; xAC=01110'
          UNION ALL SELECT 6, 'the user (the creator)', @Usr, 'no rows'
          UNION ALL SELECT 7, 'Management', @Gmt, 'no rows'
          UNION ALL SELECT 8, 'MD Secretariat', @Mds, 'no rows'
          UNION ALL SELECT 9, 'the Admin', @Adm, 'no rows'
          UNION ALL SELECT 10, 'the inactive manager (he has alert rows)', @Off, 'no rows'
          UNION ALL SELECT 11, 'the system account (it has alert rows)', @Sys, 'no rows') x
    ORDER BY x.Seq;

    ---------------------------------------------------------------------------
    -- The approval procedure: the earlier text and the new one on the same cases
    ---------------------------------------------------------------------------
    DECLARE CaseCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT a.Label, a.UserId, i.Label, i.AgendaId, x.Label, x.M, x.C
        FROM @Actors a CROSS JOIN @Items i CROSS JOIN @Actions x;
    OPEN CaseCursor;
    FETCH NEXT FROM CaseCursor INTO @cActor, @cUser, @cItem, @cAgenda, @cAct, @cM, @cC;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SAVE TRANSACTION ZZ44Case;
        DELETE FROM @R;
        INSERT INTO @R EXEC dbo.spr_ZZ44_UpdateAgendaOld @AgendaId = @cAgenda, @ShortText = N'ZZ44 changed', @ProposedResolution = N'ZZ44 resolution',
            @MgrComments = N'ZZ44 mc', @ControllerComments = N'ZZ44 cc', @ControllerApprovedStatus = @cC, @MgrApprovedStatus = @cM, @UpdatedBy = @cUser;
        SET @OldRR = ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R), 'no answer');
        SET @OldOut = @OldRR + ISNULL((SELECT TOP 1 ' [' + ISNULL(ReasonDetail, N'null') + ']' FROM @R), '') + ' rows ' + CAST((SELECT COUNT(*) FROM @R) AS VARCHAR(3))
                    + ' # ' + dbo.fn_ZZ44_State(@cAgenda);
        ROLLBACK TRANSACTION ZZ44Case;

        SAVE TRANSACTION ZZ44Case;
        DELETE FROM @R;
        INSERT INTO @R EXEC dbo.spr_UpdateAgendaByAgendaId @AgendaId = @cAgenda, @ShortText = N'ZZ44 changed', @ProposedResolution = N'ZZ44 resolution',
            @MgrComments = N'ZZ44 mc', @ControllerComments = N'ZZ44 cc', @ControllerApprovedStatus = @cC, @MgrApprovedStatus = @cM, @UpdatedBy = @cUser;
        SET @NewRR = ISNULL((SELECT TOP 1 'Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3)) FROM @R), 'no answer');
        SET @NewOut = @NewRR + ISNULL((SELECT TOP 1 ' [' + ISNULL(ReasonDetail, N'null') + ']' FROM @R), '') + ' rows ' + CAST((SELECT COUNT(*) FROM @R) AS VARCHAR(3))
                    + ' # ' + dbo.fn_ZZ44_State(@cAgenda);
        ROLLBACK TRANSACTION ZZ44Case;

        INSERT INTO @Case (Actor, Item, Act, OldRR, NewRR, OldOut, NewOut) VALUES (@cActor, @cItem, @cAct, @OldRR, @NewRR, @OldOut, @NewOut);
        FETCH NEXT FROM CaseCursor INTO @cActor, @cUser, @cItem, @cAgenda, @cAct, @cM, @cC;
    END
    CLOSE CaseCursor;
    DEALLOCATE CaseCursor;

    INSERT INTO @T SELECT 'Approval, earlier text beside the new one: cases run (13 actors x 13 items x 8 actions); cases whose Result, Reason, ReasonDetail or written rows differ', '1352 cases, 0 differ',
           CAST((SELECT COUNT(*) FROM @Case) AS VARCHAR(12)) + ' cases, ' + CAST((SELECT COUNT(*) FROM @Case WHERE OldOut <> NewOut OR OldOut IS NULL OR NewOut IS NULL) AS VARCHAR(12)) + ' differ'
         + ISNULL((SELECT TOP 1 ': ' + Actor + ' / ' + Item + ' / ' + Act + ': ' + LEFT(ISNULL(OldOut, 'null'), 200) + ' <> ' + LEFT(ISNULL(NewOut, 'null'), 200)
                   FROM @Case WHERE OldOut <> NewOut OR OldOut IS NULL OR NewOut IS NULL ORDER BY Actor, Item, Act), '');
    -- 1352 cases = 13 x 13 x 8. The system account: 104 (Reason 12). The inactive, the unknown and the missing user:
    -- 312 (Reason 8). The other nine actors: the unknown item 72 (Reason 4); the two items of the finalised agenda 144
    -- (Reason 5); the ten other items 720, of which allowed: the creator's manager 3 items x 2 actions = 6, each of the
    -- two managers with an alert row 4 x 2 = 8, the Controller 2 items at AMA x 3 action rows + 4 items at AC x reject
    -- = 10; in all 32, and 688 refused with Reason 14.
    INSERT INTO @T SELECT 'The comparison is not empty: cases that were allowed (Result 1), and each refusal that occurs', 'allowed 32; Reason 12: 104, Reason 14: 688, Reason 4: 72, Reason 5: 144, Reason 8: 312',
           'allowed ' + CAST((SELECT COUNT(*) FROM @Case WHERE NewRR = 'Result 1, Reason 0') AS VARCHAR(12)) + '; '
         + ISNULL(STUFF((SELECT ', ' + REPLACE(NewRR, 'Result 0, ', '') + ': ' + CAST(COUNT(*) AS VARCHAR(12)) FROM @Case WHERE NewRR LIKE 'Result 0,%' GROUP BY NewRR ORDER BY NewRR FOR XML PATH('')), 1, 2, ''), 'none');

    -- The cases one by one that the owner named, on the new procedure
    INSERT INTO @T
    SELECT 'Approval (new text): ' + x.Name, x.Expected, ISNULL((SELECT c.NewRR FROM @Case c WHERE c.Actor = x.Actor AND c.Item = x.Item AND c.Act = x.Act), 'case missing')
    FROM (SELECT 1 AS Seq, 'the manager of the creator approves the item at AC' AS Name, 'mg1' AS Actor, 'oAC' AS Item, 'mgr approve' AS Act, 'Result 1, Reason 0' AS Expected
          UNION ALL SELECT 2, 'the manager of the creator rejects it', 'mg1', 'oAC', 'mgr reject', 'Result 1, Reason 0'
          UNION ALL SELECT 3, 'a manager routed by his alert row approves', 'mg2', 'oAC', 'mgr approve', 'Result 1, Reason 0'
          UNION ALL SELECT 4, 'a manager whose alert row was REMOVED from his list still approves (the row counts as routing)', 'mg3', 'oAC', 'mgr approve', 'Result 1, Reason 0'
          UNION ALL SELECT 5, 'a manager of the same department who is not routed is refused', 'mg4', 'oAC', 'mgr approve', 'Result 0, Reason 14'
          UNION ALL SELECT 6, 'the manager of the creator on the item of nobody''s manager (no alert row of his) is refused', 'mg1', 'xAC', 'mgr approve', 'Result 0, Reason 14'
          UNION ALL SELECT 7, 'a manager cannot approve at AMA', 'mg1', 'oAMA', 'mgr approve', 'Result 0, Reason 14'
          UNION ALL SELECT 8, 'a manager with the Controller''s action word is refused', 'mg1', 'oAC', 'ctl approve', 'Result 0, Reason 14'
          UNION ALL SELECT 9, 'the Controller approves at AMA', 'ctl', 'oAMA', 'ctl approve', 'Result 1, Reason 0'
          UNION ALL SELECT 10, 'the Controller rejects at AMA', 'ctl', 'oAMA', 'ctl reject', 'Result 1, Reason 0'
          UNION ALL SELECT 11, 'the Controller rejects at AC', 'ctl', 'oAC', 'ctl reject', 'Result 1, Reason 0'
          UNION ALL SELECT 12, 'the Controller cannot approve at AC', 'ctl', 'oAC', 'ctl approve', 'Result 0, Reason 14'
          UNION ALL SELECT 13, 'the Controller cannot decide an approved item', 'ctl', 'oACA', 'ctl reject', 'Result 0, Reason 14'
          UNION ALL SELECT 14, 'both action words at once are refused', 'ctl', 'oAMA', 'both approve', 'Result 0, Reason 14'
          UNION ALL SELECT 15, 'no action word is refused', 'mg1', 'oAC', 'nothing', 'Result 0, Reason 14'
          UNION ALL SELECT 16, 'the system account is refused as a system account (it has an alert row)', 'sys', 'oAC', 'mgr approve', 'Result 0, Reason 12'
          UNION ALL SELECT 17, 'the inactive manager is refused', 'off', 'oAC', 'mgr approve', 'Result 0, Reason 8'
          UNION ALL SELECT 18, 'an unknown acting user is refused', 'unknown', 'oAC', 'mgr approve', 'Result 0, Reason 8'
          UNION ALL SELECT 19, 'no acting user is refused', 'none', 'oAC', 'mgr approve', 'Result 0, Reason 8'
          UNION ALL SELECT 20, 'the user (creator) is refused', 'usr', 'oAC', 'mgr approve', 'Result 0, Reason 14'
          UNION ALL SELECT 21, 'Management is refused', 'gmt', 'oAMA', 'ctl approve', 'Result 0, Reason 14'
          UNION ALL SELECT 22, 'MD Secretariat is refused', 'mds', 'oAMA', 'ctl approve', 'Result 0, Reason 14'
          UNION ALL SELECT 23, 'the Admin is refused', 'adm', 'oAC', 'mgr approve', 'Result 0, Reason 14'
          UNION ALL SELECT 24, 'a finalised agenda refuses the routed manager', 'mg1', 'fAC', 'mgr approve', 'Result 0, Reason 5'
          UNION ALL SELECT 25, 'a finalised agenda refuses the Controller', 'ctl', 'fAMA', 'ctl approve', 'Result 0, Reason 5'
          UNION ALL SELECT 26, 'an unknown item is refused', 'mg1', 'unknown', 'mgr approve', 'Result 0, Reason 4'
          UNION ALL SELECT 27, 'AS BEFORE, the procedure does not look at the meeting date: the routed manager approves an item of a meeting whose date has passed (the page refuses it, step M6a)', 'mg1', 'pAC', 'mgr approve', 'Result 1, Reason 0'
          UNION ALL SELECT 28, 'AS BEFORE, the same for the Controller at AMA', 'ctl', 'pAMA', 'ctl approve', 'Result 1, Reason 0'
          UNION ALL SELECT 29, 'a meeting without a date: the routed manager approves', 'mg1', 'nAC', 'mgr approve', 'Result 1, Reason 0') x
    ORDER BY x.Seq;

    INSERT INTO @T SELECT 'What an approval by the manager with the removed row writes (new text): the item at AMA, his name as approver, the alert AMA, his own row read',
           (SELECT TOP 1 OldOut FROM @Case WHERE Actor = 'mg3' AND Item = 'oAC' AND Act = 'mgr approve'),
           (SELECT TOP 1 NewOut FROM @Case WHERE Actor = 'mg3' AND Item = 'oAC' AND Act = 'mgr approve');
    INSERT INTO @T SELECT 'That approval did change the item (the state string names AMA and Approved)', 'yes',
           CASE WHEN (SELECT TOP 1 NewOut FROM @Case WHERE Actor = 'mg3' AND Item = 'oAC' AND Act = 'mgr approve') LIKE '%# AMA|Approved|%alert AMA%' THEN 'yes' ELSE 'no' END;
    INSERT INTO @T SELECT 'The comparison left nothing behind: the twelve items at their statuses, no audit row of the test', 'AC 5, ACA 1, ACR 1, AF 1, AMA 3, AMR 1; 0',
           ISNULL(STUFF((SELECT ', ' + a.AgendaStatusCode + ' ' + CAST(COUNT(*) AS VARCHAR(12)) FROM Agenda a WHERE a.CommitteeId = @Com GROUP BY a.AgendaStatusCode ORDER BY a.AgendaStatusCode FOR XML PATH('')), 1, 2, ''), 'none')
         + '; ' + CAST((SELECT COUNT(*) FROM Audit_Trail_Master t WHERE t.Audit_Table = 'Agenda' AND t.Key_Value LIKE 'ZZ44%') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The approval state (the Agenda Alert panel): CanApprove CanReject AgendaOpen DateOpen
    ---------------------------------------------------------------------------
    DECLARE StateCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.Name, x.UserId, x.AgendaId, x.Expected
        FROM (SELECT 1 AS Seq, 'the manager of the creator, item at AC' AS Name, @Mg1 AS UserId, (SELECT AgendaId FROM @Items WHERE Label = 'oAC') AS AgendaId, 'Result 1, Reason 0: 1 1 1 1' AS Expected
              UNION ALL SELECT 2, 'the same, the meeting date passed: he may by routing, the date is closed', @Mg1, (SELECT AgendaId FROM @Items WHERE Label = 'pAC'), 'Result 1, Reason 0: 1 1 1 0'
              UNION ALL SELECT 3, 'the same, the agenda finalised', @Mg1, (SELECT AgendaId FROM @Items WHERE Label = 'fAC'), 'Result 1, Reason 0: 1 1 0 1'
              UNION ALL SELECT 4, 'the same, a meeting without a date', @Mg1, (SELECT AgendaId FROM @Items WHERE Label = 'nAC'), 'Result 1, Reason 0: 1 1 1 1'
              UNION ALL SELECT 5, 'a manager who is not routed: no button', @Mg4, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 1, Reason 0: 0 0 1 1'
              UNION ALL SELECT 6, 'the manager with the removed alert row', @Mg3, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 1, Reason 0: 1 1 1 1'
              UNION ALL SELECT 7, 'the Controller at AC: reject only', @Ctl, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 1, Reason 0: 0 1 1 1'
              UNION ALL SELECT 8, 'the Controller at AMA', @Ctl, (SELECT AgendaId FROM @Items WHERE Label = 'oAMA'), 'Result 1, Reason 0: 1 1 1 1'
              UNION ALL SELECT 9, 'the Controller, an approved item', @Ctl, (SELECT AgendaId FROM @Items WHERE Label = 'oACA'), 'Result 1, Reason 0: 0 0 1 1'
              UNION ALL SELECT 10, 'the user', @Usr, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 1, Reason 0: 0 0 1 1'
              UNION ALL SELECT 11, 'Management', @Gmt, (SELECT AgendaId FROM @Items WHERE Label = 'oAMA'), 'Result 1, Reason 0: 0 0 1 1'
              UNION ALL SELECT 12, 'the system account', @Sys, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 0, Reason 12: 0 0 0 0'
              UNION ALL SELECT 13, 'the inactive manager', @Off, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 0, Reason 8: 0 0 0 0'
              UNION ALL SELECT 14, 'no acting user', NULL, (SELECT AgendaId FROM @Items WHERE Label = 'oAC'), 'Result 0, Reason 8: 0 0 0 0'
              UNION ALL SELECT 15, 'an unknown item', @Mg1, -1, 'Result 0, Reason 4: 0 0 0 0'
              UNION ALL SELECT 16, 'no item', @Mg1, NULL, 'Result 0, Reason 4: 0 0 0 0') x
        ORDER BY x.Seq;
    OPEN StateCursor;
    FETCH NEXT FROM StateCursor INTO @Txt, @cUser, @cAgenda, @OldRR;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @Res = NULL; SET @Rsn = NULL; SET @CanA = NULL; SET @CanR = NULL; SET @AgOpen = NULL; SET @DtOpen = NULL;
        EXEC spr_GetAgendaApprovalState @ActingUserId = @cUser, @AgendaId = @cAgenda, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
             @CanApprove = @CanA OUTPUT, @CanReject = @CanR OUTPUT, @AgendaOpen = @AgOpen OUTPUT, @DateOpen = @DtOpen OUTPUT;
        INSERT INTO @T SELECT 'Approval state: ' + @Txt, @OldRR,
               'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': '
             + ISNULL(CAST(@CanA AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@CanR AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@AgOpen AS VARCHAR(2)), '-') + ' ' + ISNULL(CAST(@DtOpen AS VARCHAR(2)), '-');
        FETCH NEXT FROM StateCursor INTO @Txt, @cUser, @cAgenda, @OldRR;
    END
    CLOSE StateCursor;
    DEALLOCATE StateCursor;

    ---------------------------------------------------------------------------
    -- The meeting list: the earlier text beside the new one, and WaitingForMe (committee Z44: MeetingNo:list:waiting)
    ---------------------------------------------------------------------------
    DECLARE MeetCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.Name, x.UserId, x.CommitteeId, x.DepartmentId, x.Expected
        FROM (SELECT 1 AS Seq, 'the Controller, committee Z44: one item at AMA waits in the open meeting; nothing in the finalised one, the one without a date and the completed one' AS Name,
                     @Ctl AS UserId, @Com AS CommitteeId, 0 AS DepartmentId, 'Result 1, Reason 0, shown 1: 94401:S:1; 94402:C:-; 94403:S:0; 94404:S:0' AS Expected
              UNION ALL SELECT 2, 'the manager of the creator, committee Z44', @Mg1, @Com, 0, 'Result 1, Reason 0, shown 1: 94401:S:1; 94402:C:-; 94403:S:0; 94404:S:1'
              UNION ALL SELECT 3, 'the manager with an alert row (department B), committee Z44: two items wait in the open meeting', @Mg2, @Com, 0, 'Result 1, Reason 0, shown 1: 94401:S:2; 94403:S:0; 94404:S:1'
              UNION ALL SELECT 4, 'the same with his department B chosen: only the item of B', @Mg2, @Com, @DB, 'Result 1, Reason 0, shown 1: 94401:S:1; 94403:S:0; 94404:S:0'
              UNION ALL SELECT 5, 'the manager not routed', @Mg4, @Com, 0, 'Result 1, Reason 0, shown 1: 94401:S:0; 94402:C:-; 94403:S:0; 94404:S:0'
              UNION ALL SELECT 6, 'the user: the column is not shown', @Usr, @Com, 0, 'Result 1, Reason 0, shown 0: 94401:S:-; 94402:C:-; 94403:S:-; 94404:S:-'
              UNION ALL SELECT 7, 'Management: not shown', @Gmt, @Com, 0, 'Result 1, Reason 0, shown 0: 94401:S:-; 94402:C:-; 94403:S:-; 94404:S:-'
              UNION ALL SELECT 8, 'MD Secretariat: not shown', @Mds, @Com, 0, 'Result 1, Reason 0, shown 0: 94401:S:-; 94402:C:-; 94403:S:-; 94404:S:-'
              UNION ALL SELECT 9, 'the Admin: not shown', @Adm, @Com, 0, 'Result 1, Reason 0, shown 0: 94401:S:-; 94402:C:-; 94403:S:-; 94404:S:-'
              UNION ALL SELECT 11, 'the inactive manager', @Off, @Com, 0, 'Result 0, Reason 8, shown 0: no rows'
              UNION ALL SELECT 12, 'an unknown committee', @Ctl, -5, 0, 'Result 0, Reason 4, shown 0: no rows') x
        ORDER BY x.Seq;
    OPEN MeetCursor;
    FETCH NEXT FROM MeetCursor INTO @Txt, @cUser, @Id, @N, @OldOut;
    SET @Refused = 0;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        DELETE FROM #MT; DELETE FROM #MO;
        SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL; SET @Wait = NULL; SET @Role = NULL;
        INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = @Id, @DepartmentId = @N, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
            @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
        INSERT INTO @T SELECT 'Meeting list, Waiting for me: ' + @Txt, CAST(@OldOut AS VARCHAR(1000)),
               'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', shown ' + ISNULL(CAST(@Wait AS VARCHAR(2)), '-') + ': '
             + ISNULL(STUFF((SELECT '; ' + MeetingNo + ':' + ListCode + ':' + ISNULL(CAST(WaitingForMe AS VARCHAR(12)), '-') FROM #MT WHERE MeetingNo LIKE '9440_' AND CommitteeName = 'ZZ44 committee'
                             ORDER BY MeetingNo FOR XML PATH('')), 1, 2, ''), 'no rows');

        -- the earlier text with the same input: the fifteen columns and the three outputs it had
        SET @OldRR = 'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', statistics ' + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ', role ' + ISNULL(@Role, '-');
        SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL; SET @Role = NULL;
        INSERT INTO #MO EXEC dbo.spr_ZZ44_MeetingsOld @ActingUserId = @cUser, @CommitteeId = @Id, @DepartmentId = @N, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
            @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT;
        SET @NewRR = 'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', statistics ' + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ', role ' + ISNULL(@Role, '-');
        IF (@OldRR <> @NewRR
            OR (SELECT COUNT(*) FROM #MT) <> (SELECT COUNT(*) FROM #MO)
            OR EXISTS (SELECT MeetingId, CommitteeId, CommitteeCode, CommitteeName, MeetingNo, MeetingDate, MeetingTime, AgendaSubmissionDate, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending FROM #MT
                       EXCEPT SELECT MeetingId, CommitteeId, CommitteeCode, CommitteeName, MeetingNo, MeetingDate, MeetingTime, AgendaSubmissionDate, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending FROM #MO)
            OR EXISTS (SELECT MeetingId, CommitteeId, CommitteeCode, CommitteeName, MeetingNo, MeetingDate, MeetingTime, AgendaSubmissionDate, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending FROM #MO
                       EXCEPT SELECT MeetingId, CommitteeId, CommitteeCode, CommitteeName, MeetingNo, MeetingDate, MeetingTime, AgendaSubmissionDate, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending FROM #MT))
            SET @Refused = @Refused + 1;
        FETCH NEXT FROM MeetCursor INTO @Txt, @cUser, @Id, @N, @OldOut;
    END
    CLOSE MeetCursor;
    DEALLOCATE MeetCursor;
    INSERT INTO @T SELECT 'Meeting list: in the eleven calls above the earlier text gives the same rows in the fifteen columns of before and the same Result, Reason, statistics flag and role (calls that differ)', '0', CAST(@Refused AS VARCHAR(12));

    -- the same comparison for every active user of the database, every committee, no filter
    SET @Refused = 0; SET @N = 0;
    DECLARE AllCursor CURSOR LOCAL FAST_FORWARD FOR SELECT u.UserId FROM Users u WHERE u.AccountStatus = 1 AND u.LoginName NOT LIKE 'zz44%';
    OPEN AllCursor;
    FETCH NEXT FROM AllCursor INTO @cUser;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        SET @N = @N + 1;
        DELETE FROM #MT; DELETE FROM #MO;
        INSERT INTO #MT EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = 0, @DepartmentId = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
            @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT, @WaitingShown = @Wait OUTPUT;
        SET @OldRR = ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ISNULL(@Role, '-');
        INSERT INTO #MO EXEC dbo.spr_ZZ44_MeetingsOld @ActingUserId = @cUser, @CommitteeId = 0, @DepartmentId = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT,
            @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @Role OUTPUT;
        SET @NewRR = ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ISNULL(@Role, '-');
        IF (@OldRR <> @NewRR
            OR (SELECT COUNT(*) FROM #MT) <> (SELECT COUNT(*) FROM #MO)
            OR EXISTS (SELECT MeetingId, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending, MeetingDate, MeetingNo FROM #MT
                       EXCEPT SELECT MeetingId, ListCode, StateCode, StateLabel, Items, Approved, Rejected, Pending, MeetingDate, MeetingNo FROM #MO)
            OR EXISTS (SELECT 1 FROM #MT t INNER JOIN Roles r ON r.RoleCode = @Role WHERE t.WaitingForMe IS NOT NULL AND r.RoleCode NOT IN ('controller', 'manager')))
            SET @Refused = @Refused + 1;
        FETCH NEXT FROM AllCursor INTO @cUser;
    END
    CLOSE AllCursor;
    DEALLOCATE AllCursor;
    INSERT INTO @T SELECT 'Meeting list: for every active user of the database (' + CAST(@N AS VARCHAR(12)) + ') the earlier text gives the same rows and outputs, and no waiting count for a role other than Controller and Manager (users that differ)', '0', CAST(@Refused AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- My approvals. Eleven more items at AMA first, so the Controller has twelve (two pages).
    ---------------------------------------------------------------------------
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ44-y' + RIGHT('0' + CAST(n.N AS VARCHAR(2)), 2), @Com, @MOpen, @DA, @SubjectTypeId, 'ZZ44 y' + RIGHT('0' + CAST(n.N AS VARCHAR(2)), 2), 'Entry', 'AMA', 'New', @Now, @Usr
    FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11)) n(N);

    DECLARE ApCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.Name, x.UserId, x.CommitteeId, x.DepartmentId, x.PageNo, x.Expected
        FROM (SELECT 1 AS Seq, 'the Controller, committee Z44, page 1: twelve items at AMA of the open meeting (not the one whose date passed, not the finalised one), ten on the page' AS Name,
                     @Ctl AS UserId, @Com AS CommitteeId, 0 AS DepartmentId, 1 AS PageNo,
                     'Result 1, Reason 0, total 12, page 1: oAMA, y01, y02, y03, y04, y05, y06, y07, y08, y09' AS Expected
              UNION ALL SELECT 2, 'the Controller, page 2', @Ctl, @Com, 0, 2, 'Result 1, Reason 0, total 12, page 2: y10, y11'
              UNION ALL SELECT 3, 'the Controller, a page past the end: the last page', @Ctl, @Com, 0, 9, 'Result 1, Reason 0, total 12, page 2: y10, y11'
              UNION ALL SELECT 4, 'the manager of the creator: the open meeting first, then the one without a date; not the passed date, not the finalised agenda', @Mg1, 0, 0, 1, 'Result 1, Reason 0, total 2, page 1: oAC, nAC'
              UNION ALL SELECT 5, 'the manager with an alert row: also the item of department B', @Mg2, 0, 0, 1, 'Result 1, Reason 0, total 3, page 1: oAC, xAC, nAC'
              UNION ALL SELECT 6, 'the same, his department B chosen', @Mg2, 0, @DB, 1, 'Result 1, Reason 0, total 1, page 1: xAC'
              UNION ALL SELECT 7, 'the same, a department that is not his', @Mg2, 0, @DA, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 8, 'the manager who removed his alert row', @Mg3, @Com, 0, 1, 'Result 1, Reason 0, total 3, page 1: oAC, xAC, nAC'
              UNION ALL SELECT 9, 'the manager not routed: allowed, nothing waits', @Mg4, 0, 0, 1, 'Result 1, Reason 0, total 0, page 1: no rows'
              UNION ALL SELECT 10, 'the user: no panel', @Usr, 0, 0, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 11, 'Management: no panel', @Gmt, 0, 0, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 12, 'MD Secretariat: no panel', @Mds, 0, 0, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 13, 'the Admin: no panel', @Adm, 0, 0, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 14, 'the system account: refused as a system account', @Sys, 0, 0, 1, 'Result 0, Reason 12, total 0, page 1: no rows'
              UNION ALL SELECT 15, 'the inactive manager', @Off, 0, 0, 1, 'Result 0, Reason 8, total 0, page 1: no rows'
              UNION ALL SELECT 16, 'no acting user', NULL, 0, 0, 1, 'Result 0, Reason 8, total 0, page 1: no rows'
              UNION ALL SELECT 17, 'an unknown acting user', -1, 0, 0, 1, 'Result 0, Reason 8, total 0, page 1: no rows'
              UNION ALL SELECT 18, 'the Controller with a department: refused', @Ctl, @Com, @DA, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 19, 'an unknown committee', @Ctl, -5, 0, 1, 'Result 0, Reason 4, total 0, page 1: no rows'
              UNION ALL SELECT 20, 'page 0', @Ctl, @Com, 0, 0, 'Result 0, Reason 4, total 0, page 1: no rows') x
        ORDER BY x.Seq;
    OPEN ApCursor;
    FETCH NEXT FROM ApCursor INTO @Txt, @cUser, @Id, @N, @Page, @OldOut;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        DELETE FROM #AP; SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Shown = NULL;
        INSERT INTO #AP EXEC spr_GetDashboardApprovals @ActingUserId = @cUser, @CommitteeId = @Id, @DepartmentId = @N, @PageNo = @Page,
            @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Shown OUTPUT;
        INSERT INTO @T SELECT 'My approvals: ' + @Txt, CAST(@OldOut AS VARCHAR(1000)),
               'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-')
             + ', page ' + ISNULL(CAST(@Shown AS VARCHAR(12)), '-') + ': '
             + ISNULL(STUFF((SELECT ', ' + SUBSTRING(AgendaNo, 6, 20) FROM #AP ORDER BY RowNo FOR XML PATH('')), 1, 2, ''), 'no rows');
        FETCH NEXT FROM ApCursor INTO @Txt, @cUser, @Id, @N, @Page, @OldOut;
    END
    CLOSE ApCursor;
    DEALLOCATE ApCursor;

    DELETE FROM #AP;
    INSERT INTO #AP EXEC spr_GetDashboardApprovals @ActingUserId = @Mg2, @CommitteeId = @Com, @DepartmentId = 0, @PageNo = 1,
        @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @PageShown = @Shown OUTPUT;
    INSERT INTO @T SELECT 'My approvals: a row carries the committee, the meeting, the item, the department and the item''s alert', 'ZZ44 committee | 94401 | ZZ44-xAC | ZZ44 xAC | ZZ44 department B | alert of the item',
           ISNULL((SELECT p.CommitteeName + ' | ' + p.MeetingNo + ' | ' + p.AgendaNo + ' | ' + CAST(p.ShortText AS VARCHAR(100)) + ' | ' + p.DepartmentName + ' | '
                        + CASE WHEN p.AlertId = (SELECT TOP 1 am.AlertId FROM Alert_Master am WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = p.AgendaId) THEN 'alert of the item' ELSE 'another alert' END
                   FROM #AP p WHERE p.AgendaNo = 'ZZ44-xAC'), 'row missing');
    INSERT INTO @T SELECT 'The panel and the column agree: the manager''s rows in the panel = the sum of his Waiting for me counts (committee Z44)', '3 = 3',
           CAST((SELECT COUNT(*) FROM #AP) AS VARCHAR(12)) + ' = '
         + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaWaitingFor(@Mg2, @Today) w WHERE w.IsWaiting = 1 AND w.CommitteeId = @Com) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Last inside the transaction: the Rollback's two batches, compared with the texts step 44 was built from
    ---------------------------------------------------------------------------
    EXEC (@OldAgenda);
    EXEC (@OldMeet);
    SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), CHAR(13), ''); SET @AgendaHash = ''; SET @I = 1;
    WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
    BEGIN
        SET @AgendaHash = @AgendaHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
        SET @I = @I + 4000;
    END
    SET @D = REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''); SET @MeetHash = ''; SET @I = 1;
    WHILE (@D IS NOT NULL AND @I <= DATALENGTH(@D) / 2)
    BEGIN
        SET @MeetHash = @MeetHash + CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(SUBSTRING(@D, @I, 4000) AS NVARCHAR(4000))), 2);
        SET @I = @I + 4000;
    END
    INSERT INTO @T SELECT 'The Rollback''s texts of spr_UpdateAgendaByAgendaId and spr_GetDashboardMeetings, installed here: SHA-1 against the saved originals (steps 35 and 42), no step 44 marker',
           'same, same, 0 markers',
           CASE WHEN @AgendaHash = '763564301F411D7CC3D94064BB115F4C23EC028A757040AD9F753B4E63B8652C378D7B74305741E8A4D1FE63C03B201B1FEDB06B4DA27D7EB55874F4' THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN @MeetHash = 'A174C0B06EA28F9C2B914B6C581F74D2D1F4788A4BDBA6D90C4878E28B72831FFC6C1866F007CE47' THEN 'same' ELSE 'differs' END + ', '
         + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) LIKE '%AgendaWaitingFor-Step44%' THEN 1 ELSE 0 END
              + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')) LIKE '%AgendaWaitingFor-Step44%' THEN 1 ELSE 0 END AS VARCHAR(2)) + ' markers';
    INSERT INTO @T SELECT 'The hashed texts are whole: characters of the two restored procedures', '10082, 5907',
           CAST(LEN(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'))) - (LEN(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'))) - LEN(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), CHAR(13), ''))) AS VARCHAR(12)) + ', '
         + CAST(LEN(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings'))) - (LEN(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings'))) - LEN(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')), CHAR(13), ''))) AS VARCHAR(12));

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus, UpdatedBy, UpdatedOn)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @AuditAfter = CAST(COUNT(*) AS VARCHAR(12)) FROM Audit_Trail_Master;
INSERT INTO @T SELECT 'After the rollback: Agenda unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;
INSERT INTO @T SELECT 'After the rollback: Alert_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: Audit_Trail_Master has the rows of before (count)', @AuditBefore, @AuditAfter;
INSERT INTO @T SELECT 'After the rollback: step 44 is installed again (markers in the five objects), the temporary objects are gone', '5, 0',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_AgendaWaitingFor'), ('spr_GetAgendaApprovalState'), ('spr_GetDashboardApprovals'),
                                          ('spr_UpdateAgendaByAgendaId'), ('spr_GetDashboardMeetings')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%AgendaWaitingFor-Step44%') AS VARCHAR(12)) + ', '
     + CAST((SELECT COUNT(*) FROM sys.objects WHERE name LIKE '%ZZ44%') AS VARCHAR(12));

Report:

INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Put every identity counter back (a rollback does not reliably), as BMMS-Test-ResetDatabase.sql does
DECLARE @Sql NVARCHAR(MAX);
DECLARE @TableName SYSNAME;
DECLARE @SavedValue BIGINT;
DECLARE @SeedValue BIGINT;
DECLARE @IncrementValue BIGINT;

DECLARE IdentCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, SavedValue, SeedValue, IncrementValue FROM #Ident;

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
        EXEC sp_executesql @Sql;
    END

    FETCH NEXT FROM IdentCursor INTO @TableName, @SavedValue, @SeedValue, @IncrementValue;
END

CLOSE IdentCursor;
DEALLOCATE IdentCursor;

INSERT INTO #T
SELECT 'After the test: used identity counters that changed', '0', CAST(COUNT(*) AS VARCHAR(12))
FROM #Ident i
WHERE i.SavedValue IS NOT NULL
AND CAST(IDENT_CURRENT('dbo.' + QUOTENAME(i.TableName)) AS BIGINT) <> i.SavedValue;

INSERT INTO #T
SELECT 'After the test: no ZZ44 department, user, committee, meeting, item or alert left', '0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ44%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz44%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z44') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ44 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ44-%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Alert_Master WHERE DisplayText LIKE 'ZZ44 %') AS VARCHAR(12));

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM #T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM #T;

DROP TABLE #MO;
DROP TABLE #MT;
DROP TABLE #AP;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
