/* ============================================================================
   BMMS - The role, status and departments read on every signed-in request
   (step 51, step RA1d)
   ----------------------------------------------------------------------------
   Prepared by Ganesh Shankar C S, Consultant.

   INSTALL THIS STEP BEFORE THE BUILD OF STEP RA1d. That build calls
   spr_GetUserAccessState on every signed-in page request; without the
   procedure every signed-in request fails closed (the safe error page) and
   nobody can work until the step is installed.

   Requirement RA1d (owner decisions 2026-11-18): every signed-in request
   compares what the session took at sign-in with the database; a change of
   role, active status or department set ends the session and sends the user
   to the sign-in page.

   Objects (marker SessionCheck-Step51)
     spr_GetUserAccessState   NEW, read only. @UserId INT. No row when the
                              user is not in View_Users (missing, or a
                              department, designation or role row missing:
                              as spr_GetUserByUserId reads it). Otherwise one
                              row:
                                UserId, RoleCode, RoleName (Roles),
                                AccountStatus (1 active), IsSystem (0 or 1),
                                DepartmentSet: Users.DepartmentId, "|", then
                                the open User_Department rows of step 39
                                (EffectiveTo NULL) by DepartmentId, comma
                                separated, the home row marked "h"; for
                                example "4|4h,5". Digits, "|", "," and "h"
                                only. A change of the home department, of
                                Users.DepartmentId or of any open row gives
                                another text.
                              No password, no e-mail.

   No table, view, index or data is changed. Nothing is granted: as steps 42
   to 50, the application login holds EXECUTE on the schema dbo (the Test
   script checks it for every database user).

   Order: installed after step 50. Needs step 18 (View_Users.IsSystem), step
   39 (User_Department, marker UserHistory-Step39) and step 40 (marker
   RoleAccess-Step40) and stops otherwise. No earlier script contains
   spr_GetUserAccessState: a re-run of an earlier step does not touch it. A
   re-run of step 18 creates View_Users again with the same columns; the
   procedure keeps working.

   Safe to re-run. BMMS-Rollback-SessionCheck-Step51.sql drops the procedure
   (roll back the build of step RA1d first).

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   Written for compatibility level 100. The file is plain ASCII. From the
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
ELSE IF (OBJECT_ID('dbo.View_Users', 'V') IS NULL OR COL_LENGTH('dbo.View_Users', 'IsSystem') IS NULL
         OR COL_LENGTH('dbo.View_Users', 'RoleCode') IS NULL OR COL_LENGTH('dbo.View_Users', 'AccountStatus') IS NULL)
BEGIN
    RAISERROR('Step 18 (BMMS-Fix-SystemAccount-Stage3.sql) is not installed in "%s" (View_Users has no IsSystem column). Run it first, then steps 39 and 40, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (OBJECT_ID('dbo.User_Department', 'U') IS NULL OR COL_LENGTH('dbo.User_Department', 'IsHome') IS NULL
         OR COL_LENGTH('dbo.User_Department', 'EffectiveTo') IS NULL
         OR ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserDepartmentMap')), '') NOT LIKE '%UserHistory-Step39%')
BEGIN
    RAISERROR('Step 39 (BMMS-Fix-UserHistory-Step39.sql) is not installed in "%s". Run it first, then step 40, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
ELSE IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.fn_UserChangeRefusal')), '') NOT LIKE '%RoleAccess-Step40%')
BEGIN
    RAISERROR('Step 40 (BMMS-Fix-RoleAccess-Step40.sql) is not installed in "%s". Run it first, then this script. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

-------------------------------------------------------------------------------
-- Users - what a signed-in session is compared with on every request (SessionCheck-Step51)
-------------------------------------------------------------------------------
-- Read only. No row: the user is not in View_Users. DepartmentSet: Users.DepartmentId, "|", the open
-- User_Department rows by DepartmentId, the home row marked "h" (for example "4|4h,5").
CREATE OR ALTER PROCEDURE [dbo].[spr_GetUserAccessState]
@UserId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT v.UserId, v.RoleCode, v.RoleName, v.AccountStatus,
	       CASE WHEN ISNULL(CAST(v.IsSystem AS INT), 0) = 1 THEN 1 ELSE 0 END AS IsSystem,
	       CAST(ISNULL(CAST(v.DepartmentId AS VARCHAR(12)), '') + '|'
	            + ISNULL(STUFF((SELECT ',' + CAST(ud.DepartmentId AS VARCHAR(12)) + CASE WHEN ud.IsHome = 1 THEN 'h' ELSE '' END
	                            FROM dbo.User_Department ud
	                            WHERE ud.UserId = v.UserId AND ud.EffectiveTo IS NULL
	                            ORDER BY ud.DepartmentId
	                            FOR XML PATH('')), 1, 1, ''), '') AS VARCHAR(MAX)) AS DepartmentSet
	FROM dbo.View_Users v
	WHERE v.UserId = @UserId;
END
GO

-------------------------------------------------------------------------------
-- What is installed now
-------------------------------------------------------------------------------
IF (ISNULL(OBJECT_DEFINITION(OBJECT_ID('dbo.spr_GetUserAccessState')), '') LIKE '%SessionCheck-Step51%'
    AND (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.spr_GetUserAccessState')) = 1)
    PRINT 'Step 51 installed: spr_GetUserAccessState (SessionCheck-Step51). Now deploy the build of step RA1d.';
ELSE
    RAISERROR('Step 51 is not complete: spr_GetUserAccessState is missing or has no marker SessionCheck-Step51. Read the messages above and run the script again.', 16, 1);
GO

SET NOEXEC OFF;
GO
