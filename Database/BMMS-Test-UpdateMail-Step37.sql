/* ============================================================================
   BMMS - Tests for BMMS-Fix-UpdateMail-Step37.sql (step 37, step ML1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-UpdateMail-Step37.sql, on the TEST COPY. It stops if
   step 37 is not installed.

   Creates its own committee, two departments, a subject type, five users
   (two Controllers, a Manager, a user of that Manager and a user without a
   manager) and an open meeting, and checks, through the real procedures,
   with made-up sample values only:
     * the marker on the 4 procedures, the texts of steps 16, 17, 18, 31,
       35 and 36 kept, @ChangedFields the one new parameter (last, OUTPUT,
       VARCHAR(400)), the MailSenderUserId row
     * @ChangedFields: empty on Save, on an Update without a change and on a
       refused Update; one code per changed field (Subject Type, Short Text,
       Agenda Type, Agenda Text, the agenda text file attached / replaced /
       removed, Proposed Resolution, Attachments, both comments, Department,
       Subject No) in the fixed order; NULL and empty text are the same; a
       trailing space and a change of case count; NULL to a value and back
       count
     * a caller without @ChangedFields: saved and refreshed as in step 36
     * spr_GetAgendaUpdateMailId (the Bcc of the update mail; the person who
       saved is the To, set by the page): the users the refreshed alert is
       shown to (no Manager for AMA / AMR, no Controller for ACA / ACR),
       never the acting user, an inactive user, a user without an address
       or the system account, and no address outside the item's alert
     * rows outside the test are not changed
   Each Actual shows the result row, cf= the list (empty) when empty, and
   where checked the alert rows of the test users (tag=ReadStatus/StatusId)
   and the test users that get the mail (ctl, ctl2 the Controllers, mgr the
   Manager, usr and usr2 the users; other recipients of the database, such
   as Admin, are not listed by name).

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') NOT LIKE '%UpdateMail-Step37%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByManager')), '') NOT LIKE '%UpdateMail-Step37%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgendaByController')), '') NOT LIKE '%UpdateMail-Step37%'
         OR OBJECT_ID('dbo.spr_GetAgendaUpdateMailId', 'P') IS NULL)
BEGIN
    RAISERROR('Step 37 (mail on Update) is not installed in "%s". Run BMMS-Fix-UpdateMail-Step37.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(200), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))));
DECLARE @Who TABLE (UserId INT PRIMARY KEY, Tag VARCHAR(10));
DECLARE @M TABLE (EmailId VARCHAR(250));

DECLARE @E NVARCHAR(10) = N'';
DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -3, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @MgrRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'manager');
DECLARE @UserRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'user');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @SubjectType2 INT;
DECLARE @C INT, @Dept INT, @Dept2 INT, @Ctl INT, @Ctl2 INT, @Mgr INT, @Usr INT, @Usr2 INT, @Mt INT;
DECLARE @Ag INT, @AgA INT, @AgB INT, @AgC INT, @AgD INT, @Actor INT;
DECLARE @NoA VARCHAR(50), @NoB VARCHAR(50), @NoC VARCHAR(50), @NoD VARCHAR(50);
DECLARE @CF VARCHAR(400), @St VARCHAR(400), @Ml VARCHAR(400), @Strangers INT, @Sender VARCHAR(250);
DECLARE @MapBefore VARCHAR(40), @MapAfter VARCHAR(40), @AgendaBefore VARCHAR(40), @AgendaAfter VARCHAR(40),
        @SettingBefore VARCHAR(40), @SettingAfter VARCHAR(40);

IF (@Sys IS NULL OR @CtrlRoleId IS NULL OR @MgrRoleId IS NULL OR @UserRoleId IS NULL OR @DesignationId IS NULL OR @SubjectTypeId IS NULL)
BEGIN
    INSERT INTO @T VALUES ('The system account, a role, a designation or a subject type is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- 1. Installation
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker on the 4 procedures (UpdateMail-Step37)', '4',
       CAST((SELECT COUNT(*) FROM (VALUES ('spr_AddEditAgenda'), ('spr_AddEditAgendaByManager'), ('spr_AddEditAgendaByController'), ('spr_GetAgendaUpdateMailId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%UpdateMail-Step37%') AS VARCHAR(12));
INSERT INTO @T SELECT 'The 3 agenda procedures keep the texts of steps 16, 17, 18, 31 and 36', '3',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%MeetingLocks-Step16%' AND definition LIKE '%UserStatus2b-Step17%' AND definition LIKE '%SystemAccount3-Step18%'
             AND definition LIKE '%UnicodeText-Step31%' AND definition LIKE '%AlertRefresh-Step36%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_AddEditAgendaByManager and spr_AddEditAgendaByController keep the text of step 35; spr_AddEditAgenda the text of step 20', '2 yes',
       CAST((SELECT COUNT(*) FROM sys.sql_modules WHERE object_id IN (OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND definition LIKE '%CommentAuthor-Step35%') AS VARCHAR(12)) + ' '
     + CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditAgenda')), '') LIKE '%AgendaRouting-Step20%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'Parameter names in order: spr_AddEditAgenda (step 36 list plus @ChangedFields); ByManager and ByController the same',
       '@Code,@AgendaId,@AgendaNo,@CommitteeId,@MeetingId,@DepartmentId,@SubjectTypeId,@ShortText,@AgendaType,@AgendaText,@AgendaTextPath,@ProposedResolution,@FilePath,@MgrComments,@ControllerComments,@CurrentStatus,@CreatedOn,@CreatedBy,@UpdatedOn,@UpdatedBy,@SubjectNo,@ActingUserId,@ChangedFields; same same',
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
INSERT INTO @T SELECT '@ChangedFields on the 3 procedures: OUTPUT, varchar(400), has a default', '3',
       CAST((SELECT COUNT(*) FROM sys.parameters p JOIN sys.types t ON t.user_type_id = p.user_type_id
             WHERE p.object_id IN (OBJECT_ID('dbo.spr_AddEditAgenda'), OBJECT_ID('dbo.spr_AddEditAgendaByManager'), OBJECT_ID('dbo.spr_AddEditAgendaByController'))
             AND p.name = '@ChangedFields' AND p.is_output = 1 AND t.name = 'varchar' AND p.max_length = 400
             AND ISNULL(OBJECT_DEFINITION(p.object_id), '') LIKE '%@ChangedFields VARCHAR(400) = NULL OUTPUT%') AS VARCHAR(12));
SET @Sender = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'MailSenderUserId');
INSERT INTO @T SELECT 'App_Setting MailSenderUserId: present; empty or an active Controller-role user', 'yes',
       CASE WHEN @Sender IS NULL THEN 'missing'
            WHEN @Sender = '' THEN 'yes'
            WHEN @Sender NOT LIKE '%[^0-9]%' AND LEN(@Sender) BETWEEN 1 AND 9
                 AND EXISTS (SELECT 1 FROM Users u JOIN Roles r ON r.RoleId = u.RoleId
                             WHERE u.UserId = CAST(@Sender AS INT) AND r.RoleCode = 'controller' AND u.AccountStatus = 1 AND u.IsSystem = 0) THEN 'yes'
            ELSE 'not an active Controller: ' + @Sender END;

-- Rows outside the test, before the test: count and checksum
SELECT @MapBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AlertUserId, AlertId, UserId, ReadStatus, StatusId)), 0) AS VARCHAR(12))
FROM Alert_User_Map;
SELECT @AgendaBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, UpdatedOn, UpdatedBy, MgrApprovedDate, ControllerApprovedDate, SubjectNo, DepartmentId)), 0) AS VARCHAR(12))
FROM Agenda;
SELECT @SettingBefore = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- 2. Fixtures (made-up names). The meeting has no CreatedOn: it counts as older than step 23
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z37', 'ZZ step 37 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ37', 'ZZ step 37 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ37B', 'ZZ step 37 department B', 999, 1, @Now, @Sys);
    SET @Dept2 = SCOPE_IDENTITY();
    INSERT INTO Subject_Type (SubjectTypeCode, SubjectTypeName, OrderNo, StatusId, IsDelete, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37', 'ZZ step 37 subject type', 999, 1, 0, @Now, @Sys, @Now, @Sys);
    SET @SubjectType2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz37ctl@example.invalid', 'zz37ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37 controller 2', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz37ctl2@example.invalid', 'zz37ctl2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl2 = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37 manager', @Dept, @DesignationId, NULL, @MgrRoleId, 'zz37mgr@example.invalid', 'zz37mgr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Mgr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37 user', @Dept, @DesignationId, @Mgr, @UserRoleId, 'zz37usr@example.invalid', 'zz37usr', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr = SCOPE_IDENTITY();
    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ37 user without manager', @Dept, @DesignationId, NULL, @UserRoleId, 'zz37usr2@example.invalid', 'zz37usr2', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Usr2 = SCOPE_IDENTITY();
    INSERT INTO @Who (UserId, Tag) VALUES (@Ctl, 'ctl'), (@Ctl2, 'ctl2'), (@Mgr, 'mgr'), (@Usr, 'usr'), (@Usr2, 'usr2');

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99937', @C, 'ZZ37 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open');
    SET @Mt = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- 3. Save, and a User's Update at AC (waiting for the Manager): one code per field
    ---------------------------------------------------------------------------
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = 'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @AgA = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoA = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgA);
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'A new item (Save): @ChangedFields empty', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'User clicks Update without a change: empty; alert not refreshed; no recipient needed', 'Result 1, Reason 0; cf=(empty); alert mgr=1/1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; alert ' + @St;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short, changed', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'User changes the short text: ShortText; the Manager''s alert unread; mail to the Manager', 'Result 1, Reason 0; cf=ShortText; alert mgr=0/1; mail mgr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; alert ' + @St + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short, changed ', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'A trailing space only: ShortText', 'Result 1, Reason 0; cf=ShortText',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'A change of case only: ShortText', 'Result 1, Reason 0; cf=ShortText',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Subject Type changed: SubjectType', 'Result 1, Reason 0; cf=SubjectType',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Type changed: AgendaType', 'Result 1, Reason 0; cf=AgendaType',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Text changed: AgendaText', 'Result 1, Reason 0; cf=AgendaText',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = N'zz37-agenda-text.pdf',
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Text file from empty to a file: AgendaTextFile:Attached', 'Result 1, Reason 0; cf=AgendaTextFile:Attached',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = N'zz37-agenda-text-2.pdf',
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Text file replaced: AgendaTextFile:Replaced', 'Result 1, Reason 0; cf=AgendaTextFile:Replaced',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = NULL,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Text file from a file to NULL: AgendaTextFile:Removed', 'Result 1, Reason 0; cf=AgendaTextFile:Removed',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Agenda Text file from NULL to empty: the same, empty list', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution <b>bold</b>', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Proposed Resolution changed: ProposedResolution', 'Result 1, Reason 0; cf=ProposedResolution',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 SHORT, CHANGED ', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text, changed', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution <b>bold</b>', @FilePath = N'zz37-a.pdf,', @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Attachments changed: Attachments', 'Result 1, Reason 0; cf=Attachments',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 3', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Four fields at once: in the fixed order', 'Result 1, Reason 0; cf=ShortText,AgendaText,ProposedResolution,Attachments',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr;
    SET @Actor = @Usr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'A caller that does not pass @ChangedFields: saved and refreshed as before (step 36)', 'Result 1, Reason 0; cf=not set; alert mgr=0/1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; alert ' + @St;

    ---------------------------------------------------------------------------
    -- 4. Manager approves (AMA), then changes the comment; the Controller comments without deciding
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ37 short 4', @ProposedResolution = N'ZZ37 resolution 3',
         @MgrComments = N'ZZ37 manager ok', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgA;   -- every recipient has read it
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = N'ZZ37 manager ok, changed', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgA;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'Manager changes the comment at AMA: MgrComments; mail to the Controllers and the creator, not to the Manager', 'Result 1, Reason 0; cf=MgrComments; alert ctl=0/1 ctl2=0/1 mgr=1/1 usr=0/1; mail ctl ctl2 usr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; alert ' + @St + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = N'ZZ37 manager ok, changed', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Manager clicks Update again without a change: empty', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = NULL, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Comment from a text to NULL: MgrComments', 'Result 1, Reason 0; cf=MgrComments',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Comment from NULL to empty: empty', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'A Manager does not write the department: another department sent is not a change', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ37 controller note', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgA;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'Controller comments at AMA without deciding: ControllerComments; no mail to the Manager (AMA alert), none to the acting Controller', 'Result 1, Reason 0; cf=ControllerComments; mail ctl2 usr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 5. Controller approves (ACA): Subject No, department; no mail to the Controllers
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgA, @ShortText = N'ZZ37 short 4', @ProposedResolution = N'ZZ37 resolution 3',
         @MgrComments = @E, @ControllerComments = N'ZZ37 controller ok', @ControllerApprovedStatus = 'Approved', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ37 controller ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = 5, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgA;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'Subject No from NULL to 5: SubjectNo; mail to the Manager and the creator, not to the other Controller (ACA alert)', 'Result 1, Reason 0; cf=SubjectNo; mail mgr usr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ37 controller ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Subject No from 5 to NULL: SubjectNo', 'Result 1, Reason 0; cf=SubjectNo',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ37 controller ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Controller changes the department: Department', 'Result 1, Reason 0; cf=Department',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgA, @AgendaNo = @NoA, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept2, @SubjectTypeId = @SubjectType2, @ShortText = N'ZZ37 short 4', @AgendaType = N'Upload', @AgendaText = N'ZZ37 text 3', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution 3', @FilePath = @E, @MgrComments = @E, @ControllerComments = N'ZZ37 controller ok', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgA;
    INSERT INTO @T SELECT 'Controller clicks Update without a change: empty', 'Result 1, Reason 0; cf=(empty)',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END;

    ---------------------------------------------------------------------------
    -- 6. Who gets the mail: inactive, no address, system account
    ---------------------------------------------------------------------------
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = 'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr2, @UpdatedOn = @Now, @UpdatedBy = @Usr2, @SubjectNo = NULL, @ActingUserId = @Usr2, @ChangedFields = @CF OUTPUT;
    SET @AgB = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr2 AND MeetingId = @Mt);
    SET @NoB = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgB);
    SET @Actor = @Usr2;
    INSERT INTO @T SELECT 'Item B (user without a manager) goes straight to the Controllers', 'AMA', ISNULL((SELECT AgendaStatusCode FROM Agenda WHERE AgendaId = @AgB), 'none');
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgB, @AgendaNo = @NoB, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text B', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr2, @UpdatedOn = @Now, @UpdatedBy = @Usr2, @SubjectNo = NULL, @ActingUserId = @Usr2, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr2;
    SET @Ag = @AgB;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'User changes the agenda text at AMA: mail to both Controllers', 'Result 1, Reason 0; cf=AgendaText; mail ctl ctl2; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    UPDATE Users SET AccountStatus = 0 WHERE UserId = @Ctl2;   -- inactive
    UPDATE Users SET EmailId = '' WHERE UserId = @Ctl;   -- no address
    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT AlertId, @Sys, 1, 1 FROM Alert_Master WHERE SourceType = 'Agenda' AND SourceTypeId = @AgB;   -- a row for the system account
    UPDATE Users SET EmailId = 'zz37sys@example.invalid' WHERE UserId = @Sys;   -- its own address (real accounts share mailboxes)
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Update', @AgendaId = @AgB, @AgendaNo = @NoB, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text B, again', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr2, @UpdatedOn = @Now, @UpdatedBy = @Usr2, @SubjectNo = NULL, @ActingUserId = @Usr2, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Usr2;
    SET @Ag = @AgB;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'An inactive Controller, a Controller without an address and the system account get no mail', 'Result 1, Reason 0; cf=AgendaText; mail none; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    INSERT INTO @T SELECT 'The system account (given its own test address) is not in the list', '0',
           CAST((SELECT COUNT(*) FROM @M WHERE EmailId = 'zz37sys@example.invalid') AS VARCHAR(12));
    UPDATE Users SET AccountStatus = 1 WHERE UserId = @Ctl2;
    UPDATE Users SET EmailId = 'zz37ctl@example.invalid' WHERE UserId = @Ctl;

    ---------------------------------------------------------------------------
    -- 7. Controller rejected (ACR), Manager rejected (AMR)
    ---------------------------------------------------------------------------
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = 'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @AgC = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoC = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgC);
    SET @Actor = @Usr;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = N'ZZ37 short', @ProposedResolution = N'ZZ37 resolution',
         @MgrComments = N'ZZ37 manager ok', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Approved', @UpdatedBy = @Mgr;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgC, @ShortText = N'ZZ37 short', @ProposedResolution = N'ZZ37 resolution',
         @MgrComments = N'ZZ37 manager ok', @ControllerComments = N'ZZ37 controller reject', @ControllerApprovedStatus = 'Rejected', @MgrApprovedStatus = '', @UpdatedBy = @Ctl;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByController @Code = 'Update', @AgendaId = @AgC, @AgendaNo = @NoC, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = N'ZZ37 manager ok', @ControllerComments = N'ZZ37 controller reject, reason added', @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl, @SubjectNo = NULL, @ActingUserId = @Ctl, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Ctl;
    SET @Ag = @AgC;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'Controller changes the comment at ACR: mail to the Manager and the creator, not to the other Controller', 'Result 1, Reason 0; cf=ControllerComments; mail mgr usr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgenda @Code = 'Save', @AgendaId = 0, @AgendaNo = '', @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = 'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = @E, @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Usr, @UpdatedOn = @Now, @UpdatedBy = @Usr, @SubjectNo = NULL, @ActingUserId = @Usr, @ChangedFields = @CF OUTPUT;
    SET @AgD = (SELECT MAX(AgendaId) FROM Agenda WHERE CreatedBy = @Usr AND MeetingId = @Mt);
    SET @NoD = (SELECT AgendaNo FROM Agenda WHERE AgendaId = @AgD);
    SET @Actor = @Usr;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaByAgendaId @AgendaId = @AgD, @ShortText = N'ZZ37 short', @ProposedResolution = N'ZZ37 resolution',
         @MgrComments = N'ZZ37 manager reject', @ControllerComments = @E, @ControllerApprovedStatus = '', @MgrApprovedStatus = 'Rejected', @UpdatedBy = @Mgr;
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = N'ZZ37 manager reject, reason added', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgD;
    DELETE FROM @M; INSERT INTO @M (EmailId) EXEC spr_GetAgendaUpdateMailId @AgendaId = @Ag, @ActingUserId = @Actor;
    SELECT @Ml = ISNULL(STUFF((SELECT ' ' + wh.Tag FROM @M x JOIN Users u ON u.EmailId = x.EmailId JOIN @Who wh ON wh.UserId = u.UserId
                ORDER BY wh.Tag FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    SELECT @Strangers = COUNT(*) FROM @M x WHERE NOT EXISTS (SELECT 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
                JOIN Users u ON u.UserId = m.UserId WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag AND m.UserId <> @Actor AND u.EmailId = x.EmailId);
    INSERT INTO @T SELECT 'Manager changes the comment at AMR: mail to the creator only', 'Result 1, Reason 0; cf=MgrComments; mail usr; strangers 0',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; mail ' + @Ml + '; strangers ' + CAST(@Strangers AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- 8. A refused Update (agenda finalized, Reason 5): empty list, nothing refreshed
    ---------------------------------------------------------------------------
    UPDATE Meeting SET AgendaStatus = 'Close' WHERE MeetingId = @Mt;
    UPDATE m SET ReadStatus = 1, StatusId = 1 FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @AgD;   -- every recipient has read it
    SET @CF = 'not set';
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditAgendaByManager @Code = 'Update', @AgendaId = @AgD, @AgendaNo = @NoD, @CommitteeId = @C, @MeetingId = @Mt,
         @DepartmentId = @Dept, @SubjectTypeId = @SubjectTypeId, @ShortText = N'ZZ37 short', @AgendaType = N'Entry', @AgendaText = N'ZZ37 text', @AgendaTextPath = @E,
         @ProposedResolution = N'ZZ37 resolution', @FilePath = @E, @MgrComments = N'ZZ37 refused change', @ControllerComments = @E, @CurrentStatus = 'New',
         @CreatedOn = @Now, @CreatedBy = @Mgr, @UpdatedOn = @Now, @UpdatedBy = @Mgr, @SubjectNo = NULL, @ActingUserId = @Mgr, @ChangedFields = @CF OUTPUT;
    SET @Actor = @Mgr;
    SET @Ag = @AgD;
    SELECT @St = ISNULL(STUFF((SELECT ' ' + wh.Tag + '=' + CAST(m.ReadStatus AS VARCHAR(4)) + '/' + CAST(m.StatusId AS VARCHAR(4))
                FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId JOIN @Who wh ON wh.UserId = m.UserId
                WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @Ag ORDER BY wh.Tag, m.AlertUserId
                FOR XML PATH(''), TYPE).value('.', 'VARCHAR(400)'), 1, 1, ''), 'none');
    INSERT INTO @T SELECT 'Manager changes the comment of a finalized agenda: refused; empty; alert not refreshed', 'Result 0, Reason 5; cf=(empty); alert mgr=1/1 usr=1/1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; cf=' + CASE WHEN @CF IS NULL THEN '(null)' WHEN @CF = '' THEN '(empty)' ELSE @CF END + '; alert ' + @St;

    ---------------------------------------------------------------------------
    -- 9. Rows outside the test
    ---------------------------------------------------------------------------
    SELECT @MapAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(m.AlertUserId, m.AlertId, m.UserId, m.ReadStatus, m.StatusId)), 0) AS VARCHAR(12))
    FROM Alert_User_Map m WHERE m.AlertId NOT IN (SELECT am.AlertId FROM Alert_Master am JOIN Agenda a ON a.AgendaId = am.SourceTypeId
                                                 WHERE am.SourceType = 'Agenda' AND a.MeetingId = @Mt);
    SELECT @AgendaAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(AgendaId, AgendaStatusCode, UpdatedOn, UpdatedBy, MgrApprovedDate, ControllerApprovedDate, SubjectNo, DepartmentId)), 0) AS VARCHAR(12))
    FROM Agenda WHERE MeetingId <> @Mt;
    SELECT @SettingAfter = CAST(COUNT(*) AS VARCHAR(12)) + ' ' + CAST(ISNULL(CHECKSUM_AGG(BINARY_CHECKSUM(SettingCode, SettingValue)), 0) AS VARCHAR(12)) FROM App_Setting;
    INSERT INTO @T SELECT 'Alert_User_Map rows outside the test unchanged (count, checksum)', @MapBefore, @MapAfter;
    INSERT INTO @T SELECT 'Agenda rows outside the test unchanged (count, checksum)', @AgendaBefore, @AgendaAfter;
    INSERT INTO @T SELECT 'App_Setting unchanged (count, checksum)', @SettingBefore, @SettingAfter;

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

-- Confirm nothing was kept: should be 0, 0, 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName LIKE 'zz37%') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE MeetingNo = '99937' AND Place = 'ZZ37 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode IN ('ZZ37', 'ZZ37B')) AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z37' AND CommitteeName = 'ZZ step 37 committee') AS TestCommitteesLeft,
       (SELECT COUNT(*) FROM Subject_Type WHERE SubjectTypeCode = 'ZZ37') AS TestSubjectTypesLeft;
GO

SET NOEXEC OFF;
GO
