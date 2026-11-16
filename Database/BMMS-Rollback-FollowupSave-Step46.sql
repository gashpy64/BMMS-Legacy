/* ============================================================================
   BMMS - Roll back step 46 (Followup page saves decided on the server, step
   UN6d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   Drops the two new procedures of step 46:
     spr_SaveFollowupActionText, spr_SaveFollowupConfirmed
   Step 46 replaced nothing, so nothing is put back: spr_UpdateActionItem
   (step 31) was never changed and is still installed.

   Roll back the application build of step UN6d first or at the same time:
   that build saves the Followup page through the two procedures; without
   them every Save and Submit of that page shows its "could not be saved"
   message and saves nothing. The earlier build saves through
   spr_UpdateActionItem again.

   Changes no data. A second run refuses (step 46 is not installed: nothing
   to roll back) and changes nothing.
   BMMS-Check-InstalledSteps.sql then shows step 46 Missing.

   Since step 47 (step FU1): it refuses while step 47 is installed. Roll back
   step 47 first (BMMS-Rollback-FollowupFinal-Step47.sql).

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
ELSE IF (OBJECT_ID('dbo.spr_SaveFollowupActionText', 'P') IS NULL AND OBJECT_ID('dbo.spr_SaveFollowupConfirmed', 'P') IS NULL)
BEGIN
    RAISERROR('Step 46 is not installed in "%s" (neither of its two procedures exists): nothing to roll back. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
-- Replaced by step 47 (step FU1): roll back step 47 first (BMMS-Rollback-FollowupFinal-Step47.sql puts the step 46
-- texts back); dropping the step 47 texts here would leave the FU1 build without its procedures
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupActionText')), '') LIKE '%FollowupFinal-Step47%'
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_SaveFollowupConfirmed')), '') LIKE '%FollowupFinal-Step47%'
         OR OBJECT_ID('dbo.spr_ReopenFollowup', 'P') IS NOT NULL)
BEGIN
    RAISERROR('Step 47 is installed in "%s". Roll back step 47 first (BMMS-Rollback-FollowupFinal-Step47.sql), then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

IF OBJECT_ID('dbo.spr_SaveFollowupActionText', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_SaveFollowupActionText;
IF OBJECT_ID('dbo.spr_SaveFollowupConfirmed', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spr_SaveFollowupConfirmed;
GO

DECLARE @Left INT = 0;
IF (OBJECT_ID('dbo.spr_SaveFollowupActionText', 'P') IS NOT NULL) SET @Left = @Left + 1;
IF (OBJECT_ID('dbo.spr_SaveFollowupConfirmed', 'P') IS NOT NULL) SET @Left = @Left + 1;

IF (@Left > 0)
    RAISERROR('Step 46 is not fully rolled back: %d of its two procedures are still there. Read the messages above and run the script again.', 16, 1, @Left);
ELSE IF (OBJECT_ID('dbo.spr_UpdateActionItem', 'P') IS NULL)
    RAISERROR('Step 46: the two procedures are dropped, but spr_UpdateActionItem (step 31) is missing, so the earlier build cannot save the Followup page. Run step 31 again (README), then tell the Consultant.', 16, 1);
ELSE
    PRINT 'Step 46 rolled back: spr_SaveFollowupActionText and spr_SaveFollowupConfirmed are dropped; spr_UpdateActionItem (step 31) is still installed.';
GO

SET NOEXEC OFF;
GO
