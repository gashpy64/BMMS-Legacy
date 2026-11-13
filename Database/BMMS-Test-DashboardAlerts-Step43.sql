/* ============================================================================
   BMMS - Test of step 43 (Dashboard alert rules, step UN6c1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 43
   is not installed.

   Run it in a NEW query window (it uses temporary tables of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the markers, parameters and result columns; that the
   objects step 43 does not change carry no marker; that every database user
   who can run step 42's procedure can run the procedures of this step (the
   script grants nothing, as step 42; the application login holds EXECUTE on
   the schema).

   Part 2 works inside ONE transaction that is rolled back, with made-up data
   (names beginning ZZ43):
     - every alert type (CC, CU, MC, MU, AF, MF, AC, AMA, AMR, ACA, ACR) with
       one old (10 days) and one young (2 days) read alert, and two alerts at
       the edge of the seven days;
     - the acting person and the event date per type: an ordinary approval
       (the approver, the decision date, although UpdatedOn is 30 seconds
       later), an edit after the decision (the editor, UpdatedOn), a decision
       without a recorded approver (nobody), an item at AC, an inactive
       person, an alert whose item is gone;
     - Recent, Unread, All; paging; the count of the header;
     - the Controller's and the Manager's type filters;
     - the Admin role and the protected system account: empty list, count 0;
     - the two mail procedures: no address of the Admin role in any branch,
       the Controller, the Manager and the creator still there;
     - "Remove from my list": own row, another user's row, an unknown id;
     - spr_UpdateAlertByUserId (unchanged) marks only the acting user's row;
     - the Action Items card: the rows each role gets (Controller,
       Management, a Manager with two departments, a Manager with one, a
       User, a User of a department without items, MD Secretariat, Admin, the
       system account, an inactive and a missing user), with an item of a
       third department, an item whose minutes are still open, a confirmed
       item and a stale mapping row; the read state per person; the four
       conditions of IsOverdue;
     - opening an item (spr_OpenDashboardActionItem): one read row per
       person, never a second, nothing outside the scope, the item itself
       untouched (Management);
     - saving the action text (spr_SaveDashboardActionText): Controller,
       Manager and User inside their scope; Management, MD Secretariat,
       Admin and another department's item refused;
     - Reasons 8 and 4;
     - the Rollback's two batches (the texts of steps 18 and 37) run here,
       inside the transaction, and their SHA-1 is compared with the texts step
       43 was built from; the rollback of the transaction puts step 43 back.

   Afterwards: nothing of ZZ43 is left, the alert and action item tables are
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
ELSE IF (OBJECT_ID('dbo.fn_DashboardAlerts', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardAlerts', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetAlertCount', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_RemoveAlertForUser', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardActionItems', 'P') IS NULL
         OR OBJECT_ID('dbo.fn_DashboardActionItems', 'IF') IS NULL
         OR OBJECT_ID('dbo.spr_OpenDashboardActionItem', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_SaveDashboardActionText', 'P') IS NULL)
BEGIN
    RAISERROR('Step 43 (BMMS-Fix-DashboardAlerts-Step43.sql) is not installed, or not in its latest text, in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#AL') IS NOT NULL DROP TABLE #AL;
IF OBJECT_ID('tempdb..#AI') IS NOT NULL DROP TABLE #AI;
IF OBJECT_ID('tempdb..#Mail') IS NOT NULL DROP TABLE #Mail;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(250), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #AL (RowNo INT, AlertUserId INT, AlertId INT, UserId INT, ReadStatus INT, SourceType VARCHAR(50), SourceTypeId INT,
                  DepartmentId INT, DepartmentName NVARCHAR(200), AlertTypeCode VARCHAR(10), AlertTypeName VARCHAR(50), CommitteeId INT,
                  CommitteeCode VARCHAR(50), CommitteeName NVARCHAR(200), DisplayText VARCHAR(150), CreatedOn DATETIME, EventOn DATETIME,
                  ActorUserId INT, ActorName NVARCHAR(200), ActorLogin NVARCHAR(200));
CREATE TABLE #AI (ActionItemId INT, MinutesId INT, ActionText NVARCHAR(MAX), ActionStatus VARCHAR(50), AgendaId INT, DecisionTypeId INT,
                  DueDate DATETIME, AgendaNo VARCHAR(50), CommitteeId INT, MeetingId INT, DecisionTypeCode VARCHAR(50),
                  DecisionTypeName NVARCHAR(200), SubjectNo NVARCHAR(50), DepartmentCode VARCHAR(50), DepartmentName NVARCHAR(200),
                  ActualResolution NVARCHAR(MAX), CommitteeName NVARCHAR(200), CommitteeCode VARCHAR(50), MeetingDate DATETIME,
                  MeetingTime VARCHAR(50), Venue NVARCHAR(500), UserId INT, ReadStatus INT, DepartmentId INT, Directions NVARCHAR(MAX),
                  IsComplied INT, IsConfirmed INT, IsOverdue INT);
CREATE TABLE #Mail (EmailId NVARCHAR(200));

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
INSERT INTO #T SELECT 'Marker DashboardAlerts-Step43 in the eight new objects and the two replaced mail procedures', '10',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'), ('spr_RemoveAlertForUser'),
                                          ('spr_GetDashboardActionItems'), ('fn_DashboardActionItems'), ('spr_OpenDashboardActionItem'),
                                          ('spr_SaveDashboardActionText'), ('spr_GetAlertMailId'), ('spr_GetAgendaUpdateMailId')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12));

INSERT INTO #T SELECT 'Parameters (all, OUTPUT): alerts 8 5, count 4 3, remove 4 2, action items 3 2, alert function 1 0, open 4 2, save 5 2, action item function 2 0', '8 5, 4 3, 4 2, 3 2, 1 0, 4 2, 5 2, 2 0',
       STUFF((SELECT ', ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.parameter_id > 0) AS VARCHAR(12))
                     + ' ' + CAST((SELECT COUNT(*) FROM sys.parameters p WHERE p.object_id = OBJECT_ID('dbo.' + o.Name) AND p.is_output = 1 AND p.parameter_id > 0) AS VARCHAR(12))
              FROM (VALUES (1, 'spr_GetDashboardAlerts'), (2, 'spr_GetAlertCount'), (3, 'spr_RemoveAlertForUser'), (4, 'spr_GetDashboardActionItems'),
                           (5, 'fn_DashboardAlerts'), (6, 'spr_OpenDashboardActionItem'), (7, 'spr_SaveDashboardActionText'),
                           (8, 'fn_DashboardActionItems')) o(Seq, Name)
              ORDER BY o.Seq FOR XML PATH('')), 1, 2, '');

DECLARE @Cols VARCHAR(MAX);
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardAlerts'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardAlerts: the result columns the page reads, in this order',
       'RowNo,AlertUserId,AlertId,UserId,ReadStatus,SourceType,SourceTypeId,DepartmentId,DepartmentName,AlertTypeCode,AlertTypeName,CommitteeId,CommitteeCode,CommitteeName,DisplayText,CreatedOn,EventOn,ActorUserId,ActorName,ActorLogin',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardActionItems'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardActionItems: the columns of View_Action_Item_Users and IsOverdue',
       'ActionItemId,MinutesId,ActionText,ActionStatus,AgendaId,DecisionTypeId,DueDate,AgendaNo,CommitteeId,MeetingId,DecisionTypeCode,DecisionTypeName,SubjectNo,DepartmentCode,DepartmentName,ActualResolution,CommitteeName,CommitteeCode,MeetingDate,MeetingTime,Venue,UserId,ReadStatus,DepartmentId,Directions,IsComplied,IsConfirmed,IsOverdue',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_OpenDashboardActionItem'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_OpenDashboardActionItem: the same columns (the details panel reads them)',
       'ActionItemId,MinutesId,ActionText,ActionStatus,AgendaId,DecisionTypeId,DueDate,AgendaNo,CommitteeId,MeetingId,DecisionTypeCode,DecisionTypeName,SubjectNo,DepartmentCode,DepartmentName,ActualResolution,CommitteeName,CommitteeCode,MeetingDate,MeetingTime,Venue,UserId,ReadStatus,DepartmentId,Directions,IsComplied,IsConfirmed,IsOverdue',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + c.name FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.fn_DashboardActionItems') ORDER BY c.column_id;
INSERT INTO #T SELECT 'fn_DashboardActionItems: the 27 columns of View_Action_Item_Users and IsOverdue',
       'ActionItemId,MinutesId,ActionText,ActionStatus,AgendaId,DecisionTypeId,DueDate,AgendaNo,CommitteeId,MeetingId,DecisionTypeCode,DecisionTypeName,SubjectNo,DepartmentCode,DepartmentName,ActualResolution,CommitteeName,CommitteeCode,MeetingDate,MeetingTime,Venue,UserId,ReadStatus,DepartmentId,Directions,IsComplied,IsConfirmed,IsOverdue',
       ISNULL(@Cols, 'none');

INSERT INTO #T SELECT 'Not changed by step 43 (no marker): spr_GetAlertByUserId, spr_UpdateAlertByAlertUserId, spr_UpdateAlertByUserId, View_Alert, spr_GetActionItemByUserId', '0 of 5',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_GetAlertByUserId'), ('spr_UpdateAlertByAlertUserId'), ('spr_UpdateAlertByUserId'), ('View_Alert'),
                                          ('spr_GetActionItemByUserId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), 'DashboardAlerts-Step43') LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12)) + ' of 5';

INSERT INTO #T SELECT 'Not changed by step 43 (no marker): spr_UpdateMinutes, spr_MinutesFinalizeByMeetingId (they write the mapping rows as before), spr_UpdateActionItem, spr_UpdateActionItemByUserId, spr_GetActionItemByActionItemIdUserId, View_Action_Item_Users', '0 of 6',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_UpdateMinutes'), ('spr_MinutesFinalizeByMeetingId'), ('spr_UpdateActionItem'), ('spr_UpdateActionItemByUserId'),
                                          ('spr_GetActionItemByActionItemIdUserId'), ('View_Action_Item_Users')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), 'DashboardAlerts-Step43') LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12)) + ' of 6';

INSERT INTO #T SELECT 'The five procedures that write alerts are not changed (no marker)', '0 of 5',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'), ('spr_AddEditMeeting'),
                                          ('spr_AddEditCommittee')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), 'DashboardAlerts-Step43') LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12)) + ' of 5';

INSERT INTO #T SELECT 'The mail procedures are not the earlier texts any more (SHA-1 differs from steps 18 and 37)', 'differs, differs',
       CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                 = '7C811E422DCF63725C91DA81EC5EB3195B677E73' THEN 'same' ELSE 'differs' END + ', '
     + CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                 = 'F6BD3580A632DF8643F2406DA53F1256D8FC6D33' THEN 'same' ELSE 'differs' END;

INSERT INTO #T SELECT 'No DENY of EXECUTE or SELECT on the eight new objects', '0',
       CAST((SELECT COUNT(*) FROM sys.database_permissions pe
             WHERE pe.class = 1 AND pe.state = 'D'
             AND pe.major_id IN (OBJECT_ID('dbo.fn_DashboardAlerts'), OBJECT_ID('dbo.spr_GetDashboardAlerts'), OBJECT_ID('dbo.spr_GetAlertCount'),
                                 OBJECT_ID('dbo.spr_RemoveAlertForUser'), OBJECT_ID('dbo.spr_GetDashboardActionItems'),
                                 OBJECT_ID('dbo.fn_DashboardActionItems'), OBJECT_ID('dbo.spr_OpenDashboardActionItem'),
                                 OBJECT_ID('dbo.spr_SaveDashboardActionText'))) AS VARCHAR(12));
GO

-- Every database user who can run step 42's spr_GetDashboardMeetings (the application login among them) can run the
-- six new procedures and the two replaced ones. Asked of the server as that user (EXECUTE AS USER), so a schema or
-- database grant counts as it does for the application.
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
        SET @Can = CASE WHEN HAS_PERMS_BY_NAME('dbo.spr_GetDashboardMeetings', 'OBJECT', 'EXECUTE') = 1 THEN
                        HAS_PERMS_BY_NAME('dbo.spr_GetDashboardAlerts', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetAlertCount', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_RemoveAlertForUser', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetDashboardActionItems', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_OpenDashboardActionItem', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_SaveDashboardActionText', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetAlertMailId', 'OBJECT', 'EXECUTE')
                      + HAS_PERMS_BY_NAME('dbo.spr_GetAgendaUpdateMailId', 'OBJECT', 'EXECUTE') ELSE -1 END;
        REVERT;
        IF (@Can >= 0) SET @Users = @Users + 1;
        IF (@Can >= 0 AND @Can < 8)
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
INSERT INTO #T SELECT 'EXECUTE: database users who can run step 42''s procedure but not all eight procedures of step 43 (' + CAST(@Users AS VARCHAR(12)) + ' such users asked)',
       '0', CAST(@Cannot AS VARCHAR(12)) + CASE WHEN @Cannot > 0 THEN ':' + @Names ELSE '' END;
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(250), Expected VARCHAR(1000), Actual VARCHAR(1000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);
DECLARE @Old DATETIME = DATEADD(HOUR, 10, DATEADD(DAY, -10, @Day));
DECLARE @Young DATETIME = DATEADD(HOUR, 10, DATEADD(DAY, -2, @Day));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @SysRole VARCHAR(50) = (SELECT TOP 1 r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.IsSystem = 1 ORDER BY u.UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @Followup INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId = 1);
DECLARE @DeptB INT, @DeptC INT, @DeptD INT, @MeetC INT, @MeetO INT, @Mg1 INT, @UsD INT, @Mds INT;
DECLARE @I1 INT, @I2 INT, @I3 INT, @I4 INT, @I5 INT, @I6 INT, @I7 INT, @I8 INT, @I9 INT;
DECLARE @ItemState VARCHAR(400), @AiMapBefore VARCHAR(60), @AiMapAfter VARCHAR(60);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @DecisionTypeId INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type ORDER BY DecisionTypeId);
DECLARE @Dept INT, @Com INT, @Meet INT;
DECLARE @Adm INT, @Ctl INT, @Mgr INT, @Usr INT, @Us2 INT, @Gmt INT, @Off INT;
DECLARE @Res INT, @Rsn INT, @Total INT, @Unread INT, @Page INT, @Rows INT, @Id INT, @Other INT, @AgId INT, @AlId INT;
DECLARE @Txt VARCHAR(1000);
DECLARE @MapBefore VARCHAR(60), @MapAfter VARCHAR(60), @MasterBefore VARCHAR(60), @MasterAfter VARCHAR(60), @ItemBefore VARCHAR(60), @ItemAfter VARCHAR(60);
DECLARE @OldMail NVARCHAR(MAX), @OldUpdate NVARCHAR(MAX);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL OR @Followup IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL OR @DecisionTypeId IS NULL
    OR (SELECT COUNT(*) FROM Alert_Type WHERE AlertTypeCode IN ('CC', 'CU', 'MC', 'MU', 'AC', 'AMA', 'AMR', 'ACA', 'ACR', 'AF', 'MF')) <> 11)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation, a subject type, the decision type Followup (1) or one of the eleven alert types is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @MasterBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, AlertTypeCode, CreatedOn, CreatedBy)), 0) AS VARCHAR(12)) FROM Alert_Master;
SELECT @ItemBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed)), 0) AS VARCHAR(12)) FROM Action_Item;
SELECT @AiMapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;

-- The texts of steps 18 and 37, as in BMMS-Rollback-DashboardAlerts-Step43.sql
SET @OldMail = N'
-- Agenda alert mail addresses (Bcc of the approve / reject mails): active users only (UserStatus2b-Step17)
-- Recipients are active users other than the protected system account (SystemAccount3-Step18)
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAlertMailId]
@Code varchar(50),
@UserId INT,
@AgendaId INT
AS
	DECLARE @AlertId INT
	DECLARE @User_Id INT
BEGIN

IF @Code = ''AMR''
BEGIN
	
    SELECT EmailId FROM Users WHERE UserId IN (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId) AND AccountStatus = 1 AND IsSystem = 0;

END

IF @Code = ''AMA''
BEGIN

	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE (RoleId = 2 OR UserId = @User_Id) AND AccountStatus = 1 AND IsSystem = 0;

END

IF @Code = ''ACA'' OR @Code = ''ACR''
BEGIN

	SET @AlertId = (SELECT AlertId FROM Alert_Master WHERE SourceType = ''Agenda'' AND SourceTypeId = @AgendaId);
	SET @User_Id = (SELECT CreatedBy FROM Agenda WHERE AgendaId = @AgendaId)

	SELECT EmailId FROM Users WHERE UserId IN
		(SELECT UserId FROM Alert_User_Map WHERE AlertId = @AlertId) AND AccountStatus = 1 AND IsSystem = 0;

END

	
END
';
SET @OldUpdate = N'
-- UpdateMail-Step37: who gets the mail when an agenda item is updated: the users the refreshed alert is shown to
-- (Alert_User_Map rows of the item''s alert except the acting user, with the role filter of spr_GetAlertByUserId),
-- active, not the system account, with an address. Reads only.
CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaUpdateMailId]
@AgendaId INT,
@ActingUserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT u.EmailId
	FROM Alert_Master am
	JOIN Alert_User_Map m ON m.AlertId = am.AlertId
	JOIN Users u ON u.UserId = m.UserId
	LEFT JOIN Roles r ON r.RoleId = u.RoleId
	WHERE am.SourceType = ''Agenda'' AND am.SourceTypeId = @AgendaId
	  AND m.UserId <> @ActingUserId
	  AND u.AccountStatus = 1 AND u.IsSystem = 0
	  AND LTRIM(RTRIM(ISNULL(u.EmailId, ''''))) <> ''''
	  AND NOT (ISNULL(r.RoleCode, '''') = ''controller'' AND am.AlertTypeCode IN (''ACA'', ''ACR''))
	  AND NOT (ISNULL(r.RoleCode, '''') = ''manager'' AND am.AlertTypeCode IN (''AMA'', ''AMR''))
	GROUP BY u.UserId, u.EmailId
	ORDER BY u.UserId;
END
';

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ43A', 'ZZ43 department', 987, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 admin', @Dept, @Desig, NULL, @rAdmin, 'zz43a@example.invalid', 'zz43adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 controller', @Dept, @Desig, NULL, @rCtl, 'zz43c@example.invalid', 'zz43ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 manager', @Dept, @Desig, NULL, @rMgr, 'zz43m@example.invalid', 'zz43mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 user', @Dept, @Desig, @Mgr, @rUser, 'zz43u@example.invalid', 'zz43usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 second user', @Dept, @Desig, @Mgr, @rUser, 'zz43v@example.invalid', 'zz43us2', 'not-a-login', 1, @Now);
    SET @Us2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 management', @Dept, @Desig, NULL, @rMgmt, 'zz43g@example.invalid', 'zz43gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 inactive user', @Dept, @Desig, NULL, @rUser, 'zz43i@example.invalid', 'zz43off', 'not-a-login', 0, @Now);
    SET @Off = SCOPE_IDENTITY();

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z43', 'ZZ43 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94301', @Com, 'ZZ43 test', 'ZZ', DATEADD(DAY, 10, @Day), '10:00', DATEADD(DAY, 5, @Day), 'Open', 'Open', @Now, @Sys);
    SET @Meet = SCOPE_IDENTITY();

    -- Ten agenda items: every agenda alert type, old and young. The label is the alert's DisplayText too.
    --   AC old      edited by the second user (UpdatedBy / UpdatedOn)
    --   AC young    never edited: the creator, CreatedOn
    --   AMA old     an ordinary approval
    --   AMA young   an ordinary approval whose UpdatedOn is 30 seconds after the decision date
    --   AMR old     an ordinary rejection; the item was entered by the ADMIN (for the mail branches)
    --   AMR young   an ordinary rejection
    --   ACA old     an ordinary approval, UpdatedOn 3 milliseconds later
    --   ACA young   approved 3 days ago, edited after it by the second user 2 days ago
    --   ACR old     no recorded approver (before step 35), UpdatedOn set
    --   ACR young   no recorded approver, no UpdatedOn: the alert's own CreatedOn
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus,
                        CreatedOn, CreatedBy, UpdatedOn, UpdatedBy, MgrApprovedDate, MgrApprovedBy, ControllerApprovedDate, ControllerApprovedBy)
    SELECT 'ZZ43-' + x.Code + '-' + x.Age, @Com, @Meet, @Dept, @SubjectTypeId, 'ZZ43 ' + x.Code + ' ' + x.Age, 'Entry', x.Code, 'New',
           x.CreatedOn, x.CreatedBy, x.UpdatedOn, x.UpdatedBy, x.MgrOn, x.MgrBy, x.CtlOn, x.CtlBy
    FROM (SELECT 'AC' AS Code, 'old' AS Age, DATEADD(DAY, -5, @Old) AS CreatedOn, @Usr AS CreatedBy, @Old AS UpdatedOn, @Us2 AS UpdatedBy,
                 CAST(NULL AS DATETIME) AS MgrOn, CAST(NULL AS INT) AS MgrBy, CAST(NULL AS DATETIME) AS CtlOn, CAST(NULL AS INT) AS CtlBy
          UNION ALL SELECT 'AC', 'young', @Young, @Usr, NULL, NULL, NULL, NULL, NULL, NULL
          UNION ALL SELECT 'AMA', 'old', DATEADD(DAY, -5, @Old), @Usr, @Old, @Mgr, @Old, @Mgr, NULL, NULL
          UNION ALL SELECT 'AMA', 'young', DATEADD(DAY, -5, @Old), @Usr, DATEADD(SECOND, 30, @Young), @Mgr, @Young, @Mgr, NULL, NULL
          UNION ALL SELECT 'AMR', 'old', DATEADD(DAY, -5, @Old), @Adm, @Old, @Mgr, @Old, @Mgr, NULL, NULL
          UNION ALL SELECT 'AMR', 'young', DATEADD(DAY, -5, @Old), @Usr, @Young, @Mgr, @Young, @Mgr, NULL, NULL
          UNION ALL SELECT 'ACA', 'old', DATEADD(DAY, -5, @Old), @Usr, DATEADD(MILLISECOND, 3, @Old), @Ctl, DATEADD(DAY, -1, @Old), @Mgr, @Old, @Ctl
          UNION ALL SELECT 'ACA', 'young', DATEADD(DAY, -5, @Old), @Usr, @Young, @Us2, DATEADD(DAY, -2, @Young), @Mgr, DATEADD(DAY, -1, @Young), @Ctl
          UNION ALL SELECT 'ACR', 'old', DATEADD(DAY, -5, @Old), @Usr, @Old, @Ctl, NULL, NULL, NULL, NULL
          UNION ALL SELECT 'ACR', 'young', DATEADD(DAY, -5, @Old), @Usr, NULL, NULL, NULL, NULL, NULL, NULL) x;

    -- The alerts. An agenda alert keeps the date of the entry (20 days ago), except "ACR young" (see above).
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    SELECT 'Agenda', a.AgendaId, @Dept, a.ShortText, a.AgendaStatusCode, 3, @Com,
           CASE WHEN a.ShortText = 'ZZ43 ACR young' THEN @Young ELSE DATEADD(DAY, -20, @Day) END, a.CreatedBy
    FROM Agenda a WHERE a.MeetingId = @Meet;

    -- The other types: the alert's own date and person. CU by the inactive user; AF old with an item that is gone.
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    SELECT x.SourceType, x.SourceTypeId, 0, 'ZZ43 ' + x.Code + ' ' + g.Age, x.Code, 3, @Com, CASE g.Age WHEN 'old' THEN @Old ELSE @Young END,
           CASE WHEN x.Code = 'CU' THEN @Off ELSE @Ctl END
    FROM (SELECT 'CC' AS Code, 'Committee' AS SourceType, @Com AS SourceTypeId
          UNION ALL SELECT 'CU', 'Committee', @Com
          UNION ALL SELECT 'MC', 'Meeting', @Meet
          UNION ALL SELECT 'MU', 'Meeting', @Meet
          UNION ALL SELECT 'AF', 'Agenda', -1
          UNION ALL SELECT 'MF', 'Meeting', @Meet) x
    CROSS JOIN (SELECT 'old' AS Age UNION ALL SELECT 'young') g;

    -- The edge of the seven days: the first moment of day -7 is still recent, one minute before it is not
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Meeting', @Meet, 0, 'ZZ43 MC edge in', 'MC', 3, @Com, DATEADD(DAY, -7, @Day), @Ctl),
           ('Meeting', @Meet, 0, 'ZZ43 MC edge out', 'MC', 3, @Com, DATEADD(MINUTE, -1, DATEADD(DAY, -7, @Day)), @Ctl);

    -- Recipients of all 24: Management has read them all; the others have not
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT am.AlertId, u.UserId, CASE WHEN u.UserId = @Gmt THEN 1 ELSE 0 END, 1
    FROM Alert_Master am
    CROSS JOIN (SELECT @Gmt AS UserId UNION ALL SELECT @Adm UNION ALL SELECT @Sys UNION ALL SELECT @Ctl UNION ALL SELECT @Mgr) u
    WHERE am.DisplayText LIKE 'ZZ43 %';
    -- and the creator on "ACA young" (as the workflow adds him)
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT am.AlertId, @Usr, 0, 1 FROM Alert_Master am WHERE am.DisplayText = 'ZZ43 ACA young';

    INSERT INTO @T SELECT 'Made-up data: agenda items, alerts, recipient rows', '10, 24, 121',
           CAST((SELECT COUNT(*) FROM Agenda WHERE MeetingId = @Meet) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Alert_Master WHERE DisplayText LIKE 'ZZ43 %') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.DisplayText LIKE 'ZZ43 %') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- The acting person and the event date (fn_DashboardAlerts, read as Management)
    ---------------------------------------------------------------------------
    INSERT INTO @T
    SELECT 'Actor and event date: ' + x.Label + ' (' + x.What + ')', x.Expected,
           ISNULL((SELECT ISNULL(f.ActorLogin, '-') + ' ' + CONVERT(VARCHAR(19), f.EventOn, 120)
                   FROM dbo.fn_DashboardAlerts(@Gmt) f WHERE f.DisplayText = x.Label), 'not listed')
    FROM (SELECT 1 AS Seq, 'ZZ43 AC young' AS Label, 'an item at AC, never edited: the creator, CreatedOn' AS What, 'zz43usr ' + CONVERT(VARCHAR(19), @Young, 120) AS Expected
          UNION ALL SELECT 2, 'ZZ43 AC old', 'an item at AC, edited: the editor, UpdatedOn', 'zz43us2 ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 3, 'ZZ43 AMA young', 'an ordinary approval, UpdatedOn 30 seconds later: the approver, the DECISION date', 'zz43mgr ' + CONVERT(VARCHAR(19), @Young, 120)
          UNION ALL SELECT 4, 'ZZ43 AMA old', 'an ordinary approval by the Manager', 'zz43mgr ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 5, 'ZZ43 AMR young', 'a rejection by the Manager', 'zz43mgr ' + CONVERT(VARCHAR(19), @Young, 120)
          UNION ALL SELECT 6, 'ZZ43 AMR old', 'a rejection by the Manager', 'zz43mgr ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 7, 'ZZ43 ACA old', 'an ordinary approval by the Controller, UpdatedOn 3 ms later', 'zz43ctl ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 8, 'ZZ43 ACA young', 'approved 3 days ago, EDITED AFTER the decision: the editor, UpdatedOn', 'zz43us2 ' + CONVERT(VARCHAR(19), @Young, 120)
          UNION ALL SELECT 9, 'ZZ43 ACR old', 'no recorded approver: nobody, UpdatedOn', '- ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 10, 'ZZ43 ACR young', 'no recorded approver, no UpdatedOn: nobody, the alert''s CreatedOn', '- ' + CONVERT(VARCHAR(19), @Young, 120)
          UNION ALL SELECT 11, 'ZZ43 MC young', 'a meeting alert: the alert''s CreatedBy and CreatedOn', 'zz43ctl ' + CONVERT(VARCHAR(19), @Young, 120)
          UNION ALL SELECT 12, 'ZZ43 CU old', 'a committee alert by a person who is inactive now: still named', 'zz43off ' + CONVERT(VARCHAR(19), @Old, 120)
          UNION ALL SELECT 13, 'ZZ43 AF old', 'an agenda alert whose item is gone: the alert''s CreatedBy and CreatedOn', 'zz43ctl ' + CONVERT(VARCHAR(19), @Old, 120)) x
    ORDER BY x.Seq;

    INSERT INTO @T SELECT 'Actor: the name beside the login (ZZ43 AMA young)', 'ZZ43 manager',
           ISNULL((SELECT CAST(f.ActorName AS VARCHAR(200)) FROM dbo.fn_DashboardAlerts(@Gmt) f WHERE f.DisplayText = 'ZZ43 AMA young'), 'not listed');
    INSERT INTO @T SELECT 'Event date of ZZ43 AMA young to the millisecond: the decision date, not UpdatedOn', CONVERT(VARCHAR(23), @Young, 121),
           ISNULL((SELECT CONVERT(VARCHAR(23), f.EventOn, 121) FROM dbo.fn_DashboardAlerts(@Gmt) f WHERE f.DisplayText = 'ZZ43 AMA young'), 'not listed');

    ---------------------------------------------------------------------------
    -- Recent, Unread, All; paging (Management: all 24 read)
    ---------------------------------------------------------------------------
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Unread = NULL; SET @Page = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'R', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Recent, page 1 (24 read alerts: 11 young, 11 old, 2 at the edge)', 'Result 1, Reason 0, total 12, unread 0, page 1, 10 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-')
         + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-') + ', page ' + ISNULL(CAST(@Page AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'R', @PageNo = 2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Recent, pages 1 and 2 together: the young read alert of EVERY type, no old one', '11 types young, 0 old, 12 rows, RowNo 1 to 12',
           CAST((SELECT COUNT(DISTINCT AlertTypeCode) FROM #AL WHERE DisplayText LIKE 'ZZ43 % young') AS VARCHAR(12)) + ' types young, '
         + CAST((SELECT COUNT(*) FROM #AL WHERE DisplayText LIKE 'ZZ43 % old') AS VARCHAR(12)) + ' old, '
         + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows, RowNo ' + CAST((SELECT MIN(RowNo) FROM #AL) AS VARCHAR(12)) + ' to ' + CAST((SELECT MAX(RowNo) FROM #AL) AS VARCHAR(12));
    INSERT INTO @T SELECT 'Recent: a read alert of the first moment of day -7 is listed, one a minute older is not', 'in 1, out 0',
           'in ' + CAST((SELECT COUNT(*) FROM #AL WHERE DisplayText = 'ZZ43 MC edge in') AS VARCHAR(12)) + ', out ' + CAST((SELECT COUNT(*) FROM #AL WHERE DisplayText = 'ZZ43 MC edge out') AS VARCHAR(12));
    INSERT INTO @T SELECT 'Recent: newest event first (rows whose event is newer than that of the row before)', '0',
           CAST((SELECT COUNT(*) FROM #AL a JOIN #AL b ON b.RowNo = a.RowNo + 1 WHERE b.EventOn > a.EventOn) AS VARCHAR(12));

    DELETE FROM #AL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'A', @PageNo = 3, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'All, page 3 of 24 alerts', 'Result 1, total 24, page 3, 4 rows, RowNo 21 to 24',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-') + ', page ' + ISNULL(CAST(@Page AS VARCHAR(12)), '-') + ', '
         + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows, RowNo ' + ISNULL(CAST((SELECT MIN(RowNo) FROM #AL) AS VARCHAR(12)), '-') + ' to ' + ISNULL(CAST((SELECT MAX(RowNo) FROM #AL) AS VARCHAR(12)), '-');
    DELETE FROM #AL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'A', @PageNo = 9, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'All, page 9 asked: the last page is given', 'Result 1, page 3, 4 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', page ' + ISNULL(CAST(@Page AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'U', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Unread, nothing unread', 'Result 1, total 0, unread 0, page 1, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-') + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-')
         + ', page ' + ISNULL(CAST(@Page AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';

    -- One OLD alert becomes unread: it is in Recent and in Unread, and it is the count of the header
    UPDATE m SET ReadStatus = 0 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE m.UserId = @Gmt AND am.DisplayText = 'ZZ43 MC old';
    DELETE FROM #AL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'R', @PageNo = 2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Recent after an old alert became unread: it is listed (every unread alert is)', 'total 13, unread 1, old MC on page 2: 1',
           'total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-') + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-') + ', old MC on page 2: ' + CAST((SELECT COUNT(*) FROM #AL WHERE DisplayText = 'ZZ43 MC old') AS VARCHAR(12));
    DELETE FROM #AL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Gmt, @Mode = 'U', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Unread: that alert only', 'total 1, ZZ43 MC old',
           'total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-') + ', ' + ISNULL((SELECT TOP 1 DisplayText FROM #AL ORDER BY RowNo), 'no row');
    SET @Res = NULL; SET @Rsn = NULL; SET @Unread = NULL;
    EXEC spr_GetAlertCount @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @Unread OUTPUT;
    INSERT INTO @T SELECT 'Header count (spr_GetAlertCount) for Management', 'Result 1, Reason 0, count 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', count ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-');

    ---------------------------------------------------------------------------
    -- Role filters (all 24 unread for each)
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Controller: no ACA and ACR; everything else (24 - 4)', '20 listed, 0 of ACA or ACR',
           CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@Ctl)) AS VARCHAR(12)) + ' listed, '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@Ctl) WHERE AlertTypeCode IN ('ACA', 'ACR')) AS VARCHAR(12)) + ' of ACA or ACR';
    INSERT INTO @T SELECT 'Manager: no AMA and AMR; everything else (24 - 4)', '20 listed, 0 of AMA or AMR',
           CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@Mgr)) AS VARCHAR(12)) + ' listed, '
         + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@Mgr) WHERE AlertTypeCode IN ('AMA', 'AMR')) AS VARCHAR(12)) + ' of AMA or AMR';
    SET @Unread = NULL;
    EXEC spr_GetAlertCount @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @Unread OUTPUT;
    INSERT INTO @T SELECT 'Header count for the Controller: his list only', '20', ISNULL(CAST(@Unread AS VARCHAR(12)), '-');

    ---------------------------------------------------------------------------
    -- The Admin role and the protected system account: 24 unread rows each, nothing listed
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'The Admin and the system account each have 24 unread rows in the table (they are not deleted)', '24, 24',
           CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE m.UserId = @Adm AND m.StatusId = 1 AND am.DisplayText LIKE 'ZZ43 %') AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE m.UserId = @Sys AND m.StatusId = 1 AND am.DisplayText LIKE 'ZZ43 %') AS VARCHAR(12));
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Unread = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Adm, @Mode = 'A', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Admin, mode All: allowed, and an empty list', 'Result 1, Reason 0, total 0, unread 0, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-')
         + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Unread = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Adm, @Mode = 'R', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Admin, mode Recent (24 unread rows): an empty list', 'Result 1, Reason 0, total 0, unread 0, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-')
         + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    SET @Res = NULL; SET @Rsn = NULL; SET @Unread = NULL;
    EXEC spr_GetAlertCount @ActingUserId = @Adm, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @Unread OUTPUT;
    INSERT INTO @T SELECT 'Admin: header count', 'Result 1, Reason 0, count 0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', count ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-');

    INSERT INTO @T SELECT 'The protected system account has the Admin role in this database', 'admin', ISNULL(@SysRole, 'no role');
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL; SET @Total = NULL; SET @Unread = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Sys, @Mode = 'A', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'System account, mode All (its own old rows and 24 new ones): allowed, and an EMPTY list', 'Result 1, Reason 0, total 0, unread 0, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', total ' + ISNULL(CAST(@Total AS VARCHAR(12)), '-')
         + ', unread ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    SET @Res = NULL; SET @Rsn = NULL; SET @Unread = NULL;
    EXEC spr_GetAlertCount @ActingUserId = @Sys, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @Unread OUTPUT;
    INSERT INTO @T SELECT 'System account: header count', 'Result 1, Reason 0, count 0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', count ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-');

    ---------------------------------------------------------------------------
    -- The mail lists: only the ZZ43 addresses are looked at (zz43a = Admin, c = Controller, g = Management,
    -- m = Manager, u = the creator)
    ---------------------------------------------------------------------------
    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 ACA young');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'ACA', @UserId = @Ctl, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Approve mail, branch ACA (the users of the item''s alert; the Admin and the system account have rows): no Admin; Controller, Management, Manager, creator',
           'zz43c, zz43g, zz43m, zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');
    INSERT INTO @T SELECT 'Approve mail, branch ACA: no address of any user with the Admin role in the whole list', '0',
           CAST((SELECT COUNT(*) FROM #Mail ml WHERE EXISTS (SELECT 1 FROM Users u WHERE u.EmailId = ml.EmailId AND u.RoleId = @rAdmin)
                 AND NOT EXISTS (SELECT 1 FROM Users u WHERE u.EmailId = ml.EmailId AND u.RoleId <> @rAdmin)) AS VARCHAR(12));
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'ACR', @UserId = @Ctl, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Reject mail, branch ACR (the same branch): no Admin', 'zz43c, zz43g, zz43m, zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');

    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 AC young');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'AMA', @UserId = @Mgr, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Manager approve mail, branch AMA (the Controllers and the creator): Controller and creator', 'zz43c, zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'AMR', @UserId = @Mgr, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Manager reject mail, branch AMR (the creator): the creator', 'zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');

    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 AMR old');   -- entered by the Admin
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'AMA', @UserId = @Mgr, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Branch AMA for an item the ADMIN entered: the Controller, not the Admin', 'zz43c',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'AMR', @UserId = @Mgr, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'Branch AMR for an item the ADMIN entered: nobody', 'none',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');

    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 AC young');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAgendaUpdateMailId @AgendaId = @AgId, @ActingUserId = @Us2;
    INSERT INTO @T SELECT 'Update mail for an item at AC (alert rows: Admin, system account, Controller, Management, Manager): no Admin', 'zz43c, zz43g, zz43m',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');
    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 ACA young');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAgendaUpdateMailId @AgendaId = @AgId, @ActingUserId = @Us2;
    INSERT INTO @T SELECT 'Update mail for an item at ACA (the Controller is left out as before, step 37): Management, Manager, creator; no Admin', 'zz43g, zz43m, zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');

    ---------------------------------------------------------------------------
    -- Remove from my list
    ---------------------------------------------------------------------------
    SET @AlId = (SELECT AlertId FROM Alert_Master WHERE DisplayText = 'ZZ43 MC young');
    SET @Id = (SELECT AlertUserId FROM Alert_User_Map WHERE AlertId = @AlId AND UserId = @Mgr);
    SET @Other = (SELECT AlertUserId FROM Alert_User_Map WHERE AlertId = @AlId AND UserId = @Ctl);

    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = @Mgr, @AlertUserId = @Other, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: the Manager sends the Controller''s row id: refused, nothing changes', 'Result 0, Reason 4; Controller row shown 1, Manager row shown 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-')
         + '; Controller row shown ' + CAST((SELECT StatusId FROM Alert_User_Map WHERE AlertUserId = @Other) AS VARCHAR(12))
         + ', Manager row shown ' + CAST((SELECT StatusId FROM Alert_User_Map WHERE AlertUserId = @Id) AS VARCHAR(12));
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = @Mgr, @AlertUserId = -5, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: an id that does not exist', 'Result 0, Reason 4',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = @Mgr, @AlertUserId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: no id', 'Result 0, Reason 4',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = @Off, @AlertUserId = @Id, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: an inactive acting user', 'Result 0, Reason 8; row shown 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + '; row shown ' + CAST((SELECT StatusId FROM Alert_User_Map WHERE AlertUserId = @Id) AS VARCHAR(12));
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = NULL, @AlertUserId = @Id, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: no acting user', 'Result 0, Reason 8',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_RemoveAlertForUser @ActingUserId = @Mgr, @AlertUserId = @Id, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Remove: the Manager''s own row: removed from his list only; the row and the alert stay in the tables',
           'Result 1, Reason 0; own row shown 0, exists 1; other rows of the alert shown 4; Manager lists 19',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-')
         + '; own row shown ' + CAST((SELECT StatusId FROM Alert_User_Map WHERE AlertUserId = @Id) AS VARCHAR(12))
         + ', exists ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertUserId = @Id) AS VARCHAR(12))
         + '; other rows of the alert shown ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @AlId AND UserId <> @Mgr AND StatusId = 1) AS VARCHAR(12))
         + '; Manager lists ' + CAST((SELECT COUNT(*) FROM dbo.fn_DashboardAlerts(@Mgr)) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Opening an alert: spr_UpdateAlertByUserId (not changed) marks the acting user's row only
    ---------------------------------------------------------------------------
    SET @AlId = (SELECT AlertId FROM Alert_Master WHERE DisplayText = 'ZZ43 MU young');
    EXEC spr_UpdateAlertByUserId @UserId = @Mgr, @AlertId = @AlId;
    INSERT INTO @T SELECT 'Mark read (spr_UpdateAlertByUserId, unchanged): only the row of the user id given; the other unread rows of the alert stay unread',
           'Manager row read 1; unread rows of the others 3',
           'Manager row read ' + CAST((SELECT ReadStatus FROM Alert_User_Map WHERE AlertId = @AlId AND UserId = @Mgr) AS VARCHAR(12))
         + '; unread rows of the others ' + CAST((SELECT COUNT(*) FROM Alert_User_Map WHERE AlertId = @AlId AND UserId IN (@Adm, @Sys, @Ctl) AND ReadStatus = 0) AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Reasons of the list and the count
    ---------------------------------------------------------------------------
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = NULL, @Mode = 'R', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Alerts: no acting user', 'Result 0, Reason 8, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Off, @Mode = 'R', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Alerts: an inactive acting user', 'Result 0, Reason 8, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Ctl, @Mode = 'X', @PageNo = 1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Alerts: a mode other than R, U, A', 'Result 0, Reason 4, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Ctl, @Mode = 'A', @PageNo = 0, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Alerts: page 0', 'Result 0, Reason 4, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    DELETE FROM #AL; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AL EXEC spr_GetDashboardAlerts @ActingUserId = @Ctl, @Mode = 'a', @PageNo = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @TotalRows = @Total OUTPUT, @UnreadCount = @Unread OUTPUT, @PageShown = @Page OUTPUT;
    INSERT INTO @T SELECT 'Alerts: mode in small letters and no page number count as A and page 1', 'Result 1, Reason 0, 10 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #AL) AS VARCHAR(12)) + ' rows';
    SET @Res = NULL; SET @Rsn = NULL; SET @Unread = NULL;
    EXEC spr_GetAlertCount @ActingUserId = @Off, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @UnreadCount = @Unread OUTPUT;
    INSERT INTO @T SELECT 'Header count: an inactive acting user', 'Result 0, Reason 8, count 0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', count ' + ISNULL(CAST(@Unread AS VARCHAR(12)), '-');

    ---------------------------------------------------------------------------
    -- Action Items card: the scope by role and department, the read state per person, IsOverdue.
    -- Nine followups; the label is the action text.
    --   1 to 6   department A (ZZ43A), minutes finalised (F): the conditions of IsOverdue; 6 is confirmed
    --   7        department B, minutes confirmed (C), due date passed
    --   8        department C (nobody's department here), minutes finalised
    --   9        department A, minutes still open, due date passed
    -- People: the Controller, Management, the manager (home A, also mapped to B), a manager of B only, the user
    -- and the second user (A), a user of department D (no items), MD Secretariat, the Admin, the inactive user.
    -- The lists below show the made-up items only (Directions ZZ43): a Controller and Management see the
    -- database's own items as well.
    -- Mapping rows (they hold the read state only): the user has read 1, not read 2, and has TWO rows for 3 (one
    -- read); the user of department D has a stale row for 1 (as finalising gives every active user one).
    ---------------------------------------------------------------------------
    UPDATE Meeting SET MinutesStatus = 'F' WHERE MeetingId = @Meet;

    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ43B', 'ZZ43 department B', 988, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ43C', 'ZZ43 department C', 989, 1, @Now, @Sys);
    SET @DeptC = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ43D', 'ZZ43 department D', 990, 1, @Now, @Sys);
    SET @DeptD = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 manager of B', @DeptB, @Desig, NULL, @rMgr, 'zz43n@example.invalid', 'zz43mg1', 'not-a-login', 1, @Now);
    SET @Mg1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 user of D', @DeptD, @Desig, NULL, @rUser, 'zz43d@example.invalid', 'zz43usd', 'not-a-login', 1, @Now);
    SET @UsD = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ43 md secretariat', @Dept, @Desig, NULL, @rMd, 'zz43s@example.invalid', 'zz43mds', 'not-a-login', 1, @Now);
    SET @Mds = SCOPE_IDENTITY();

    -- the manager's second department (his home department A needs no row: a user without rows counts as mapped to it)
    INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy)
    VALUES (@Mgr, @DeptB, 0, DATEADD(DAY, -30, @Day), NULL, @Now, @Sys);

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94302', @Com, 'ZZ43 test', 'ZZ', DATEADD(DAY, -20, @Day), '10:00', DATEADD(DAY, -25, @Day), 'Close', 'C', @Now, @Sys);
    SET @MeetC = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('94303', @Com, 'ZZ43 test', 'ZZ', DATEADD(DAY, -15, @Day), '10:00', DATEADD(DAY, -20, @Day), 'Close', 'Open', @Now, @Sys);
    SET @MeetO = SCOPE_IDENTITY();

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    VALUES ('ZZ43-B-item', @Com, @MeetC, @DeptB, @SubjectTypeId, 'ZZ43 item of B', 'Entry', 'ACA', 'New', @Now, @Usr),
           ('ZZ43-C-item', @Com, @Meet, @DeptC, @SubjectTypeId, 'ZZ43 item of C', 'Entry', 'ACA', 'New', @Now, @Usr),
           ('ZZ43-open-item', @Com, @MeetO, @Dept, @SubjectTypeId, 'ZZ43 item open minutes', 'Entry', 'ACA', 'New', @Now, @Usr);

    INSERT INTO Minutes (AgendaId, DecisionTypeId, DueDate, StatusId, CreatedOn, CreatedBy)
    SELECT a.AgendaId, @Followup, x.DueDate, 0, @Now, @Sys
    FROM (SELECT 'ZZ43 AC old' AS Item, DATEADD(HOUR, 10, DATEADD(DAY, -1, @Day)) AS DueDate      -- yesterday 10:00
          UNION ALL SELECT 'ZZ43 AC young', DATEADD(MINUTE, -1, DATEADD(DAY, 1, @Day))            -- today 23:59
          UNION ALL SELECT 'ZZ43 AMA old', DATEADD(DAY, 3, @Day)                                  -- in three days
          UNION ALL SELECT 'ZZ43 AMA young', NULL                                                  -- no due date
          UNION ALL SELECT 'ZZ43 AMR old', DATEADD(DAY, -5, @Day)                                 -- past, complied
          UNION ALL SELECT 'ZZ43 AMR young', DATEADD(DAY, -5, @Day)                               -- past, confirmed
          UNION ALL SELECT 'ZZ43 item of B', DATEADD(DAY, -5, @Day)                               -- past
          UNION ALL SELECT 'ZZ43 item of C', NULL
          UNION ALL SELECT 'ZZ43 item open minutes', DATEADD(DAY, -5, @Day)) x                    -- past
    JOIN Agenda a ON a.MeetingId IN (@Meet, @MeetC, @MeetO) AND a.ShortText = x.Item;

    INSERT INTO Action_Item (MinutesId, Directions, ActionText, ActionStatus, IsComplied, IsConfirmed, UpdatedOn, UpdatedBy)
    SELECT mi.MinutesId, N'ZZ43', x.Label, '', x.IsComplied, x.IsConfirmed, @Old, @Sys
    FROM (SELECT 'ZZ43 AC old' AS Item, N'1 due yesterday' AS Label, 0 AS IsComplied, 0 AS IsConfirmed
          UNION ALL SELECT 'ZZ43 AC young', N'2 due today 23:59', 0, 0
          UNION ALL SELECT 'ZZ43 AMA old', N'3 due in three days', 0, 0
          UNION ALL SELECT 'ZZ43 AMA young', N'4 no due date', 0, 0
          UNION ALL SELECT 'ZZ43 AMR old', N'5 past but complied', 1, 0
          UNION ALL SELECT 'ZZ43 AMR young', N'6 past but confirmed', 1, 1
          UNION ALL SELECT 'ZZ43 item of B', N'7 past, department B', 0, 0
          UNION ALL SELECT 'ZZ43 item of C', N'8 department C', 0, 0
          UNION ALL SELECT 'ZZ43 item open minutes', N'9 open minutes, past', 0, 0) x
    JOIN Agenda a ON a.MeetingId IN (@Meet, @MeetC, @MeetO) AND a.ShortText = x.Item
    JOIN Minutes mi ON mi.AgendaId = a.AgendaId;

    SET @I1 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'1 %');
    SET @I2 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'2 %');
    SET @I3 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'3 %');
    SET @I4 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'4 %');
    SET @I5 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'5 %');
    SET @I6 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'6 %');
    SET @I7 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'7 %');
    SET @I8 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'8 %');
    SET @I9 = (SELECT ActionItemId FROM Action_Item WHERE Directions = N'ZZ43' AND ActionText LIKE N'9 %');

    INSERT INTO ActionItem_User_Map (ActionItemId, UserId, ReadStatus, StatusId)
    VALUES (@I1, @Usr, 1, 1), (@I2, @Usr, 0, 1), (@I3, @Usr, 0, 1), (@I3, @Usr, 1, 1), (@I1, @UsD, 0, 1);

    INSERT INTO @T SELECT 'The nine made-up action items exist (ids found)', '9',
           CAST((SELECT COUNT(*) FROM (VALUES (@I1), (@I2), (@I3), (@I4), (@I5), (@I6), (@I7), (@I8), (@I9)) v(Id) WHERE v.Id IS NOT NULL) AS VARCHAR(12));

    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Controller: every item that is not confirmed, also the one with open minutes and those of every department; overdue 1, 7 and 9',
           'Result 1, Reason 0: 1 due yesterday=1; 2 due today 23:59=0; 3 due in three days=0; 4 no due date=0; 5 past but complied=0; 7 past, department B=1; 8 department C=0; 9 open minutes, past=1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Gmt, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Management: the same rows as the Controller',
           'Result 1, Reason 0: 1 due yesterday=1; 2 due today 23:59=0; 3 due in three days=0; 4 no due date=0; 5 past but complied=0; 7 past, department B=1; 8 department C=0; 9 open minutes, past=1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Manager with two departments (A and B): the items of A and B with finalised or confirmed minutes; not department C (8), not open minutes (9), not the confirmed one (6)',
           'Result 1, Reason 0: 1 due yesterday=1; 2 due today 23:59=0; 3 due in three days=0; 4 no due date=0; 5 past but complied=0; 7 past, department B=1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    INSERT INTO @T SELECT 'The manager has no mapping row: every row unread, UserId the acting user (rows, read, rows with his id)', '6, 0, 6',
           CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ', ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM #AI WHERE UserId = @Mgr) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mg1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Manager with one department (B): its one item',
           'Result 1, Reason 0: 7 past, department B=1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Usr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'User of department A: the items of A with finalised minutes (two mapping rows for item 3 give ONE row); not 9 (open minutes)',
           'Result 1, Reason 0: 1 due yesterday=1; 2 due today 23:59=0; 3 due in three days=0; 4 no due date=0; 5 past but complied=0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    INSERT INTO @T SELECT 'The read state is the person''s own: the user has read 1 and 3 (one of his two rows), not 2; no row for 4 and 5 = unread', '1=1; 2=0; 3=1; 4=0; 5=0',
           ISNULL(STUFF((SELECT '; ' + LEFT(CAST(ActionText AS VARCHAR(100)), 1) + '=' + CAST(ReadStatus AS VARCHAR(2)) FROM #AI ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Us2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Second user of department A (no mapping row at all): the same five items',
           'Result 1, Reason 0: 1 due yesterday=1; 2 due today 23:59=0; 3 due in three days=0; 4 no due date=0; 5 past but complied=0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @UsD, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'User of department D (no items; a stale mapping row for item 1 of department A): allowed, no rows',
           'Result 1, Reason 0: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mds, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'MD Secretariat: no Action Items card',
           'Result 0, Reason 4: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Adm, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Admin: no Action Items card',
           'Result 0, Reason 4: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Sys, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'The protected system account (Admin role): no Action Items card',
           'Result 0, Reason 4: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Off, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Action items: an inactive acting user',
           'Result 0, Reason 8: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Action items: no acting user',
           'Result 0, Reason 8: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Action items: an unknown acting user', 'Result 0, Reason 8: no rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': ' + ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) + '=' + CAST(IsOverdue AS VARCHAR(2)) FROM #AI WHERE Directions = N'ZZ43' ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'no rows');

    -- Opening an item
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mgr, @ActionItemId = @I7, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the manager opens item 7 (in scope, no row yet): the item is returned read, ONE own row is created',
           'Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId = @Mgr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId = @Mgr), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mgr, @ActionItemId = @I7, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open again: no second row',
           'Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId = @Mgr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId = @Mgr), 0) AS VARCHAR(12)) + ')';
    INSERT INTO @T SELECT 'The row created by opening: StatusId 1; the other people''s rows of item 7 untouched (rows of others)', '1, 0',
           CAST(ISNULL((SELECT MAX(StatusId) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId = @Mgr), -1) AS VARCHAR(12)) + ', '
         + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I7 AND UserId <> @Mgr) AS VARCHAR(12));
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the user opens item 2 (his unread row): marked read, no new row',
           'Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I2 AND UserId = @Usr), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I3, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the user opens item 3 (two rows of his): both read, no third row',
           'Result 1, Reason 0, returned 1 (read 1), own rows 2 (read 2)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I3 AND UserId = @Usr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I3 AND UserId = @Usr), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mg1, @ActionItemId = @I1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the manager of B opens item 1 (department A): refused, nothing returned, no row',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Mg1) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Mg1), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Usr, @ActionItemId = @I9, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the user opens item 9 (his department, open minutes): refused, no row',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I9 AND UserId = @Usr) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I9 AND UserId = @Usr), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @UsD, @ActionItemId = @I1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the user of department D opens item 1 (his stale row): refused, the row stays unread',
           'Result 0, Reason 4, returned 0 (read 0), own rows 1 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @UsD) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @UsD), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = @I6, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the Controller opens the confirmed item 6: refused, no row',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I6 AND UserId = @Ctl) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I6 AND UserId = @Ctl), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = @I9, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: the Controller opens item 9 (open minutes): allowed',
           'Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I9 AND UserId = @Ctl) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I9 AND UserId = @Ctl), 0) AS VARCHAR(12)) + ')';
    SET @ItemState = (SELECT ISNULL(CAST(ActionText AS VARCHAR(100)), '') + '|' + ISNULL(ActionStatus, '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                             + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I8);
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Gmt, @ActionItemId = @I8, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: Management opens item 8: allowed, its own read row is created',
           'Result 1, Reason 0, returned 1 (read 1), own rows 1 (read 1)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I8 AND UserId = @Gmt) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I8 AND UserId = @Gmt), 0) AS VARCHAR(12)) + ')';
    INSERT INTO @T SELECT 'Management opened read-only: the action item itself is unchanged (text, status, flags, UpdatedOn, UpdatedBy)', @ItemState,
           (SELECT ISNULL(CAST(ActionText AS VARCHAR(100)), '') + '|' + ISNULL(ActionStatus, '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                 + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I8);
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Mds, @ActionItemId = @I1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: MD Secretariat: refused, no row',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Mds) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Mds), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Adm, @ActionItemId = @I1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: Admin: refused, no row',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Adm) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Adm), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Off, @ActionItemId = @I1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: an inactive acting user: Reason 8, no row',
           'Result 0, Reason 8, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Off) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = @I1 AND UserId = @Off), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = -1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: an unknown item id: refused',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = -1 AND UserId = @Ctl) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = -1 AND UserId = @Ctl), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_OpenDashboardActionItem @ActingUserId = @Ctl, @ActionItemId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Open: no item id: refused',
           'Result 0, Reason 4, returned 0 (read 0), own rows 0 (read 0)',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', returned ' + CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ')'
         + ', own rows ' + CAST((SELECT COUNT(*) FROM ActionItem_User_Map WHERE ActionItemId = NULL AND UserId = @Ctl) AS VARCHAR(12))
         + ' (read ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM ActionItem_User_Map WHERE ActionItemId = NULL AND UserId = @Ctl), 0) AS VARCHAR(12)) + ')';
    DELETE FROM #AI; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #AI EXEC spr_GetDashboardActionItems @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'After opening, the manager''s list shows item 7 read and the others unread (rows, read, the read one)', '6, 1, 7',
           CAST((SELECT COUNT(*) FROM #AI) AS VARCHAR(12)) + ', ' + CAST(ISNULL((SELECT SUM(ReadStatus) FROM #AI), 0) AS VARCHAR(12)) + ', '
         + ISNULL((SELECT TOP 1 LEFT(CAST(ActionText AS VARCHAR(100)), 1) FROM #AI WHERE ReadStatus = 1), '-');

    -- Saving the action text (the Submit of the details panel)
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Gmt, @ActionItemId = @I1, @ActionText = N'ZZ43 by management', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: Management, an item it sees: refused, text unchanged',
           'Result 0, Reason 4, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mds, @ActionItemId = @I1, @ActionText = N'ZZ43 by md', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: MD Secretariat: refused',
           'Result 0, Reason 4, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Adm, @ActionItemId = @I1, @ActionText = N'ZZ43 by admin', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: Admin: refused',
           'Result 0, Reason 4, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mg1, @ActionItemId = @I1, @ActionText = N'ZZ43 by other manager', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the manager of B, an item of department A: refused',
           'Result 0, Reason 4, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mgr, @ActionItemId = @I8, @ActionText = N'ZZ43 by manager', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the manager (A and B), the item of department C: refused',
           'Result 0, Reason 4, text: 8 department C',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I8), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I9, @ActionText = N'ZZ43 by user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the user, the item of his department with open minutes: refused',
           'Result 0, Reason 4, text: 9 open minutes, past',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I9), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I6, @ActionText = N'ZZ43 by controller', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the Controller, the confirmed item: refused',
           'Result 0, Reason 4, text: 6 past but confirmed',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I6), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Off, @ActionItemId = @I1, @ActionText = N'ZZ43 by inactive', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: an inactive acting user: Reason 8',
           'Result 0, Reason 8, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = NULL, @ActionItemId = @I1, @ActionText = N'ZZ43 by nobody', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: no acting user: Reason 8',
           'Result 0, Reason 8, text: 1 due yesterday',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = -1, @ActionText = N'ZZ43 unknown', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: an unknown item id: refused',
           'Result 0, Reason 4, text: no item',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = -1), 'no item');
    SET @ItemState = (SELECT ISNULL(ActionStatus, '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                             + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I1);
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Usr, @ActionItemId = @I1, @ActionText = N'1 saved by the user', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the user, an item of his department: saved',
           'Result 1, Reason 0, text: 1 saved by the user',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I1), 'no item');
    INSERT INTO @T SELECT 'The save wrote the action text only (status, flags, UpdatedOn, UpdatedBy as before, as spr_UpdateActionItem does)', @ItemState,
           (SELECT ISNULL(ActionStatus, '') + '|' + CAST(IsComplied AS VARCHAR(2)) + CAST(IsConfirmed AS VARCHAR(2))
                 + '|' + CONVERT(VARCHAR(30), UpdatedOn, 126) + '|' + CAST(UpdatedBy AS VARCHAR(12)) FROM Action_Item WHERE ActionItemId = @I1);
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Mgr, @ActionItemId = @I7, @ActionText = N'7 saved by the manager', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the manager, the item of his second department: saved',
           'Result 1, Reason 0, text: 7 saved by the manager',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I7), 'no item');
    SET @Res = NULL; SET @Rsn = NULL;
    EXEC spr_SaveDashboardActionText @ActingUserId = @Ctl, @ActionItemId = @I9, @ActionText = N'9 saved by the controller', @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Save: the Controller, the item with open minutes: saved',
           'Result 1, Reason 0, text: 9 saved by the controller',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', text: ' + ISNULL((SELECT CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId = @I9), 'no item');
    INSERT INTO @T SELECT 'The refused saves and opens changed no other item (texts of 2 to 6 and 8 as made)', '2 due today 23:59; 3 due in three days; 4 no due date; 5 past but complied; 6 past but confirmed; 8 department C',
           ISNULL(STUFF((SELECT '; ' + CAST(ActionText AS VARCHAR(100)) FROM Action_Item WHERE ActionItemId IN (@I2, @I3, @I4, @I5, @I6, @I8) ORDER BY CAST(ActionText AS VARCHAR(100)) FOR XML PATH('')), 1, 2, ''), 'none');

    ---------------------------------------------------------------------------
    -- Last inside the transaction: the Rollback's two batches, compared with the texts step 43 was built from
    ---------------------------------------------------------------------------
    EXEC (@OldMail);
    EXEC (@OldUpdate);
    INSERT INTO @T SELECT 'The Rollback''s texts of spr_GetAlertMailId and spr_GetAgendaUpdateMailId, installed here: SHA-1 against the saved originals (steps 18 and 37), no step 43 marker',
           'same, same, 0 markers',
           CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                     = '7C811E422DCF63725C91DA81EC5EB3195B677E73' THEN 'same' ELSE 'differs' END + ', '
         + CASE WHEN CONVERT(VARCHAR(40), HASHBYTES('SHA1', CAST(REPLACE(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')), CHAR(13), '') AS NVARCHAR(4000))), 2)
                     = 'F6BD3580A632DF8643F2406DA53F1256D8FC6D33' THEN 'same' ELSE 'differs' END + ', '
         + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAlertMailId')) LIKE '%DashboardAlerts-Step43%' THEN 1 ELSE 0 END
              + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaUpdateMailId')) LIKE '%DashboardAlerts-Step43%' THEN 1 ELSE 0 END AS VARCHAR(2)) + ' markers';
    SET @AgId = (SELECT AgendaId FROM Agenda WHERE MeetingId = @Meet AND ShortText = 'ZZ43 ACA young');
    DELETE FROM #Mail; INSERT INTO #Mail EXEC spr_GetAlertMailId @Code = 'ACA', @UserId = @Ctl, @AgendaId = @AgId;
    INSERT INTO @T SELECT 'With the earlier text the Admin IS in the ACA list (so the checks above test step 43, not the data)', 'zz43a, zz43c, zz43g, zz43m, zz43u',
           ISNULL(STUFF((SELECT ', ' + LEFT(EmailId, 5) FROM #Mail WHERE EmailId LIKE 'zz43%' ORDER BY EmailId FOR XML PATH('')), 1, 2, ''), 'none');

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
SELECT @MasterAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, AlertTypeCode, CreatedOn, CreatedBy)), 0) AS VARCHAR(12)) FROM Alert_Master;
SELECT @ItemAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemId, MinutesId, IsComplied, IsConfirmed)), 0) AS VARCHAR(12)) FROM Action_Item;
INSERT INTO @T SELECT 'After the rollback: Alert_User_Map unchanged (count, checksum)', @MapBefore, @MapAfter;
INSERT INTO @T SELECT 'After the rollback: Alert_Master unchanged (count, checksum)', @MasterBefore, @MasterAfter;
INSERT INTO @T SELECT 'After the rollback: Action_Item unchanged (count, checksum)', @ItemBefore, @ItemAfter;
SELECT @AiMapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(ActionItemUserMapId, ActionItemId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM ActionItem_User_Map;
INSERT INTO @T SELECT 'After the rollback: ActionItem_User_Map unchanged (count, checksum)', @AiMapBefore, @AiMapAfter;
INSERT INTO @T SELECT 'After the rollback: step 43 is installed again (markers in the ten objects)', '10',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_DashboardAlerts'), ('spr_GetDashboardAlerts'), ('spr_GetAlertCount'), ('spr_RemoveAlertForUser'),
                                          ('spr_GetDashboardActionItems'), ('fn_DashboardActionItems'), ('spr_OpenDashboardActionItem'),
                                          ('spr_SaveDashboardActionText'), ('spr_GetAlertMailId'), ('spr_GetAgendaUpdateMailId')) o(Name)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)) LIKE '%DashboardAlerts-Step43%') AS VARCHAR(12));

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
SELECT 'After the test: no ZZ43 department, user, committee, meeting, alert, action item or department row of a ZZ43 user left', '0 0 0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ43%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz43%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z43') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ43 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Alert_Master WHERE DisplayText LIKE 'ZZ43 %') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Action_Item WHERE Directions = N'ZZ43') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM User_Department ud WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.UserId = ud.UserId)) AS VARCHAR(12));

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

DROP TABLE #Mail;
DROP TABLE #AI;
DROP TABLE #AL;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
