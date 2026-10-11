/* ============================================================================
   BMMS - Critical fix #5, step 5: add the manager foreign key
   ----------------------------------------------------------------------------
   Adds one key:
     FK_Users_ManagerId   Users.ManagerId -> Users.UserId

   "No manager" must be stored as NULL, never 0. Before running this script:
     1. Deploy the application build in which UserDB.AddEditUser sends NULL for
        "no manager" and Agenda.aspx.cs reads a NULL ManagerId. With the old
        build, saving a user without a manager fails once the key exists.
     2. Run BMMS-Fix-ResetDatabase-Seeds.sql. This script checks for it and
        adds nothing if spr_sys_ResetDatabase has not been updated, because the
        old procedure seeds ManagerId = 0 and Reset Database would then fail
        partway through. That script only installs the procedure definition; it
        does not reset anything. NEVER execute spr_sys_ResetDatabase itself on
        a live database: it wipes all data.

   The key has no ON DELETE action: a user cannot be deleted while another
   user has them as manager. spr_DeleteUserByUserId already checks for that
   and returns Result = 0.

   The key is NOT added if existing rows would break it. That includes rows
   holding 0 ("no manager"); those must be set to NULL first:
     UPDATE dbo.Users SET ManagerId = NULL WHERE ManagerId = 0;

   Safe to re-run: a key that already exists is skipped.
   Take a backup first, e.g.
     BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_fk_step4.bak' WITH COPY_ONLY;

   Still deliberately NOT added:
     Alert_Master.DepartmentId, Alert_Master.CommitteeId, Alert_User_Map.UserId.
     Agenda.MgrApprovedBy and Agenda.ControllerApprovedBy are unused by the
     application code and are left in place without a key.
   ============================================================================ */

USE [BMMS];
GO

SET NOCOUNT ON;
GO

DECLARE @ResetProcedureUpdated INT;
DECLARE @NullManagers INT;

SET @ResetProcedureUpdated = (SELECT COUNT(*) FROM sys.sql_modules
                              WHERE object_id = OBJECT_ID('dbo.spr_sys_ResetDatabase')
                              AND definition LIKE '%FK#5-ManagerId-NULL%');

IF (@ResetProcedureUpdated = 0)
BEGIN
    PRINT 'spr_sys_ResetDatabase has not been updated - NO key added.';
    PRINT 'Run BMMS-Fix-ResetDatabase-Seeds.sql first, then run this script again.';
    PRINT 'That script only installs the procedure. Do NOT execute spr_sys_ResetDatabase on a live database: it wipes all data.';
END
ELSE
BEGIN

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Users_ManagerId')
        PRINT 'FK_Users_ManagerId: already exists - skipped.';
    ELSE IF EXISTS (SELECT 1 FROM dbo.Users u WHERE u.ManagerId IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM dbo.Users m WHERE m.UserId = u.ManagerId))
        PRINT 'FK_Users_ManagerId: users found whose ManagerId matches no user (ManagerId = 0 counts) - NOT added. Re-run BMMS-Check-Orphans.sql.';
    ELSE
    BEGIN
        ALTER TABLE dbo.Users WITH CHECK
            ADD CONSTRAINT FK_Users_ManagerId FOREIGN KEY (ManagerId) REFERENCES dbo.Users (UserId);
        PRINT 'FK_Users_ManagerId: added.';
    END

    SET @NullManagers = (SELECT COUNT(*) FROM dbo.Users WHERE ManagerId IS NULL);

    PRINT 'Users with no manager (ManagerId IS NULL): ' + CAST(@NullManagers AS VARCHAR(12));

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Users_ManagerId')
        PRINT 'FK_Users_ManagerId exists: YES';
    ELSE
        PRINT 'FK_Users_ManagerId exists: NO';

    -- Confirm: one row; OnDelete should be NO_ACTION and is_not_trusted 0.
    SELECT DB_NAME() AS CurrentDatabase,
           fk.name AS ForeignKey,
           OBJECT_NAME(fk.parent_object_id) AS ChildTable,
           OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
           fk.delete_referential_action_desc AS OnDelete,
           fk.is_not_trusted,
           @NullManagers AS UsersWithNoManager
    FROM sys.foreign_keys fk
    WHERE fk.name = 'FK_Users_ManagerId';

END
GO
