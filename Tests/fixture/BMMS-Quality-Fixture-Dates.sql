/* ============================================================================
   BMMS tester - fixture dates for BMMS_Quality (step WF3a1)
   ----------------------------------------------------------------------------
   Run by the tester after every restore of the baseline. A baseline ages: the
   meeting that was "30 days ahead" when the baseline was taken would one day
   lie in the past. This script sets the dates of the six fixture meetings of
   committee QA1 again, relative to today (the database server date):

     00001 agenda open             meeting today + 30, submission today + 20
     00002 submission date passed  meeting today + 10, submission today - 2
     00003 agenda finalised        meeting today + 5,  submission today - 5
     00004 minutes in Draft        meeting today - 10, submission today - 20
     00005 minutes Finalised       meeting today - 20, submission today - 30
     00006 minutes Confirmed       meeting today - 30, submission today - 40

   and of the thirteen meetings of committee QA2 (step UN6b; 00013 step UN6c2a):

     00001 dated today             meeting today,      submission today
     00002 to 00010                meeting today - 1 to today - 9,
                                   submission five days before the meeting
     00011, 00012                  meeting today - 11, today - 12, likewise
     00013 agenda still open       meeting today - 40, submission today - 45

   It updates the two date columns of those nineteen Meeting rows directly
   (spr_AddEditMeeting refuses a date before today).

   Step UN6c1 (the Alerts card lists read alerts of the last seven days only,
   and a baseline ages): it also sets, relative to today,
     - CreatedOn of every alert, and CreatedOn, UpdatedOn, MgrApprovedDate and
       ControllerApprovedDate (where set) of every item of QA1: today;
     - the decision and update date of item QA1-00004-001: today - 12, and of
       QA1-00004-002: today - 2 (qa_user has read both alerts: the first is
       not "recent", the second is);
     - CreatedOn of the alert "Committee (QA2)": today - 10 (read by qa_user,
       unread for everybody else);
     - the due dates of the three Followups: QA1-00005-001 today - 3
       (overdue), QA1-00005-002 today + 5, QA1-00006-001 none.

   Step UN6c2a: CreatedOn of the alert "Agenda (QA2-00013-1)" and CreatedOn and
   UpdatedOn of its item: today - 40 (the Alerts card dates an entry alert by
   its item; read by qa_manager, so it is on the last page of All only).

   It runs on BMMS_Quality only and stops unless all nineteen meetings, the
   three items, the two alerts and the three Followups are there.
   Compatibility level 100. Plain ASCII. Safe to run again.
   ============================================================================ */
SET NOCOUNT ON;
GO
DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();
IF (@CurrentDatabase COLLATE Latin1_General_BIN <> N'BMMS_Quality')
BEGIN
    RAISERROR('Current database is "%s". This script runs on BMMS_Quality only. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF ((SELECT COUNT(*) FROM Meeting m JOIN Committee c ON c.CommitteeId = m.CommitteeId
          WHERE c.CommitteeCode = 'QA1' AND m.MeetingNo IN ('00001', '00002', '00003', '00004', '00005', '00006')) <> 6)
