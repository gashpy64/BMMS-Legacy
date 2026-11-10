/* ============================================================================
   BMMS - Roll back step 41 (report access, step RA1b)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the three procedures of step 41:
     spr_GetMinutesReportMeetingsAllStatus
     spr_GetMinutesReportAllStatus
     spr_GetFollowupReportForManagement
   Nothing else: step 41 replaced no object, so nothing is restored. The
   Minutes report of the Manager and the other roles (step 22) is unaffected.

   Roll back the application build of step RA1b first or at the same time:
   that build calls these procedures for the Controller's and Management's
   Minutes report and for Management's Followup; without them those pages
   show the error page.

   Changes no data. Safe to re-run. BMMS-Check-InstalledSteps.sql then shows
   step 41 Missing.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS", and when step 41 is not
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
ELSE IF (OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetMinutesReportAllStatus', 'P') IS NULL
         AND OBJECT_ID('dbo.spr_GetFollowupReportForManagement', 'P') IS NULL)
BEGIN
    RAISERROR('Step 41 is not installed in "%s" (none of its three procedures exists): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetMinutesReportMeetingsAllStatus;
IF OBJECT_ID('dbo.spr_GetMinutesReportAllStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetMinutesReportAllStatus;
IF OBJECT_ID('dbo.spr_GetFollowupReportForManagement', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_GetFollowupReportForManagement;
GO

DECLARE @Left INT = 0;
IF (OBJECT_ID('dbo.spr_GetMinutesReportMeetingsAllStatus', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetMinutesReportAllStatus', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_GetFollowupReportForManagement', 'P') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left = 0)
    PRINT 'Step 41 rolled back: spr_GetMinutesReportMeetingsAllStatus, spr_GetMinutesReportAllStatus and spr_GetFollowupReportForManagement dropped.';
ELSE
    RAISERROR('Step 41 is not fully rolled back: %d procedures are still there. Read the messages above and run the script again.', 16, 1, @Left);
GO

SET NOEXEC OFF;
GO
