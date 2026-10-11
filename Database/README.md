# BMMS database scripts

All scripts start with `USE [BMMS]`. Run in SSMS in this order on a database that does not have the changes yet:

1. BMMS-Fix-Login-Procedures.sql          (login lookup split; needed by the new password hashing)
2. BMMS-Fix-Delete-Procedures.sql         (delete procedures with reference checks)
3. BMMS-Fix-ResetDatabase-Seeds.sql       (Reset Database seeds the 4 default users with hashed passwords and ManagerId NULL for "no manager"; installs the procedure only, does not reset)
4. BMMS-Add-PrimaryKeys.sql
5. BMMS-Add-ForeignKeys-Safe.sql          (FK_Agenda_Committee, FK_Attendance_Committee)
6. BMMS-Fix-FK-Procedures.sql             (7 procedures changed so the next 4 keys can be added; needs the MemberDB.cs NULL-state fix deployed)
7. BMMS-Add-ForeignKeys-Step3.sql         (FK_Action_Item_Minutes, FK_ActionItem_User_Map_Users, FK_Meeting_Chairman, FK_Member_State_Master)
8. BMMS-Fix-MinutesFinalize-Procedure.sql (minutes finalization no longer duplicates action items or maps users to other meetings' items)
9. BMMS-Add-ForeignKeys-Step4.sql         (FK_Users_ManagerId; run after the build that stores "no manager" as NULL is deployed, and after re-running step 3 if it was applied before this change - the script refuses otherwise)

Optional / read-only:
- BMMS-Check-Orphans.sql                  (read-only check of candidate foreign keys)
- BMMS-Test-Delete-Procedures.sql         (delete-procedure tests; block-path tests need test data)
- BMMS-Test-FK-Procedures.sql             (tests for steps 6 to 9; runs in a transaction that is rolled back)

Already applied to the local development database. Re-running the fix scripts is safe;
re-running the key scripts reports that the constraint already exists.
