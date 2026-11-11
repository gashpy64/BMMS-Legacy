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

   It updates the two date columns of those six Meeting rows directly and
   nothing else (spr_AddEditMeeting refuses a date before today). It runs on
   BMMS_Quality only and stops unless all six meetings are there.
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

IF (@@ROWCOUNT <> 6)
    RAISERROR('The dates of the six fixture meetings were not all set.', 16, 1);
ELSE
    PRINT 'FIXTURE DATES: DONE';
GO
SET NOEXEC OFF;
GO
