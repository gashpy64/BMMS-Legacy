# BMMS Documentation Audits

- Title: BMMS Documentation Audits
- Audience: Gashpy Software (internal)
- Shipped: No
- Applies to: DA1
- Commit: 5f8c4fe
- Last updated by: DA1, based on 5f8c4fe
- Status: Draft
- Verified against: .claude/agents/doc-auditor.md, .claude/hooks/doc-auditor-guard.ps1, Documents/_build/Export-Catalog.ps1, Documents/_build/Check-Documents.ps1 and Export-Documents.ps1 (step DA1)
- To confirm:

This folder holds the documentation audits made by the doc-auditor agent. They are internal:
never exported (Export-Documents.ps1 refuses every file here) and never given to a client.

An audit is not part of the per-step gate. It runs at each release candidate and on the owner's
request.

## What a run is

One folder per run, `DA-yyyymmdd-<short SHA>/` (the audit date and the commit audited), with four
files written by the doc-auditor and nothing else:

| File | Content |
|---|---|
| Audit-Summary.md | Traceability (repository, branch, commit, audit date, agent, run id, the standard's date, the catalog's date and highest installed step), coverage figures, claims checked per document, the top Critical and High gaps, assumptions, what was not checked, the comparison with the previous run, and the documents done |
| Coverage-Matrix.md | Feature areas against the role manuals 00 to 04, the System manual chapter, the Program-to-Program flow, the Workflow, the Database chapter and the CHANGELOG; each cell "Existence / Verification" and the path, or n/a with a reason |
| Gap-Register.md | DA-G-nnn, document, area, gap, evidence, priority (Critical / High / Medium / Low) with its reason, proposed WF2 part |
| Drift-Register.md | document:line, claim, code or catalog evidence, verdict (Outdated / To confirm) |

Status rules: Existence is Found / Partial / Missing; Verification is Verified / Unverified /
Outdated (never one mixed scale). A WF2a skeleton and a doc-writer stub count as Missing. The
CHANGELOG column has Existence only (its Verification is n/a: history, not current behaviour).
Coverage per group and overall, n/a cells left out: Found+Verified % = Found and Verified cells /
applicable cells; Found % = Found or Partial cells / applicable cells; Partial % = Partial cells /
applicable cells.

The doc-auditor's guard (.claude/hooks/doc-auditor-guard.ps1) lets it write only those four files
of the run folder of the current HEAD; this README is written by the main session.

## How to run an audit

1. In a Claude Code session started after the agent file exists (doc-auditor is listed among the
   agent types), from the repository root: `git status --short --ignored` (keep the output).
2. The catalog of BMMS_Test (read only: SELECT statements only; it reads no row values, the Check
   script outputs row counts only; a fingerprint shows no schema change during the export):

   ```
   pwsh -NoProfile -File Documents/_build/Export-Catalog.ps1 -Server .\SQLEXPRESS -Database BMMS_Test -Replace
   ```

   It writes `%LOCALAPPDATA%\BMMS-Audit\catalog-<yyyymmdd>-<short SHA>\`, outside the repository,
   so it never shows in git status (the script refuses a folder inside the working tree). The
   catalog holds the procedure texts as installed, among them the Reset Database procedure with
   the seed users' password hashes and salts: keep it on this machine, and delete the older
   catalog folder after the next export.
3. Run the doc-auditor with the catalog folder, "new run" (or `continue DA-<run id>`) and the
   previous run folder.
4. The doc-writer makes a stub for each document the standard requires that has no file (header
   block, Status Draft, a "To confirm" naming the DA-G id, a register or layout entry in
   Documents/README.md). Stubs stay Missing in every summary.
5. `pwsh -File Documents/_build/Check-Documents.ps1`, then `git status --short --ignored` again:
   only the run folder, the stubs and Documents/README.md may have changed, and nothing of the
   catalog.
6. The security-reviewer reads the run folder (secrets and personal names).

A run may span several sessions. The doc-auditor stops at a document boundary and lists the
documents done in Audit-Summary.md; in a new session, ask for `continue DA-<run id>` with the same
catalog folder. It refuses when HEAD or the catalog date differ from those of the run.

## Runs

| Run | Commit | Catalog | Result |
|---|---|---|---|
| DA-20261119-5f8c4fe | 5f8c4fe | 2026-11-19, highest installed step 52 (plus D1) | First run, finished in four agent sessions (the first stopped on a usage limit): 43 gaps (Critical 5, High 12, Medium 19, Low 7), 43 drift items (Outdated 29, To confirm 14), no stubs needed; overall Found+Verified 9.6%, Found 57.3%, Partial 16.8% |
