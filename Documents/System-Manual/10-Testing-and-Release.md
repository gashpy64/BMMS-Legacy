# Testing and Release

- Title: Testing and Release
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: RA1b (step 41)
- Last updated by: RA1b (step 41), based on 1d1bbbe
- Status: Draft
- Verified against: none yet (leads from the old Architecture notes added in WF2b1); for the step 40
  section Database/BMMS-Test-RoleAccess-Step40.sql (header), the diff of the three changed Test scripts
  and the owner's test result of step RA1a; for the step 41 section Database/BMMS-Test-ReportAccess-Step41.sql
  (header), Database/README.md (section RA1b) and the owner's test result of step RA1b
- To confirm: the count of 44 checks and the counts of the older Test scripts are Database/README.md's, not
  recounted from the scripts; chapter not written yet (WF2b2); leads from the old Architecture notes to verify

## Test database

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: database tests run on a test copy (BMMS_Test or BMMS_bak1), never first on BMMS]]

## Test scripts and how to run them

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: every step has a test script that runs inside a transaction and rolls back]]

### Step 40 (RA1a): role access

Database/BMMS-Test-RoleAccess-Step40.sql (BMMS_Test only; refuses the name BMMS; stops when step 40 is
not installed). Part 1 reads the markers of step 40 and the older markers (steps 13, 14, 18, 21), the
parameters and that no THROW is left in the two member type procedures. Part 2 runs in one transaction
that is rolled back, with made-up users, a department and a member type (ZZ40...): a Controller is
refused (Reason 4) on Create, Edit, RoleChange, Deactivate, Activate, Delete and ResetPassword of another
account, and may Edit and ResetPassword its own; the Reason 1, 7 and 8 cases stay; an Admin may do all
of it; a Manager is refused as before; the user procedures and the User Master list flags end to end;
the member type Save and Delete (Controller refused, Admin allowed); nothing left after the rollback and
every identity counter put back. Result on BMMS_Test (owner's run for RA1a): 43 of 43 PASS.

Older Test scripts changed for step 40: only their Controller expectations (each changed line carries a
"Step 40 (RA1a)" comment). After step 40 they pass on BMMS_Test; on a database without step 40 those
cases fail.

| Script | Result with step 40 | What changed |
|---|---|---|
| BMMS-Test-UserProtection-Stage1.sql | 142 PASS | The Controller acting on a Manager, User, Management or MD Secretariat user, and creating a Manager, User, Management or MD Secretariat user: Reason 4 instead of 0; spr_CheckUserChange, Controller resets a User's password: Reason 4; the list flags of the MD Secretariat row for a Controller: 0 0 0 |
| BMMS-Test-UserStatus-Stage2a.sql | 50 PASS | The Controller deactivates or activates a User: Reason 4; the list flag CanDeactivate of a User row for a Controller: 0 |
| BMMS-Test-MemberTypes-Step21.sql | 100 PASS | The Controller's save, edit and delete of a member type: Reason 4. The display order case of reserved type 3 now acts as the Admin and keeps its result (Reason 7), renamed "by an Admin"; two setup lines (no check row) have the Admin save and edit the types the later cases use |

The other user and member type Test scripts are unchanged and PASS. The Rollback script restores the earlier
texts; BMMS-Check-InstalledSteps.sql shows step 40 Installed, 3 of 3.

### Step 41 (RA1b): report access

Database/BMMS-Test-ReportAccess-Step41.sql (BMMS_Test only; refuses the name BMMS; stops when step 41 is
not installed). Part 1 only reads: the three markers, the parameters, the result columns (the old columns in
the same order plus the new ones) and that the step 22 procedures are unchanged. Part 2 runs in one
transaction that is rolled back, with made-up users, a committee, meetings, agenda items, minutes rows and
action items (ZZ41...): who may call each procedure (Controller and Management the two Minutes procedures;
Management only the Followup one; Manager, User, Admin and MD Secretariat Reason 4; an inactive, unknown or
missing acting user Reason 8; a refused call returns no rows); the meeting list in every status with the
marks (a meeting without a minutes row and another committee's meetings left out); the minutes rows (every
meeting, one meeting, a range, a department, a subject number range); the step 22 procedures still F and C
only; spr_GetFollowupReportForManagement against a copy of the Controller's code-built query for nine
filter combinations (the same rows by count and ActionItemId); nothing left after the rollback and every
identity counter put back. Count: 44 checks according to Database/README.md. Unchanged Test scripts that
must still pass with step 41: BMMS-Test-MinutesGating-Step22.sql (36), BMMS-Test-UnicodeText-Step31.sql (41),
BMMS-Test-WorkflowOrder-Step23.sql (53) and BMMS-Test-RoleAccess-Step40.sql (43).

Result (owner's run on BMMS_Test for step RA1b): every row of the database Test script passed, and the
browser table passed for the Controller, Management, Manager, User, Admin and MD Secretariat, the RA1a
regression (the nine Admin-only addresses), Followup Cancel, a 1366 px window, and real Print, Export to Pdf
and Export to Word of a draft; the error log was clean and PageAccessLog.txt showed the expected lines. Two
Low findings of that test are in the change log (RA1b).

## Reviewer stage

[[CONFIRM: not written yet (WF2b2)]]

## Documentation stage

[[CONFIRM: not written yet (WF2b2)]]

## Release tags and versions

[[CONFIRM: not written yet (WF2b2)]]
[[CONFIRM: lead from old Architecture notes: build with Visual Studio, Rebuild Solution (BMMS.sln), 0 errors]]
[[CONFIRM: lead from old Architecture notes: release order is back up BMMS, run the step's script, then deploy the matching build straight away (the scripts say when the order matters)]]
[[CONFIRM: lead from old Architecture notes: branch modernization; one tag per release; files staged by explicit path; rebuilt binaries stay out of commits]]

## Exporting the documents

[[CONFIRM: not written yet (WF2b2)]]
