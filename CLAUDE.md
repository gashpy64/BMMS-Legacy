# BMMS legacy

## Development workflow (BMMS)

1. Plan first. Wait for the owner's approval before any code or file change.
2. Build, then run the build checks: compile into the scratchpad (Build, not Rebuild; bin and obj
   untouched), site precompile, SQL parse with NOEXEC, and the step's Test script on BMMS_Test.
3. Run security-reviewer, ux-reviewer and ui-reviewer separately, each on git diff plus the new
   untracked files of the step, named one by one. Give each the step's requirement, not the
   reasoning behind the code. A reviewer with nothing to review says "Not applicable" and why.
4. Fix High and Medium findings, or list them as open with a reason. Low findings go to the backlog
   list ("Known items for later steps" in Database/README.md). After a fix, run the build checks
   again and the reviewer that raised it.
5. Report to the owner in 5 parts:
   1. build checks and results;
   2. files changed (git status --short);
   3. the three reviewer records, verbatim;
   4. what was fixed and what is open;
   5. test steps for the owner.
6. Never commit, tag or push. The owner does that.
7. Always left out of commits: BMMS/Files/AgendaText/, Database/BMMS-Check-SmallintParameters.sql,
   bin, obj.

House rules (unchanged)
- Test scripts run on BMMS_Test only.
- Numbered database steps have Fix, Rollback and Test scripts, a marker in the procedure text and
  a row in BMMS-Check-InstalledSteps.sql.
- SQL compatibility level 100: no THROW, TRY_CONVERT, IIF, CONCAT, FORMAT or OFFSET.
  Database-name guard BMMS%. Plain ASCII; LF in .sql files.
- One README section per step.
- Commit messages end with the session attribution lines. git add by explicit path. One tag per step.
