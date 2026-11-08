/* ============================================================================
   BMMS - Tests for BMMS-Fix-AlertRefresh-Step36.sql (step 36, step AL1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-AlertRefresh-Step36.sql, on the TEST COPY. It stops if
   step 36 is not installed.

   Creates its own committee, two departments, five users (two Controllers,
   a Manager, a user of that Manager and a user without a manager) and an
   open meeting, and checks, through the real procedures, with made-up
   sample values only:
     * the marker on the 3 procedures, the older texts they keep, and their
       parameter lists (unchanged)
     * a User's Update at AC: the Manager's alert is unread again
     * a User's Update of an item sent straight to the Controllers (AMA):
       the Controllers' alert is unread again
     * a Manager's comment change at AMA (the reported case) and at AMR, a
       Controller's comment change at AMA, ACA and ACR: every other
       recipient unread again
     * Update without a change: nothing refreshed (User, Manager,
       Controller); NULL and empty text are the same
     * NULL to a value and a value to NULL count as a change (comment and
       Subject No); so do a trailing space, a change of case and a change
       of department (Controller)
     * the acting user's own row is not changed; an alert the recipient had
       removed (StatusId 0) comes back unread
     * spr_GetAlertByUserId lists the refreshed alert as unread
     * Alert_Master (AlertTypeCode, CreatedOn) is not changed
     * a refused Update (agenda finalized) refreshes nothing
     * rows outside the test are not changed
   Each Actual shows the rows of the test users as tag=ReadStatus/StatusId
   (ctl, ctl2 the Controllers, mgr the Manager, usr and usr2 the users), and
   for the other recipients of the same alert (Admin and the Controllers of
   the database) whether all of them are unread or all read.

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%AlertRefresh-Step36%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%AlertRefresh-Step36%')
BEGIN
    RAISERROR('Step 36 (alert refresh on Update) is not installed in "%s". Run BMMS-Fix-AlertRefresh-Step36.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));
DECLARE @Who TABLE (UserId INT PRIMARY KEY, Tag VARCHAR(10));
DECLARE @VA TABLE (AlertUserId INT, UserId INT, ReadStatus INT, SourceType VARCHAR(50), AlertId INT, SourceTypeId INT,
                   DepartmentId INT, DepartmentName VARCHAR(50), AlertTypeCode VARCHAR(10), CommitteeId INT, CommitteeCode VARCHAR(10),
                   CommitteeName VARCHAR(50), CreatedOn DATETIME, AlertTypeName VARCHAR(50), DisplayText VARCHAR(150),
                   AlertSendOption INT, StatusId INT);

DECLARE @E NVARCHAR(10) = N'';
DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -3, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @C INT, @Dept INT, @Dept2 INT, @Ctl INT, @Ctl2 INT, @Mgr INT, @Usr INT, @Usr2 INT, @Mt INT;
DECLARE @Ag INT, @AgA INT, @AgB INT, @AgC INT, @AgD INT;
DECLARE @NoA VARCHAR(50), @NoB VARCHAR(50), @NoC VARCHAR(50), @NoD VARCHAR(50);
DECLARE @St VARCHAR(400), @NotUnread INT, @NotRead INT, @AmBefore VARCHAR(80);
DECLARE @MapBefore VARCHAR(40), @MapAfter VARCHAR(40), @MasterBefore VARCHAR(40), @MasterAfter VARCHAR(40),
        @AgendaBefore VARCHAR(40), @AgendaAfter VARCHAR(40);

IF (@Sys IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL OR @DesignationId IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- 1. Installation
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker on the 3 procedures (AlertRefresh-Step36)', '3',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%AlertRefresh-Step36%') AS VARCHAR(12));
INSERT INTO @T SELECT 'The 3 procedures keep the texts of steps 16, 17, 18 and 31', '3',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%'
             AND definition LIKE '%SystemAccount3-Step18%' AND definition LIKE '%UnicodeText-Step31%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_AddEditAgendaByManager and spr_AddEditAgendaByController keep the text of step 35', '2',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%CommentAuthor-Step35%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_AddEditAgenda keeps the text of step 20 and has no marker of step 35', 'yes no marker',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%AgendaRouting-Step20%' THEN 'yes' ELSE 'no' END + ' '
     + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%CommentAuthor-Step35%' THEN 'marker' ELSE 'no marker' END;
INSERT INTO @T SELECT 'spr_UpdateAgendaByAgendaId (Approve / Reject) is not changed by step 36', 'no marker',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') LIKE '%AlertRefresh-Step36%' THEN 'marker' ELSE 'no marker' END;
INSERT INTO @T SELECT 'Parameter names in order: spr_AddEditAgenda; ByManager and ByController the same as spr_AddEditAgenda',
       '@Code,@AgendaId,@AgendaNo,@CommitteeId,@MeetingId,@DepartmentId,@SubjectTypeId,@ShortText,@AgendaType,@AgendaText,@AgendaTextPath,@ProposedResolution,@FilePath,@MgrComments,@ControllerComments,@CurrentStatus,@CreatedOn,@CreatedBy,@UpdatedOn,@UpdatedBy,@SubjectNo,@ActingUserId; same same',
       ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + '; '
     + CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByManager') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END + ' '
     + CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByController') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END;

-- Rows outside the test, before the test: count and checksum
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12))
FROM Alert_User_Map;
SELECT @MasterBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, AlertTypeCode, CreatedOn, SourceTypeId)), 0) AS VARCHAR(12))
FROM Alert_Master;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, UpdatedOn, UpdatedBy, MgrApprovedDate, ControllerApprovedDate, SubjectNo, DepartmentId)), 0) AS VARCHAR(12))
FROM Agenda;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- 2. Fixtures (made-up names). The meeting has no CreatedOn: it counts as older than step 23
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z36', 'ZZ step 36 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ36', 'ZZ step 36 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ36B', 'ZZ step 36 department B', 999, 1, @Now, @Sys);
    SET @Dept2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ36 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz36ctl@example.invalid', 'zz36ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ36 controller 2', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz36ctl2@example.invalid', 'zz36ctl2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ36 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz36mgr@example.invalid', 'zz36mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ36 user', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz36usr@example.invalid', 'zz36usr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ36 user without manager', @Dept, @DesignationId, NULL, @UserRoleId, 'zz36usr2@example.invalid', 'zz36usr2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr2 = SCOPE_IDENTITY();
    INSERT INTO @Who (UserId, Tag) VALUES (@Ctl, 'ctl'), (@Ctl2, 'ctl2'), (@Mgr, 'mgr'), (@Usr, 'usr'), (@Usr2, 'usr2');

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99936', @C, 'ZZ36 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- 3. A User's item waiting for the Manager (AC): the User edits it
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = 'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgA = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoA = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgA);
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'User saves an item (route to the Manager): status AC; the Manager''s row unread', 'Result 1, Reason 0; mgr=0/1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Item A status after the User''s save', 'AC', ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA), 'none');
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'User clicks Update without a change: nothing refreshed', 'Result 1, Reason 0; mgr=1/1; others read',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotRead = 0 THEN 'others read' ELSE CAST(@NotRead AS VARCHAR(12)) + ' others not read' END;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'User changes the short text: the Manager''s alert is unread again (and Admin''s)', 'Result 1, Reason 0; mgr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'User adds only a trailing space: counts as a change', 'Result 1, Reason 0; mgr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;

    ---------------------------------------------------------------------------
    -- 4. Manager approves (AMA), then changes the comment on Agenda Entry (the reported case)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ36 short, changed by the user ', @ProposedResolution = N'ZZ36 resolution',
         @MgrComments = N'ZZ36 manager ok', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Manager approves on the Dashboard: status AMA; the Controllers and the creator unread, the Manager read', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St;
    SELECT @AmBefore = AlertTypeCode + ' ' + CONVERT(VARCHAR(23), CreatedOn, 121) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager ok, comment changed', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Manager changes the comment at AMA: the Controllers, the creator and Admin unread; the Manager''s own row unchanged', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    DELETE FROM @VA; INSERT INTO @VA EXEC spr_GetAlertByUserId @RoleName = 'controller', @UserId = @Ctl;
    INSERT INTO @T SELECT 'spr_GetAlertByUserId (controller) lists the refreshed alert as unread', '0/1',
           ISNULL((SELECT TOP 1 CAST(ReadStatus AS VARCHAR(4)) + '/' + CAST(StatusId AS VARCHAR(4)) FROM @VA WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA), 'not listed');
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager ok, comment changed', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Manager clicks Update again without a change: nothing refreshed', 'Result 1, Reason 0; ctl=1/1 ctl2=1/1 mgr=1/1 usr=1/1; others read',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotRead = 0 THEN 'others read' ELSE CAST(@NotRead AS VARCHAR(12)) + ' others not read' END;
    UPDATE Agenda SET MgrComments = NULL WHERE AgendaId = @AgA;   -- the saved comment is NULL
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 typed into an empty comment', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Comment from NULL to a text: counts as a change', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = NULL, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Comment from a text to NULL: counts as a change', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Comment from NULL to empty text: the same, nothing refreshed', 'Result 1, Reason 0; ctl=1/1 ctl2=1/1 mgr=1/1 usr=1/1; others read',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotRead = 0 THEN 'others read' ELSE CAST(@NotRead AS VARCHAR(12)) + ' others not read' END;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 MANAGER', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Only the case of the comment changes: counts as a change', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    UPDATE m SET ReadStatus = 1, StatusId = 0 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA AND m.UserId = @Ctl;   -- the Controller removed the alert from the Dashboard
    UPDATE m SET ReadStatus = 1, StatusId = 0 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA AND m.UserId = @Mgr;   -- the acting Manager's own row: read and removed
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'A removed alert comes back unread (ctl); the acting Manager''s own row stays as it was (1/0)', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1 mgr=1/0 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    INSERT INTO @T SELECT 'Alert_Master of the item unchanged by the refreshes (AlertTypeCode, CreatedOn)', ISNULL(@AmBefore, 'none'),
           ISNULL((SELECT AlertTypeCode + ' ' + CONVERT(VARCHAR(23), CreatedOn, 121) FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgA), 'none');

    ---------------------------------------------------------------------------
    -- 5. Controller approves (ACA), then changes the comment, the Subject No and the department
    ---------------------------------------------------------------------------
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA AND m.UserId = @Mgr;   -- shown again for the next checks
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ36 short, changed by the user ', @ProposedResolution = N'ZZ36 resolution',
         @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Controller changes the comment at ACA: the creator, the Manager, the other Controller and Admin unread; the Controller''s own row unchanged', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1 mgr=0/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 5, @ActingUserId = @Ctl;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Subject No from NULL to 5: counts as a change', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1 mgr=0/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Subject No from 5 to NULL: counts as a change', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1 mgr=0/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Controller changes the department: counts as a change', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1 mgr=0/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager, once more', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Controller clicks Update without a change: nothing refreshed', 'Result 1, Reason 0; ctl=1/1 ctl2=1/1 mgr=1/1 usr=1/1; others read',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotRead = 0 THEN 'others read' ELSE CAST(@NotRead AS VARCHAR(12)) + ' others not read' END;

    ---------------------------------------------------------------------------
    -- 6. An item sent straight to the Controllers (no manager, AMA)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = 'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr2, @UpdatedOn = @Now, @UpdatedBy = @Usr2, @SubjectNo = NULL, @ActingUserId = @Usr2;
    SET @AgB = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr2 AND MeetingId = @Mt);
    SET @NoB = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgB);
    INSERT INTO @T SELECT 'Item B status after the save of a User without a manager', 'AMA', ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgB), 'none');
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgB;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgB, @AgendaNo = @NoB, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text, changed by the user', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr2, @UpdatedOn = @Now, @UpdatedBy = @Usr2, @SubjectNo = NULL, @ActingUserId = @Usr2;
    SET @Ag = @AgB;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'User changes the agenda text: the Controllers'' alert is unread again', 'Result 1, Reason 0; ctl=0/1 ctl2=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgB;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgB, @AgendaNo = @NoB, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text, changed by the user', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ36 controller note before deciding', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgB;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Controller comments at AMA without deciding: the other Controller unread; the acting Controller unchanged', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;

    ---------------------------------------------------------------------------
    -- 7. Controller rejected (ACR), then changes the comment
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = 'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoC = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgC);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = N'ZZ36 short', @ProposedResolution = N'ZZ36 resolution',
         @MgrComments = N'ZZ36 manager ok', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = N'ZZ36 short', @ProposedResolution = N'ZZ36 resolution',
         @MgrComments = N'ZZ36 manager ok', @ControllerComments = N'ZZ36 controller reject', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Item C status after the Controller''s reject', 'ACR', ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgC), 'none');
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgC;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgC, @AgendaNo = @NoC, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager ok', @ControllerComments = N'ZZ36 controller reject, reason added', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @Ag = @AgC;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Controller changes the comment at ACR: the creator, the Manager and the other Controller unread', 'Result 1, Reason 0; ctl=1/1 ctl2=0/1 mgr=0/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;

    ---------------------------------------------------------------------------
    -- 8. Manager rejected (AMR), then changes the comment
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = 'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgD = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoD = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgD);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgD, @ShortText = N'ZZ36 short', @ProposedResolution = N'ZZ36 resolution',
         @MgrComments = N'ZZ36 manager reject', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Item D status after the Manager''s reject', 'AMR', ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgD), 'none');
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgD;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 manager reject, reason added', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgD;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Manager changes the comment at AMR: the creator unread; the Manager''s own row unchanged', 'Result 1, Reason 0; mgr=1/1 usr=0/1; others unread',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotUnread = 0 THEN 'others unread' ELSE CAST(@NotUnread AS VARCHAR(12)) + ' others not unread' END;

    ---------------------------------------------------------------------------
    -- 9. A refused Update (agenda finalized, Reason 5) refreshes nothing
    ---------------------------------------------------------------------------
    UPDATE Meeting SET AgendaStatus = 'Close' WHERE MeetingId = @Mt;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ36 short, changed by the user ', @AgendaType = N'Entry', @AgendaText = N'ZZ36 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ36 resolution', @FilePath = @E, @MgrComments = N'ZZ36 refused change', @ControllerComments = N'ZZ36 controller ok, comment changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @NotUnread = ISNULL(SUM(CASE WHEN m.ReadStatus = 0 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0),
           @NotRead = ISNULL(SUM(CASE WHEN m.ReadStatus = 1 AND m.StatusId = 1 THEN 0 ELSE 1 END), 0)
    FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId NOT IN (SELECT UserId FROM @Who);
    INSERT INTO @T SELECT 'Manager changes the comment of a finalized agenda: refused; nothing refreshed', 'Result 0, Reason 5; ctl=1/1 ctl2=1/1 mgr=1/1 usr=1/1; others read',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + @St + '; ' + CASE WHEN @NotRead = 0 THEN 'others read' ELSE CAST(@NotRead AS VARCHAR(12)) + ' others not read' END;

    ---------------------------------------------------------------------------
    -- 10. Rows outside the test
    ---------------------------------------------------------------------------
    SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(m.AlertUserId, m.AlertId, m.UserId, m.ReadStatus, m.StatusId)), 0) AS VARCHAR(12))
    FROM Alert_User_Map m WHERE m.AlertId NOT IN (SELECT am.AlertId FROM Alert_Master am JOIN Agenda a ON a.AgendaId = am.SourceTypeId
                                                 WHERE am.SourceType = 'Agenda' AND a.MeetingId = @Mt);
    SELECT @MasterAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertId, AlertTypeCode, CreatedOn, SourceTypeId)), 0) AS VARCHAR(12))
    FROM Alert_Master WHERE AlertId NOT IN (SELECT am.AlertId FROM Alert_Master am JOIN Agenda a ON a.AgendaId = am.SourceTypeId
                                            WHERE am.SourceType = 'Agenda' AND a.MeetingId = @Mt);
    SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, UpdatedOn, UpdatedBy, MgrApprovedDate, ControllerApprovedDate, SubjectNo, DepartmentId)), 0) AS VARCHAR(12))
    FROM Agenda WHERE MeetingId <> @Mt;
    INSERT INTO @T SELECT 'Alert_User_Map rows outside the test unchanged (count, checksum)', @MapBefore, @MapAfter;
    INSERT INTO @T SELECT 'Alert_Master rows outside the test unchanged (count, checksum)', @MasterBefore, @MasterAfter;
    INSERT INTO @T SELECT 'Agenda rows outside the test unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;

END TRY
BEGIN CATCH
    INSERT INTO @T VALUES ('Unexpected error - tests after this point did not run', 'No error',
                           'Error ' + CAST(ERROR_NUMBER() AS VARCHAR(12)) + ' line ' + CAST(ERROR_LINE() AS VARCHAR(12)) + ': ' + LEFT(ERROR_MESSAGE(), 300));
END CATCH

IF (@@TRANCOUNT > 0)
    ROLLBACK TRANSACTION;

Report:

SELECT TestNo, Test, Expected, Actual,
       CASE WHEN Actual = 'SKIPPED' THEN 'SKIPPED'
            WHEN Actual = Expected THEN 'PASS'
            ELSE 'FAIL' END AS Status
FROM @T
ORDER BY TestNo;

SELECT DB_NAME() AS CurrentDatabase,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND Actual = Expected THEN 1 ELSE 0 END) AS Passed,
       SUM(CASE WHEN Actual <> 'SKIPPED' AND (Actual <> Expected OR Actual IS NULL) THEN 1 ELSE 0 END) AS Failed,
       SUM(CASE WHEN Actual = 'SKIPPED' THEN 1 ELSE 0 END) AS Skipped
FROM @T;

-- Confirm nothing was kept: should be 0, 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz36%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo = '99936' AND Place = 'ZZ36 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode IN ('ZZ36', 'ZZ36B')) AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z36' AND CommitteeName = 'ZZ step 36 committee') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
