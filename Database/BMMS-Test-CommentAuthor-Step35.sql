/* ============================================================================
   BMMS - Tests for BMMS-Fix-CommentAuthor-Step35.sql (step 35, step UN4)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-CommentAuthor-Step35.sql, on the TEST COPY. It stops if
   step 35 is not installed.

   Creates its own committee, department, three users (a Controller, a
   Manager and a user of that Manager) and an open meeting, and checks,
   through the real procedures, with made-up sample values only:
     * the marker on the 3 procedures, the older texts they keep, and their
       parameter lists (unchanged)
     * a User's save and edit (spr_AddEditAgenda) write no who and when
     * Dashboard: the Manager's Approve (with an empty comment) and Reject,
       the Controller's Approve and Reject (at AC and at AMA, the reject of
       Agenda Finalization) write the acting user and the time of their own
       role only, and leave the other role's who and when as they are
     * a refused Approve (the system account) writes nothing
     * Agenda Entry: a new item of a Manager / of the Controller writes the
       who and when of that role (also with an empty comment); an edit writes
       them only when that role's comment text changes (a change of case and
       a trailing space count; NULL and empty text are the same), and never
       for the other role's comment; a refused edit writes nothing
     * View_Agenda returns the who and when
     * rows outside the test are not changed
   Dates written by a save are checked as "now" (within 10 minutes of the
   server clock); "old" is a date the test sets on purpose before a save that
   must keep it.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')), '') NOT LIKE '%CommentAuthor-Step35%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%CommentAuthor-Step35%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%CommentAuthor-Step35%')
BEGIN
    RAISERROR('Step 35 (who and when of the comments) is not installed in "%s". Run BMMS-Fix-CommentAuthor-Step35.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));

DECLARE @E NVARCHAR(10) = N'';
DECLARE @Now DATETIME = GETDATE();
DECLARE @Old DATETIME = '20260101 08:00:00';
DECLARE @Past DATETIME = DATEADD(DAY, -3, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @C INT, @Dept INT, @Ctl INT, @Mgr INT, @Usr INT, @Mt INT;
DECLARE @AgA INT, @AgB INT, @AgC INT, @AgD INT, @AgE INT, @AgF INT;
DECLARE @NoA VARCHAR(50), @NoB VARCHAR(50), @NoC VARCHAR(50), @NoD VARCHAR(50), @NoE VARCHAR(50), @NoF VARCHAR(50);
DECLARE @OthersBefore VARCHAR(40), @OthersAfter VARCHAR(40);

IF (@Sys IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL OR @DesignationId IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- 1. Installation
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker on the 3 procedures (CommentAuthor-Step35)', '3',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_UpdateAgendaByAgendaId'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%CommentAuthor-Step35%') AS VARCHAR(12));
INSERT INTO @T SELECT 'The 3 procedures keep the texts of steps 16, 17, 18 and 31', '3',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%'
             AND definition LIKE '%SystemAccount3-Step18%' AND definition LIKE '%UnicodeText-Step31%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_UpdateAgendaByAgendaId keeps the text of step 20', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId')) LIKE '%AgendaRouting-Step20%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_AddEditAgenda is not changed by step 35', 'no marker',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%CommentAuthor-Step35%' THEN 'marker' ELSE 'no marker' END;
INSERT INTO @T SELECT 'Parameter names in order: spr_UpdateAgendaByAgendaId; ByManager and ByController the same as spr_AddEditAgenda',
       '@AgendaId,@ShortText,@ProposedResolution,@MgrComments,@ControllerComments,@ControllerApprovedStatus,@MgrApprovedStatus,@UpdatedBy; same same',
       ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_UpdateAgendaByAgendaId') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none') + '; '
     + CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByManager') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END + ' '
     + CASE WHEN ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgendaByController') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'x')
               = ISNULL(STUFF((SELECT ',' + name FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditAgenda') ORDER BY parameter_id
                     FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'y') THEN 'same' ELSE 'different' END;

-- Rows outside the test: how many have a who or a when, and the latest date, before the test
SELECT @OthersBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL(CONVERT(VARCHAR(19), MAX(ISNULL(CASE WHEN MgrApprovedDate > ISNULL(ControllerApprovedDate, 0) THEN MgrApprovedDate ELSE ControllerApprovedDate END, 0)), 120), 'none')
FROM Agenda WHERE MgrApprovedBy IS NOT NULL OR MgrApprovedDate IS NOT NULL OR ControllerApprovedBy IS NOT NULL OR ControllerApprovedDate IS NOT NULL;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names). The meeting has no CreatedOn: it counts as older than step 23
    ---------------------------------------------------------------------------
    -- Own committee with a three-letter code: the agenda number is read by position
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z35', 'ZZ step 35 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ35', 'ZZ step 35 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ35 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz35ctl@example.invalid', 'zz35ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ35 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz35mgr@example.invalid', 'zz35mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ35 user', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz35usr@example.invalid', 'zz35usr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99935', @C, 'ZZ35 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- 2. A User's item (spr_AddEditAgenda): no who and when
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgA = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr);
    SET @NoA = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgA);
    INSERT INTO @T SELECT 'User saves an item: result, status; Manager and Controller who/when', 'Result 1, Reason 0; AC; none/none none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    INSERT INTO @T SELECT 'User edits the item: result; still no who/when', 'Result 1, Reason 0; none/none none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item');

    ---------------------------------------------------------------------------
    -- 3. Dashboard (spr_UpdateAgendaByAgendaId)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = @E, @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'The system account approves: refused (Reason 12); no who/when', 'Result 0, Reason 12; none/none none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = @E, @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Manager approves with an EMPTY comment: result, status; Manager who/when written, Controller none', 'Result 1, Reason 0; AMA; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item');
    INSERT INTO @T SELECT 'Manager approval: MgrApprovedDate is the UpdatedOn of the same save', 'same',
           ISNULL((SELECT CASE WHEN MgrApprovedDate = UpdatedOn THEN 'same' ELSE 'different' END FROM Agenda WHERE AgendaId = @AgA), 'none');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgA;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = @E, @ControllerComments = N'ZZ35 controller comment', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Controller approves at AMA with a comment: result, status; Controller written, the Manager''s kept', 'Result 1, Reason 0; ACA; mgr/old ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgA), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgA), 'no item');
    INSERT INTO @T SELECT 'View_Agenda returns the who and when (MgrApprovedBy, MgrApprovedDate, ControllerApprovedBy, ControllerApprovedDate)', 'mgr old ctl set',
           ISNULL((SELECT CASE WHEN MgrApprovedBy = @Mgr THEN 'mgr' ELSE 'other' END + ' ' + CASE WHEN MgrApprovedDate = @Old THEN 'old' ELSE 'other' END + ' ' + CASE WHEN ControllerApprovedBy = @Ctl THEN 'ctl' ELSE 'other' END + ' ' + CASE WHEN ControllerApprovedDate IS NOT NULL THEN 'set' ELSE 'none' END FROM View_Agenda WHERE AgendaId = @AgA), 'none');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgB = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr);
    SET @NoB = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgB);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgB, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = N'ZZ35 manager reject', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @Mgr;
    INSERT INTO @T SELECT 'Manager rejects with a comment: result, status; Manager written, Controller none', 'Result 1, Reason 0; AMR; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgB), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgB), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgB), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr);
    SET @NoC = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgC);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = @E, @ControllerComments = N'ZZ35 controller reject', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Controller rejects at AC: result, status; Controller written, Manager none', 'Result 1, Reason 0; ACR; none/none ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgC), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgC), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgC), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @AgF = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr);
    SET @NoF = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgF);
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgF, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = N'ZZ35 ok', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgF;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgF, @ShortText = N'ZZ35 short', @ProposedResolution = N'ZZ35 resolution',
         @MgrComments = N'ZZ35 ok', @ControllerComments = N'Agenda rejected by Controller on agenda finalized.', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Reject of Agenda Finalization (Controller, at AMA, fixed comment): result, status; Controller written, the Manager''s kept', 'Result 1, Reason 0; ACR; mgr/old ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgF), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgF), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgF), 'no item');

    ---------------------------------------------------------------------------
    -- 4. Agenda Entry, a Manager's item (spr_AddEditAgendaByManager)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    SET @AgD = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Mgr);
    SET @NoD = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgD);
    INSERT INTO @T SELECT 'Manager saves a new item with an EMPTY comment: result, status; Manager written, Controller none', 'Result 1, Reason 0; AMA; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgD), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgD;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = NULL, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager edits it, comment empty before and NULL now (the same): result; kept', 'Result 1, Reason 0; mgr/old none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    UPDATE Agenda SET MgrApprovedBy = @Usr WHERE AgendaId = @AgD;   -- to see that the acting user is written
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'zz35 comment', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager types a comment: result; the acting Manager and now are written', 'Result 1, Reason 0; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgD;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'zz35 comment', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager saves the same comment again: kept', 'Result 1, Reason 0; mgr/old none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'zz35 comment', @ControllerComments = N'ZZ35 written back', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager''s save with a different Controller comment written back: neither who/when changes', 'Result 1, Reason 0; mgr/old none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 COMMENT', @ControllerComments = N'ZZ35 written back', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager changes only the case of the comment: written', 'Result 1, Reason 0; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgD;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 COMMENT ', @ControllerComments = N'ZZ35 written back', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    INSERT INTO @T SELECT 'Manager adds only a trailing space: written', 'Result 1, Reason 0; mgr/now none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgD;
    UPDATE Meeting SET AgendaStatus = 'Close' WHERE MeetingId = @Mt;   -- the agenda is finalized: a Manager's edit is refused
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 other', @ControllerComments = N'ZZ35 written back', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr;
    UPDATE Meeting SET AgendaStatus = 'Open' WHERE MeetingId = @Mt;
    INSERT INTO @T SELECT 'A refused edit (agenda finalized, Reason 5): no change of the comment or its who/when', 'Result 0, Reason 5; ZZ35 COMMENT ; mgr/old none/none',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CAST(MgrComments AS VARCHAR(40)) FROM Agenda WHERE AgendaId = @AgD), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgD), 'no item');

    ---------------------------------------------------------------------------
    -- 5. Agenda Entry, the Controller's item (spr_AddEditAgendaByController)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ35 ctl comment', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    SET @AgE = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Ctl);
    SET @NoE = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgE);
    INSERT INTO @T SELECT 'Controller saves a new item with a comment: result, status; Controller written, Manager none', 'Result 1, Reason 0; ACA; none/none ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgE), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgE;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgE, @AgendaNo = @NoE, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 mgr text written back', @ControllerComments = N'ZZ35 ctl comment', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller saves the same comment (a Manager comment written back): neither who/when changes', 'Result 1, Reason 0; none/none ctl/old',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item');
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgE, @AgendaNo = @NoE, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 mgr text written back', @ControllerComments = N'ZZ35 ctl comment, changed', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller changes the comment: Controller written', 'Result 1, Reason 0; none/none ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item');
    UPDATE Agenda SET MgrApprovedDate = CASE WHEN MgrApprovedDate IS NULL THEN NULL ELSE @Old END,
                      ControllerApprovedDate = CASE WHEN ControllerApprovedDate IS NULL THEN NULL ELSE @Old END WHERE AgendaId = @AgE;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgE, @AgendaNo = @NoE, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ35 short', @AgendaType = 'Entry', @AgendaText = N'ZZ35 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ35 resolution', @FilePath = @E, @MgrComments = N'ZZ35 mgr text written back', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl;
    INSERT INTO @T SELECT 'Controller clears the comment: written (the caption then shows the name with an empty box)', 'Result 1, Reason 0; none/none ctl/now',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT CASE WHEN MgrApprovedBy IS NULL THEN 'none' WHEN MgrApprovedBy = @Mgr THEN 'mgr' WHEN MgrApprovedBy = @Ctl THEN 'ctl' WHEN MgrApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN MgrApprovedDate IS NULL THEN 'none' WHEN MgrApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, MgrApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item') + ' ' + ISNULL((SELECT CASE WHEN ControllerApprovedBy IS NULL THEN 'none' WHEN ControllerApprovedBy = @Mgr THEN 'mgr' WHEN ControllerApprovedBy = @Ctl THEN 'ctl' WHEN ControllerApprovedBy = @Usr THEN 'usr' ELSE 'other' END + '/' + CASE WHEN ControllerApprovedDate IS NULL THEN 'none' WHEN ControllerApprovedDate = @Old THEN 'old' WHEN DATEDIFF(SECOND, ControllerApprovedDate, GETDATE()) BETWEEN 0 AND 600 THEN 'now' ELSE 'other' END FROM Agenda WHERE AgendaId = @AgE), 'no item');

    ---------------------------------------------------------------------------
    -- 6. Rows outside the test
    ---------------------------------------------------------------------------
    SELECT @OthersAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + ISNULL(CONVERT(VARCHAR(19), MAX(ISNULL(CASE WHEN MgrApprovedDate > ISNULL(ControllerApprovedDate, 0) THEN MgrApprovedDate ELSE ControllerApprovedDate END, 0)), 120), 'none')
    FROM Agenda WHERE MeetingId <> @Mt
    AND (MgrApprovedBy IS NOT NULL OR MgrApprovedDate IS NOT NULL OR ControllerApprovedBy IS NOT NULL OR ControllerApprovedDate IS NOT NULL);
    INSERT INTO @T SELECT 'Rows outside the test: the same count with a who or when, and the same latest date', @OthersBefore, @OthersAfter;

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
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz35%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo = '99935' AND Place = 'ZZ35 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ35') AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z35' AND CommitteeName = 'ZZ step 35 committee') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
