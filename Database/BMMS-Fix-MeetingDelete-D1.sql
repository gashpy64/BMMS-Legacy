/* ============================================================================
   BMMS - Meeting delete: closed after the meeting date, alerts removed (step D1)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   The baseline spr_DeleteMeetingByMeetingId refused only when the meeting had
   Meeting_Member rows or Agenda rows. It had no date rule (only Meeting
   Master checked the date, step M1), no transaction, and it left the
   meeting's alerts behind, so the Dashboard kept an alert of a meeting that
   no longer exists.

   spr_DeleteMeetingByMeetingId, checked in this order under an update lock
   on the meeting row (UPDLOCK, HOLDLOCK), today = the database server date:
     Reason 4    the meeting does not exist
     Reason 20   the meeting date has passed (dates compared as dates, the
                 time is ignored; open for the whole of the meeting date; a
                 meeting with no date is open), as Meeting Master since M1
     Reason 21   the meeting has meeting members or agenda items (kept from
                 the baseline) or attendance (new; committee members' attendance
                 rows exist without Meeting_Member rows, and Attendance has a
                 foreign key to Meeting). ReasonDetail names them, for example
                 'Members, Agenda items'.
   When allowed, in one transaction (SET XACT_ABORT ON, TRY/CATCH): the
   Alert_User_Map rows of the meeting's alerts, then those Alert_Master rows
   (SourceType 'Meeting', SourceTypeId = the MeetingId: the "Meeting
   Created" (MC) and "Meeting Updated" (MU) alerts of spr_AddEditMeeting),
   then the meeting. An error rolls everything back and is raised again.

   Returns Result (1 deleted, 0 refused; the baseline column, so an older
   build still works), Reason and ReasonDetail.

   Objects
     spr_DeleteMeetingByMeetingId  REPLACED (the baseline text is in no
                                   numbered script; marker MeetingDelete-D1)

   Changes no data. Agenda alerts, committee alerts, Audit_Trail_Master and
   spr_UpdateAlertByMeetingId are not touched. Alerts of meetings deleted
   before this step (orphan Meeting alerts) are NOT removed; the script
   reports their count at the end. Safe to re-run.

   Written for compatibility level 100 (SQL Server 2008 syntax): no THROW,
   TRY_CONVERT, IIF, FORMAT, CONCAT or OFFSET.

   Run it BEFORE deploying the build of step D1 (either order is safe: the
   older build reads only Result; the D1 build on the old procedure logs
   the missing Reason and shows "The meeting could not be deleted").

   It has no USE line: select the database in SSMS first (BMMS_Test, then
   BMMS). It stops if the current database name does not start with "BMMS".

   If you install from the command line, use sqlcmd -I (quoted identifiers ON);
   installing from SSMS already does this.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME;
SET @CurrentDatabase = DB_NAME();

DECLARE @MissingColumns INT;
SET @MissingColumns = 0;
IF (COL_LENGTH('dbo.Meeting', 'MeetingId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Meeting', 'MeetingDate') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Meeting_Member', 'MeetingId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Agenda', 'MeetingId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Attendance', 'MeetingId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Alert_Master', 'AlertId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Alert_Master', 'SourceType') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Alert_Master', 'SourceTypeId') IS NULL) SET @MissingColumns = @MissingColumns + 1;
IF (COL_LENGTH('dbo.Alert_User_Map', 'AlertId') IS NULL) SET @MissingColumns = @MissingColumns + 1;

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.spr_DeleteMeetingByMeetingId') IS NULL)
BEGIN
    RAISERROR('spr_DeleteMeetingByMeetingId was not found in "%s". This is not a BMMS database. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (@MissingColumns > 0)
BEGIN
    RAISERROR('%d of the columns this step uses (Meeting, Meeting_Member, Agenda, Attendance, Alert_Master, Alert_User_Map) were not found in "%s". Nothing was changed.', 16, 1, @MissingColumns, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-- Meeting - delete (MeetingDelete-D1). Refused, in this order, under an update lock on the meeting row:
-- Reason 4 the meeting does not exist; Reason 20 the meeting date is before today (database server date,
-- compared as dates; no date = open); Reason 21 the meeting has meeting members or agenda items (baseline) or
-- attendance, ReasonDetail names them. When allowed, one transaction removes the Alert_User_Map rows and the
-- Alert_Master rows of the meeting's own alerts (SourceType 'Meeting', SourceTypeId = MeetingId: MC and MU of
-- spr_AddEditMeeting), then the meeting. Result 1 deleted, 0 refused (baseline column); Reason; ReasonDetail.
CREATE OR ALTER PROCEDURE [dbo].[spr_DeleteMeetingByMeetingId]
@MeetingId INT
AS
DECLARE @Result INT;
DECLARE @Reason INT;
DECLARE @Detail VARCHAR(200);
DECLARE @OwnTransaction INT;
DECLARE @Found INT;
DECLARE @MeetingDate DATETIME;
DECLARE @Today DATE;
DECLARE @ErrorMessage NVARCHAR(2048);
DECLARE @ErrorSeverity INT;
DECLARE @ErrorState INT;
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @Result = 0;
	SET @Reason = 0;
	SET @Detail = '';
	SET @Today = CAST(GETDATE() AS date);

	IF (@@TRANCOUNT = 0)
		SET @OwnTransaction = 1;
	ELSE
		SET @OwnTransaction = 0;

	BEGIN TRY
		IF (@OwnTransaction = 1)
			BEGIN TRANSACTION;
		ELSE
			SAVE TRANSACTION MeetingDelete;

		SELECT @Found = MeetingId, @MeetingDate = MeetingDate
		FROM Meeting WITH (UPDLOCK, HOLDLOCK)
		WHERE MeetingId = @MeetingId;

		IF (@Found IS NULL)
		BEGIN
			SET @Reason = 4;
		END
		ELSE IF (@MeetingDate IS NOT NULL AND CAST(@MeetingDate AS date) < @Today)
		BEGIN
			SET @Reason = 20;
		END
		ELSE
		BEGIN
			-- Baseline checks: meeting members, agenda items. MeetingDelete-D1: attendance as well
			IF EXISTS (SELECT 1 FROM Meeting_Member WHERE MeetingId = @MeetingId)
				SET @Detail = @Detail + 'Members';

			IF EXISTS (SELECT 1 FROM Agenda WHERE MeetingId = @MeetingId)
				SET @Detail = @Detail + CASE WHEN @Detail = '' THEN '' ELSE ', ' END + 'Agenda items';

			IF EXISTS (SELECT 1 FROM Attendance WHERE MeetingId = @MeetingId)
				SET @Detail = @Detail + CASE WHEN @Detail = '' THEN '' ELSE ', ' END + 'Attendance';

			IF (@Detail <> '')
			BEGIN
				SET @Reason = 21;
			END
			ELSE
			BEGIN
				-- The meeting's own alerts: map rows first (foreign key to Alert_Master), then the alerts
				DELETE m
				FROM Alert_User_Map m
				JOIN Alert_Master am ON am.AlertId = m.AlertId
				WHERE am.SourceType = 'Meeting' AND am.SourceTypeId = @MeetingId;

				DELETE FROM Alert_Master
				WHERE SourceType = 'Meeting' AND SourceTypeId = @MeetingId;

				DELETE FROM Meeting WHERE MeetingId = @MeetingId;

				SET @Result = 1;
			END
		END

		IF (@OwnTransaction = 1)
			COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		SET @ErrorMessage = ERROR_MESSAGE();
		SET @ErrorSeverity = ERROR_SEVERITY();
		SET @ErrorState = ERROR_STATE();

		IF (@OwnTransaction = 1)
		BEGIN
			IF (@@TRANCOUNT > 0)
				ROLLBACK TRANSACTION;
		END
		ELSE IF (XACT_STATE() = 1)
			ROLLBACK TRANSACTION MeetingDelete;

		-- No THROW at compatibility level 100: raise the message again (severity at most 16, no WITH LOG needed)
		IF (@ErrorSeverity IS NULL OR @ErrorSeverity > 16)
			SET @ErrorSeverity = 16;
		IF (@ErrorState IS NULL OR @ErrorState < 1)
			SET @ErrorState = 1;

		RAISERROR('spr_DeleteMeetingByMeetingId failed and was rolled back: %s', @ErrorSeverity, @ErrorState, @ErrorMessage);
		RETURN;
	END CATCH

	SELECT @Result AS Result, @Reason AS Reason, CAST(@Detail AS NVARCHAR(2000)) AS ReasonDetail;
END
GO

PRINT 'Step D1 installed: spr_DeleteMeetingByMeetingId refuses a meeting whose date has passed (Reason 20) or that is in use (Reason 21) and removes the meeting''s alerts with it (MeetingDelete-D1).';
GO

-- Report only: alerts of meetings deleted before this step. Not removed (to be decided separately).
DECLARE @OrphanAlerts INT;
DECLARE @OrphanMaps INT;
DECLARE @Line NVARCHAR(400);

SELECT @OrphanAlerts = COUNT(*)
FROM Alert_Master am
WHERE am.SourceType = 'Meeting'
  AND NOT EXISTS (SELECT 1 FROM Meeting mt WHERE mt.MeetingId = am.SourceTypeId);

SELECT @OrphanMaps = COUNT(*)
FROM Alert_User_Map m
JOIN Alert_Master am ON am.AlertId = m.AlertId
WHERE am.SourceType = 'Meeting'
  AND NOT EXISTS (SELECT 1 FROM Meeting mt WHERE mt.MeetingId = am.SourceTypeId);

SET @Line = N'Orphan Meeting alerts (meeting no longer exists, or no meeting id), not removed: '
          + CAST(@OrphanAlerts AS NVARCHAR(12)) + N' Alert_Master row(s) with '
          + CAST(@OrphanMaps AS NVARCHAR(12)) + N' Alert_User_Map row(s).';
PRINT @Line;

SELECT am.AlertId, am.SourceTypeId AS MissingMeetingId, am.AlertTypeCode, am.DisplayText, am.CommitteeId, am.CreatedOn,
       (SELECT COUNT(*) FROM Alert_User_Map m WHERE m.AlertId = am.AlertId) AS UserRows
FROM Alert_Master am
WHERE am.SourceType = 'Meeting'
  AND NOT EXISTS (SELECT 1 FROM Meeting mt WHERE mt.MeetingId = am.SourceTypeId)
ORDER BY am.AlertId;
GO

SET NOEXEC OFF;
GO
