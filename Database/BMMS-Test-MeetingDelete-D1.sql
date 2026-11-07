/* ============================================================================
   BMMS - Test of step D1 (meeting delete: closed after the meeting date, the
   meeting's alerts removed in the same transaction)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Runs ONLY on the database BMMS_Test: every part stops with a message on any
   other database. It has no USE line: select BMMS_Test in SSMS first.
   Needs BMMS-Fix-MeetingDelete-D1.sql installed (part 2 stops otherwise).
   Written for compatibility level 100. The file is plain ASCII.

   The file has four parts. Select the lines of ONE part and press F5.
     Procedure test:  part 1, part 2, part 3 (optional), part 4.
     Browser test:    part 1, the browser checks in the README, part 3, part 4.
   Part 2 deletes test meetings, so the browser test needs a fresh part 1
   (run part 4 first if part 2 was run).

   Test committee: code A94, name "ZZ D1 meeting delete" (3 characters: see
   the agenda numbering note N3). Parts 2, 3 and 4 take the committee only
   when the name also starts with "ZZ D1". Dates are the database server
   date; the page compares with the web server date (the same machine on
   BMMS_Test).

   PART 1  Inserts the committee and seven meetings (Agenda and Minutes
           status Open), numbered as Meeting Master numbers them:
             00901  ZZ D1 today        meeting today
             00902  ZZ D1 past         meeting yesterday
             00903  ZZ D1 no date      no meeting date (not written when
                                       MeetingDate is NOT NULL; reported)
             00904  ZZ D1 items        tomorrow, one agenda item
             00905  ZZ D1 rollback     tomorrow (the forced-failure check)
             00906  ZZ D1 attendance   today, one committee-member
                                       attendance row, no meeting member
             00907  ZZ D1 member       tomorrow, one meeting member
           Each meeting gets one "Meeting Created" alert (SourceType
           'Meeting', MC) mapped to every active user except the system
           account, as spr_AddEditMeeting writes it. Two control alerts that
           must survive every delete: an 'Agenda' alert whose SourceTypeId
           equals the id of 00901, and a 'Committee' alert of the test
           committee. Refuses when rows of an earlier run are still there, or
           when a committee A94 exists that is not a test row.
   PART 2  The checks, with PASS / FAIL / SKIPPED:
             1  00901 today: deleted (Result 1, Reason 0); its alert and map
                rows gone; the two control alerts still there
             2  00902 past: Result 0, Reason 20; meeting, alert and map rows
                unchanged
             3  00903 no date: deleted; its alert and map rows gone
             4  00904 items: Reason 21, ReasonDetail 'Agenda items'; nothing
                removed
             5  00906 attendance: Reason 21, ReasonDetail 'Attendance';
                nothing removed
             6  00907 member: Reason 21, ReasonDetail 'Members'; nothing
                removed
             7  an id that does not exist: Reason 4
             8  00905 rollback: a temporary trigger on Meeting (created and
                dropped here; it fails only for the venue "ZZ D1 rollback")
                makes the meeting delete fail after the alert deletes: the
                error comes back, no transaction is left open, the meeting,
                its alert and map rows are all still there
             9  the trigger is gone again
   PART 3  Read-only: the test meetings with their alert, member, agenda and
           attendance counts, and the test alerts.
   PART 4  Cleanup by the test code and name: the leftover trigger (if any),
           the alerts of the committee and of the test meetings, the
           attendance, meeting member and agenda rows of the test meetings,
           the meetings and the committee. Stops, changing nothing, when
           another meeting of the committee or an action item uses the test
           rows.
   ============================================================================ */


