# BMMS legacy

## Development workflow (BMMS)

1. Plan first. Wait for the owner's approval before any code or file change. Every plan names the
   documents affected (by the update matrix in Documents/README.md), or says
   "documents affected: none".
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
6. Documentation stage, after the owner's tests pass and before the commit commands:
   1. Run doc-writer with the step's requirement, the diff (git range or diff plus the new files)
      and the test result, not the reasoning behind the code.
   2. In this stage only files inside Documents/ may change: git status --short --ignored, taken
      before and after doc-writer runs, must show no other file added or changed by it.
      doc-writer's guard hook (.claude/hooks/doc-writer-guard.ps1, in its frontmatter) blocks
      writes outside Documents/ and any Bash command but one read-only git command; it is a
      second layer, and this git status --ignored gate stays. The hook command ends with
      "|| exit 2", so it also blocks when pwsh cannot start the guard.
   3. Run `pwsh -File Documents/_build/Check-Documents.ps1` and
      `pwsh -File Documents/_build/Check-UserManuals.ps1`. The user-manual check is a text search
      of Documents/User-Manuals/ for procedure and function names (spr_, fn_), step numbers and
      codes, "Reason", table names, file paths, internal words and open [[CONFIRM: ...]] points;
      it must find nothing in a manual that is to be exported.
   4. Show the owner doc-writer's record (documents changed, To confirm, shot list) and the check
      output. The documents go in the same commit as the step.
   A step with "documents affected: none" still gets its CHANGELOG entry.
7. Never commit, tag or push. The owner does that.
8. Always left out of commits: BMMS/Files/AgendaText/, Database/BMMS-Check-SmallintParameters.sql,
   bin, obj.

House rules (unchanged)
- Test scripts run on BMMS_Test only.
- Numbered database steps have Fix, Rollback and Test scripts, a marker in the procedure text and
  a row in BMMS-Check-InstalledSteps.sql.
- SQL compatibility level 100: no THROW, TRY_CONVERT, IIF, CONCAT, FORMAT or OFFSET.
  Database-name guard BMMS%. Plain ASCII; LF in .sql files.
- One README section per step.
- Documents (Documents/): Markdown with Mermaid, plain ASCII, LF; rules, register and update
  matrix in Documents/README.md. Exports are made per release and never committed.
- Commit messages end with the session attribution lines. git add by explicit path. One tag per step.
