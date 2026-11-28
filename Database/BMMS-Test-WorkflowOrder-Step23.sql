/* ============================================================================
   BMMS - Tests for BMMS-Fix-WorkflowOrder-Step23.sql (step 23)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Run AFTER BMMS-Fix-WorkflowOrder-Step23.sql, on the TEST COPY. It stops if
   step 23 is not installed.

   Creates its own committee, department, two committee members and meetings,
   and checks, through the real procedures, with made-up sample values only:
     * markers: step 23 on the new and replaced objects, the older texts kept,
       the WorkflowOrderFrom setting
     * a meeting created now (new) taken through the order: attendance and
       chairman before Agenda Finalisation (Reason 17), Update Minutes and the
       short text before attendance (18), a chairman without anyone present
       (18), Finalise with a minute never updated (19, 'n/m'), then every step
       in order; Confirm before Finalise (Reason 3, 'Open')
     * the existing refusals first: 4, 1, 3, 7, and 17 before 9
     * a new meeting without agenda items: attendance allowed, Finalise 19 '0/0'
     * an agenda item added after finalization (as the Controller option does):
       its new minute must be updated before Finalise
     * older meetings (no CreatedOn, or created before step 23): every step
       allowed exactly as before
     * the read procedure for the pages
   No mail is sent: only database procedures run.

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
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_WorkflowState')), '') NOT LIKE '%WorkflowOrder-Step23%')
BEGIN
    RAISERROR('The workflow order (step 23) is not installed in "%s". Run BMMS-Fix-WorkflowOrder-Step23.sql first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

DECLARE @T TABLE (TestNo INT IDENTITY(1,1), Test VARCHAR(160), Expected VARCHAR(400), Actual VARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000),
                  Txt AS ('Result ' + CAST(Result AS VARCHAR(2)) + ', Reason ' + CAST(Reason AS VARCHAR(3))
                          + CASE WHEN ReasonDetail <> '' THEN ', ' + CAST(ReasonDetail AS VARCHAR(200)) ELSE '' END));
DECLARE @R1 TABLE (Result INT);
DECLARE @S TABLE (IsNew INT, AgendaFinalized INT, AttendanceRecorded INT, MinutesTotal INT, MinutesUpdated INT,
                  Txt AS (CAST(IsNew AS VARCHAR(2)) + ',' + CAST(AgendaFinalized AS VARCHAR(2)) + ',' + CAST(AttendanceRecorded AS VARCHAR(2))
                          + ',' + CAST(MinutesUpdated AS VARCHAR(12)) + '/' + CAST(MinutesTotal AS VARCHAR(12))));

DECLARE @Now DATETIME = GETDATE();
DECLARE @Past DATETIME = DATEADD(DAY, -3, CAST(CAST(GETDATE() AS date) AS DATETIME));
DECLARE @Sys INT = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
DECLARE @SubjectTypeId INT = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
DECLARE @MemberTypeId INT = (SELECT TOP 1 MemberTypeId FROM Member_Type ORDER BY MemberTypeId);
DECLARE @DecisionOther INT = (SELECT TOP 1 DecisionTypeId FROM Decision_Type WHERE DecisionTypeId <> 1 ORDER BY DecisionTypeId);
DECLARE @M1 INT = (SELECT MIN(MemberId) FROM Member);
DECLARE @M2 INT = (SELECT MIN(MemberId) FROM Member WHERE MemberId > (SELECT MIN(MemberId) FROM Member));
DECLARE @MOut INT = (SELECT MIN(MemberId) FROM Member WHERE MemberId > (SELECT MIN(MemberId) FROM Member WHERE MemberId > (SELECT MIN(MemberId) FROM Member)));
DECLARE @C INT, @Dept INT;
DECLARE @MN INT, @MZ INT, @MB INT, @MO INT, @MO2 INT, @Missing INT;
DECLARE @Ag1 INT, @Ag2 INT, @Min1 INT, @Min2 INT, @AgB INT, @AgLate INT, @AgO2 INT, @MinO2 INT;
DECLARE @From VARCHAR(250);

IF (@Sys IS NULL OR @SubjectTypeId IS NULL OR @MemberTypeId IS NULL OR @DecisionOther IS NULL OR @MOut IS NULL
    OR NOT EXISTS (SELECT 1 FROM Agenda_Status WHERE AgendaStatusCode = 'ACA'))
BEGIN
    INSERT INTO @T VALUES ('The system account, a subject type, a member type, a decision type other than 1, three members or agenda status ACA is missing', 'PASS', 'SKIPPED');
    GOTO Report;
END

---------------------------------------------------------------------------
-- Objects
---------------------------------------------------------------------------
INSERT INTO @T SELECT 'Marker on the 7 objects of step 23 (WorkflowOrder-Step23)', '7',
       CAST((SELECT COUNT(*) FROM (VALUES ('fn_WorkflowState'), ('spr_GetMeetingWorkflowState'), ('spr_UpdateAttendance'), ('spr_UpdateMeetingChairman'),
             ('spr_UpdateAgendaShortText'), ('spr_UpdateMinutes'), ('spr_MinutesFinalizeByMeetingId')) o(Name)
             WHERE ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.' + o.Name)), '') LIKE '%WorkflowOrder-Step23%') AS VARCHAR(12));
INSERT INTO @T SELECT 'spr_UpdateAttendance keeps Attendance-FutureMeeting, MeetingLocks-Step15, MeetingLocks-Step16', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAttendance')) LIKE '%Attendance-FutureMeeting%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAttendance')) LIKE '%MeetingLocks-Step15%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAttendance')) LIKE '%MeetingLocks-Step16%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_UpdateMeetingChairman keeps MeetingLocks-Step15, MeetingLocks-Step16', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMeetingChairman')) LIKE '%MeetingLocks-Step15%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMeetingChairman')) LIKE '%MeetingLocks-Step16%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_UpdateAgendaShortText keeps MeetingLocks-Step16', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateAgendaShortText')) LIKE '%MeetingLocks-Step16%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_UpdateMinutes keeps FK #5, MeetingLocks-Step16, UserStatus2b-Step17, SystemAccount3-Step18', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%FK #5%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%MeetingLocks-Step16%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%UserStatus2b-Step17%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_UpdateMinutes')) LIKE '%SystemAccount3-Step18%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_MinutesFinalizeByMeetingId keeps the step 8 check, MeetingLocks-Step15, UserStatus2b-Step17, SystemAccount3-Step18', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%NOT EXISTS (SELECT 1 FROM ActionItem[_]User[_]Map x%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%MeetingLocks-Step15%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%UserStatus2b-Step17%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesFinalizeByMeetingId')) LIKE '%SystemAccount3-Step18%' THEN 'yes' ELSE 'no' END;
INSERT INTO @T SELECT 'spr_MinutesConfirmByMeetingId unchanged (step 15 text, no step 23 text)', 'yes',
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesConfirmByMeetingId')) LIKE '%MeetingLocks-Step15%'
             AND OBJECT_DEFINITION(OBJECT_ID('dbo.spr_MinutesConfirmByMeetingId')) NOT LIKE '%WorkflowOrder-Step23%' THEN 'yes' ELSE 'no' END;
SET @From = (SELECT SettingValue FROM App_Setting WHERE SettingCode = 'WorkflowOrderFrom');
INSERT INTO @T SELECT 'Setting WorkflowOrderFrom: present, a date, not in the future', 'yes',
       CASE WHEN @From IS NOT NULL AND ISDATE(@From) = 1 AND CONVERT(DATETIME, CASE WHEN ISDATE(@From) = 1 THEN @From END, 126) <= GETDATE()
            THEN 'yes' ELSE 'no: ' + ISNULL(@From, 'missing') END;

BEGIN TRANSACTION;

BEGIN TRY

    ---------------------------------------------------------------------------
    -- Fixtures (made-up names). New meetings: CreatedOn now; older meetings: no CreatedOn, or the year 2000
    ---------------------------------------------------------------------------
    INSERT INTO Committee (CommitteeCode, CommitteeName, IncorporationDate, StatusId, Board) VALUES ('Z23', 'ZZ step 23 committee', '2000-01-01', 1, 0);
    SET @C = SCOPE_IDENTITY();
    INSERT INTO Department (DepartmentCode, DepartmentName, OrderNo, StatusId, CreatedOn, CreatedBy) VALUES ('ZZ23', 'ZZ step 23 department', 999, 1, @Now, @Sys);
    SET @Dept = SCOPE_IDENTITY();
    INSERT INTO Committee_Member (CommitteeId, MemberId, MemberTypeId, AppointmentDate, CessationDate, IsFeeApplicable, ApplicableFee, CreatedOn, CreatedBy) VALUES
    (@C, @M1, @MemberTypeId, NULL, '', 0, 0, @Now, @Sys),
    (@C, @M2, @MemberTypeId, NULL, '', 0, 0, @Now, @Sys);

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('99231', @C, 'ZZ23 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open', @Now, @Sys);
    SET @MN = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('99232', @C, 'ZZ23 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open', @Now, @Sys);
    SET @MZ = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('99233', @C, 'ZZ23 test', 'ZZ', @Past, '10:00', @Past, 'Close', 'Open', @Now, @Sys);
    SET @MB = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('99234', @C, 'ZZ23 test', 'ZZ', @Past, '10:00', @Past, 'Open', 'Open');
    SET @MO = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus, CreatedOn, CreatedBy)
    VALUES ('99235', @C, 'ZZ23 test', 'ZZ', @Past, '10:00', @Past, 'Close', 'Open', '2000-01-01', @Sys);
    SET @MO2 = SCOPE_IDENTITY();
    SET @Missing = (SELECT ISNULL(MAX(MeetingId), 0) + 1000 FROM Meeting);

    -- Two approved agenda items on the new meeting (Agenda Finalisation turns them into minutes)
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    VALUES ('Z23-99231-001', @C, @MN, @Dept, @SubjectTypeId, 'ZZ23 item 1', 'Entry', 'ZZ', 'ZZ23 resolution 1', 'ACA', 'Approved', 1, @Now, @Sys);
    SET @Ag1 = SCOPE_IDENTITY();
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    VALUES ('Z23-99231-002', @C, @MN, @Dept, @SubjectTypeId, 'ZZ23 item 2', 'Entry', 'ZZ', 'ZZ23 resolution 2', 'ACA', 'Approved', 2, @Now, @Sys);
    SET @Ag2 = SCOPE_IDENTITY();

    -- The bypass meeting: agenda finalized, attendance entered, its one minute updated
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    VALUES ('Z23-99233-001', @C, @MB, @Dept, @SubjectTypeId, 'ZZ23 bypass 1', 'Entry', 'ZZ', 'ZZ', 'ACA', 'Approved', 1, @Now, @Sys);
    SET @AgB = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, StatusId, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgB, @DecisionOther, ' ', 'ZZ', 1, @Now, @Sys, @Now, @Sys);
    UPDATE Meeting SET ChairmanNameId = @M1 WHERE MeetingId = @MB;
    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@C, @MB, 'C', @M1, 'P', 0, @Now, @Sys);

    -- The older meeting created in 2000: agenda finalized, one minute never updated, no attendance
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    VALUES ('Z23-99235-001', @C, @MO2, @Dept, @SubjectTypeId, 'ZZ23 old', 'Entry', 'ZZ', 'ZZ', 'ACA', 'Approved', 1, @Now, @Sys);
    SET @AgO2 = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgO2, @DecisionOther, ' ', 'ZZ', @Now, @Sys, @Now, @Sys);
    SET @MinO2 = SCOPE_IDENTITY();

    ---------------------------------------------------------------------------
    -- New meeting, step by step
    ---------------------------------------------------------------------------
    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @MN;
    INSERT INTO @T SELECT 'State of the new meeting at the start (new, agenda, attendance, updated/total)', '1,0,0,0/0', ISNULL((SELECT TOP 1 Txt FROM @S), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MN, @CommitteeId = @C, @ChairmanNameId = @M1;
    INSERT INTO @T SELECT 'Chairman before Agenda Finalisation', 'Result 0, Reason 17', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MN, @CommitteeId = @C, @ChairmanNameId = @MOut;
    INSERT INTO @T SELECT 'Chairman not on the committee, before Agenda Finalisation: 17 comes before 9', 'Result 0, Reason 17', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MN, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Attendance before Agenda Finalisation: refused, nothing saved', 'Result 0; 0 rows',
           'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none') + '; '
         + CAST((SELECT COUNT(*) FROM Attendance WHERE MeetingId = @MN) AS VARCHAR(12)) + ' rows';

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise Minutes before Agenda Finalisation', 'Result 0, Reason 17', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @Ag1, @ShortText = 'ZZ23 short', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Short text (minutes page) before Agenda Finalisation', 'Result 0, Reason 17', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MN;
    SET @Min1 = (SELECT MinutesId FROM Minutes WHERE AgendaId = @Ag1);
    SET @Min2 = (SELECT MinutesId FROM Minutes WHERE AgendaId = @Ag2);
    INSERT INTO @T SELECT 'Agenda Finalisation (unchanged): agenda closed, two minutes created', 'Result 1, Reason 0; Close; 2',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT AgendaStatus FROM Meeting WHERE MeetingId = @MN), 'NULL') + '; '
         + CAST((SELECT COUNT(*) FROM Minutes WHERE AgendaId IN (@Ag1, @Ag2)) AS VARCHAR(12));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min1, @DecisionTypeId = @DecisionOther,
        @Directions = '', @ActualResolution = '', @ShortText = 'ZZ23 item 1', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes (All) before attendance', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @Min1, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ directions', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes (Directions) before attendance', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'ActualResolution', @MinutesId = @Min1, @DecisionTypeId = @DecisionOther,
        @Directions = '', @ActualResolution = 'ZZ resolution', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes (ActualResolution) before attendance', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @Ag1, @ShortText = 'ZZ23 short', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Short text before attendance', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise Minutes before attendance', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MN, @CommitteeId = @C, @ChairmanNameId = @MOut;
    INSERT INTO @T SELECT 'Chairman not on the committee, agenda finalized: Reason 9 as before', 'Result 0, Reason 9', LEFT(ISNULL((SELECT TOP 1 Txt FROM @R), 'none'), 18);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MN, @CommitteeId = @C, @ChairmanNameId = @M1;
    INSERT INTO @T SELECT 'Chairman after Agenda Finalisation', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MN, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'A', @UpdatedBy = @Sys;
    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @MN;
    INSERT INTO @T SELECT 'Attendance saved with nobody present: not yet "attendance entered"', 'Result 1; 1,1,0,0/2',
           'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none') + '; ' + ISNULL((SELECT TOP 1 Txt FROM @S), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min1, @DecisionTypeId = @DecisionOther,
        @Directions = '', @ActualResolution = '', @ShortText = 'ZZ23 item 1', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes with a chairman but nobody present', 'Result 0, Reason 18', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MN, @MemberOf = 'C', @MemberId = @M2, @Attendance = 'P', @UpdatedBy = @Sys;
    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @MN;
    INSERT INTO @T SELECT 'A member present: attendance entered', 'Result 1; 1,1,1,0/2',
           'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none') + '; ' + ISNULL((SELECT TOP 1 Txt FROM @S), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'All', @MinutesId = @Min1, @DecisionTypeId = @DecisionOther,
        @Directions = '', @ActualResolution = '', @ShortText = 'ZZ23 item 1', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes (All) after attendance', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateAgendaShortText @AgendaId = @Ag2, @ShortText = 'ZZ23 item 2 short', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Short text after attendance (does not count as updating the minute)', 'Result 1, Reason 0; 1/2',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; '
         + (SELECT CAST(MinutesUpdated AS VARCHAR(12)) + '/' + CAST(MinutesTotal AS VARCHAR(12)) FROM dbo.fn_WorkflowState(@MN));

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise Minutes with one of two minutes never updated', 'Result 0, Reason 19, 1/2', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @Min2, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ directions 2', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update the second minute (Directions)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Confirm before Finalise (unchanged procedure)', 'Result 0, Reason 3, Open', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise Minutes with everything in order', 'Result 1, Reason 0; F',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MN), 'NULL');

    ---------------------------------------------------------------------------
    -- After Finalise: the existing refusals come first
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise again: Reason 3 as before', 'Result 0, Reason 3, F', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MN, @CommitteeId = @C, @ChairmanNameId = @M2;
    INSERT INTO @T SELECT 'Chairman after Finalise: Reason 1 as before', 'Result 0, Reason 1', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MN, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Attendance after Finalise: refused as before', 'Result 0', 'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @Min2, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ late directions', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes at F: still allowed (step 16 rule)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MN, @UserId = @Sys;
    INSERT INTO @T SELECT 'Confirm after Finalise', 'Result 1, Reason 0; C',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; ' + ISNULL((SELECT MinutesStatus FROM Meeting WHERE MeetingId = @MN), 'NULL');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @Min2, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ after confirm', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update Minutes after Confirm: Reason 7 as before', 'Result 0, Reason 7', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    IF (OBJECT_ID('dbo.spr_GetMinutesReport', 'P') IS NOT NULL)
        INSERT INTO @T SELECT 'Step 22: the confirmed new meeting is in the minutes report', '2',
               CAST((SELECT COUNT(*) FROM View_Minute v JOIN Meeting m ON m.MeetingId = v.MeetingId
                     WHERE v.MeetingId = @MN AND ISNULL(m.MinutesStatus, 'Open') IN ('F', 'C')) AS VARCHAR(12));
    ELSE
        INSERT INTO @T VALUES ('Step 22: the confirmed new meeting is in the minutes report', '2', 'SKIPPED');

    ---------------------------------------------------------------------------
    -- New meeting without agenda items
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_AgendaFinalizeByMeetingId @MeetingId = @MZ;
    INSERT INTO @T SELECT 'No agenda items: Agenda Finalisation allowed by the procedure', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MZ, @CommitteeId = @C, @ChairmanNameId = @M1;
    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MZ, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'No agenda items: chairman and attendance allowed', 'Result 1, Reason 0; Result 1',
           ISNULL((SELECT TOP 1 Txt FROM @R), 'none') + '; Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MZ, @UserId = @Sys;
    INSERT INTO @T SELECT 'No agenda items: Finalise Minutes refused, no minutes', 'Result 0, Reason 19, 0/0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesConfirmByMeetingId @MeetingId = @MZ, @UserId = @Sys;
    INSERT INTO @T SELECT 'No agenda items: Confirm refused (not finalized)', 'Result 0, Reason 3, Open', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    ---------------------------------------------------------------------------
    -- An agenda item added after Agenda Finalisation (as the Controller option does: a new minute, StatusId 0)
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MB, @UserId = @Sys;
    INSERT INTO @T SELECT 'Bypass meeting before the late item: would finalize (checked, rolled back below)', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');
    UPDATE Meeting SET MinutesStatus = 'Open' WHERE MeetingId = @MB;

    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution,
                        AgendaStatusCode, ControllerApprovedStatus, SubjectNo, CreatedOn, CreatedBy)
    VALUES ('Z23-99233-002', @C, @MB, @Dept, @SubjectTypeId, 'ZZ23 late item', 'Entry', 'ZZ', 'ZZ', 'ACA', 'Approved', 2, @Now, @Sys);
    SET @AgLate = SCOPE_IDENTITY();
    INSERT INTO Minutes (AgendaId, DecisionTypeId, Directions, ActualResolution, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
    VALUES (@AgLate, @DecisionOther, ' ', 'ZZ', @Now, @Sys, @Now, @Sys);

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MB, @UserId = @Sys;
    INSERT INTO @T SELECT 'Late agenda item not yet updated: Finalise refused', 'Result 0, Reason 19, 1/2', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    ---------------------------------------------------------------------------
    -- Older meetings: as before
    ---------------------------------------------------------------------------
    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @MO;
    INSERT INTO @T SELECT 'Meeting without CreatedOn: counts as older', '0', ISNULL((SELECT TOP 1 CAST(IsNew AS VARCHAR(2)) FROM @S), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMeetingChairman @MeetingId = @MO, @CommitteeId = @C, @ChairmanNameId = @M1;
    INSERT INTO @T SELECT 'Older meeting, agenda open: chairman allowed as before', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R1; INSERT INTO @R1 EXEC spr_UpdateAttendance @CommitteeId = @C, @MeetingId = @MO, @MemberOf = 'C', @MemberId = @M1, @Attendance = 'P', @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Older meeting, agenda open: attendance allowed as before', 'Result 1', 'Result ' + ISNULL((SELECT TOP 1 CAST(Result AS VARCHAR(2)) FROM @R1), 'none');

    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @MO2;
    INSERT INTO @T SELECT 'Meeting created in 2000: counts as older', '0,1,0,0/1', ISNULL((SELECT TOP 1 Txt FROM @S), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = @MinO2, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ old', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Older meeting, no attendance: Update Minutes allowed as before', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    UPDATE Minutes SET StatusId = 0 WHERE MinutesId = @MinO2;
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @MO2, @UserId = @Sys;
    INSERT INTO @T SELECT 'Older meeting, no attendance, a minute never updated: Finalise allowed as before', 'Result 1, Reason 0', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    ---------------------------------------------------------------------------
    -- Unknown meeting or minute: Reason 4 first
    ---------------------------------------------------------------------------
    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_MinutesFinalizeByMeetingId @MeetingId = @Missing, @UserId = @Sys;
    INSERT INTO @T SELECT 'Finalise an unknown meeting', 'Result 0, Reason 4', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @R; INSERT INTO @R (Result, Reason, ReasonDetail) EXEC spr_UpdateMinutes @Code = 'Directions', @MinutesId = -1, @DecisionTypeId = @DecisionOther,
        @Directions = 'ZZ', @ActualResolution = '', @ShortText = '', @CreatedBy = @Sys, @UpdatedBy = @Sys;
    INSERT INTO @T SELECT 'Update an unknown minute', 'Result 0, Reason 4', ISNULL((SELECT TOP 1 Txt FROM @R), 'none');

    DELETE FROM @S; INSERT INTO @S (IsNew, AgendaFinalized, AttendanceRecorded, MinutesTotal, MinutesUpdated) EXEC spr_GetMeetingWorkflowState @MeetingId = @Missing;
    INSERT INTO @T SELECT 'Read procedure, unknown meeting: no row', '0', CAST((SELECT COUNT(*) FROM @S) AS VARCHAR(12));

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

-- Confirm nothing was kept: should be 0, 0 and 0
SELECT (SELECT COUNT(*) FROM Meeting WHERE Place = 'ZZ23 test') AS TestMeetingsLeft,
       (SELECT COUNT(*) FROM Department WHERE DepartmentCode = 'ZZ23') AS TestDepartmentsLeft,
       (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'Z23' AND CommitteeName = 'ZZ step 23 committee') AS TestCommitteesLeft;
GO

SET NOEXEC OFF;
GO