/* ============================================================================
   PART 1 - insert the test committee, meetings and alerts
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CodeTaken INT;
SET @CodeTaken = (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A94' AND CommitteeName NOT LIKE 'ZZ D1%');
IF (@CodeTaken > 0)
BEGIN
    RAISERROR('A committee with code A94 already exists and is not a test row. Change the test code in this file. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @Existing INT;
SET @Existing = (SELECT COUNT(*) FROM Committee WHERE CommitteeCode = 'A94' OR CommitteeName LIKE 'ZZ D1%');
IF (@Existing > 0)
BEGIN
    RAISERROR('%d test committee(s) from an earlier run are still there. Run part 4 first. Nothing was changed.', 16, 1, @Existing);
    RETURN;
END

DECLARE @Sys INT;
DECLARE @ColorCode VARCHAR(50);
DECLARE @Dept INT;
DECLARE @SubjectTypeId INT;
DECLARE @MemberId INT;
DECLARE @ActiveUsers INT;
SET @Sys = (SELECT TOP 1 UserId FROM Users WHERE IsSystem = 1 ORDER BY UserId);
SET @ColorCode = (SELECT TOP 1 CommitteeColorCode FROM Committee WHERE ISNULL(CommitteeColorCode, '') <> '' ORDER BY CommitteeId);
SET @Dept = (SELECT TOP 1 DepartmentId FROM Department ORDER BY DepartmentId);
SET @SubjectTypeId = (SELECT TOP 1 SubjectTypeId FROM Subject_Type ORDER BY SubjectTypeId);
SET @MemberId = (SELECT TOP 1 MemberId FROM Member ORDER BY MemberId);
SET @ActiveUsers = (SELECT COUNT(*) FROM Users WHERE AccountStatus = 1 AND IsSystem = 0);

IF (@Sys IS NULL OR @Dept IS NULL OR @SubjectTypeId IS NULL OR @MemberId IS NULL OR @ActiveUsers = 0)
BEGIN
    RAISERROR('BMMS_Test needs the system account, a department, a subject type, a member and an active user. One of them is missing. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @MeetingDateNullable INT;
DECLARE @SubmissionNullable INT;
SET @MeetingDateNullable = (SELECT CASE WHEN IS_NULLABLE = 'YES' THEN 1 ELSE 0 END FROM INFORMATION_SCHEMA.COLUMNS
                            WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Meeting' AND COLUMN_NAME = 'MeetingDate');
SET @SubmissionNullable = (SELECT CASE WHEN IS_NULLABLE = 'YES' THEN 1 ELSE 0 END FROM INFORMATION_SCHEMA.COLUMNS
                           WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Meeting' AND COLUMN_NAME = 'AgendaSubmissionDate');

DECLARE @Now DATETIME;
DECLARE @Today DATETIME;
DECLARE @Yesterday DATETIME;
DECLARE @TwoDaysAgo DATETIME;
DECLARE @Tomorrow DATETIME;
DECLARE @NoSubmission DATETIME;
SET @Now = GETDATE();
SET @Today = CAST(CAST(GETDATE() AS date) AS DATETIME);
SET @Yesterday = DATEADD(DAY, -1, @Today);
SET @TwoDaysAgo = DATEADD(DAY, -2, @Today);
SET @Tomorrow = DATEADD(DAY, 1, @Today);
SET @NoSubmission = CASE WHEN @SubmissionNullable = 1 THEN NULL ELSE @Today END;

DECLARE @CommitteeId INT;
DECLARE @MeetingRows INT;
DECLARE @AlertRows INT;
DECLARE @MapRows INT;
DECLARE @M01 INT;
DECLARE @M04 INT;
DECLARE @M06 INT;
DECLARE @M07 INT;
DECLARE @ErrorText NVARCHAR(2048);

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Committee (CommitteeCode, CommitteeName, Board, IncorporationDate, MeetingStartNo, CommitteeColorCode, StatusId, IsDelete, CreatedOn, CreatedBy)
    VALUES ('A94', 'ZZ D1 meeting delete', 0, '2000-01-01', 901, @ColorCode, 1, 0, @Now, @Sys);
    SET @CommitteeId = SCOPE_IDENTITY();

    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00901', @CommitteeId, 'ZZ D1', 'ZZ D1 today', @Today, '10:00', @Today, 'Open', 'Open');
    SET @M01 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00902', @CommitteeId, 'ZZ D1', 'ZZ D1 past', @Yesterday, '10:00', @TwoDaysAgo, 'Open', 'Open');
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00904', @CommitteeId, 'ZZ D1', 'ZZ D1 items', @Tomorrow, '10:00', @Today, 'Open', 'Open');
    SET @M04 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00905', @CommitteeId, 'ZZ D1', 'ZZ D1 rollback', @Tomorrow, '10:00', @Today, 'Open', 'Open');
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00906', @CommitteeId, 'ZZ D1', 'ZZ D1 attendance', @Today, '10:00', @Today, 'Open', 'Open');
    SET @M06 = SCOPE_IDENTITY();
    INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
    VALUES ('00907', @CommitteeId, 'ZZ D1', 'ZZ D1 member', @Tomorrow, '10:00', @Today, 'Open', 'Open');
    SET @M07 = SCOPE_IDENTITY();
    SET @MeetingRows = 6;

    IF (@MeetingDateNullable = 1)
    BEGIN
        INSERT INTO Meeting (MeetingNo, CommitteeId, Place, Venue, MeetingDate, MeetingTime, AgendaSubmissionDate, AgendaStatus, MinutesStatus)
        VALUES ('00903', @CommitteeId, 'ZZ D1', 'ZZ D1 no date', NULL, '10:00', @NoSubmission, 'Open', 'Open');
        SET @MeetingRows = @MeetingRows + 1;
    END

    -- 00904: one agenda item; 00906: committee-member attendance without a meeting member; 00907: one meeting member
    INSERT INTO Agenda (AgendaNo, CommitteeId, MeetingId, DepartmentId, SubjectTypeId, ShortText, AgendaType, AgendaText, ProposedResolution, AgendaStatusCode, CreatedOn, CreatedBy)
    VALUES ('A94-00904-001', @CommitteeId, @M04, @Dept, @SubjectTypeId, 'ZZ D1 item', 'Entry', 'ZZ', 'ZZ', 'AMA', @Now, @Sys);

    INSERT INTO Attendance (CommitteeId, MeetingId, MemberOf, MemberId, Attendance, SittingFees, UpdatedOn, UpdatedBy)
    VALUES (@CommitteeId, @M06, 'C', @MemberId, 'P', 0, @Now, @Sys);

    INSERT INTO Meeting_Member (MeetingId, MemberId, MemberTypeId, StatusId, CreatedOn, CreatedBy)
    VALUES (@M07, @MemberId, 3, 1, @Now, @Sys);

    -- One "Meeting Created" alert per meeting, as spr_AddEditMeeting writes it
    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    SELECT 'Meeting', 0, mt.MeetingId, 'Meeting (A94-' + mt.MeetingNo + ')', 'MC', 3, @CommitteeId, @Now, @Sys
    FROM Meeting mt
    WHERE mt.CommitteeId = @CommitteeId;
    SET @AlertRows = @@ROWCOUNT;

    -- Control alerts that no delete may remove: an Agenda alert carrying the id of 00901, and a Committee alert
    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Agenda', @Dept, @M01, 'ZZ D1 control - agenda alert with the id of 00901', 'AMA', 3, @CommitteeId, @Now, @Sys);
    INSERT INTO Alert_Master (SourceType, DepartmentId, SourceTypeId, DisplayText, AlertTypeCode, AlertSendOption, CommitteeId, CreatedOn, CreatedBy)
    VALUES ('Committee', 0, @CommitteeId, 'ZZ D1 control - committee alert', 'CC', 3, @CommitteeId, @Now, @Sys);
    SET @AlertRows = @AlertRows + 2;

    INSERT INTO Alert_User_Map (AlertId, UserId, ReadStatus, StatusId)
    SELECT am.AlertId, u.UserId, 0, 1
    FROM Alert_Master am
    CROSS JOIN Users u
    WHERE am.CommitteeId = @CommitteeId
      AND u.AccountStatus = 1 AND u.IsSystem = 0;
    SET @MapRows = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    SET @ErrorText = ERROR_MESSAGE();
    RAISERROR('Part 1 failed and was rolled back, nothing was changed: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'CommitteeId ' + CAST(@CommitteeId AS NVARCHAR(12)) + N' (A94, ZZ D1 meeting delete), ' + CAST(@MeetingRows AS NVARCHAR(12))
          + N' meeting(s), ' + CAST(@AlertRows AS NVARCHAR(12)) + N' alert(s), ' + CAST(@MapRows AS NVARCHAR(12)) + N' alert user row(s).';
PRINT @Line;
IF (@MeetingDateNullable = 0)
    PRINT N'Meeting.MeetingDate does not allow NULL: meeting 00903 (no meeting date) was not written; check 3 reads SKIPPED.';
PRINT N'Next: part 2 (procedure test) or the browser checks in the README (browser test).';
GO


/* ============================================================================
   PART 2 - the checks (deletes test meetings; creates and drops a test trigger)
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_DeleteMeetingByMeetingId')), '') NOT LIKE '%MeetingDelete-D1%')
BEGIN
    RAISERROR('Step D1 (BMMS-Fix-MeetingDelete-D1.sql) is not installed in BMMS_Test. Run it first. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @CommitteeId INT;
SET @CommitteeId = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A94' AND CommitteeName LIKE 'ZZ D1%' ORDER BY CommitteeId);
IF (@CommitteeId IS NULL)
BEGIN
    RAISERROR('The test committee A94 was not found. Run part 1 first. Nothing was changed.', 16, 1);
    RETURN;
END

DECLARE @M01 INT, @M02 INT, @M03 INT, @M04 INT, @M05 INT, @M06 INT, @M07 INT;
SELECT @M01 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00901';
SELECT @M02 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00902';
SELECT @M03 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00903';
SELECT @M04 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00904';
SELECT @M05 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00905';
SELECT @M06 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00906';
SELECT @M07 = MeetingId FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingNo = '00907';

IF (@M01 IS NULL OR @M02 IS NULL OR @M04 IS NULL OR @M05 IS NULL OR @M06 IS NULL OR @M07 IS NULL)
BEGIN
    RAISERROR('A test meeting is missing (part 2 or the browser test was already run). Run part 4, then part 1, then part 2. Nothing was changed.', 16, 1);
    RETURN;
END

-- A trigger left by an interrupted run is dropped first
IF (OBJECT_ID('dbo.trg_ZZ_D1_MeetingDeleteFails', 'TR') IS NOT NULL)
    EXEC (N'DROP TRIGGER dbo.trg_ZZ_D1_MeetingDeleteFails;');

DECLARE @T TABLE (Seq INT IDENTITY(1,1), CheckNo INT, CheckName NVARCHAR(200), Outcome VARCHAR(10), Detail NVARCHAR(400));
DECLARE @R TABLE (Result INT, Reason INT, ReasonDetail NVARCHAR(2000));
DECLARE @Res INT, @Rsn INT, @Det NVARCHAR(2000);
DECLARE @A0 INT, @U0 INT, @A1 INT, @U1 INT, @Exists INT;
DECLARE @CtlAgenda INT, @CtlCommittee INT;
DECLARE @Ok INT;
DECLARE @Msg NVARCHAR(2048);
DECLARE @OpenTran INT;
DECLARE @Unknown INT;

-- ---- Check 1: 00901 today is deleted with its alert; the control alerts stay --------------------------
SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M01;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M01;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M01;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M01;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M01;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M01;
SELECT @CtlAgenda = COUNT(*) FROM Alert_Master am JOIN Alert_User_Map m ON m.AlertId = am.AlertId
    WHERE am.SourceType = 'Agenda' AND am.SourceTypeId = @M01 AND am.CommitteeId = @CommitteeId;
SELECT @CtlCommittee = COUNT(*) FROM Alert_Master am JOIN Alert_User_Map m ON m.AlertId = am.AlertId
    WHERE am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId;
SET @Ok = CASE WHEN @Res = 1 AND @Rsn = 0 AND @Exists = 0 AND @A0 = 1 AND @U0 > 0 AND @A1 = 0 AND @U1 = 0
                    AND @CtlAgenda > 0 AND @CtlCommittee > 0 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (1, N'00901 today: deleted, its alert and map rows removed, control alerts kept', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
        + N'; meeting rows ' + CAST(@Exists AS NVARCHAR(12)) + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12))
        + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12))
        + N'; control agenda map rows ' + CAST(@CtlAgenda AS NVARCHAR(12)) + N', control committee map rows ' + CAST(@CtlCommittee AS NVARCHAR(12)));

-- ---- Check 2: 00902 past is refused with Reason 20 and nothing changes --------------------------------
SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M02;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M02;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M02;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M02;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M02;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M02;
SET @Ok = CASE WHEN @Res = 0 AND @Rsn = 20 AND @Exists = 1 AND @A0 = 1 AND @A1 = 1 AND @U0 > 0 AND @U1 = @U0 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (2, N'00902 past: refused with Reason 20, nothing removed', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
        + N'; meeting rows ' + CAST(@Exists AS NVARCHAR(12)) + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12))
        + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));

-- ---- Check 3: 00903 with no meeting date is deleted with its alert ------------------------------------
IF (@M03 IS NULL)
BEGIN
    INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
    VALUES (3, N'00903 no date: deleted, its alert and map rows removed', 'SKIPPED', N'Meeting.MeetingDate does not allow NULL; part 1 did not write 00903.');
END
ELSE
BEGIN
    SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M03;
    SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M03;
    SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
    DELETE FROM @R;
    INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M03;
    SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
    SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M03;
    SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M03;
    SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M03;
    SET @Ok = CASE WHEN @Res = 1 AND @Rsn = 0 AND @Exists = 0 AND @A0 = 1 AND @A1 = 0 AND @U1 = 0 THEN 1 ELSE 0 END;
    INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
    VALUES (3, N'00903 no date: deleted, its alert and map rows removed', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
            N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
            + N'; meeting rows ' + CAST(@Exists AS NVARCHAR(12)) + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12))
            + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));
END

-- ---- Check 4: 00904 with an agenda item is refused with Reason 21 'Agenda items' ----------------------
SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M04;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M04;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M04;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M04;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M04;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M04;
SET @Ok = CASE WHEN @Res = 0 AND @Rsn = 21 AND @Det = N'Agenda items' AND @Exists = 1 AND @A1 = @A0 AND @U1 = @U0 AND @A0 = 1 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (4, N'00904 agenda item: refused with Reason 21 ''Agenda items'', nothing removed', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
        + N', detail ''' + ISNULL(@Det, N'') + N'''; meeting rows ' + CAST(@Exists AS NVARCHAR(12))
        + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12)) + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));

-- ---- Check 5: 00906 with attendance (no meeting member) is refused with Reason 21 'Attendance' --------
SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M06;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M06;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M06;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M06;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M06;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M06;
SET @Ok = CASE WHEN @Res = 0 AND @Rsn = 21 AND @Det = N'Attendance' AND @Exists = 1 AND @A1 = @A0 AND @U1 = @U0 AND @A0 = 1 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (5, N'00906 attendance, no meeting member: refused with Reason 21 ''Attendance'', nothing removed', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
        + N', detail ''' + ISNULL(@Det, N'') + N'''; meeting rows ' + CAST(@Exists AS NVARCHAR(12))
        + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12)) + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));

-- ---- Check 6: 00907 with a meeting member is refused with Reason 21 'Members' --------------------------
SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M07;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M07;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M07;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M07;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M07;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M07;
SET @Ok = CASE WHEN @Res = 0 AND @Rsn = 21 AND @Det = N'Members' AND @Exists = 1 AND @A1 = @A0 AND @U1 = @U0 AND @A0 = 1 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (6, N'00907 meeting member: refused with Reason 21 ''Members'', nothing removed', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none') + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none')
        + N', detail ''' + ISNULL(@Det, N'') + N'''; meeting rows ' + CAST(@Exists AS NVARCHAR(12))
        + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12)) + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));

-- ---- Check 7: an id that does not exist gives Reason 4 ------------------------------------------------
SELECT @Unknown = ISNULL(MAX(MeetingId), 0) + 100000 FROM Meeting;
SET @Res = NULL; SET @Rsn = NULL; SET @Det = NULL;
DELETE FROM @R;
INSERT INTO @R (Result, Reason, ReasonDetail) EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @Unknown;
SELECT TOP 1 @Res = Result, @Rsn = Reason, @Det = ReasonDetail FROM @R;
SET @Ok = CASE WHEN @Res = 0 AND @Rsn = 4 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (7, N'Unknown meeting id: Reason 4', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'MeetingId ' + CAST(@Unknown AS NVARCHAR(12)) + N': Result ' + ISNULL(CAST(@Res AS NVARCHAR(12)), N'none')
        + N', Reason ' + ISNULL(CAST(@Rsn AS NVARCHAR(12)), N'none'));

-- ---- Check 8: a failure after the alert deletes rolls everything back ---------------------------------
-- The temporary trigger fails only for the venue "ZZ D1 rollback" (meeting 00905).
EXEC (N'CREATE TRIGGER dbo.trg_ZZ_D1_MeetingDeleteFails ON dbo.Meeting AFTER DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE Venue = ''ZZ D1 rollback'')
        RAISERROR(''ZZ D1 forced failure'', 16, 1);
END');

SELECT @A0 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M05;
SELECT @U0 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M05;
SET @Msg = NULL;
BEGIN TRY
    -- Called directly (not INSERT ... EXEC), so the procedure runs its own transaction
    EXEC dbo.spr_DeleteMeetingByMeetingId @MeetingId = @M05;
END TRY
BEGIN CATCH
    SET @Msg = ERROR_MESSAGE();
END CATCH
SET @OpenTran = @@TRANCOUNT;
IF (@OpenTran > 0)
    ROLLBACK TRANSACTION;
SELECT @Exists = COUNT(*) FROM Meeting WHERE MeetingId = @M05;
SELECT @A1 = COUNT(*) FROM Alert_Master WHERE SourceType = 'Meeting' AND SourceTypeId = @M05;
SELECT @U1 = COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @M05;
SET @Ok = CASE WHEN @Msg LIKE N'%ZZ D1 forced failure%' AND @OpenTran = 0 AND @Exists = 1 AND @A0 = 1 AND @A1 = 1 AND @U0 > 0 AND @U1 = @U0 THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (8, N'00905 forced failure: error returned, nothing half-done', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        N'Error ''' + ISNULL(@Msg, N'none') + N'''; open transactions ' + CAST(@OpenTran AS NVARCHAR(12))
        + N'; meeting rows ' + CAST(@Exists AS NVARCHAR(12)) + N'; alerts ' + CAST(@A0 AS NVARCHAR(12)) + N'->' + CAST(@A1 AS NVARCHAR(12))
        + N', map rows ' + CAST(@U0 AS NVARCHAR(12)) + N'->' + CAST(@U1 AS NVARCHAR(12)));

IF (OBJECT_ID('dbo.trg_ZZ_D1_MeetingDeleteFails', 'TR') IS NOT NULL)
    EXEC (N'DROP TRIGGER dbo.trg_ZZ_D1_MeetingDeleteFails;');

-- ---- Check 9: the test trigger is gone ----------------------------------------------------------------
SET @Ok = CASE WHEN OBJECT_ID('dbo.trg_ZZ_D1_MeetingDeleteFails', 'TR') IS NULL THEN 1 ELSE 0 END;
INSERT INTO @T (CheckNo, CheckName, Outcome, Detail)
VALUES (9, N'Test trigger dropped', CASE WHEN @Ok = 1 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN @Ok = 1 THEN N'dbo.trg_ZZ_D1_MeetingDeleteFails does not exist' ELSE N'dbo.trg_ZZ_D1_MeetingDeleteFails still exists: run part 4' END);

SELECT CheckNo, CheckName, Outcome, Detail FROM @T ORDER BY Seq;

DECLARE @Pass INT, @Fail INT, @Skipped INT, @Line NVARCHAR(400);
SELECT @Pass = COUNT(*) FROM @T WHERE Outcome = 'PASS';
SELECT @Fail = COUNT(*) FROM @T WHERE Outcome = 'FAIL';
SELECT @Skipped = COUNT(*) FROM @T WHERE Outcome = 'SKIPPED';
SET @Line = N'Step D1 test: ' + CAST(@Pass AS NVARCHAR(12)) + N' PASS, ' + CAST(@Fail AS NVARCHAR(12)) + N' FAIL, '
          + CAST(@Skipped AS NVARCHAR(12)) + N' SKIPPED (9 checks). Run part 4 to clean up.';
PRINT @Line;
GO


/* ============================================================================
   PART 3 - read-only: the test meetings and the test alerts
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @CommitteeId INT;
SET @CommitteeId = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A94' AND CommitteeName LIKE 'ZZ D1%' ORDER BY CommitteeId);

SELECT mt.MeetingId, mt.MeetingNo, mt.Venue, mt.MeetingDate,
       (SELECT COUNT(*) FROM Alert_Master am WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = mt.MeetingId) AS MeetingAlerts,
       (SELECT COUNT(*) FROM Alert_User_Map m JOIN Alert_Master am ON am.AlertId = m.AlertId
         WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = mt.MeetingId) AS AlertUserRows,
       (SELECT COUNT(*) FROM Meeting_Member mm WHERE mm.MeetingId = mt.MeetingId) AS MeetingMembers,
       (SELECT COUNT(*) FROM Agenda a WHERE a.MeetingId = mt.MeetingId) AS AgendaItems,
       (SELECT COUNT(*) FROM Attendance att WHERE att.MeetingId = mt.MeetingId) AS AttendanceRows
FROM Meeting mt
WHERE mt.CommitteeId = @CommitteeId
ORDER BY mt.MeetingNo;

SELECT am.AlertId, am.SourceType, am.SourceTypeId, am.AlertTypeCode, am.DisplayText,
       CASE WHEN am.SourceType = 'Meeting' AND NOT EXISTS (SELECT 1 FROM Meeting mt WHERE mt.MeetingId = am.SourceTypeId)
            THEN 'meeting gone' ELSE '' END AS Note,
       (SELECT COUNT(*) FROM Alert_User_Map m WHERE m.AlertId = am.AlertId) AS UserRows
FROM Alert_Master am
WHERE am.CommitteeId = @CommitteeId
ORDER BY am.AlertId;

SELECT CASE WHEN OBJECT_ID('dbo.trg_ZZ_D1_MeetingDeleteFails', 'TR') IS NULL THEN 'no test trigger' ELSE 'TEST TRIGGER STILL EXISTS: run part 4' END AS TestTrigger;
GO


/* ============================================================================
   PART 4 - cleanup by the test code and name
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase <> N'BMMS_Test')
BEGIN
    RAISERROR('Current database is "%s". This test runs only on BMMS_Test. Select BMMS_Test and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    RETURN;
END

DECLARE @TriggerDropped INT;
SET @TriggerDropped = 0;
IF (OBJECT_ID('dbo.trg_ZZ_D1_MeetingDeleteFails', 'TR') IS NOT NULL)
BEGIN
    EXEC (N'DROP TRIGGER dbo.trg_ZZ_D1_MeetingDeleteFails;');
    SET @TriggerDropped = 1;
    PRINT N'The test trigger dbo.trg_ZZ_D1_MeetingDeleteFails was dropped.';
END

DECLARE @CommitteeId INT;
SET @CommitteeId = (SELECT TOP 1 CommitteeId FROM Committee WHERE CommitteeCode = 'A94' AND CommitteeName LIKE 'ZZ D1%' ORDER BY CommitteeId);
IF (@CommitteeId IS NULL)
BEGIN
    PRINT N'The test committee A94 was not found: nothing to delete.';
    RETURN;
END

DECLARE @Meetings TABLE (MeetingId INT PRIMARY KEY);
INSERT INTO @Meetings (MeetingId)
SELECT MeetingId FROM Meeting
WHERE CommitteeId = @CommitteeId AND MeetingNo IN ('00901', '00902', '00903', '00904', '00905', '00906', '00907');

DECLARE @Agendas TABLE (AgendaId INT PRIMARY KEY);
INSERT INTO @Agendas (AgendaId)
SELECT AgendaId FROM Agenda WHERE MeetingId IN (SELECT MeetingId FROM @Meetings) OR CommitteeId = @CommitteeId;

-- Anything else that uses the test rows stops the cleanup
DECLARE @OtherMeetings INT, @OtherAgendas INT, @MinutesRows INT, @ActionItems INT;
SELECT @OtherMeetings = COUNT(*) FROM Meeting WHERE CommitteeId = @CommitteeId AND MeetingId NOT IN (SELECT MeetingId FROM @Meetings);
SELECT @OtherAgendas = COUNT(*) FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas)
                                              AND (CommitteeId <> @CommitteeId OR MeetingId NOT IN (SELECT MeetingId FROM @Meetings));
SELECT @MinutesRows = COUNT(*) FROM Minutes WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);
SELECT @ActionItems = COUNT(*) FROM Action_Item ai JOIN Minutes mi ON mi.MinutesId = ai.MinutesId
                      WHERE mi.AgendaId IN (SELECT AgendaId FROM @Agendas);

IF (@OtherMeetings + @OtherAgendas + @MinutesRows + @ActionItems > 0)
BEGIN
    RAISERROR('Other rows use the test rows; this cleanup does not delete them. Other meetings of the committee %d, agenda items of another meeting %d, minutes %d, action items %d. Remove them on screen first. Nothing else was changed.', 16, 1,
              @OtherMeetings, @OtherAgendas, @MinutesRows, @ActionItems);
    RETURN;
END

DECLARE @MapRows INT, @AlertRows INT, @AttendanceRows INT, @MemberRows INT, @AgendaRows INT, @MeetingRows INT, @CommitteeRows INT;
DECLARE @ErrorText NVARCHAR(2048);

BEGIN TRY
    BEGIN TRANSACTION;

    -- The test alerts (all carry the committee id) and any alert of the test meetings
    DELETE m
    FROM Alert_User_Map m
    JOIN Alert_Master am ON am.AlertId = m.AlertId
    WHERE am.CommitteeId = @CommitteeId
       OR (am.SourceType = 'Meeting' AND am.SourceTypeId IN (SELECT MeetingId FROM @Meetings))
       OR (am.SourceType = 'Agenda' AND am.SourceTypeId IN (SELECT AgendaId FROM @Agendas))
       OR (am.SourceType = 'Committee' AND am.SourceTypeId = @CommitteeId);
    SET @MapRows = @@ROWCOUNT;

    DELETE FROM Alert_Master
    WHERE CommitteeId = @CommitteeId
       OR (SourceType = 'Meeting' AND SourceTypeId IN (SELECT MeetingId FROM @Meetings))
       OR (SourceType = 'Agenda' AND SourceTypeId IN (SELECT AgendaId FROM @Agendas))
       OR (SourceType = 'Committee' AND SourceTypeId = @CommitteeId);
    SET @AlertRows = @@ROWCOUNT;

    DELETE FROM Attendance WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @AttendanceRows = @@ROWCOUNT;

    DELETE FROM Meeting_Member WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @MemberRows = @@ROWCOUNT;

    DELETE FROM Agenda WHERE AgendaId IN (SELECT AgendaId FROM @Agendas);
    SET @AgendaRows = @@ROWCOUNT;

    DELETE FROM Meeting WHERE MeetingId IN (SELECT MeetingId FROM @Meetings);
    SET @MeetingRows = @@ROWCOUNT;

    DELETE FROM Committee WHERE CommitteeId = @CommitteeId;
    SET @CommitteeRows = @@ROWCOUNT;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;
    SET @ErrorText = ERROR_MESSAGE();
    RAISERROR('Part 4 failed and was rolled back, nothing was deleted: %s', 16, 1, @ErrorText);
    RETURN;
END CATCH

DECLARE @Line NVARCHAR(400);
SET @Line = N'Deleted ' + CAST(@MapRows AS NVARCHAR(12)) + N' Alert_User_Map, ' + CAST(@AlertRows AS NVARCHAR(12)) + N' Alert_Master, '
          + CAST(@AttendanceRows AS NVARCHAR(12)) + N' Attendance, ' + CAST(@MemberRows AS NVARCHAR(12)) + N' Meeting_Member, '
          + CAST(@AgendaRows AS NVARCHAR(12)) + N' Agenda, ' + CAST(@MeetingRows AS NVARCHAR(12)) + N' Meeting and '
          + CAST(@CommitteeRows AS NVARCHAR(12)) + N' Committee row(s).';
PRINT @Line;
PRINT N'Expected after part 2: 5 Meeting (00902, 00904, 00905, 00906, 00907), 1 Attendance, 1 Meeting_Member, 1 Agenda, 1 Committee; after part 1 alone: 7 Meeting (6 when 00903 was skipped).';
GO
