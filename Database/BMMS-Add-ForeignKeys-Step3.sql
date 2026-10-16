/* ============================================================================
   BMMS - Critical fix #5, step 4: add the four foreign keys that needed
   procedure changes first
   ----------------------------------------------------------------------------
   Adds four keys:
     FK_Action_Item_Minutes        Action_Item.MinutesId      -> Minutes.MinutesId
     FK_ActionItem_User_Map_Users  ActionItem_User_Map.UserId -> Users.UserId
     FK_Meeting_Chairman           Meeting.ChairmanNameId     -> Member.MemberId
     FK_Member_State_Master        Member.State_Id            -> State_Master.State_Id

   Run BMMS-Fix-FK-Procedures.sql FIRST. This script checks for it and adds
   nothing if the seven procedures have not been updated, because without
   those changes the keys turn normal actions (saving a member with no state,
   deleting an agenda, deleting a user) into SQL errors.

   None of the four keys cascades on delete: a parent row cannot be deleted
   while a child row points at it. The procedures remove or check the child
   rows themselves. spr_sys_ResetDatabase already clears the child tables
   before the parent tables, so Reset Database still works.

   A key is NOT added if existing rows would break it. For Member.State_Id
   that includes rows holding 0 ("no state"); those must be set to NULL first:
     UPDATE dbo.Member SET State_Id = NULL WHERE State_Id = 0;

   Safe to re-run: a key that already exists is skipped.
   Take a backup first, e.g.
     BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_fk_step3.bak' WITH COPY_ONLY;

   Still deliberately NOT added:
     Alert_Master.DepartmentId, Alert_Master.CommitteeId, Alert_User_Map.UserId.
     Users.ManagerId is added by BMMS-Add-ForeignKeys-Step4.sql.
     Agenda.MgrApprovedBy and Agenda.ControllerApprovedBy are unused by the
     application code and are left in place without a key.
   ============================================================================ */

USE [BMMS];
GO

SET NOCOUNT ON;
GO

DECLARE @ProceduresUpdated INT;

SET @ProceduresUpdated = (SELECT COUNT(*) FROM sys.procedures
                          WHERE name IN ('spr_AddEditMember', 'spr_UpdateMeetingChairman', 'spr_DeleteMemberByMemberId',
                                         'spr_UpdateMinutes', 'spr_AgendaFinalizeByMeetingId', 'spr_DeleteAgendaByAgendaId',
                                         'spr_DeleteUserByUserId')
                          AND OBJECT_DEFINITION(object_id) LIKE '%FK #5%');

IF (@ProceduresUpdated < 7)
BEGIN
    PRINT 'Only ' + CAST(@ProceduresUpdated AS VARCHAR(2)) + ' of the 7 procedures have been updated - NO key added.';
    PRINT 'Run BMMS-Fix-FK-Procedures.sql first, then run this script again.';
END
ELSE
BEGIN

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Action_Item_Minutes')
        PRINT 'FK_Action_Item_Minutes: already exists - skipped.';
    ELSE IF EXISTS (SELECT 1 FROM dbo.Action_Item a
                    WHERE NOT EXISTS (SELECT 1 FROM dbo.Minutes m WHERE m.MinutesId = a.MinutesId))
        PRINT 'FK_Action_Item_Minutes: orphan rows found - NOT added. Re-run BMMS-Check-Orphans.sql.';
    ELSE
    BEGIN
        ALTER TABLE dbo.Action_Item WITH CHECK
            ADD CONSTRAINT FK_Action_Item_Minutes FOREIGN KEY (MinutesId) REFERENCES dbo.Minutes (MinutesId);
        PRINT 'FK_Action_Item_Minutes: added.';
    END

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ActionItem_User_Map_Users')
        PRINT 'FK_ActionItem_User_Map_Users: already exists - skipped.';
    ELSE IF EXISTS (SELECT 1 FROM dbo.ActionItem_User_Map a WHERE a.UserId IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM dbo.Users u WHERE u.UserId = a.UserId))
        PRINT 'FK_ActionItem_User_Map_Users: orphan rows found - NOT added. Re-run BMMS-Check-Orphans.sql.';
    ELSE
    BEGIN
        ALTER TABLE dbo.ActionItem_User_Map WITH CHECK
            ADD CONSTRAINT FK_ActionItem_User_Map_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId);
        PRINT 'FK_ActionItem_User_Map_Users: added.';
    END

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Meeting_Chairman')
        PRINT 'FK_Meeting_Chairman: already exists - skipped.';
    ELSE IF EXISTS (SELECT 1 FROM dbo.Meeting a WHERE a.ChairmanNameId IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM dbo.Member m WHERE m.MemberId = a.ChairmanNameId))
        PRINT 'FK_Meeting_Chairman: orphan rows found - NOT added. Re-run BMMS-Check-Orphans.sql.';
    ELSE
    BEGIN
        ALTER TABLE dbo.Meeting WITH CHECK
            ADD CONSTRAINT FK_Meeting_Chairman FOREIGN KEY (ChairmanNameId) REFERENCES dbo.Member (MemberId);
        PRINT 'FK_Meeting_Chairman: added.';
    END

    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Member_State_Master')
        PRINT 'FK_Member_State_Master: already exists - skipped.';
    ELSE IF EXISTS (SELECT 1 FROM dbo.Member a WHERE a.State_Id IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM dbo.State_Master s WHERE s.State_Id = a.State_Id))
        PRINT 'FK_Member_State_Master: orphan rows found (State_Id = 0 counts) - NOT added. Re-run BMMS-Check-Orphans.sql.';
    ELSE
    BEGIN
        ALTER TABLE dbo.Member WITH CHECK
            ADD CONSTRAINT FK_Member_State_Master FOREIGN KEY (State_Id) REFERENCES dbo.State_Master (State_Id);
        PRINT 'FK_Member_State_Master: added.';
    END

END
GO

-- Confirm: one row per key; is_not_trusted should be 0 for all four.
SELECT DB_NAME() AS CurrentDatabase,
       fk.name AS ForeignKey,
       OBJECT_NAME(fk.parent_object_id) AS ChildTable,
       OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
       fk.delete_referential_action_desc AS OnDelete,
       fk.is_not_trusted
FROM sys.foreign_keys fk
WHERE fk.name IN ('FK_Action_Item_Minutes', 'FK_ActionItem_User_Map_Users',
                  'FK_Meeting_Chairman', 'FK_Member_State_Master')
ORDER BY fk.name;
GO
