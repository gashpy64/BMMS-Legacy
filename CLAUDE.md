# BMMS legacy

## Development workflow (BMMS)

1. Plan first. Wait for the owner's approval before any code or file change. Every plan names the
   documents affected (by the update matrix in Documents/README.md), or says
   "documents affected: none". Every plan lists its browser checks in two sets: "tester" (the
   packs the tester runs) and "owner by eye" (what only the owner can judge: looks, print, Word,
   PDF layout).
2. Build, then run the build checks: compile into the scratchpad (Build, not Rebuild; bin and obj
   untouched), site precompile, SQL parse with NOEXEC, and the step's Test script on BMMS_Test.
3. Run security-reviewer, ux-reviewer and ui-reviewer separately, each on git diff plus the new
   untracked files of the step, named one by one. Give each the step's requirement, not the
   reasoning behind the code. A reviewer with nothing to review says "Not applicable" and why.
4. Fix High and Medium findings, or list them as open with a reason. Low findings go to the backlog
   list ("Known items for later steps" in Database/README.md). After a fix, run the build checks
   again and the reviewer that raised it.
5. Tester, after the fixes of step 4 and before the owner's tests: run the tester agent with the
   step's packs (always at least access-matrix; Tests/README.md). A step with a new database
   script first brings the tester's baseline up to date with Tests/_runner/Update-Baseline.ps1
   (on the owner's approval of the build). A failed check goes to the owner as it is, with the
   main session's reading of it (product, expected result or fixture); the main session changes
   no product code, test or expected result to make it pass without the owner's word. The tester
   never writes or changes a test, a pack or an expected result. A REFUSED, VOID or RUNNER FAILED
   result is reported, and the tester is run again once the cause is removed.
6. Report to the owner in 6 parts:
   1. build checks and results;
   2. files changed (git status --short);
   3. the three reviewer records, verbatim;
   4. what was fixed and what is open;
   5. test steps for the owner (the "owner by eye" set);
   6. the tester record, verbatim.
7. Documentation stage, after the owner's tests pass and before the commit commands:
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
8. Never commit, tag or push. The owner does that.
9. Always left out of commits: BMMS/Files/AgendaText/, Database/BMMS-Check-SmallintParameters.sql,
   bin, obj.

Agents: security-reviewer, ux-reviewer, ui-reviewer (step 3), tester (step 5), doc-writer (step 7),
doc-auditor (below).

Documentation audit (doc-auditor, step DA1)
- Not part of the per-step gate. It runs at each release candidate and on the owner's request,
  by Documents/Audit/README.md (catalog export with Documents/_build/Export-Catalog.ps1 into
  %LOCALAPPDATA%\BMMS-Audit\, outside the repository; git status --short --ignored before and
  after).
- The doc-auditor writes only the four files of its run folder
  Documents/Audit/DA-yyyymmdd-<short SHA of HEAD>/ (its guard .claude/hooks/doc-auditor-guard.ps1
  blocks every other write, every edit, any Bash command but one read-only git command, and reads
  of connectionStrings.config and of Log\ and App_Data\). Documents/Audit/README.md is written by
  the main session; Documents/Standards/documents-spec.md changes only on the owner's word.
- After a run, the doc-writer (not the auditor) makes the stubs the run lists.

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
