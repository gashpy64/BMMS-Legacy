# Security

- Title: Security
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: user-ud1a
- Last updated by: WF2b1, based on 3dd0eec
- Status: Draft
- Verified against: none yet (leads from the old Architecture notes added in WF2b1); the THROW
  pointer is from 04-Database.md and the BMMS_Test catalog export of 2026-11-09
- To confirm: chapter not written yet (WF2b2); the minimum SQL Server version (THROW in 24
  procedures, pointer to chapter 04); leads from the old Architecture notes to verify;
  lead from the old Errata notes: values still stored in the old Triple DES format (empty-string
  key, fixed IV) in the live database

## Sign-in and passwords

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: passwords are stored as PBKDF2 (RFC 2898) hashes, 100,000 iterations, a 16-byte random salt per password, in the form iterations.salt.hash]]
[[CONFIRM: lead from old Architecture notes: the login lookup and the password check are separate (step 1); a user who logs in with the default password goes straight to the first-login password change]]
[[CONFIRM: lead from old Architecture notes: Users.AccountStatus is 1 (active) or 0 (inactive); login refuses an inactive account after the password check, and the page-access module re-reads the status on every request]]
The old Triple DES routine in BMMSBAL/Common.cs (DecryptVal and its encrypt counterpart), kept for values saved before DPAPI, derives its key from a hash of a fixed, empty text and uses a fixed IV in the code; it has no real secret key. [[CONFIRM: lead from old Errata notes: the old Triple DES routine kept for values saved before DPAPI uses no real secret key (a key derived from an empty string and a fixed IV), so a value still stored in the old format, for example an SMTP password or an old Users.Password value, can be read by anyone who can read the database; check the live database for values still in the old format]]

## Page access

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: the roles are admin, controller, manager, user, mgmt, md_sect; the menu and PageAccess.xml decide which pages a role opens]]

## Role and acting-user checks in procedures

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: open known item, see "Known database limitations" in chapter 04: 24 procedures use THROW on BMMS_Test although the house rule for compatibility level 100 says no THROW; it runs because the server is SQL Server 17; the owner has to decide the minimum SQL Server version]]
[[CONFIRM: lead from old Architecture notes: the stored procedures decide which changes a role may make; dbo.fn_UserChangeRefusal (step 13 onwards) says who may change which user]]
[[CONFIRM: lead from old Architecture notes: nobody can delete, deactivate or change the role of their own account; the last active ordinary Admin and the last active Controller cannot be deleted, deactivated or given another role (checked under a lock in the same transaction)]]
[[CONFIRM: lead from old Architecture notes: Admin may change any user; Controller any user except Admin and Controller users; other roles only their own details and password]]
[[CONFIRM: lead from old Architecture notes: the acting user is the logged-in user, passed as @ActingUserId; a missing or inactive acting user is refused]]
[[CONFIRM: lead from old Architecture notes: one protected system account (Users.IsSystem = 1) cannot be edited, deleted, deactivated or given another role, even by itself; only it can change its own password; it takes no part in the workflow (step 18)]]
[[CONFIRM: lead from old Architecture notes: every protected procedure returns one row Result, Reason, ReasonDetail (1 done, 0 refused); the page turns the Reason into a sentence; a database error is re-raised, not reported as a refusal]]

## Input and output handling

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Errata notes: a scan of the stored procedures for dynamic SQL (EXEC of a string, sp_executesql) found none; this lead is contradicted by the 2026-11-09 BMMS_Test catalog export, where spr_sys_ResetDatabase calls sp_executesql twice (see "Dynamic SQL in the stored procedures" in chapter 04, Database); decide what chapter 08 says after the owner has read chapter 04]]
[[CONFIRM: lead from old Errata notes: report queries built in ReportsMgr and the database backup (Sql_Backup_Mgr) are the calls that do not use a stored procedure]]

## Uploads

[[CONFIRM: not written yet (WF2b2)]]

## Audit trail

[[CONFIRM: not written yet (WF2b2)]]

## Recommended hardening

[[CONFIRM: not written yet (WF2b2)]]
