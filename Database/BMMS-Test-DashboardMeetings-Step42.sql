/* ============================================================================
   BMMS - Tests for BMMS-Fix-DashboardMeetings-Step42.sql (step 42, step UN6b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   TEST DATABASE ONLY. It refuses to run in a database named exactly "BMMS".
   Run it AFTER BMMS-Fix-DashboardMeetings-Step42.sql; it stops if step 42 is
   not installed.

   Part 1, read only: the five markers, the parameters, the result columns
   of spr_GetDashboardMeetings, spr_GetScheduleMeet unchanged, and on this
   database every agenda item in one of the groups approved, rejected or in
   progress (none in "other"), so Items = Approved + Rejected + Pending.

   Part 2, inside one transaction that is ROLLED BACK, with made-up
   departments, users, committees, meetings and agenda items (ZZ42...):
     * the colour rules of fn_MeetingDashboardState on fixed dates, in their
       order (grey before red before green before orange before blue); a
       meeting dated today is scheduled and not red; the submission date
       itself is still open; a meeting without a date is scheduled
     * fn_UserDepartmentScope: open rows and the home department; a closed
       row is left out; a user without history rows gets the home department
     * fn_AgendaStatusGroup: the four groups add up to all items
     * spr_GetDashboardMeetings: who may call it (six roles; another role,
       an inactive, unknown or missing user refused); every scheduled
       meeting, ordered by date; the last 10 completed meetings, newest
       first, for EVERY role (13 completed test meetings: exactly 10 shown,
       with one committee and with all committees); for a Manager and a User
       only completed meetings with an item of their department(s); the
       statistics per role and department filter; NULL statistics for MD
       Secretariat and Admin; the refused filters (another department for a
       User or a Manager, a closed mapping, any department for the other
       roles, a committee that does not exist)
     * spr_GetDashboardDepartments: a Manager's departments, home first; a
       User's department; another role, an inactive user refused
     * rows outside the test are unchanged after the rollback, and every
       identity counter is put back

   Result: one grid, one row per check. Status should be PASS for every row.

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
ELSE IF (OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NULL
         OR OBJECT_ID('dbo.spr_GetDashboardDepartments', 'P') IS NULL
         OR OBJECT_ID('dbo.fn_MeetingDashboardState', 'IF') IS NULL
         OR OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL
         OR OBJECT_ID('dbo.fn_AgendaStatusGroup', 'IF') IS NULL)
BEGIN
    RAISERROR('Step 42 (BMMS-Fix-DashboardMeetings-Step42.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#DM') IS NOT NULL DROP TABLE #DM;
IF OBJECT_ID('tempdb..#DD') IS NOT NULL DROP TABLE #DD;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(1000), Actual VARCHAR(1000));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);
CREATE TABLE #DM (MeetingId INT, CommitteeId INT, CommitteeCode VARCHAR(10), CommitteeName VARCHAR(50), MeetingNo VARCHAR(10),
                  MeetingDate DATETIME, MeetingTime VARCHAR(10), AgendaSubmissionDate DATETIME, ListCode CHAR(1),
                  StateCode VARCHAR(10), StateLabel VARCHAR(30), Items INT, Approved INT, Rejected INT, Pending INT);
CREATE TABLE #DD (DepartmentId INT, DepartmentName VARCHAR(50), IsHome BIT);

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
INSERT INTO #T SELECT 'Marker DashboardMeetings-Step42 in the five new objects', '5',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_MeetingDashboardState')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserDepartmentScope')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_AgendaStatusGroup')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardMeetings')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END
          + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetDashboardDepartments')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END AS VARCHAR(12));
INSERT INTO #T SELECT 'Parameters: meetings 7 (4 OUTPUT), departments 3 (2 OUTPUT)', '7 4 3 2',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetDashboardMeetings')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetDashboardMeetings') AND is_output = 1) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetDashboardDepartments')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetDashboardDepartments') AND is_output = 1) AS VARCHAR(12));

DECLARE @Cols VARCHAR(MAX);
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardMeetings'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardMeetings: the result columns the page reads, in this order',
       'MeetingId,CommitteeId,CommitteeCode,CommitteeName,MeetingNo,MeetingDate,MeetingTime,AgendaSubmissionDate,ListCode,StateCode,StateLabel,Items,Approved,Rejected,Pending',
       ISNULL(@Cols, 'none');
SET @Cols = NULL;
SELECT @Cols = ISNULL(@Cols + ',', '') + name FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID('dbo.spr_GetDashboardDepartments'), 0) ORDER BY column_ordinal;
INSERT INTO #T SELECT 'spr_GetDashboardDepartments: the result columns', 'DepartmentId,DepartmentName,IsHome', ISNULL(@Cols, 'none');

INSERT INTO #T SELECT 'spr_GetScheduleMeet unchanged: still the GETDATE() rule, no step 42 marker', '1 0',
       CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetScheduleMeet')) LIKE '%MeetingDate >= GETDATE()%' THEN 1 ELSE 0 END AS VARCHAR(2)) + ' '
     + CAST(CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetScheduleMeet')) LIKE '%DashboardMeetings-Step42%' THEN 1 ELSE 0 END AS VARCHAR(2));

INSERT INTO #T SELECT 'This database: every agenda item has exactly one group; none is "other" (Items = Approved + Rejected + Pending)', 'same, 0 other',
       CASE WHEN (SELECT COUNT(*) FROM Agenda) = (SELECT COUNT(*) FROM dbo.fn_AgendaStatusGroup()) THEN 'same' ELSE 'differs' END + ', '
     + CAST((SELECT COUNT(*) FROM dbo.fn_AgendaStatusGroup() WHERE StatusGroup = 'other') AS VARCHAR(12)) + ' other';
GO

-------------------------------------------------------------------------------
-- Part 2: the rules, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(1000), Actual VARCHAR(1000));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME);
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @rMgmt INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'mgmt' ORDER BY RoleId);
DECLARE @rMd INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'md_sect' ORDER BY RoleId);
DECLARE @rOther INT;
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @CZ INT, @CY INT, @CX INT, @DeptA INT, @DeptB INT, @DeptC INT;
DECLARE @Adm INT, @Ctl INT, @CtlOff INT, @Gmt INT, @Mgr INT, @Mgr1 INT, @Usr INT, @Usr2 INT, @Md INT, @Odd INT;
DECLARE @MC1 INT, @MS2 INT, @MNull INT;
DECLARE @Res INT, @Rsn INT, @Shown INT, @RoleOut VARCHAR(50);
DECLARE @Txt VARCHAR(1000);
DECLARE @Seq INT, @Label VARCHAR(200), @cUser INT, @cComm INT, @cDept INT, @Kind VARCHAR(20), @Arg VARCHAR(10), @Expected VARCHAR(1000);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @MeetBefore VARCHAR(60), @MeetAfter VARCHAR(60), @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @rMgmt IS NULL OR @rMd IS NULL
    OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, AccountStatus, DepartmentId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @MeetBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MeetingId, MeetingDate, MinutesStatus, AgendaStatus)), 0) AS VARCHAR(12)) FROM Meeting;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, DepartmentId)), 0) AS VARCHAR(12)) FROM Agenda;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names)
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ42A', 'ZZ42 department A', 987, 1, @Now, @Sys);
    SET @DeptA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ42B', 'ZZ42 department B', 988, 1, @Now, @Sys);
    SET @DeptB = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ42C', 'ZZ42 department C', 989, 1, @Now, @Sys);
    SET @DeptC = SCOPE_IDENTITY();

    INSERT INTO Roles (RoleCode, RoleName, RoleDescription, OrderNo, CreatedOn, CreatedBy) VALUES ('zz42role', 'ZZ42 role', 'ZZ42 test only', 999, @Now, @Sys);
    SET @rOther = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 admin', @DeptA, @Desig, NULL, @rAdmin, 'zz42a@example.invalid', 'zz42adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 controller', @DeptA, @Desig, NULL, @rCtl, 'zz42c@example.invalid', 'zz42ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 controller inactive', @DeptA, @Desig, NULL, @rCtl, 'zz42i@example.invalid', 'zz42off', 'not-a-login', 0, @Now);
    SET @CtlOff = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 management', @DeptA, @Desig, NULL, @rMgmt, 'zz42g@example.invalid', 'zz42gmt', 'not-a-login', 1, @Now);
    SET @Gmt = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 md secretariat', @DeptA, @Desig, NULL, @rMd, 'zz42s@example.invalid', 'zz42md', 'not-a-login', 1, @Now);
    SET @Md = SCOPE_IDENTITY();
    -- Manager of A (home) and B; a closed row for C
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 manager', @DeptA, @Desig, NULL, @rMgr, 'zz42m@example.invalid', 'zz42mgr', 'not-a-login', 1, @Now);
    SET @Mgr = SCOPE_IDENTITY();
    -- Manager of A without any history row (counts as mapped to the home department)
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 manager one', @DeptA, @Desig, NULL, @rMgr, 'zz42n@example.invalid', 'zz42mg1', 'not-a-login', 1, @Now);
    SET @Mgr1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 user A', @DeptA, @Desig, @Mgr, @rUser, 'zz42u@example.invalid', 'zz42usr', 'not-a-login', 1, @Now);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 user B', @DeptB, @Desig, @Mgr, @rUser, 'zz42v@example.invalid', 'zz42us2', 'not-a-login', 1, @Now);
    SET @Usr2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ42 other role', @DeptA, @Desig, NULL, @rOther, 'zz42o@example.invalid', 'zz42odd', 'not-a-login', 1, @Now);
    SET @Odd = SCOPE_IDENTITY();

    INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy)
    VALUES (@Mgr, @DeptA, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@Mgr, @DeptB, 0, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@Usr, @DeptA, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys),
           (@Usr2, @DeptB, 1, DATEADD(DAY, -30, @Today), NULL, @Now, @Sys);
    -- The Manager's closed department C: a closed row carries ClosedOn, ClosedBy and CloseReason
    -- (CK_User_Department_Closed, step 39); 'C' = changed, an ordinary end of an assignment
    INSERT INTO User_Department (UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, CreatedOn, CreatedBy, ClosedOn, ClosedBy, CloseReason)
    VALUES (@Mgr, @DeptC, 0, DATEADD(DAY, -30, @Today), DATEADD(DAY, -1, @Today), @Now, @Sys, @Now, @Sys, 'C');

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z42', 'ZZ42 committee', '2000-01-01', 1, 0);
    SET @CZ = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Y42', 'ZZ42 other committee', '2000-01-01', 1, 0);
    SET @CY = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('X42', 'ZZ42 committee without dates', '2000-01-01', 1, 0);
    SET @CX = SCOPE_IDENTITY();

    -- Committee Z42: five scheduled meetings and 13 completed ones (days -1 to -13)
    DECLARE @Meet TABLE (MeetingNo VARCHAR(10), CommitteeId INT, DayOffset INT NULL, SubOffset INT NULL, AgendaStatus VARCHAR(50), MinutesStatus VARCHAR(50));
    INSERT INTO @Meet VALUES
    ('94201', @CZ, 0, 0, 'Open', 'Open'),        -- today, submission today: blue (scheduled, not red)
    ('94202', @CZ, 5, -1, 'Open', 'Open'),       -- submission yesterday: orange
    ('94203', @CZ, 3, -2, 'Close', 'Open'),      -- agenda finalised: green (before orange)
    ('94204', @CZ, 10, 5, 'Open', NULL),         -- blue, no items, NULL minutes status = Open
    ('94206', @CZ, 20, 10, 'Close', 'F'),        -- grey before green and blue
    ('94211', @CZ, -1, -10, 'Open', 'Open'),     -- red: the day has passed, agenda never finalised
    ('94212', @CZ, -2, -10, 'Close', 'Open'),    -- red
    ('94213', @CZ, -3, -10, 'Close', 'F'),       -- grey Minutes finalised
    ('94214', @CZ, -4, -10, 'Close', 'C'),       -- grey Minutes confirmed
    ('94215', @CZ, -5, -10, 'Close', 'C'), ('94216', @CZ, -6, -10, 'Close', 'C'), ('94217', @CZ, -7, -10, 'Close', 'C'),
    ('94218', @CZ, -8, -10, 'Close', 'C'), ('94219', @CZ, -9, -10, 'Close', 'C'), ('94220', @CZ, -10, -11, 'Close', 'C'),
    ('94221', @CZ, -11, -12, 'Close', 'C'), ('94222', @CZ, -12, -13, 'Close', 'C'), ('94223', @CZ, -13, -14, 'Close', 'C'),
    ('94231', @CY, 2, 1, 'Open', 'Open'),        -- other committee, scheduled
    ('94232', @CY, -1, -5, 'Close', 'C'),        -- other committee, completed
    ('94241', @CX, NULL, NULL, NULL, NULL);      -- no dates: scheduled, blue

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    SELECT mt.MeetingNo, mt.CommitteeId, 'ZZ42 test', 'ZZ', DATEADD(DAY, mt.DayOffset, @Day), '10:00', DATEADD(DAY, mt.SubOffset, @Day),
           mt.AgendaStatus, mt.MinutesStatus, @Now, @Sys
    FROM @Meet mt;

    SET @MC1 = (SELECT MeetingId FROM Meeting WHERE Place = 'ZZ42 test' AND MeetingNo = '94211');
    SET @MS2 = (SELECT MeetingId FROM Meeting WHERE Place = 'ZZ42 test' AND MeetingNo = '94202');
    SET @MNull = (SELECT MeetingId FROM Meeting WHERE Place = 'ZZ42 test' AND MeetingNo = '94241');

    -- Agenda items: meeting, department, status
    DECLARE @Items TABLE (Seq INT IDENTITY(1,1), MeetingNo VARCHAR(10), DepartmentId INT, StatusCode VARCHAR(50));
    INSERT INTO @Items (MeetingNo, DepartmentId, StatusCode) VALUES
    ('94201', @DeptA, 'AC'), ('94201', @DeptA, 'AMA'), ('94201', @DeptB, 'ACA'), ('94201', @DeptC, 'ACR'),
    ('94202', @DeptA, 'AMR'), ('94202', @DeptA, 'AF'),
    ('94203', @DeptB, 'ACA'),
    ('94211', @DeptA, 'ACA'), ('94211', @DeptB, 'AC'),
    ('94212', @DeptB, 'ACR'),
    ('94213', @DeptC, 'ACA'),
    ('94214', @DeptA, 'ACA'), ('94215', @DeptA, 'ACA'), ('94216', @DeptA, 'ACA'), ('94217', @DeptA, 'ACA'), ('94218', @DeptA, 'ACA'),
    ('94219', @DeptA, 'ACA'), ('94220', @DeptA, 'ACA'), ('94221', @DeptA, 'ACA'), ('94222', @DeptA, 'ACA'), ('94223', @DeptA, 'ACA'),
    ('94232', @DeptA, 'ACA');

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ42-' + i.MeetingNo + '-' + CAST(i.Seq AS VARCHAR(12)), m.CommitteeId, m.MeetingId, i.DepartmentId, @SubjectTypeId,
           'ZZ42 item ' + CAST(i.Seq AS VARCHAR(12)), 'Entry', i.StatusCode, 'New', @Now, @Sys
    FROM @Items i JOIN Meeting m ON m.MeetingNo = i.MeetingNo AND m.Place = 'ZZ42 test';

    ---------------------------------------------------------------------------
    -- fn_MeetingDashboardState on fixed dates
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'State today: the five Z42 scheduled meetings by MeetingNo',
           '94201 1 blue Open for submission, 94202 1 orange Submission closed, 94203 1 green Agenda finalised, 94204 1 blue Open for submission, 94206 1 grey Minutes finalised',
           ISNULL(STUFF((SELECT ', ' + m.MeetingNo + ' ' + CAST(s.IsScheduled AS VARCHAR(1)) + ' ' + s.StateCode + ' ' + s.StateLabel
                         FROM dbo.fn_MeetingDashboardState(@Today) s JOIN Meeting m ON m.MeetingId = s.MeetingId
                         WHERE m.Place = 'ZZ42 test' AND m.MeetingNo IN ('94201', '94202', '94203', '94204', '94206')
                         ORDER BY m.MeetingNo FOR XML PATH('')), 1, 2, ''), 'none');
    INSERT INTO @T SELECT 'State today: red for a passed day (agenda open or closed), grey F and C before red',
           '94211 0 red Minutes pending, 94212 0 red Minutes pending, 94213 0 grey Minutes finalised, 94214 0 grey Minutes confirmed',
           ISNULL(STUFF((SELECT ', ' + m.MeetingNo + ' ' + CAST(s.IsScheduled AS VARCHAR(1)) + ' ' + s.StateCode + ' ' + s.StateLabel
                         FROM dbo.fn_MeetingDashboardState(@Today) s JOIN Meeting m ON m.MeetingId = s.MeetingId
                         WHERE m.Place = 'ZZ42 test' AND m.MeetingNo IN ('94211', '94212', '94213', '94214')
                         ORDER BY m.MeetingNo FOR XML PATH('')), 1, 2, ''), 'none');
    SET @Txt = (SELECT CAST(s.IsScheduled AS VARCHAR(1)) + ' ' + s.StateCode FROM dbo.fn_MeetingDashboardState(DATEADD(DAY, -1, @Today)) s WHERE s.MeetingId = @MC1);
    INSERT INTO @T SELECT 'State on the meeting day itself (94211 seen yesterday): scheduled, orange (not red)', '1 orange', ISNULL(@Txt, 'none');
    SET @Txt = (SELECT s.StateCode FROM dbo.fn_MeetingDashboardState(DATEADD(DAY, -1, @Today)) s WHERE s.MeetingId = @MS2);
    INSERT INTO @T SELECT 'State on the submission date itself (94202 seen yesterday): blue (still open)', 'blue', ISNULL(@Txt, 'none');
    SET @Txt = (SELECT CAST(s.IsScheduled AS VARCHAR(1)) + ' ' + s.StateCode FROM dbo.fn_MeetingDashboardState(@Today) s WHERE s.MeetingId = @MNull);
    INSERT INTO @T SELECT 'State of a meeting without dates: scheduled, blue', '1 blue', ISNULL(@Txt, 'none');
    INSERT INTO @T SELECT 'fn_MeetingDashboardState: one row per meeting', 'same',
           CASE WHEN (SELECT COUNT(*) FROM Meeting) = (SELECT COUNT(*) FROM dbo.fn_MeetingDashboardState(@Today)) THEN 'same' ELSE 'differs' END;

    ---------------------------------------------------------------------------
    -- fn_UserDepartmentScope and fn_AgendaStatusGroup
    ---------------------------------------------------------------------------
    INSERT INTO @T SELECT 'Departments: Manager A and B (C closed yesterday), Manager without history rows A, User B',
           'A B | A | B',
           ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_UserDepartmentScope(@Mgr, @Today) s JOIN Department d ON d.DepartmentId = s.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), 'none')
         + ' | ' + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_UserDepartmentScope(@Mgr1, @Today) s JOIN Department d ON d.DepartmentId = s.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), 'none')
         + ' | ' + ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_UserDepartmentScope(@Usr2, @Today) s JOIN Department d ON d.DepartmentId = s.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'Departments: the Manager''s C row counted while it was open (two days ago)', 'A B C',
           ISNULL(STUFF((SELECT ' ' + RIGHT(d.DepartmentCode, 1) FROM dbo.fn_UserDepartmentScope(@Mgr, DATEADD(DAY, -2, @Today)) s JOIN Department d ON d.DepartmentId = s.DepartmentId ORDER BY d.DepartmentCode FOR XML PATH('')), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'Groups of the 22 test items: approved, rejected, in progress, other; they add up to all items', '15 3 3 1 = 22',
           (SELECT CAST(SUM(CASE WHEN g.StatusGroup = 'approved' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
                 + CAST(SUM(CASE WHEN g.StatusGroup = 'rejected' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
                 + CAST(SUM(CASE WHEN g.StatusGroup = 'in progress' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' '
                 + CAST(SUM(CASE WHEN g.StatusGroup = 'other' THEN 1 ELSE 0 END) AS VARCHAR(12)) + ' = ' + CAST(COUNT(*) AS VARCHAR(12))
            FROM dbo.fn_AgendaStatusGroup() g JOIN Agenda a ON a.AgendaId = g.AgendaId WHERE a.AgendaNo LIKE 'ZZ42-%');

    ---------------------------------------------------------------------------
    -- spr_GetDashboardMeetings: one call per case. Kinds:
    --   call     Result, Reason, StatisticsShown, ActingRoleCode, scheduled and completed row counts
    --   ccount   the number of completed rows
    --   slist    the scheduled rows: MeetingNo StateCode StateLabel
    --   clist    the completed rows: MeetingNo
    --   cstate   the completed rows: MeetingNo StateCode
    --   stats    Items Approved Rejected Pending of meeting @Arg (NULL shown as -)
    --   nulls    the rows whose four counts are not all NULL
    ---------------------------------------------------------------------------
    DECLARE @Cases TABLE (Seq INT IDENTITY(1,1), Label VARCHAR(200), UserId INT, CommitteeId INT, DepartmentId INT, Kind VARCHAR(20), Arg VARCHAR(10), Expected VARCHAR(1000));
    INSERT INTO @Cases (Label, UserId, CommitteeId, DepartmentId, Kind, Arg, Expected) VALUES
    ('Controller, committee Z42: allowed, statistics, 5 scheduled, 10 of 13 completed', @Ctl, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 1, Role controller, S 5, C 10'),
    ('Controller, Z42: scheduled by date with state and label (the meeting dated today first)', @Ctl, @CZ, 0, 'slist', '',
        '94201 blue Open for submission, 94203 green Agenda finalised, 94202 orange Submission closed, 94204 blue Open for submission, 94206 grey Minutes finalised'),
    ('Controller, Z42: the last 10 completed, newest first (94221 to 94223 left out)', @Ctl, @CZ, 0, 'cstate', '',
        '94211 red, 94212 red, 94213 grey, 94214 grey, 94215 grey, 94216 grey, 94217 grey, 94218 grey, 94219 grey, 94220 grey'),
    ('Controller, Z42, meeting 94201: Items Approved Rejected Pending', @Ctl, @CZ, 0, 'stats', '94201', '4 1 1 2'),
    ('Controller, Z42, meeting 94202: AF counted in Items only', @Ctl, @CZ, 0, 'stats', '94202', '2 0 1 0'),
    ('Controller, Z42, meeting 94204: no items, all counts 0', @Ctl, @CZ, 0, 'stats', '94204', '0 0 0 0'),
    ('Controller, all committees: exactly 10 completed', @Ctl, 0, 0, 'ccount', '', '10'),
    ('Controller, committee Y42: 1 scheduled, 1 completed', @Ctl, @CY, 0, 'call', '', 'Result 1, Reason 0, Shown 1, Role controller, S 1, C 1'),
    ('Controller with a department: refused', @Ctl, 0, @DeptA, 'call', '', 'Result 0, Reason 4, Shown 0, Role controller, S 0, C 0'),
    ('Controller, a committee that does not exist: refused', @Ctl, -5, 0, 'call', '', 'Result 0, Reason 4, Shown 0, Role controller, S 0, C 0'),
    ('Management, Z42: allowed, statistics, 5 and 10', @Gmt, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 1, Role mgmt, S 5, C 10'),
    ('Management, Z42, meeting 94201', @Gmt, @CZ, 0, 'stats', '94201', '4 1 1 2'),
    ('Management, all committees: exactly 10 completed', @Gmt, 0, 0, 'ccount', '', '10'),
    ('MD Secretariat, Z42: allowed, no statistics, 5 and 10', @Md, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 0, Role md_sect, S 5, C 10'),
    ('MD Secretariat, Z42: every count NULL', @Md, @CZ, 0, 'nulls', '', '0'),
    ('MD Secretariat, Z42: the same states as the Controller', @Md, @CZ, 0, 'cstate', '',
        '94211 red, 94212 red, 94213 grey, 94214 grey, 94215 grey, 94216 grey, 94217 grey, 94218 grey, 94219 grey, 94220 grey'),
    ('MD Secretariat, all committees: exactly 10 completed', @Md, 0, 0, 'ccount', '', '10'),
    ('Admin, Z42: allowed, no statistics, 5 and 10', @Adm, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 0, Role admin, S 5, C 10'),
    ('Admin, Z42: every count NULL', @Adm, @CZ, 0, 'nulls', '', '0'),
    ('Admin, all committees: exactly 10 completed', @Adm, 0, 0, 'ccount', '', '10'),
    ('Manager (A, B), Z42: all scheduled; 10 of the 12 completed with an A or B item', @Mgr, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 1, Role manager, S 5, C 10'),
    ('Manager (A, B), Z42: completed list (94213 has a C item only)', @Mgr, @CZ, 0, 'clist', '', '94211, 94212, 94214, 94215, 94216, 94217, 94218, 94219, 94220, 94221'),
    ('Manager (A, B), Z42, meeting 94201: A and B items only', @Mgr, @CZ, 0, 'stats', '94201', '3 1 0 2'),
    ('Manager (A, B), Z42, meeting 94204: no items, counts 0', @Mgr, @CZ, 0, 'stats', '94204', '0 0 0 0'),
    ('Manager (A, B), all committees: exactly 10 completed', @Mgr, 0, 0, 'ccount', '', '10'),
    ('Manager, department B only, Z42: allowed, 2 completed', @Mgr, @CZ, @DeptB, 'call', '', 'Result 1, Reason 0, Shown 1, Role manager, S 5, C 2'),
    ('Manager, department B only, meeting 94201', @Mgr, @CZ, @DeptB, 'stats', '94201', '1 1 0 0'),
    ('Manager, department A only, meeting 94201', @Mgr, @CZ, @DeptA, 'stats', '94201', '2 0 0 2'),
    ('Manager, department C (closed yesterday): refused', @Mgr, @CZ, @DeptC, 'call', '', 'Result 0, Reason 4, Shown 0, Role manager, S 0, C 0'),
    ('Manager without history rows: home department A, meeting 94201', @Mgr1, @CZ, 0, 'stats', '94201', '2 0 0 2'),
    ('Manager without history rows, all committees: exactly 10 completed', @Mgr1, 0, 0, 'ccount', '', '10'),
    ('User (A), Z42: allowed, statistics, all scheduled, 10 of 11 completed', @Usr, @CZ, 0, 'call', '', 'Result 1, Reason 0, Shown 1, Role user, S 5, C 10'),
    ('User (A), Z42: completed list (94212 and 94213 have no A item)', @Usr, @CZ, 0, 'clist', '', '94211, 94214, 94215, 94216, 94217, 94218, 94219, 94220, 94221, 94222'),
    ('User (A), Z42, meeting 94201: A items only', @Usr, @CZ, 0, 'stats', '94201', '2 0 0 2'),
    ('User (A), all committees: exactly 10 completed', @Usr, 0, 0, 'ccount', '', '10'),
    ('User (A) with his own department: allowed', @Usr, @CZ, @DeptA, 'call', '', 'Result 1, Reason 0, Shown 1, Role user, S 5, C 10'),
    ('User (A) with another department: refused', @Usr, @CZ, @DeptB, 'call', '', 'Result 0, Reason 4, Shown 0, Role user, S 0, C 0'),
    ('User (B), Z42: 2 completed with a B item', @Usr2, @CZ, 0, 'clist', '', '94211, 94212'),
    ('User (B), Z42, meeting 94201', @Usr2, @CZ, 0, 'stats', '94201', '1 1 0 0'),
    ('Another role: refused, no role returned', @Odd, 0, 0, 'call', '', 'Result 0, Reason 4, Shown 0, Role -, S 0, C 0'),
    ('Inactive Controller: Reason 8', @CtlOff, 0, 0, 'call', '', 'Result 0, Reason 8, Shown 0, Role -, S 0, C 0'),
    ('Acting user 0: Reason 8', 0, 0, 0, 'call', '', 'Result 0, Reason 8, Shown 0, Role -, S 0, C 0'),
    ('No acting user: Reason 8', NULL, 0, 0, 'call', '', 'Result 0, Reason 8, Shown 0, Role -, S 0, C 0');

    SET @Seq = 1;
    WHILE (@Seq <= (SELECT COUNT(*) FROM @Cases))
    BEGIN
        SELECT @Label = Label, @cUser = UserId, @cComm = CommitteeId, @cDept = DepartmentId, @Kind = Kind, @Arg = Arg, @Expected = Expected
        FROM @Cases WHERE Seq = @Seq;

        DELETE FROM #DM; SET @Res = NULL; SET @Rsn = NULL; SET @Shown = NULL; SET @RoleOut = NULL;
        INSERT INTO #DM EXEC spr_GetDashboardMeetings @ActingUserId = @cUser, @CommitteeId = @cComm, @DepartmentId = @cDept,
             @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @RoleOut OUTPUT;

        IF (@Kind = 'call')
            SET @Txt = 'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-')
                     + ', Shown ' + ISNULL(CAST(@Shown AS VARCHAR(2)), '-') + ', Role ' + ISNULL(@RoleOut, '-')
                     + ', S ' + CAST((SELECT COUNT(*) FROM #DM WHERE ListCode = 'S') AS VARCHAR(12))
                     + ', C ' + CAST((SELECT COUNT(*) FROM #DM WHERE ListCode = 'C') AS VARCHAR(12));
        ELSE IF (@Kind = 'ccount')
            SET @Txt = CAST((SELECT COUNT(*) FROM #DM WHERE ListCode = 'C') AS VARCHAR(12));
        ELSE IF (@Kind = 'slist')
            -- #DM keeps the procedure's order only by an explicit sort; MeetingDate, MeetingTime, MeetingId is the procedure's
            SET @Txt = ISNULL(STUFF((SELECT ', ' + MeetingNo + ' ' + StateCode + ' ' + StateLabel FROM #DM WHERE ListCode = 'S'
                                     ORDER BY MeetingDate, MeetingTime, MeetingId FOR XML PATH('')), 1, 2, ''), 'none');
        ELSE IF (@Kind = 'clist')
            SET @Txt = ISNULL(STUFF((SELECT ', ' + MeetingNo FROM #DM WHERE ListCode = 'C'
                                     ORDER BY MeetingDate DESC, MeetingTime DESC, MeetingId DESC FOR XML PATH('')), 1, 2, ''), 'none');
        ELSE IF (@Kind = 'cstate')
            SET @Txt = ISNULL(STUFF((SELECT ', ' + MeetingNo + ' ' + StateCode FROM #DM WHERE ListCode = 'C'
                                     ORDER BY MeetingDate DESC, MeetingTime DESC, MeetingId DESC FOR XML PATH('')), 1, 2, ''), 'none');
        ELSE IF (@Kind = 'stats')
            SET @Txt = ISNULL((SELECT TOP 1 ISNULL(CAST(Items AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Approved AS VARCHAR(12)), '-') + ' '
                                     + ISNULL(CAST(Rejected AS VARCHAR(12)), '-') + ' ' + ISNULL(CAST(Pending AS VARCHAR(12)), '-')
                               FROM #DM WHERE MeetingNo = @Arg AND CommitteeId = @cComm ORDER BY MeetingId), 'no row');
        ELSE IF (@Kind = 'nulls')
            SET @Txt = CAST((SELECT COUNT(*) FROM #DM WHERE Items IS NOT NULL OR Approved IS NOT NULL OR Rejected IS NOT NULL OR Pending IS NOT NULL) AS VARCHAR(12));
        ELSE
            SET @Txt = 'unknown kind ' + @Kind;

        INSERT INTO @T VALUES ('Meetings: ' + @Label, @Expected, @Txt);
        SET @Seq = @Seq + 1;
    END

    -- One committee with one meeting in each list: scheduled first, then completed
    DELETE FROM #DM;
    INSERT INTO #DM EXEC spr_GetDashboardMeetings @ActingUserId = @Ctl, @CommitteeId = @CY, @DepartmentId = 0,
         @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT, @StatisticsShown = @Shown OUTPUT, @ActingRoleCode = @RoleOut OUTPUT;
    INSERT INTO @T SELECT 'Meetings: Controller, Y42: one scheduled then one completed, with committee name', 'S 94231 ZZ42 other committee, C 94232 ZZ42 other committee',
           ISNULL(STUFF((SELECT ', ' + ListCode + ' ' + MeetingNo + ' ' + CommitteeName FROM #DM ORDER BY CASE ListCode WHEN 'S' THEN 0 ELSE 1 END FOR XML PATH('')), 1, 2, ''), 'none');

    ---------------------------------------------------------------------------
    -- spr_GetDashboardDepartments
    ---------------------------------------------------------------------------
    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @Mgr, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: Manager, home first (C closed is left out)', 'Result 1, Reason 0: ZZ42 department A 1, ZZ42 department B 0',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': '
         + ISNULL(STUFF((SELECT ', ' + DepartmentName + ' ' + CAST(IsHome AS VARCHAR(1)) FROM #DD ORDER BY IsHome DESC, DepartmentName FOR XML PATH('')), 1, 2, ''), 'none');

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @Usr2, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: User, his department', 'Result 1, Reason 0: ZZ42 department B 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': '
         + ISNULL(STUFF((SELECT ', ' + DepartmentName + ' ' + CAST(IsHome AS VARCHAR(1)) FROM #DD ORDER BY IsHome DESC, DepartmentName FOR XML PATH('')), 1, 2, ''), 'none');

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @Mgr1, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: Manager without history rows, the home department', 'Result 1, Reason 0: ZZ42 department A 1',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ': '
         + ISNULL(STUFF((SELECT ', ' + DepartmentName + ' ' + CAST(IsHome AS VARCHAR(1)) FROM #DD ORDER BY IsHome DESC, DepartmentName FOR XML PATH('')), 1, 2, ''), 'none');

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @Ctl, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: Controller refused', 'Result 0, Reason 4, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #DD) AS VARCHAR(12)) + ' rows';

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @Md, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: MD Secretariat refused', 'Result 0, Reason 4, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #DD) AS VARCHAR(12)) + ' rows';

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = @CtlOff, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: inactive user, Reason 8', 'Result 0, Reason 8, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #DD) AS VARCHAR(12)) + ' rows';

    DELETE FROM #DD; SET @Res = NULL; SET @Rsn = NULL;
    INSERT INTO #DD EXEC spr_GetDashboardDepartments @ActingUserId = NULL, @Result = @Res OUTPUT, @Reason = @Rsn OUTPUT;
    INSERT INTO @T SELECT 'Departments: no acting user, Reason 8', 'Result 0, Reason 8, 0 rows',
           'Result ' + ISNULL(CAST(@Res AS VARCHAR(2)), '-') + ', Reason ' + ISNULL(CAST(@Rsn AS VARCHAR(3)), '-') + ', ' + CAST((SELECT COUNT(*) FROM #DD) AS VARCHAR(12)) + ' rows';

END TRY
BEGIN CATCH
    SET @Txt = 'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300);
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error', @Txt);
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, AccountStatus, DepartmentId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @MeetAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(MeetingId, MeetingDate, MinutesStatus, AgendaStatus)), 0) AS VARCHAR(12)) FROM Meeting;
SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, DepartmentId)), 0) AS VARCHAR(12)) FROM Agenda;
INSERT INTO @T SELECT 'After the rollback: Users unchanged (count, checksum)', @UsersBefore, @UsersAfter;
INSERT INTO @T SELECT 'After the rollback: Meeting unchanged (count, checksum)', @MeetBefore, @MeetAfter;
INSERT INTO @T SELECT 'After the rollback: Agenda unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;

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
SELECT 'After the test: no ZZ42 department, role, user, committee or meeting left', '0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ42%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Roles WHERE RoleCode = 'zz42role') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz42%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z42', 'Y42', 'X42')) AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ42 test') AS VARCHAR(12));

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

DROP TABLE #DD;
DROP TABLE #DM;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
