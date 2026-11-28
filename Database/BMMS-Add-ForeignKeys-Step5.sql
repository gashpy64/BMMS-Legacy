/* ============================================================================
   BMMS - Critical fix #5, step 7: foreign keys from the user-id columns to Users
   ----------------------------------------------------------------------------
   Adds 21 keys, all -> Users.UserId, none with an ON DELETE action:

     FK_Agenda_CreatedBy               Agenda.CreatedBy
     FK_Agenda_UpdatedBy               Agenda.UpdatedBy
     FK_Agenda_MgrApprovedBy           Agenda.MgrApprovedBy
     FK_Agenda_ControllerApprovedBy    Agenda.ControllerApprovedBy
     FK_Meeting_CreatedBy              Meeting.CreatedBy
     FK_Meeting_UpdatedBy              Meeting.UpdatedBy
     FK_Committee_CreatedBy            Committee.CreatedBy
     FK_Committee_UpdatedBy            Committee.UpdatedBy
     FK_Committee_Member_CreatedBy     Committee_Member.CreatedBy
     FK_Committee_Member_UpdatedBy     Committee_Member.UpdatedBy
     FK_Meeting_Member_CreatedBy       Meeting_Member.CreatedBy
     FK_Meeting_Member_UpdatedBy       Meeting_Member.UpdatedBy
     FK_Member_CreatedBy               Member.CreatedBy
     FK_Member_UpdatedBy               Member.UpdatedBy
     FK_Attendance_UpdatedBy           Attendance.UpdatedBy
     FK_Action_Item_UpdatedBy          Action_Item.UpdatedBy
     FK_Alert_Master_CreatedBy         Alert_Master.CreatedBy
     FK_Alert_User_Map_Users           Alert_User_Map.UserId
     FK_Audit_Trail_Master_Update_By   Audit_Trail_Master.Update_By
     FK_Audit_Trail_SqlBackup_User_Id  Audit_Trail_SqlBackup.User_Id
     FK_Users_UpdatedBy                Users.UpdatedBy

   Run BMMS-Fix-UserDelete-Procedure.sql FIRST. This script checks for it and
   adds nothing if spr_DeleteUserByUserId has not been replaced: with the old
   procedure these keys turn "delete a user who has history" into a SQL error
   instead of the "in use" message.

   A key is NOT added if existing rows would break it (a value that matches no
   user, 0 included). The script says which key and how many rows, and the
   other keys are still added. Nothing is cleaned up automatically.

   Safe to re-run: a key that already exists is skipped.
   Take a backup first, e.g.
     BACKUP DATABASE BMMS TO DISK = N'C:\Backups\BMMS_before_fk_step5.bak' WITH COPY_ONLY;

   Deliberately NOT added (spr_DeleteUserByUserId still checks every one):
     Minutes.CreatedBy, Minutes.UpdatedBy
         spr_AgendaFinalizeByMeetingId and spr_AddEditAgendaByController insert
         Minutes rows with CreatedBy = 1 and UpdatedBy = 1 hard-coded. User 1
         does not exist in the live data, so a key on either column would make
         Agenda Finalization fail. Logged as a defect; not changed here.
     Users.CreatedBy
         2 rows hold 1 (seed data), and user 1 does not exist.
     Audit_Trial_Login.User_Id, Audit_Trail_SendMail.Mail_Send_By
         hold ids of users deleted long ago (login and mail history).
     Department, Designation, Roles, Alert_Type, Decision_Type, Member_Type,
     Subject_Type (CreatedBy, UpdatedBy)
         seed rows hold 1, and Users already references Department,
         Designation and Roles, so a key back to Users would make a circle
         that spr_sys_ResetDatabase cannot delete its way out of.
     Alert_Master.DepartmentId, Alert_Master.CommitteeId (0 is stored for "none").

   It has no USE line: select the database in SSMS first (the test copy, then
   BMMS). It stops if the current database name does not start with "BMMS".
   ============================================================================ */

SET NOCOUNT ON;

DECLARE @CurrentDatabase SYSNAME = DB_NAME();

IF (@CurrentDatabase NOT LIKE 'BMMS%')
BEGIN
    RAISERROR('Current database is "%s". Select the BMMS database (or its test copy) and run again. Nothing was changed.', 16, 1, @CurrentDatabase);
    SET NOEXEC ON;
END
GO

PRINT 'Database: ' + DB_NAME();
GO

DECLARE @Keys TABLE (KeyNo INT IDENTITY(1,1), KeyName SYSNAME, TableName SYSNAME, ColumnName SYSNAME);