BEGIN
    RAISERROR('The six fixture meetings of committee QA1 were not found. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
ELSE IF ((SELECT COUNT(*) FROM Meeting m JOIN Committee c ON c.CommitteeId = m.CommitteeId
          WHERE c.CommitteeCode = 'QA2' AND m.MeetingNo IN ('00001', '00002', '00003', '00004', '00005', '00006',
                                                             '00007', '00008', '00009', '00010', '00011', '00012',
                                                             '00013')) <> 13)
BEGIN
    RAISERROR('The thirteen fixture meetings of committee QA2 were not found. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END
GO
DECLARE @Today DATETIME;
SET @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0);

UPDATE m SET
    MeetingDate = DATEADD(DAY, CASE m.MeetingNo WHEN '00001' THEN 30 WHEN '00002' THEN 10 WHEN '00003' THEN 5
                                                WHEN '00004' THEN -10 WHEN '00005' THEN -20 ELSE -30 END, @Today),
    AgendaSubmissionDate = DATEADD(DAY, CASE m.MeetingNo WHEN '00001' THEN 20 WHEN '00002' THEN -2 WHEN '00003' THEN -5
                                                         WHEN '00004' THEN -20 WHEN '00005' THEN -30 ELSE -40 END, @Today)
FROM Meeting m
JOIN Committee c ON c.CommitteeId = m.CommitteeId
WHERE c.CommitteeCode = 'QA1' AND m.MeetingNo IN ('00001', '00002', '00003', '00004', '00005', '00006');

DECLARE @SetQa1 INT;
SET @SetQa1 = @@ROWCOUNT;

-- QA2 (step UN6b): 00001 today; 00002 to 00012 one day apart going back, skipping day -10 (QA1 00004); 00013 (step
-- UN6c2a) 40 days back, older than every other fixture meeting
UPDATE m SET
    MeetingDate = DATEADD(DAY, x.DayOffset, @Today),
    AgendaSubmissionDate = DATEADD(DAY, x.SubOffset, @Today)
FROM Meeting m
JOIN Committee c ON c.CommitteeId = m.CommitteeId
JOIN (SELECT '00001' AS MeetingNo, 0 AS DayOffset, 0 AS SubOffset
      UNION ALL SELECT '00002', -1, -6 UNION ALL SELECT '00003', -2, -7 UNION ALL SELECT '00004', -3, -8
      UNION ALL SELECT '00005', -4, -9 UNION ALL SELECT '00006', -5, -10 UNION ALL SELECT '00007', -6, -11
      UNION ALL SELECT '00008', -7, -12 UNION ALL SELECT '00009', -8, -13 UNION ALL SELECT '00010', -9, -14
      UNION ALL SELECT '00011', -11, -16 UNION ALL SELECT '00012', -12, -17
      UNION ALL SELECT '00013', -40, -45) x ON x.MeetingNo = m.MeetingNo
WHERE c.CommitteeCode = 'QA2';

DECLARE @SetQa2 INT;
SET @SetQa2 = @@ROWCOUNT;

-- Step UN6c1: the alert dates (see the header)
DECLARE @Set INT;
SET @Set = 0;

UPDATE Alert_Master SET CreatedOn = @Today;

UPDATE a SET
    CreatedOn = @Today,
    UpdatedOn = CASE WHEN a.UpdatedOn IS NULL THEN NULL ELSE @Today END,
    MgrApprovedDate = CASE WHEN a.MgrApprovedDate IS NULL THEN NULL ELSE @Today END,
    ControllerApprovedDate = CASE WHEN a.ControllerApprovedDate IS NULL THEN NULL ELSE @Today END
FROM Agenda a
JOIN Committee c ON c.CommitteeId = a.CommitteeId
WHERE c.CommitteeCode = 'QA1';

UPDATE a SET
    UpdatedOn = DATEADD(DAY, CASE a.AgendaNo WHEN 'QA1-00004-001' THEN -12 ELSE -2 END, @Today),
    ControllerApprovedDate = DATEADD(DAY, CASE a.AgendaNo WHEN 'QA1-00004-001' THEN -12 ELSE -2 END, @Today)
FROM Agenda a
JOIN Committee c ON c.CommitteeId = a.CommitteeId
WHERE c.CommitteeCode = 'QA1' AND a.AgendaNo IN ('QA1-00004-001', 'QA1-00004-002') AND a.ControllerApprovedBy IS NOT NULL;
SET @Set = @Set + @@ROWCOUNT;

UPDATE Alert_Master SET CreatedOn = DATEADD(DAY, -10, @Today)
WHERE SourceType = 'Committee' AND DisplayText = 'Committee (QA2)';
SET @Set = @Set + @@ROWCOUNT;

-- Step UN6c2a: the read alert of the item of the passed meeting
UPDATE Alert_Master SET CreatedOn = DATEADD(DAY, -40, @Today)
WHERE SourceType = 'Agenda' AND DisplayText = 'Agenda (QA2-00013-1)';
SET @Set = @Set + @@ROWCOUNT;
UPDATE Agenda SET CreatedOn = DATEADD(DAY, -40, @Today), UpdatedOn = DATEADD(DAY, -40, @Today)
WHERE AgendaNo = 'QA2-00013-1';
SET @Set = @Set + @@ROWCOUNT;

UPDATE mi SET
    DueDate = CASE a.AgendaNo WHEN 'QA1-00005-001' THEN DATEADD(DAY, -3, @Today)
                              WHEN 'QA1-00005-002' THEN DATEADD(DAY, 5, @Today) ELSE NULL END
FROM Minutes mi
JOIN Agenda a ON a.AgendaId = mi.AgendaId
JOIN Committee c ON c.CommitteeId = a.CommitteeId
JOIN Action_Item ai ON ai.MinutesId = mi.MinutesId
WHERE c.CommitteeCode = 'QA1' AND a.AgendaNo IN ('QA1-00005-001', 'QA1-00005-002', 'QA1-00006-001');
SET @Set = @Set + @@ROWCOUNT;

IF (@SetQa1 <> 6 OR @SetQa2 <> 13)
    RAISERROR('The dates of the nineteen fixture meetings were not all set.', 16, 1);
ELSE IF (@Set <> 8)
    RAISERROR('The alert and due dates of steps UN6c1 and UN6c2a were not all set (three items, two alerts, three Followups).', 16, 1);
ELSE
    PRINT 'FIXTURE DATES: DONE';
GO
SET NOEXEC OFF;
GO
