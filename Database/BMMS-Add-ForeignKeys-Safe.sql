/* ============================================================================
   BMMS - Critical fix #5, step 2: add the foreign keys verified as safe
   ----------------------------------------------------------------------------
   Adds two keys:
     FK_Agenda_Committee      Agenda.CommitteeId     -> Committee.CommitteeId
     FK_Attendance_Committee  Attendance.CommitteeId -> Committee.CommitteeId

   Why these two are safe:
     * The orphan check found 0 offending rows for both.
     * The application only writes the committee the user picked on screen,
       never 0 or a made-up value.
     * An agenda or attendance row can only exist for a committee that has a
       meeting, and spr_DeleteCommitteeByCommitteeId already refuses to delete
       a committee that has meetings, so the new keys will not turn a clean
       "cannot delete" message into a SQL error.
     * spr_sys_ResetDatabase already clears Attendance, Minutes, Agenda and
       Meeting before it deletes Committee, so Reset Database still works.

   Safe to re-run: a key that already exists is skipped.
   Take a backup first, e.g.
     BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_fk.bak' WITH COPY_ONLY;

   Deliberately NOT added here (see the notes that came with this script):
     Alert_Master.DepartmentId, Alert_Master.CommitteeId, Alert_User_Map.UserId,
     Users.ManagerId, Agenda.MgrApprovedBy, Agenda.ControllerApprovedBy, and
     (until small procedure changes are made) Action_Item.MinutesId,
     ActionItem_User_Map.UserId, Meeting.ChairmanNameId, Member.State_Id.
   ============================================================================ */

USE [BMMS];
GO

SET NOCOUNT ON;
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Agenda_Committee')
    PRINT 'FK_Agenda_Committee: already exists - skipped.';
ELSE IF EXISTS (SELECT 1 FROM dbo.Agenda a WHERE a.CommitteeId IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM dbo.Committee c WHERE c.CommitteeId = a.CommitteeId))
    PRINT 'FK_Agenda_Committee: orphan rows found - NOT added. Re-run BMMS-Check-Orphans.sql.';
ELSE
BEGIN
    ALTER TABLE dbo.Agenda WITH CHECK
        ADD CONSTRAINT FK_Agenda_Committee FOREIGN KEY (CommitteeId) REFERENCES dbo.Committee (CommitteeId);
    PRINT 'FK_Agenda_Committee: added.';
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Attendance_Committee')
    PRINT 'FK_Attendance_Committee: already exists - skipped.';
ELSE IF EXISTS (SELECT 1 FROM dbo.Attendance a WHERE a.CommitteeId IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM dbo.Committee c WHERE c.CommitteeId = a.CommitteeId))
    PRINT 'FK_Attendance_Committee: orphan rows found - NOT added. Re-run BMMS-Check-Orphans.sql.';
ELSE
BEGIN
    ALTER TABLE dbo.Attendance WITH CHECK
        ADD CONSTRAINT FK_Attendance_Committee FOREIGN KEY (CommitteeId) REFERENCES dbo.Committee (CommitteeId);
    PRINT 'FK_Attendance_Committee: added.';
END
GO

-- Confirm: one row per key; is_not_trusted should be 0 for both.
SELECT DB_NAME() AS CurrentDatabase,
       fk.name AS ForeignKey,
       OBJECT_NAME(fk.parent_object_id) AS ChildTable,
       OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
       fk.is_not_trusted
FROM sys.foreign_keys fk
WHERE fk.name IN ('FK_Agenda_Committee', 'FK_Attendance_Committee')
ORDER BY fk.name;
GO
