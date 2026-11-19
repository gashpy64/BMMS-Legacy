/* ============================================================================
   BMMS - Test of step 52 (Manager release rule and the meeting-date rule;
   step MR1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   FOR THE TEST COPY ONLY (BMMS_Test). It refuses a database named exactly
   "BMMS" and any name that does not start with "BMMS", and stops if step 52
   is not installed.

   Run it in a NEW query window (it uses temporary objects of its own names).
   Result: one grid with a numbered row per check (TestNo, Test, Expected,
   Actual, Status) and one summary row (Passed, Failed, Skipped). Every row
   must read PASS.

   Part 1 reads only: the marker ManagerRelease-Step52 and the markers of the
   earlier steps in the four objects, their parameter counts, no feature
   above compatibility level 100 added (TRY_CONVERT, IIF, CONCAT, FORMAT,
   OFFSET, STRING_AGG).

   Part 2, inside ONE transaction that is rolled back (made-up data ZZ52: two
   departments, a committee, four meetings - date to come, date passed, no
   date, agenda finalised with the date passed -, an Admin, a Controller,
   five Managers written through the real spr_AddEditUser, three Users):
     - rule 12, the personal part: items of a meeting to come or without a
       date are open ('P'), items of a past meeting with the agenda still
       open are past ('Q'), an item of a finalised agenda is not counted;
     - the ReasonDetail 'open:<n>|past:<n>|<department part>' of a role
       change away from Manager, with the personal part only, the
       department part only (unchanged text), and the mgruser-like case (a
       Manager with past items only while the department has other
       Managers);
     - an edit that removes a department checks the department part only;
     - Deactivate of an active Manager refused with the same Reason 24 and
       nothing changed; Deactivate of a Manager with nothing routed works;
     - a Manager's approve and reject after the meeting date refused with
       Reason 28 and nothing written (the item, its alert rows, the audit
       rows); a Manager who is not routed gets Reason 14 first; a Manager's
       approve of an item to come and of an item without a date works;
     - the Controller's reject of a past-meeting item at AC and at AMA works
       (as Agenda Finalization calls it).

   Afterwards: nothing of ZZ52 is left; Users, User_Role, User_Department,
   Agenda and Alert_User_Map are as before and every identity counter is put
   back.

   The Rollback is checked by running it (it compares the four texts it puts
   back with the texts step 52 was built from, SHA-1), then the Fix again.

   It has no USE line: select the TEST database in SSMS first. Written for
   compatibility level 100. Plain ASCII. QUOTED_IDENTIFIER and ANSI_NULLS ON
   (the filtered indexes of step 39 need them; sqlcmd -I).
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

IF (@CurrentDatabase = 'BMMS' OR @CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". This test is only allowed in a test copy whose name starts with "BMMS" but is not "BMMS" (for example BMMS_Test). Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (EXISTS (SELECT 1 FROM (VALUES ('fn_ManagerReleaseRefusal'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditUser'),
                                       ('spr_SetUserStatusByUserId')) o(Name)
                 WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') NOT LIKE '%ManagerRelease-Step52%'))
BEGIN
    RAISERROR('Step 52 (BMMS-Fix-ManagerRelease-Step52.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
IF OBJECT_ID('tempdb..#Ident') IS NOT NULL DROP TABLE #Ident;
IF OBJECT_ID('tempdb..#ZZ52_Save') IS NOT NULL DROP PROCEDURE #ZZ52_Save;
IF OBJECT_ID('tempdb..#ZZ52_Edit') IS NOT NULL DROP PROCEDURE #ZZ52_Edit;
IF OBJECT_ID('tempdb..#ZZ52_Kinds') IS NOT NULL DROP PROCEDURE #ZZ52_Kinds;
IF OBJECT_ID('tempdb..#ZZ52_Item') IS NOT NULL DROP PROCEDURE #ZZ52_Item;
GO

CREATE TABLE #T (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
CREATE TABLE #Ident (TableName SYSNAME, SavedValue BIGINT NULL, SeedValue BIGINT, IncrementValue BIGINT);

-- Every identity counter before the test (put back at the end)
INSERT INTO #Ident (TableName, SavedValue, SeedValue, IncrementValue)
SELECT t.name, CAST(ic.last_value AS BIGINT), CAST(ic.seed_value AS BIGINT), CAST(ic.increment_value AS BIGINT)
FROM sys.identity_columns ic
INNER JOIN sys.tables t ON t.object_id = ic.object_id
WHERE t.is_ms_shipped = 0 AND t.name <> 'sysdiagrams';
GO

-- Add a user through spr_AddEditUser, with a department list
CREATE PROCEDURE #ZZ52_Save
    @UserName VARCHAR(50), @LoginName VARCHAR(50), @RoleId INT, @DepartmentId INT, @ManagerId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);

    EXEC spr_AddEditUser @Code = 'Save', @UserId = 0, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @Desig, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = 'zz52@example.invalid',
         @LoginName = @LoginName, @Password = 'not-a-login', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- Edit a user through spr_AddEditUser: the stored values, with the role, home department and list given
CREATE PROCEDURE #ZZ52_Edit
    @UserId INT, @RoleId INT, @DepartmentId INT, @List VARCHAR(MAX), @Actor INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @UserName VARCHAR(50), @DesignationId INT, @ManagerId INT, @Mail VARCHAR(50), @LoginName VARCHAR(50);

    SELECT @UserName = UserName, @DesignationId = DesignationId, @ManagerId = ManagerId, @Mail = EmailId, @LoginName = LoginName
    FROM Users WHERE UserId = @UserId;

    EXEC spr_AddEditUser @Code = 'Update', @UserId = @UserId, @UserName = @UserName, @DepartmentId = @DepartmentId,
         @DesignationId = @DesignationId, @ManagerId = @ManagerId, @RoleId = @RoleId, @EmailId = @Mail,
         @LoginName = @LoginName, @Password = '', @CreatedOn = @Now, @CreatedBy = @Actor,
         @UpdatedOn = @Now, @UpdatedBy = @Actor, @DepartmentIds = @List;
END
GO

-- The rows of fn_ManagerReleaseRefusal as one text: "D:<dept>=<n> P=<n> Q=<n>", in that order; '-' for none
CREATE PROCEDURE #ZZ52_Kinds
    @UserId INT, @DepartmentId INT, @Personal BIT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Text = ISNULL(STUFF((SELECT ' ' + f.Kind + CASE WHEN f.Kind = 'D' THEN ':' + CAST(f.DepartmentName AS VARCHAR(200)) ELSE '' END
                                     + '=' + CAST(f.Items AS VARCHAR(12))
                              FROM dbo.fn_ManagerReleaseRefusal(@UserId, @DepartmentId, @Personal) f
                              ORDER BY f.Kind, f.DepartmentName FOR XML PATH('')), 1, 1, ''), '-');
END
GO

-- One item as one text: status, manager and Controller decision, its alert rows, the audit rows of the item
CREATE PROCEDURE #ZZ52_Item
    @AgendaId INT, @Text VARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Text = ISNULL(a.AgendaStatusCode, 'NULL') + ' m:' + ISNULL(a.MgrApprovedStatus, '') + ' c:' + ISNULL(a.ControllerApprovedStatus, '')
                 + ' alerts:' + CAST((SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                                      WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = a.AgendaId) AS VARCHAR(12))
                 + ' audit:' + CAST((SELECT COUNT(*) FROM Audit_Trail_Master t WHERE t.Audit_Table = 'Agenda' AND t.Key_Value = a.AgendaNo) AS VARCHAR(12))
    FROM Agenda a WHERE a.AgendaId = @AgendaId;
END
GO

-------------------------------------------------------------------------------
-- Part 1: read only
-------------------------------------------------------------------------------
INSERT INTO #T
SELECT 'The four objects carry ManagerRelease-Step52 and the markers of their earlier steps', '1 1 1 1 | 1 1 1 1 1 1',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_ManagerReleaseRefusal')) o(n) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerRelease-Step52%') AS VARCHAR(1)) + ' '
     + CAST((SELECT COUNT(*) FROM (VALUES ('spr_UpdateAgendaByAgendaId')) o(n) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerRelease-Step52%') AS VARCHAR(1)) + ' '
     + CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditUser')) o(n) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerRelease-Step52%') AS VARCHAR(1)) + ' '
     + CAST((SELECT COUNT(*) FROM (VALUES ('spr_SetUserStatusByUserId')) o(n) WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE '%ManagerRelease-Step52%') AS VARCHAR(1)) + ' | '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fn_ManagerReleaseRefusal')) LIKE '%UserHistory-Step39%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) LIKE '%AgendaWaitingFor-Step44%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) LIKE '%CommentAuthor-Step35%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')) LIKE '%UserHistory-Step39%' AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditUser')) LIKE '%UserProtection-Stage1%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')) LIKE '%UserHistory-Step39%' THEN '1' ELSE '0' END + ' '
     + CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SetUserStatusByUserId')) LIKE '%UserProtection-Stage1%' THEN '1' ELSE '0' END;

INSERT INTO #T
SELECT 'Parameters unchanged: fn_ManagerReleaseRefusal 3, spr_UpdateAgendaByAgendaId 8, spr_AddEditUser 17, spr_SetUserStatusByUserId 5', '3 8 17 5',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.fn_ManagerReleaseRefusal') AND parameter_id > 0) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditUser')) AS VARCHAR(4)) + ' '
     + CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_SetUserStatusByUserId')) AS VARCHAR(4));

INSERT INTO #T
SELECT 'No feature above compatibility level 100 in the four texts (TRY_CONVERT, IIF, CONCAT, FORMAT, OFFSET, STRING_AGG)', '0',
       CAST((SELECT COUNT(*)
             FROM (VALUES ('fn_ManagerReleaseRefusal'), ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditUser'), ('spr_SetUserStatusByUserId')) o(n)
             CROSS JOIN (VALUES ('%TRY_CONVERT%'), ('%IIF(%'), ('%CONCAT(%'), ('%FORMAT(%'), ('% OFFSET %'), ('%STRING_AGG%')) w(Pattern)
             WHERE OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.n)) LIKE w.Pattern) AS VARCHAR(4));
GO

-------------------------------------------------------------------------------
-- Part 2: the cases, inside one transaction that is rolled back
-------------------------------------------------------------------------------
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(300)) ELSE '' END));
DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Day DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME);
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @rAdmin INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'admin' ORDER BY RoleId);
DECLARE @rCtl INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller' ORDER BY RoleId);
DECLARE @rMgr INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager' ORDER BY RoleId);
DECLARE @rUser INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user' ORDER BY RoleId);
DECLARE @Desig INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @Adm INT, @Ctl INT, @M1 INT, @M2 INT, @M3 INT, @M4 INT, @M5 INT, @U1 INT, @U2 INT, @U3 INT;
DECLARE @DA INT, @DB INT, @Com INT, @MFut INT, @MPast INT, @MNone INT, @MFin INT;
DECLARE @iFut INT, @iPast1 INT, @iPast2 INT, @iNone INT, @iFin INT, @iB INT, @iCtlAC INT, @iCtlAMA INT, @iM4a INT, @iM4b INT;
DECLARE @L VARCHAR(MAX), @S VARCHAR(400), @S2 VARCHAR(400), @E VARCHAR(400);
DECLARE @UsersBefore VARCHAR(60), @UsersAfter VARCHAR(60), @HistBefore VARCHAR(100), @HistAfter VARCHAR(100);
DECLARE @AgendaBefore VARCHAR(60), @AgendaAfter VARCHAR(60), @MapBefore VARCHAR(60), @MapAfter VARCHAR(60);

IF (@Sys IS NULL OR @rAdmin IS NULL OR @rCtl IS NULL OR @rMgr IS NULL OR @rUser IS NULL OR @Desig IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role (admin, controller, manager, user), a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

-- Rows outside the test, before
SELECT @UsersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistBefore = @HistBefore + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;

BEGIN TRANSACTION;

BEGIN TRY
    ---------------------------------------------------------------------------
    -- Made-up data
    ---------------------------------------------------------------------------
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ52A', 'ZZ step 52 department A', 991, 1, @Now, @Sys);
    SET @DA = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ52B', 'ZZ step 52 department B', 992, 1, @Now, @Sys);
    SET @DB = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ52 admin', @DA, @Desig, NULL, @rAdmin, 'zz52a@example.invalid', 'zz52adm', 'not-a-login', 1, @Now);
    SET @Adm = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ52 controller', @DA, @Desig, NULL, @rCtl, 'zz52c@example.invalid', 'zz52ctl', 'not-a-login', 1, @Now);
    SET @Ctl = SCOPE_IDENTITY();

    -- Managers: M1, M2 and M4 of A; M3 of A (home) and B, the only Manager of B; M5 of A, nothing routed
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Save 'ZZ52 manager one', 'zz52m1', @rMgr, @DA, NULL, @L, @Adm;
    SET @M1 = (SELECT UserId FROM Users WHERE LoginName = 'zz52m1');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Save 'ZZ52 manager two', 'zz52m2', @rMgr, @DA, NULL, @L, @Adm;
    SET @M2 = (SELECT UserId FROM Users WHERE LoginName = 'zz52m2');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Save 'ZZ52 manager four', 'zz52m4', @rMgr, @DA, NULL, @L, @Adm;
    SET @M4 = (SELECT UserId FROM Users WHERE LoginName = 'zz52m4');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Save 'ZZ52 manager five', 'zz52m5', @rMgr, @DA, NULL, @L, @Adm;
    SET @M5 = (SELECT UserId FROM Users WHERE LoginName = 'zz52m5');
    SET @L = CAST(@DA AS VARCHAR(12)) + ',' + CAST(@DB AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Save 'ZZ52 manager three', 'zz52m3', @rMgr, @DA, NULL, @L, @Adm;
    SET @M3 = (SELECT UserId FROM Users WHERE LoginName = 'zz52m3');

    -- Users: U1 of A reports to M1, U3 of A to M4, U2 of B to nobody
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ52 user one', @DA, @Desig, @M1, @rUser, 'zz52u1@example.invalid', 'zz52u1', 'not-a-login', 1, @Now);
    SET @U1 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ52 user two', @DB, @Desig, NULL, @rUser, 'zz52u2@example.invalid', 'zz52u2', 'not-a-login', 1, @Now);
    SET @U2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn)
    VALUES ('ZZ52 user three', @DA, @Desig, @M4, @rUser, 'zz52u3@example.invalid', 'zz52u3', 'not-a-login', 1, @Now);
    SET @U3 = SCOPE_IDENTITY();

    INSERT INTO @T SELECT 'Made-up data: five Managers saved through spr_AddEditUser', '5', CAST((SELECT COUNT(*) FROM Users WHERE LoginName IN ('zz52m1', 'zz52m2', 'zz52m3', 'zz52m4', 'zz52m5')) AS VARCHAR(4));

    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z52', 'ZZ step 52 committee', '2000-01-01', 1, 0);
    SET @Com = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95201', @Com, 'ZZ52 test', 'ZZ', DATEADD(DAY, 10, @Day), '10:00', DATEADD(DAY, 5, @Day), 'Open', 'Open');
    SET @MFut = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95202', @Com, 'ZZ52 test', 'ZZ', DATEADD(DAY, -3, @Day), '10:00', DATEADD(DAY, -8, @Day), 'Open', 'Open');
    SET @MPast = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95203', @Com, 'ZZ52 test', 'ZZ', NULL, NULL, NULL, 'Open', 'Open');
    SET @MNone = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('95204', @Com, 'ZZ52 test', 'ZZ', DATEADD(DAY, -3, @Day), '10:00', DATEADD(DAY, -8, @Day), 'Close', 'Open');
    SET @MFin = SCOPE_IDENTITY();

    -- Items: of U1 (routed to M1) to come, two past, without a date, of a finalised agenda, two for the Controller
    -- (past, at AC and at AMA); of U2 in B (routed to nobody); of U3 (routed to M4) two past
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaStatusCode, CurrentStatus, CreatedOn, CreatedBy)
    SELECT 'ZZ52-' + x.Label, @Com, x.MeetingId, x.DepartmentId, @SubjectTypeId, 'ZZ52 ' + x.Label, 'Entry', x.Code, 'New', @Now, x.CreatedBy
    FROM (SELECT 'fut' AS Label, @MFut AS MeetingId, 'AC' AS Code, @DA AS DepartmentId, @U1 AS CreatedBy
          UNION ALL SELECT 'past1', @MPast, 'AC', @DA, @U1
          UNION ALL SELECT 'past2', @MPast, 'AC', @DA, @U1
          UNION ALL SELECT 'none', @MNone, 'AC', @DA, @U1
          UNION ALL SELECT 'fin', @MFin, 'AC', @DA, @U1
          UNION ALL SELECT 'ctlAC', @MPast, 'AC', @DA, @U1
          UNION ALL SELECT 'ctlAMA', @MPast, 'AMA', @DA, @U1
          UNION ALL SELECT 'B', @MFut, 'AC', @DB, @U2
          UNION ALL SELECT 'm4a', @MPast, 'AC', @DA, @U3
          UNION ALL SELECT 'm4b', @MPast, 'AC', @DA, @U3) x;
    SELECT @iFut = MAX(CASE WHEN AgendaNo = 'ZZ52-fut' THEN AgendaId END), @iPast1 = MAX(CASE WHEN AgendaNo = 'ZZ52-past1' THEN AgendaId END),
           @iPast2 = MAX(CASE WHEN AgendaNo = 'ZZ52-past2' THEN AgendaId END), @iNone = MAX(CASE WHEN AgendaNo = 'ZZ52-none' THEN AgendaId END),
           @iFin = MAX(CASE WHEN AgendaNo = 'ZZ52-fin' THEN AgendaId END), @iCtlAC = MAX(CASE WHEN AgendaNo = 'ZZ52-ctlAC' THEN AgendaId END),
           @iCtlAMA = MAX(CASE WHEN AgendaNo = 'ZZ52-ctlAMA' THEN AgendaId END), @iB = MAX(CASE WHEN AgendaNo = 'ZZ52-B' THEN AgendaId END),
           @iM4a = MAX(CASE WHEN AgendaNo = 'ZZ52-m4a' THEN AgendaId END), @iM4b = MAX(CASE WHEN AgendaNo = 'ZZ52-m4b' THEN AgendaId END)
    FROM Agenda WHERE CommitteeId = @Com;

    -- One alert per item, with a row for its creator (as the agenda save writes them)
    INSERT INTO Alert_Master (SourceType, SourceTypeId, DepartmentId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    SELECT 'Agenda', a.AgendaId, a.DepartmentId, a.ShortText, a.AgendaStatusCode, 3, @Com, @Now, a.CreatedBy
    FROM Agenda a WHERE a.CommitteeId = @Com;
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT am.AlertId, am.CreatedBy, 1, 1 FROM Alert_Master am WHERE am.SourceType = 'Agenda' AND am.SourceTypeId IN (SELECT AgendaId FROM Agenda WHERE CommitteeId = @Com);

    ---------------------------------------------------------------------------
    -- Rule 12, the parts
    ---------------------------------------------------------------------------
    EXEC #ZZ52_Kinds @M1, NULL, 1, @S OUTPUT;
    INSERT INTO @T SELECT 'M1, personal part: to come and without a date open (P 2: fut, none); past with the agenda open (Q 3: past1, past2, ctlAC); finalised and AMA not counted; no D (M2, M4, M5 also of A)',
                          'P=2 Q=3', @S;

    EXEC #ZZ52_Kinds @M3, NULL, 1, @S OUTPUT;
    INSERT INTO @T SELECT 'M3, the only Manager of B with an item waiting: the department part D only (nothing routed to M3)', 'D:ZZ step 52 department B=1', @S;

    EXEC #ZZ52_Kinds @M4, NULL, 1, @S OUTPUT;
    INSERT INTO @T SELECT 'M4 (as mgruser): past items only (Q 2), no D (A has other Managers)', 'Q=2', @S;

    EXEC #ZZ52_Kinds @M1, @DA, 0, @S OUTPUT;
    INSERT INTO @T SELECT 'M1, department part only (@Personal 0) for A: nothing (other Managers of A)', '-', @S;

    ---------------------------------------------------------------------------
    -- Reason 24: role change, department removal, Deactivate
    ---------------------------------------------------------------------------
    SET @L = CAST(@DA AS VARCHAR(12));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Edit @M1, @rUser, @DA, @L, @Adm;
    INSERT INTO @T SELECT 'M1 made a User: refused, the personal part only (open 2, past 3), no department part; still a Manager',
                          'Result 0, Reason 24, open:2|past:3| | manager',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + (SELECT r.RoleCode FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE u.UserId = @M1);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Edit @M4, @rUser, @DA, @L, @Adm;
    INSERT INTO @T SELECT 'M4 (as mgruser) made a User: refused with the past items only',
                          'Result 0, Reason 24, open:0|past:2|', ISNULL((SELECT Txt FROM @R), '-');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Edit @M3, @rUser, @DA, @L, @Adm;
    INSERT INTO @T SELECT 'M3 made a User: refused with the department part only, its text as before step 52',
                          'Result 0, Reason 24, open:0|past:0|last active Manager of ZZ step 52 department B (1 item waiting)', ISNULL((SELECT Txt FROM @R), '-');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC #ZZ52_Edit @M3, @rMgr, @DA, @L, @Adm;
    INSERT INTO @T SELECT 'M3 edited to remove B (still a Manager): the department part only',
                          'Result 0, Reason 24, open:0|past:0|last active Manager of ZZ step 52 department B (1 item waiting) | 2',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @M3 AND EffectiveTo IS NULL) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @M4, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivate M4 (past items routed to him): refused, Reason 24 as for a role change; still active, his rows open',
                          'Result 0, Reason 24, open:0|past:2| | 1 1/1',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @M4) AS VARCHAR(4)) + ' '
                        + CAST((SELECT COUNT(*) FROM User_Role WHERE UserId = @M4 AND EffectiveTo IS NULL) AS VARCHAR(4)) + '/'
                        + CAST((SELECT COUNT(*) FROM User_Department WHERE UserId = @M4 AND EffectiveTo IS NULL) AS VARCHAR(4));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @M3, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivate M3 (the only Manager of B with an item waiting): refused with the department part',
                          'Result 0, Reason 24, open:0|past:0|last active Manager of ZZ step 52 department B (1 item waiting)', ISNULL((SELECT Txt FROM @R), '-');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @U1, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivate a User (not a Manager): rule 12 does not apply, done', 'Result 1, Reason 0 | 0', ISNULL((SELECT Txt FROM @R), '-') + ' | ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @U1) AS VARCHAR(4));
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @U1, @AccountStatus = 1, @ActingUserId = @Adm;

    ---------------------------------------------------------------------------
    -- Reason 28: a Manager's decision after the meeting date
    ---------------------------------------------------------------------------
    EXEC #ZZ52_Item @iPast1, @S OUTPUT;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iPast1, @ShortText = 'ZZ52 past1', @ProposedResolution = '',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @M1;
    EXEC #ZZ52_Item @iPast1, @S2 OUTPUT;
    INSERT INTO @T SELECT 'M1 approves an item of a past meeting: refused, Reason 28; the item, its alert rows and audit rows unchanged',
                          'Result 0, Reason 28 | ' + @S, ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2;

    EXEC #ZZ52_Item @iPast2, @S OUTPUT;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iPast2, @ShortText = 'ZZ52 past2', @ProposedResolution = '',
         @MgrComments = 'no', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @M1;
    EXEC #ZZ52_Item @iPast2, @S2 OUTPUT;
    INSERT INTO @T SELECT 'M1 rejects an item of a past meeting: refused, Reason 28; nothing written',
                          'Result 0, Reason 28 | ' + @S, ISNULL((SELECT Txt FROM @R), '-') + ' | ' + @S2;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iPast1, @ShortText = 'ZZ52 past1', @ProposedResolution = '',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @M2;
    INSERT INTO @T SELECT 'M2 (not routed) approves the same past item: Reason 14 first (routing), not 28',
                          'Result 0, Reason 14, Agenda Creation', ISNULL((SELECT Txt FROM @R), '-');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iFut, @ShortText = 'ZZ52 fut', @ProposedResolution = '',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @M1;
    INSERT INTO @T SELECT 'M1 approves the item of a meeting to come: done, AMA', 'Result 1, Reason 0 | AMA',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @iFut);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iNone, @ShortText = 'ZZ52 none', @ProposedResolution = '',
         @MgrComments = 'ok', @ControllerComments = '', @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @M1;
    INSERT INTO @T SELECT 'M1 approves the item of a meeting without a date: done, AMA', 'Result 1, Reason 0 | AMA',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @iNone);

    ---------------------------------------------------------------------------
    -- The Controller's reject after the meeting date (Agenda Finalization)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iCtlAC, @ShortText = 'ZZ52 ctlAC', @ProposedResolution = '',
         @MgrComments = '', @ControllerComments = 'Agenda rejected by Controller on agenda finalized.', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'The Controller rejects a past-meeting item at AC (as Agenda Finalization does): done, ACR', 'Result 1, Reason 0 | ACR',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @iCtlAC);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @iCtlAMA, @ShortText = 'ZZ52 ctlAMA', @ProposedResolution = '',
         @MgrComments = '', @ControllerComments = 'Agenda rejected by Controller on agenda finalized.', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'The Controller rejects a past-meeting item at AMA: done, ACR', 'Result 1, Reason 0 | ACR',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + (SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @iCtlAMA);

    -- After these decisions: M1 has no open item; past1 and past2 are still past
    EXEC #ZZ52_Kinds @M1, NULL, 1, @S OUTPUT;
    INSERT INTO @T SELECT 'M1 after the decisions: no open item; the two past items still counted (the Controller''s reject removed ctlAC)', 'Q=2', @S;

    -- Deactivate of a Manager with nothing routed, A keeps other Managers
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_SetUserStatusByUserId @UserId = @M5, @AccountStatus = 0, @ActingUserId = @Adm;
    INSERT INTO @T SELECT 'Deactivate M5 (a Manager, nothing routed, not the last of A): done', 'Result 1, Reason 0 | 0',
                          ISNULL((SELECT Txt FROM @R), '-') + ' | ' + CAST((SELECT AccountStatus FROM Users WHERE UserId = @M5) AS VARCHAR(4));

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
    INSERT INTO @T SELECT 'Part 2 ran to the end without an error', 'no error', LEFT('error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + ERROR_MESSAGE(), 400);
END CATCH

-- Rows outside the test, after
SELECT @UsersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserId, RoleId, DepartmentId, AccountStatus, ManagerId, EmailId)), 0) AS VARCHAR(12)) FROM Users;
SELECT @HistAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserRoleId, UserId, RoleId, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Role;
SELECT @HistAfter = @HistAfter + ' / ' + CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(UserDepartmentId, UserId, DepartmentId, IsHome, EffectiveFrom, EffectiveTo, ClosedBy)), 0) AS VARCHAR(12)) FROM User_Department;
SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, MgrApprovedStatus, ControllerApprovedStatus)), 0) AS VARCHAR(12)) FROM Agenda;
SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12)) FROM Alert_User_Map;
INSERT INTO @T SELECT 'After the rollback: Users as before', @UsersBefore, @UsersAfter;
INSERT INTO @T SELECT 'After the rollback: User_Role and User_Department as before', @HistBefore, @HistAfter;
INSERT INTO @T SELECT 'After the rollback: Agenda and Alert_User_Map as before', @AgendaBefore + ' / ' + @MapBefore, @AgendaAfter + ' / ' + @MapAfter;

Report:
INSERT INTO #T (Test, Expected, Actual) SELECT Test, Expected, Actual FROM @T ORDER BY TestNo;
GO

-- Every identity counter as before the test (a rolled-back insert still moves it)
DECLARE @TableName SYSNAME, @SavedValue BIGINT, @SeedValue BIGINT, @IncrementValue BIGINT, @Sql NVARCHAR(400);
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
SELECT 'After the test: no ZZ52 department, user, committee, meeting or item left', '0 0 0 0 0',
       CAST((SELECT COUNT(*) FROM Department WHERE DepartmentCode LIKE 'ZZ52%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz52%') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z52') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ52 test') AS VARCHAR(12)) + ' '
     + CAST((SELECT COUNT(*) FROM Agenda WHERE AgendaNo LIKE 'ZZ52-%') AS VARCHAR(12));

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

DROP PROCEDURE #ZZ52_Item;
DROP PROCEDURE #ZZ52_Kinds;
DROP PROCEDURE #ZZ52_Edit;
DROP PROCEDURE #ZZ52_Save;
DROP TABLE #Ident;
DROP TABLE #T;
GO

SET NOEXEC OFF;
GO
