# BMMS database scripts

All scripts start with `USE [BMMS]`. Run in SSMS in this order on a database that does not have the changes yet:

1. BMMS-Fix-Login-Procedures.sql          (login lookup split; needed by the new password hashing)
2. BMMS-Fix-Delete-Procedures.sql         (delete procedures with reference checks)
3. BMMS-Fix-ResetDatabase-Seeds.sql       (Reset Database seeds the 4 default users with hashed passwords)
4. BMMS-Add-PrimaryKeys.sql
5. BMMS-Add-ForeignKeys-Safe.sql          (FK_Agenda_Committee, FK_Attendance_Committee)

Optional / read-only:
- BMMS-Check-Orphans.sql                  (read-only check of candidate foreign keys)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests; block-path tests need test data)

Already applied to the local development database. Re-running the fix scripts is safe;
re-running the key scripts reports that the constraint already exists.