INSERT INTO @Keys (KeyName, TableName, ColumnName) VALUES
('FK_Agenda_CreatedBy',              'Agenda',                'CreatedBy'),
('FK_Agenda_UpdatedBy',              'Agenda',                'UpdatedBy'),
('FK_Agenda_MgrApprovedBy',          'Agenda',                'MgrApprovedBy'),
('FK_Agenda_ControllerApprovedBy',   'Agenda',                'ControllerApprovedBy'),
('FK_Meeting_CreatedBy',             'Meeting',               'CreatedBy'),
('FK_Meeting_UpdatedBy',             'Meeting',               'UpdatedBy'),
('FK_Committee_CreatedBy',           'Committee',             'CreatedBy'),
('FK_Committee_UpdatedBy',           'Committee',             'UpdatedBy'),
('FK_Committee_Member_CreatedBy',    'Committee_Member',      'CreatedBy'),
('FK_Committee_Member_UpdatedBy',    'Committee_Member',      'UpdatedBy'),
('FK_Meeting_Member_CreatedBy',      'Meeting_Member',        'CreatedBy'),
('FK_Meeting_Member_UpdatedBy',      'Meeting_Member',        'UpdatedBy'),
('FK_Member_CreatedBy',              'Member',                'CreatedBy'),
('FK_Member_UpdatedBy',              'Member',                'UpdatedBy'),
('FK_Attendance_UpdatedBy',          'Attendance',            'UpdatedBy'),
('FK_Action_Item_UpdatedBy',         'Action_Item',           'UpdatedBy'),
('FK_Alert_Master_CreatedBy',        'Alert_Master',          'CreatedBy'),
('FK_Alert_User_Map_Users',          'Alert_User_Map',        'UserId'),
('FK_Audit_Trail_Master_Update_By',  'Audit_Trail_Master',    'Update_By'),
('FK_Audit_Trail_SqlBackup_User_Id', 'Audit_Trail_SqlBackup', 'User_Id'),
('FK_Users_UpdatedBy',               'Users',                 'UpdatedBy');

DECLARE @KeyNo INT;
DECLARE @KeyCount INT;
DECLARE @KeyName SYSNAME;
DECLARE @TableName SYSNAME;
DECLARE @ColumnName SYSNAME;
DECLARE @Sql NVARCHAR(MAX);
DECLARE @Orphans INT;
DECLARE @Added INT;
DECLARE @Refused INT;

SET @Added = 0;
SET @Refused = 0;

IF NOT EXISTS (SELECT 1 FROM sys.sql_modules
               WHERE object_id = OBJECT_ID('dbo.spr_DeleteUserByUserId')
               AND definition LIKE '%FK#5-UserDelete-AllColumns%')
BEGIN
    PRINT 'spr_DeleteUserByUserId has not been replaced - NO key added.';
    PRINT 'Run BMMS-Fix-UserDelete-Procedure.sql first, then run this script again.';
END
ELSE
BEGIN

    SET @KeyNo = 1;
    SET @KeyCount = (SELECT COUNT(*) FROM @Keys);

    WHILE (@KeyNo <= @KeyCount)
    BEGIN
        SELECT @KeyName = KeyName, @TableName = TableName, @ColumnName = ColumnName
        FROM @Keys WHERE KeyNo = @KeyNo;

        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = @KeyName)
            PRINT @KeyName + ': already exists - skipped.';
        ELSE
        BEGIN
            SET @Sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@TableName) + N' c'
                     + N' WHERE c.' + QUOTENAME(@ColumnName) + N' IS NOT NULL'
                     + N' AND NOT EXISTS (SELECT 1 FROM dbo.Users u WHERE u.UserId = c.' + QUOTENAME(@ColumnName) + N')';

            EXEC sp_executesql @Sql, N'@n INT OUTPUT', @n = @Orphans OUTPUT;

            IF (@Orphans > 0)
            BEGIN
                PRINT @KeyName + ': ' + CAST(@Orphans AS VARCHAR(12)) + ' row(s) in ' + @TableName + '.' + @ColumnName
                    + ' match no user (0 counts) - NOT added. Report this before changing any data.';
                SET @Refused = @Refused + 1;
            END
            ELSE
            BEGIN
                SET @Sql = N'ALTER TABLE dbo.' + QUOTENAME(@TableName) + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@KeyName)
                         + N' FOREIGN KEY (' + QUOTENAME(@ColumnName) + N') REFERENCES dbo.Users (UserId)';

                EXEC sp_executesql @Sql;

                PRINT @KeyName + ': added.';
                SET @Added = @Added + 1;
            END
        END

        SET @KeyNo = @KeyNo + 1;
    END

    PRINT 'Added now: ' + CAST(@Added AS VARCHAR(12)) + '   Refused (orphan rows): ' + CAST(@Refused AS VARCHAR(12));

    -- Confirm: 21 rows expected; OnDelete should be NO_ACTION and is_not_trusted 0 for all.
    SELECT DB_NAME() AS CurrentDatabase,
           k.KeyName AS ForeignKey,
           k.TableName + '.' + k.ColumnName AS ChildColumn,
           CASE WHEN fk.name IS NULL THEN 'MISSING' ELSE 'exists' END AS KeyStatus,
           fk.delete_referential_action_desc AS OnDelete,
           fk.is_not_trusted
    FROM @Keys k
    LEFT JOIN sys.foreign_keys fk ON fk.name = k.KeyName
    ORDER BY k.KeyNo;

END
GO

SET NOEXEC OFF;
GO
