/* ============================================================================
   BMMS - Rollback of step 33 (BMMS-Fix-ManagerDepartment-Step33.sql)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Restores the baseline texts of the two procedures, as read from BMMS_Test
   before step 33:
     spr_GetAgendaByMeetingIdDeptId  only the items the user entered
                                     (CreatedBy = @UserId), for every role
     spr_GetAgendaByMeetingId        every item of the meeting
   Neither returns EnteredByName afterwards. The build of step C2 still runs
   on the baseline procedures: the "Entered by" column is empty and the
   Manager's list holds only the Manager's own items again. Its page check
   (Edit and Update of a department item, Delete for the Controller only)
   stays as the build has it.

   Changes no data. Safe to re-run, also where step 33 was never installed.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII.
   ============================================================================ */

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaByMeetingIdDeptId]
@MeetingId INT,
@UserId INT
AS
BEGIN
	SELECT
	*
	FROM View_Agenda
	WHERE MeetingId = @MeetingId
	AND
	CreatedBy = @UserId
	ORDER BY AgendaStatusCode, SubjectNo;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[spr_GetAgendaByMeetingId]
@MeetingId INT
AS
BEGIN
	SELECT
	*
	FROM View_Agenda
	WHERE MeetingId = @MeetingId
	ORDER BY AgendaStatusCode, SubjectNo;
END
GO

DECLARE @Left INT = 0;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingIdDeptId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Left = @Left + 1;
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetAgendaByMeetingId')), '') LIKE '%ManagerDepartment-Step33%')
    SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 33 rolled back: spr_GetAgendaByMeetingIdDeptId and spr_GetAgendaByMeetingId have their baseline texts.';
ELSE
    RAISERROR('Rollback of step 33 is not complete: %d of 2 procedures still carry the marker ManagerDepartment-Step33. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
