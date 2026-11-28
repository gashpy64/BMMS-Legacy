/* ============================================================================
   BMMS - Tests for BMMS-Fix-MeetingDates-Step24.sql (step 24)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-MeetingDates-Step24.sql, on the TEST COPY. It stops if
   step 24 is not installed.

   Creates its own two committees, department, Controller and meetings, and
   checks, through spr_AddEditMeeting, with made-up sample values only:
     * markers: step 24 added, the texts of steps 16, 17 and 18 kept, the
       parameters unchanged
     * create: submission date before today, meeting date before today,
       submission after the meeting date, a date missing (Reason 16 with its
       ReasonDetail); today / today, today / later, between, equal to the
       meeting date, a time of day on the dates (saved); a refused create
       saves no meeting and no alert
     * edit: an old meeting (dates in the past) and a meeting whose submission
       date has passed, edited without changing the dates (saved); a changed
       date before today, a submission date after the meeting date, a date
       missing (refused); the same date at another time of day is no change;
       the order Reason 4, 6 and 10 before the date rules; refused edits
       change nothing and create no alert
   No mail is sent: only database procedures run. Today is the database server
   date, as in the procedure; do not run it across midnight.

   Everything runs inside one transaction that is ROLLED BACK. The only
   lasting effect is that identity values skip a few numbers. It uses no
   temporary tables, so it can be run twice in the same query window.

   Result: one grid, one row per check. Status should be PASS for every row.
   SKIPPED means a lookup row needed for the checks does not exist.

   It has no USE line: select the database in SSMS first (the test copy). It
   stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') NOT LIKE '%MeetingDates-Step24%')
BEGIN
    RAISERROR('The meeting dates (step 24) are not installed in "%s". Run BMMS-Fix-MeetingDates-Step24.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Today DATETIME = CAST(CAST(GETDATE() AS date) AS DATETIME);
DECLARE @TodayLate DATETIME = DATEADD(HOUR, 23, @Today);
DECLARE @Yesterday DATETIME = DATEADD(DAY, -1, @Today);
DECLARE @Minus2 DATETIME = DATEADD(DAY, -2, @Today);
DECLARE @Old DATETIME = DATEADD(DAY, -10, @Today);
DECLARE @OldSub DATETIME = DATEADD(DAY, -12, @Today);
DECLARE @OldSubLate DATETIME = DATEADD(HOUR, 15, @OldSub);
DECLARE @Plus1 DATETIME = DATEADD(DAY, 1, @Today);
DECLARE @Plus2 DATETIME = DATEADD(DAY, 2, @Today);
DECLARE @Plus3 DATETIME = DATEADD(DAY, 3, @Today);
DECLARE @Plus5 DATETIME = DATEADD(DAY, 5, @Today);
DECLARE @Plus6 DATETIME = DATEADD(DAY, 6, @Today);
DECLARE @NoDate DATETIME = NULL;
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @CtrlRoleId INT = (SELECT TOP 1 RoleId FROM Roles WHERE RoleCode = 'controller');
DECLARE @DesignationId INT = (SELECT TOP 1 DesignationId FROM Designation ORDER BY DesignationId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @MemberId INT = (SELECT MIN(MemberId) FROM Member);
DECLARE @C INT, @C2 INT, @Dept INT, @Ctl INT;
DECLARE @MOld INT, @MFut INT, @MAtt INT, @MAg INT, @Missing INT;
DECLARE @AlertsBefore INT, @Count INT;

IF (@Sys IS NULL OR @CtrlRoleId IS NULL OR @DesignationId IS NULL OR @SubjectTypeId IS NULL OR @MemberId IS NULL
    OR NOT EXISTS (SELECT 1 FROM Agenda_Status WHERE AgendaStatusCode = 'ACA'))
BEGIN
    INSERT INTO @T VALUES ('The system account, the controller role, a designation, a subject type, a member or agenda status ACA is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- Objects
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker: spr_AddEditMeeting (MeetingDates-Step24)', 'yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%MeetingDates-Step24%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_AddEditMeeting keeps the texts of steps 16, 17 and 18', 'yes',
       CASE WHEN ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%MeetingLocks-Step16%'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%UserStatus2b-Step17%'
             AND ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_AddEditMeeting')), '') LIKE '%SystemAccount3-Step18%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_AddEditMeeting parameters unchanged (14)', '14',
       CAST((SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_AddEditMeeting')) AS VARCHAR(12));

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names and addresses)
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z24', 'ZZ step 24 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Y24', 'ZZ step 24 other committee', '2000-01-01', 1, 0);
    SET @C2 = SCOPE_IDENTITY();

    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ24', 'ZZ step 24 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();

    INSERT INTO Users (UserName, DepartmentId, DesignationId, ManagerId, RoleId, EmailId, LoginName, [Password], AccountStatus, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES ('ZZ24 controller', @Dept, @DesignationId, NULL, @CtrlRoleId, 'zz24ctl@example.invalid', 'zz24ctl', 'not-a-login', 1, @Now, @Sys, @Now, @Sys);
    SET @Ctl = SCOPE_IDENTITY();

    -- Meetings saved before step 24 (inserted directly): an old one, one whose submission date has passed,
    -- an old one with attendance, a future one with an agenda item
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99241', @C, 'ZZ24 test', 'ZZ old venue', @Old, '10:00', @OldSub, 'Open', 'Open');
    SET @MOld = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99242', @C, 'ZZ24 test', 'ZZ venue', @Plus5, '10:00', @Yesterday, 'Open', 'Open');
    SET @MFut = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99243', @C, 'ZZ24 test', 'ZZ venue', @Old, '10:00', @OldSub, 'Open', 'Open');
    SET @MAtt = SCOPE_IDENTITY();
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@C, @MAtt, 'M', @MemberId, 'P', 0, @Now, @Sys);
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99244', @C, 'ZZ24 test', 'ZZ venue', @Plus5, '10:00', @Plus2, 'Open', 'Open');
    SET @MAg = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, CreatedOn, CreatedBy)
    VALUES ('Z24-99244-001', @C, @MAg, @Dept, @SubjectTypeId, 'ZZ24 item', 'Entry', 'ZZ', 'ZZ', 'ACA', 'Approved', @Now, @Ctl);
    SET @Missing = (SELECT ISNULL(MAX(MeetingId), 0) + 1000 FROM Meeting);

    ---------------------------------------------------------------------------
    -- Create
    ---------------------------------------------------------------------------
    SET @AlertsBefore = (SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND CommitteeId = @C);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99250', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @Yesterday, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission date yesterday (finding A)', 'Result 0, Reason 16, SubmissionBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99251', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Yesterday, @MeetingTime = '10:00', @AgendaSubmissionDate = @Yesterday, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: meeting date and submission date yesterday', 'Result 0, Reason 16, MeetingBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99252', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSub, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: a past meeting (no exception for past meetings)', 'Result 0, Reason 16, MeetingBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99253', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus6, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission date the day after the meeting date', 'Result 0, Reason 16, SubmissionAfterMeeting', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99254', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @NoDate, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus3, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: no meeting date', 'Result 0, Reason 16, Missing', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99255', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @NoDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: no agenda submission date', 'Result 0, Reason 16, Missing', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    INSERT INTO @T SELECT 'Create: the refused saves left no meeting and no alert', '0 0',
           CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C AND MeetingNo BETWEEN '99250' AND '99255') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND CommitteeId = @C) - @AlertsBefore AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99260', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Today, @MeetingTime = '10:00', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: meeting today, submission today', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99261', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @Now, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission today (with the time of day), meeting in 5 days', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99262', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus3, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission between today and the meeting date', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99263', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus5, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus5, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission date equal to the meeting date (finding B)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Save', @MeetingId = 0, @MeetingNo = '99264', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Today, @MeetingTime = '10:00', @AgendaSubmissionDate = @TodayLate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Create: submission today 23:00, meeting today 00:00 (compared as dates)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    INSERT INTO @T SELECT 'Create: the five saved meetings exist, each with its "created" alert', '5 5',
           CAST((SELECT COUNT(*) FROM Meeting WHERE CommitteeId = @C AND MeetingNo BETWEEN '99260' AND '99264') AS VARCHAR(12)) + ' '
         + CAST((SELECT COUNT(*) FROM Alert_Master a JOIN Meeting m ON m.MeetingId = a.SourceTypeId
                 WHERE a.SourceType = 'Meeting' AND a.AlertTypeCode = 'MC' AND m.CommitteeId = @C AND m.MeetingNo BETWEEN '99260' AND '99264') AS VARCHAR(12));

    ---------------------------------------------------------------------------
    -- Edit: dates unchanged
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ new venue', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSub, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: old meeting (both dates in the past), venue changed, dates unchanged', 'Result 1, Reason 0; ZZ new venue',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT Venue FROM Meeting WHERE MeetingId = @MOld), 'NULL');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ newer venue', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSubLate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: old meeting, submission date sent at another time of day (no change)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus5, @MeetingTime = '11:30', @AgendaSubmissionDate = @Yesterday, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: future meeting whose submission date has passed, time changed', 'Result 1, Reason 0; 11:30',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT MeetingTime FROM Meeting WHERE MeetingId = @MFut), 'NULL');

    ---------------------------------------------------------------------------
    -- Edit: a date changed
    ---------------------------------------------------------------------------
    SET @AlertsBefore = (SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MOld);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ refused', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @Yesterday, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: old meeting, submission date changed to yesterday', 'Result 0, Reason 16, SubmissionBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ refused', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: old meeting, submission date changed to today (after the meeting date)', 'Result 0, Reason 16, SubmissionAfterMeeting', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ refused', @MeetingDate = @Yesterday, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSub, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: old meeting, meeting date changed to yesterday', 'Result 0, Reason 16, MeetingBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MOld, @MeetingNo = '99241', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ refused', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @NoDate, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: no agenda submission date', 'Result 0, Reason 16, Missing', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    INSERT INTO @T SELECT 'Edit: the refused edits changed nothing and created no alert', 'ZZ newer venue; same dates; 0',
           ISNULL((SELECT Venue FROM Meeting WHERE MeetingId = @MOld), 'NULL') + '; '
         + CASE WHEN EXISTS (SELECT 1 FROM Meeting WHERE MeetingId = @MOld AND CAST(MeetingDate AS date) = CAST(@Old AS date)
                             AND CAST(AgendaSubmissionDate AS date) = CAST(@OldSub AS date)) THEN 'same dates' ELSE 'dates changed' END + '; '
         + CAST((SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MOld) - @AlertsBefore AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus5, @MeetingTime = '11:30', @AgendaSubmissionDate = @Minus2, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: passed submission date moved to another past date', 'Result 0, Reason 16, SubmissionBeforeToday', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus5, @MeetingTime = '11:30', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: passed submission date moved to today', 'Result 1, Reason 0; today',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + CASE WHEN EXISTS (SELECT 1 FROM Meeting WHERE MeetingId = @MFut AND CAST(AgendaSubmissionDate AS date) = CAST(@Today AS date)) THEN 'today' ELSE 'not today' END;

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus5, @MeetingTime = '11:30', @AgendaSubmissionDate = @Plus5, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: submission date moved to the meeting date', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus3, @MeetingTime = '11:30', @AgendaSubmissionDate = @Plus5, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: meeting date moved before the (unchanged) submission date', 'Result 0, Reason 16, SubmissionAfterMeeting', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Plus6, @MeetingTime = '11:30', @AgendaSubmissionDate = @Plus5, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: meeting date moved later', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MFut, @MeetingNo = '99242', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ venue', @MeetingDate = @Today, @MeetingTime = '11:30', @AgendaSubmissionDate = @Today, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: both dates moved to today', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    ---------------------------------------------------------------------------
    -- Edit: Reasons 4, 6 and 10 come before the date rules
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @Missing, @MeetingNo = '99999', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Yesterday, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus6, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: unknown meeting with bad dates: Reason 4 first', 'Result 0, Reason 4', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAtt, @MeetingNo = '99243', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Yesterday, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSub, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: attendance recorded, meeting date changed to yesterday: Reason 6 first', 'Result 0, Reason 6, MeetingDate', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAtt, @MeetingNo = '99243', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ att venue', @MeetingDate = @Old, @MeetingTime = '10:00', @AgendaSubmissionDate = @OldSub, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: attendance recorded, venue only (dates in the past, unchanged)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAg, @MeetingNo = '99244', @CommitteeId = @C2,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Yesterday, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus2, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: agenda items, committee changed and bad dates: Reason 10 first', 'Result 0, Reason 10, CommitteeId', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AddEditMeeting @Code = 'Update', @MeetingId = @MAg, @MeetingNo = '99244', @CommitteeId = @C,
         @Place = 'ZZ24 test', @Venue = 'ZZ', @MeetingDate = @Plus1, @MeetingTime = '10:00', @AgendaSubmissionDate = @Plus2, @MeetingColorCode = '',
         @CreatedOn = @Now, @CreatedBy = @Ctl, @UpdatedOn = @Now, @UpdatedBy = @Ctl;
    INSERT INTO @T SELECT 'Edit: agenda items, same committee, meeting date before the submission date', 'Result 0, Reason 16, SubmissionAfterMeeting', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    INSERT INTO @T SELECT 'Edit: "updated" alerts only for the saved edits of the old meeting', '2',
           CAST((SELECT COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @MOld AND AlertTypeCode = 'MU') AS VARCHAR(12));

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
SELECT (SELECT COUNT(*) FROM Users WHERE LoginName = 'zz24ctl') AS TestUsersLeft,
       (SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ24 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ24') AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode IN ('Z24', 'Y24') AND CommitteeName LIKE 'ZZ step 24%') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
