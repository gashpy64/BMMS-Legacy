/* ============================================================================
   BMMS - Roll back step 51 (the role, status and departments read on every
   signed-in request, step RA1d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the one procedure of step 51: spr_GetUserAccessState. Step 51
   replaced nothing, so nothing is put back.

   ROLL BACK THE APPLICATION BUILD OF STEP RA1d FIRST. That build calls the
   procedure on every signed-in page request; without it every signed-in
   request fails closed (the safe error page). The earlier build reads the
   status through spr_GetUserStatusByUserId (step 14), which step 51 never
   changed.

   Changes no data. A second run refuses (step 51 is not installed: nothing
   to roll back) and changes nothing. BMMS-Check-InstalledSteps.sql then
   shows step 51 Missing.

   It has no USE line: select the database in SSMS first. It stops if the
   current database name does not start with "BMMS". Plain ASCII. From the
   command line use sqlcmd -I.
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
ELSE IF (OBJECT_ID('dbo.spr_GetUserAccessState', 'P') IS NULL)
BEGIN
    RAISERROR('Step 51 is not installed in "%s" (spr_GetUserAccessState does not exist): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('dbo.spr_GetUserAccessState', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[spr_GetUserAccessState];
GO

IF (OBJECT_ID('dbo.spr_GetUserAccessState', 'P') IS NULL)
    PRINT 'Step 51 rolled back: spr_GetUserAccessState dropped. Nothing else was changed.';
ELSE
    RAISERROR('Step 51 is not rolled back: spr_GetUserAccessState still exists. Read the messages above.', 16, 1);
GO

SET NOEXEC OFF;
GO
