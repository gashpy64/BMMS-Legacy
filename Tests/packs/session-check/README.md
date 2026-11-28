# Session-check pack (step RA1d)

The pack proves on every run that a change of a signed-in user's role, departments or status, made by the
Admin in User Master, ends that user's session at their next click (owner decisions RA1d, 2026-11-18:
Database\README.md, section "Step RA1d"), and that an unchanged user is never interrupted.

BMMS_Quality only, as every pack. Run it as the LAST pack of a run (`-Pack access-matrix,page-assets,session-check`):
it changes three fixture users and puts them back, and a pack after it would see them changed if putting them
back failed.

## Files

| File | What | Who changes it |
|---|---|---|
| `pack.js` | The checks, the accounts and the texts expected. | Claude, in a reviewed step. Never the tester. |

## The data

The fixture (Tests\fixture): qa_mdsec (MD Secretariat, Secretarial), qa_manager2 (Manager, HRD home and
Secretarial), qa_user2 (User, HRD), qa_manager (Manager, Credit; step MR1), qa_ctrl (Controller) and qa_admin
(Admin). The changes are made as qa_admin
through User Master, the Admin's own page, so they go through the same procedures as the Admin's work
(spr_AddEditUser, spr_SetUserStatusByUserId).

## Checks

0. Before any change, User Master shows the four users as the fixture has them. The runner restores BMMS_Quality
   at the start of every run, so a user found changed here was left so by an earlier pack of the same run; the
   check fails, names what it saw, and the pack changes nothing.
1. qa_mdsec, qa_manager2, qa_user2 and qa_ctrl sign in and open the Dashboard.
2. Role: the Admin changes qa_mdsec to Management ("Successfully Saved"). qa_mdsec's next click ends on the
   sign-in page (`?status=changed`) with "Your access has changed. Please sign in again."
3. Departments: the Admin adds Credit to qa_manager2. (Removing Secretarial is refused in the fixture by step 39
   rule 12, Reason 24: qa_manager2 is the last active Manager of Secretarial with an item waiting; owner's word
   2026-11-19.) qa_manager2's next request is a Dashboard filter (an UpdatePanel postback); it ends on the sign-in
   page with the same text, with no script error in the page.
4. Status: the Admin deactivates qa_user2 ("User deactivated"). qa_user2's next click ends on the sign-in page
   (`?status=inactive`) with "Your account is inactive. Contact the administrator."
   After each ended session the browser holds another ASP.NET_SessionId cookie than before (the ended session's
   cookie was expired, answer C): qa_mdsec and qa_manager2 sign in again in the same browser and reach the
   Dashboard; qa_user2, who cannot sign in, is checked on the sign-in page.
4b. Step MR1 (database step 52), rewritten in step UD1b (database step 53): since step 53 every active Manager of a
   department decides its items, and Credit has other active Managers (qa_manager3, credmanager), so a change of qa_manager to User is
   allowed. The refusal is shown on qa_manager2 instead, the only Manager of Secretarial (step 3 gave him Credit too).
   Step UD1c (database step 54, owner 2026-11-24): the fixture's qa_manager4 is a second active Manager of HRD, so the
   HRD item QA1-00001-006 no longer needs qa_manager2 (qa_manager4 can decide it) and HRD drops out of the message.
   The Admin tries to make qa_manager2 a User. Rule 12 refuses it: the message box reads, line by line,
   "Not saved: this Manager is still needed.", "1 item routed to them is still open for approval: approve or reject
   it first." (QA2-00001-2 of Secretarial, a meeting to come), "Last active Manager of Secretarial (1 item of the
   department waiting): give the department another active Manager first." and "Nothing was changed."; no
   past-meeting line. qa_manager2 stays a Manager. (Before step UD1c: 2 items, QA1-00001-006 too, and the HRD line.)
5. qa_ctrl, unchanged, opens Meeting, Reports (Minutes) and the Dashboard between the changes: each opens.
6. App_Data\PageAccessLog.txt (the site copy's): exactly one SESSION-ENDED line for each of the three, with
   "UserId [n]; " and the reason (`role md_sect to mgmt`, `departments changed`, `inactive`); none for qa_ctrl
   or qa_admin; no SESSION-CHECK-ERROR line.
7. Finally, also after a failed check above: the four users are put back through User Master (qa_manager2 by
   removing Credit; qa_manager only if the refusal of 4b did not hold) and must read as at the start (role, departments, status). One that could not be put back fails the check and is named.

The runner's own count of new error log lines covers "error log clean".

## Not covered

- A database error during the check (the safe error page, the session kept): the tester cannot stop SQL Server.
  It is in the owner's browser steps.
- The report pop-up and the Word and PDF exports after a change; the second tab: owner's browser steps.
