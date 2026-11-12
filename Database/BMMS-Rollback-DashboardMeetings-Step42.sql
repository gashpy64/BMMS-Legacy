/* ============================================================================
   BMMS - Roll back step 42 (Dashboard meeting list, step UN6b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the five objects of step 42:
     spr_GetDashboardMeetings
     spr_GetDashboardDepartments
     fn_MeetingDashboardState
     fn_UserDepartmentScope
     fn_AgendaStatusGroup
   Nothing else: step 42 replaced no object, so nothing is restored.
   spr_GetScheduleMeet (the list before step UN6b) was never changed.

   Roll back the application build of step UN6b first or at the same time:
   that build calls these procedures for the Dashboard's Meetings card;
   without them the card shows "The meeting list could not be loaded." (the
   alerts and action items still work).

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 42 Missing.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 42 is not
   installed (nothing to roll back). Plain ASCII.
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
ELSE IF (OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetDashboardDepartments', 'P') IS NULL
         AND OBJECT_ID('dbo.fn_MeetingDashboardState', 'IF') IS NULL
         AND OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NULL
         AND OBJECT_ID('dbo.fn_AgendaStatusGroup', 'IF') IS NULL)
BEGIN
    RAISERROR('Step 42 is not installed in "%s" (none of its five objects exists): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardMeetings;
IF OBJECT_ID('dbo.spr_GetDashboardDepartments', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetDashboardDepartments;
IF OBJECT_ID('dbo.fn_MeetingDashboardState', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_MeetingDashboardState;
IF OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_UserDepartmentScope;
IF OBJECT_ID('dbo.fn_AgendaStatusGroup', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_AgendaStatusGroup;
GO

DECLARE @Left INT = 0;
IF (OBJECT_ID('dbo.spr_GetDashboardMeetings', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetDashboardDepartments', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_MeetingDashboardState', 'IF') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_UserDepartmentScope', 'IF') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.fn_AgendaStatusGroup', 'IF') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 42 rolled back: spr_GetDashboardMeetings, spr_GetDashboardDepartments, fn_MeetingDashboardState, fn_UserDepartmentScope and fn_AgendaStatusGroup dropped.';
ELSE
    RAISERROR('Step 42 is not fully rolled back: %d objects are still there. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
