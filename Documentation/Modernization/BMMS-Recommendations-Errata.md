# BMMS Modernization Recommendations — Verified Errata

**Subject:** `BMMS — Modernization & Technology Upgrade Recommendations.md`
**Verification date:** 2026-10-07
**Verified against:** the tracked source of `BMMS-Legacy` (362 files, branch `modernization`),
a full SQL Server 2019 schema export (`script.sql` — 29 tables, 11 views, 133 stored procedures,
22 foreign keys), and the compiled `BMMSBAL.dll`.

> **Revision 2 — corrected.** §1.4 and §2 have been revised after the foreign-key extraction was
> redone. The first pass split the script on `CREATE TABLE`, so every `ALTER TABLE ... ADD
> CONSTRAINT` statement was attributed to the table preceding it, producing a false claim that all
> 22 foreign keys sat on `SysCodeSetting`. All 22 are real and spread across 11 child tables. This
> changes the characterisation of Critical #3 — see §1.4 — and removes the claim that SQL Server
> enforces nothing outside one table.

---

## Purpose and method

Every factual claim in the Critical and High tiers was re-checked against the source and the
exported schema rather than taken on trust. Where a claim was verified by execution, the method
is stated so it can be reproduced.

Two techniques were used beyond reading:

1. **Executing the real crypto and hash code.** `EncryptVal`/`DecryptVal` and the new
   PBKDF2 `HashPassword`/`VerifyPassword` were extracted verbatim from
   `BMMSBAL/Common.cs`, compiled with `Microsoft.NET\Framework64\v4.0.30319\csc.exe`, and run
   through a migration simulation.
2. **Parsing the schema export.** Procedures, tables, keys and constraints were extracted
   programmatically (procedure bodies, `COUNT(*)` guards, `FOREIGN KEY ... REFERENCES` pairs,
   and a dynamic-SQL scan across all 133 procedures).

Overall assessment: the recommendations are unusually well-grounded for this kind of document —
the majority of the Critical tier is accurate as written. The corrections below are the
exceptions, and each one changes a decision rather than a wording.

---

## 1. Corrections that change decisions

### 1.1 "This requires a forced password reset for all users" — **incorrect; no reset is needed**

The document states (Critical #1) that migration requires a forced password reset "since the old
values can't be converted." They can be converted. The legacy cipher is *reversible by design*:
the key is `MD5(lscryptoKey)` where `lscryptoKey` is the empty string (never assigned anywhere in
the tree), and the IV is a hardcoded constant. That is precisely why the finding is critical — and
it is also why migration is a conversion, not a reset.

Verified by executing the actual code:

```
PASS  legacy ciphertext decrypts back to the original plaintext
PASS  ATTACKER: MD5("") + hardcoded IV decrypts it with no secret at all
PASS  legacy value is not mistaken for a hash by IsHashedPassword
PASS  MIGRATION: legacy row -> decrypt -> hash still verifies the SAME password
PASS  MIGRATION: the produced value is recognised as a hash
```

**Correction:** replace "requires a forced password reset for all users on migration since the old
values can't be converted" with: migration is a decrypt-then-hash conversion, so **every user keeps
their existing password**; no reset campaign and no associated support load. A forced reset would
only be required if the key were lost.

### 1.2 Plaintext SQL credentials — **right credential, wrong file**

Critical #2 places `uid=sa;password=sa` in `Web.config`. It is not there. The only occurrence of
that literal in all 362 tracked files is a **commented-out line** at
`BMMSBAL/Sql_Backup_Mgr.cs:19`:

```
//server=.\SQLEXPRESS;database=BMMS;uid=sa;password=sa
```

Both `BMMS/Web.config:14-15` and `BMMS/Web.xml:9-13` specify `Integrated Security=True` with no
SQL login at all.

That said, the finding is substantively right and should not be dropped: `Sql_Backup_Mgr.cs:21-25`
splits the connection string and reads elements 2 and 3 as username and password unconditionally —
which only works against a `server;database;uid;password` string. That code was therefore written
for SQL authentication, strongly implying the **deployed** configuration used the `sa` account.
(The committed error log references `C:\BMMS\BMMS\Source\BMMS\web.config`, a path absent from the
repository, so the deployed config is a different file from the committed one.)

**Correction:** keep the recommendation; change the location to "the deployed
`C:\BMMS\BMMS\Source\BMMS\web.config` (and a hardcoded sample at `BMMSBAL/Sql_Backup_Mgr.cs:19`)".
The committed `Web.config` cannot be the source of this finding.

### 1.3 "Reset Database" — **the High-tier description is the opposite of the truth, and it belongs in Critical**

The document (High tier) says the procedure "truncates only tagging/attendance/audit tables,
silently leaves Committee/Meeting/Agenda/Minutes/Member/Users untouched." The actual body is the
reverse. `spr_sys_ResetDatabase` is 232 lines and performs **5 `TRUNCATE`, 23 `DELETE` and 17
`DBCC CHECKIDENT` reseeds**, including:

```sql
DELETE FROM Users;      DBCC CHECKIDENT (Users, RESEED, 0);
DELETE FROM Roles;      DELETE FROM Member;     DELETE FROM Meeting;
DELETE FROM Agenda;     DELETE FROM Minutes;    DELETE FROM Committee;
DELETE FROM Department; DELETE FROM Designation; DELETE FROM Subject_Type;
DELETE FROM Decision_Type;  DELETE FROM Member_Type;  DELETE FROM Alert_Type;
DELETE FROM Audit_Trial_Login;  DELETE FROM Audit_Trail_Master;
```

It deletes **every user account and every role**, so after a reset nobody can sign in at all, and
it also destroys the login audit trail. Separately, the document never mentions the fact that makes
this the single most severe item in the codebase: `Master/ResetDatabase.aspx` has **no
authorization check of any kind** — `Page_Load` is empty, there is no `Common.InitSetup` call, no
role check, and the button is protected only by a client-side JavaScript `confirm()`.

**Correction:** move this item from High to the **top of Critical**, replace the description with
the actual behaviour (all records including Users and Roles, plus the login audit, followed by
identity reseeds), and record that the endpoint was reachable **unauthenticated** by direct URL
before the fix in `BMMS/Master/ResetDatabase.aspx.cs`.

### 1.4 Delete procedures — **nine are unguarded, not seven**

Critical #3 lists seven procedures lacking a reference-integrity check. Against the exported schema
the count is nine. `spr_DeleteAgendaByAgendaId` also contains no `COUNT(*)` guard and is not named
in the document.

Additionally, `spr_DeleteMeetingMemberByMeetingMemberId` — which the pattern-based reading would
suggest is a correct example — does contain a `COUNT(*)`, but it is a **status rule, not a
reference check**:

```sql
SET @CountRec = (SELECT COUNT(*) FROM Meeting WHERE MeetingId = @MeetingId
                 AND (MinutesStatus = 'F' OR MinutesStatus = 'C'));
```

That refuses to remove a member once minutes are finalized. It is correct business logic but it
does not protect referential integrity, so it should not be cited as the model.

Confirmed unguarded (9): `spr_DeleteAgendaByAgendaId`, `spr_DeleteCommitteeByCommitteeId`,
`spr_DeleteCommitteeMemberByCommitteeMemberId`, `spr_DeleteDecisionTypeByDecisionTypeId`,
`spr_DeleteDepartmentByDeptId`, `spr_DeleteDesignationByDesignationId`,
`spr_DeleteMemberTypeByMemberTypeId`, `spr_DeleteSubjectTypeBySubjectTypeId`,
`spr_DeleteUserByUserId`.

True reference checks (2): `spr_DeleteMemberByMemberId`, `spr_DeleteMeetingByMeetingId` — and both
check only **one** child table each, so even they are partial.

**The document's stated rationale for this item is largely wrong.** These relationships *are*
enforced: the database has **22 foreign key constraints spread across 11 child tables**, declared as
`ALTER TABLE ... ADD CONSTRAINT` statements outside the `CREATE TABLE` blocks.

| Child table | Parent tables |
|---|---|
| `Agenda` | `Agenda_Status`, `Department`, `Meeting`, `Subject_Type` |
| `Committee_Member` | `Committee`, `Member`, `Member_Type` |
| `Meeting_Member` | `Meeting`, `Member`, `Member_Type` |
| `Minutes` | `Agenda`, `Decision_Type` |
| `Users` | `Department`, `Designation`, `Roles` |
| `Attendance` | `Meeting`, `Member` |
| `Meeting` | `Committee` |
| `Member` | `Designation` |
| `Alert_User_Map` | `Alert_Master` |
| `Alert_Master` | `Alert_Type` |
| `ActionItem_User_Map` | `Action_Item` |

All 22 are `ON UPDATE CASCADE` with **no `ON DELETE` action**, so deleting a referenced parent is
blocked by default. Checking the nine procedures child by child:

- `spr_DeleteCommitteeByCommitteeId` — children `Meeting`, `Committee_Member`: both constrained.
- `spr_DeleteDepartmentByDeptId` — children `Agenda`, `Users`: both constrained.
- `spr_DeleteDesignationByDesignationId` — children `Users`, `Member`: both constrained.
- `spr_DeleteMemberTypeByMemberTypeId` — children `Committee_Member`, `Meeting_Member`: constrained.
- `spr_DeleteSubjectTypeBySubjectTypeId` — child `Agenda`: constrained.
- `spr_DeleteDecisionTypeByDecisionTypeId` — child `Minutes`: constrained.
- `spr_DeleteAgendaByAgendaId` — child `Minutes`: constrained.
- `spr_DeleteCommitteeMemberByCommitteeMemberId` — nothing references `Committee_Member` by id.

So for **eight of the nine**, a delete of a referenced row already fails with an FK violation rather
than orphaning anything. The defect is that it fails as a **raw SQL exception**, which the pages
surface only because every handler wraps the call in `catch { ... delete_reference }`. A guard
returning a clean `Result = 0` is therefore a **usability and consistency fix, not a data-integrity
fix** — worth doing, but it should not be described as closing an orphaning hole.

**The one genuine integrity gap is `spr_DeleteUserByUserId`.** The columns that reference `Users` —
`Users.ManagerId`, `Agenda.MgrApprovedBy`, `Agenda.ControllerApprovedBy`, `Alert_User_Map.UserId`,
`ActionItem_User_Map.UserId` — have no foreign key, so deleting a user does orphan rows. That one
needs a guard *and* the constraints from Critical #5.

**Critical implementation note missing from the document:** adding `SELECT @Result AS Result` to a
procedure is not sufficient, because of how the procedures are called. All nine are invoked through
`CommonDB.ExecuteProcedure` → `cmd.ExecuteNonQuery()`, which **discards any result set**. The two
procedures that genuinely work do so because they are called through `CommonDB.GetDataTable`. Any
guard added without changing the call sites will silently block the delete while the application
reports success — the DAL, Mgr and page layers must change in the same commit.

### 1.5 Missing primary keys — **three tables, not two**

Critical #6 names `Source_Type` and `Audit_Trail_SendMail`. `SMTP_Master` also has no primary key.

**Correction:** three tables require a key.

### 1.6 Authorisation is worse than "scattered per-page checks"

Critical #7 describes `Session["RoleCode"]` checks "scattered per page." That overstates the
existing protection and understates the problem. `Session["RoleCode"]` appears in exactly **one**
code-behind (`Master/DecisionType.aspx.cs:107`) plus the menu markup
(`UserControl/MenuUserControl.ascx`). The actual issue is pages with no check at all:

- **No authentication check** (no `Common.InitSetup`, no session test): `Master/ResetDatabase.aspx`,
  `Master/SMTPServerConfig.aspx`, `Master/ResetPassword.aspx`, `Report/ReportPrint.aspx`,
  `Report/ViewReport.aspx`, `Error/TestPage.aspx`.
- **Authenticated but not role-gated**: `Master/User.aspx` — any signed-in user of any role can
  create users and assign roles, hidden only by the menu.

There is no `<authorization>` element in `Web.config` and no authentication hook in
`Global.asax`; the only server-side gate anywhere is `Common.InitSetup`, a *login* check.

---

## 2. Verified accurate as written

| Claim | Verdict |
|---|---|
| Password storage is reversible, not hashed | Confirmed — TripleDES, MD5-derived key, fixed IV |
| `spr_DeleteUserByUserId` has no check | Confirmed verbatim: `DELETE FROM Users WHERE UserId = @UserId;` |
| Eight relationship columns have no FK | Confirmed — all eight exist as nullable `int` (except `Action_Item.MinutesId`, `NOT NULL`) with no constraint |
| `Source_Type`, `Audit_Trail_SendMail` have no PK | Confirmed (plus `SMTP_Master`) |
| `Meeting.MeetingTime` is `varchar(10)` | Confirmed: `[MeetingTime] [varchar](10) NULL` |
| Schema scripted at compatibility level 100 | Confirmed: `ALTER DATABASE [BMMS] SET COMPATIBILITY_LEVEL = 100` |
| Zero automated tests | Confirmed — no test project in the solution |
| iTextSharp relicensed AGPL from v5 | Correct as a licensing history statement; see §3.1 |

The foreign-key position is **better than an earlier draft of this errata claimed**, and the
correction matters because it changes the work. The schema does contain 22 foreign keys across 11
child tables (enumerated in §1.4). What the document correctly identifies is the residual gap: the
eight relationship columns in Critical #5 genuinely carry no constraint —
`Agenda.CommitteeId`, `Users.ManagerId`, `Member.SexId`, `Member.State_Id`,
`Meeting.ChairmanNameId`, `Action_Item.MinutesId`, `Alert_User_Map.UserId`,
`ActionItem_User_Map.UserId`. Each was confirmed present in its table and absent from the FK list.

The parent tables to target are, respectively: `Committee`, `Users` (self-reference),
`SysCodeSetting` (`MainCode = 'Sex'`), `State_Master`, `Member` (confirmed —
`View_Meeting` joins `dbo.Member.MemberId = dbo.Meeting.ChairmanNameId`), `Minutes`, `Users`,
`Users`.

Adding them needs a pre-flight orphan scan. `ALTER TABLE ... ADD CONSTRAINT` fails outright when
existing rows already violate it, and `Alert_User_Map` / `ActionItem_User_Map` are the likeliest to
hold stale `UserId` values. `Action_Item.MinutesId` is `NOT NULL`, which is fine for a constraint.
Before constraining `Member.SexId` / `Member.State_Id`, confirm every stored value resolves —
`SexId` holds a `SysCodeSetting.SysCodeId`, not a literal 1/0.

---

## 3. Open questions in the document, now closed

### 3.1 iTextSharp licensing — the AGPL concern is moot

`BMMS.csproj` references `itextsharp, Version=4.0.2.0`, and the committed
`BMMS/bin/itextsharp.dll` reports `FileVersion=4.0.2.0`. The AGPL relicense arrived with iText 5;
version 4.0.2 is LGPL/MPL. **No commercial-use problem exists**, and no library swap is required on
licensing grounds.

### 3.2 Dynamic SQL / injection scan — clean across all 133 procedures

The document's "What Would Sharpen This Further" asks for this scan. It is now done. Across every
procedure in the export there are **zero** occurrences of `EXEC(`, `EXECUTE(`, `sp_executesql`,
`EXEC @variable` or `EXEC 'literal'`. Six procedures concatenate strings, but only into display
values, never into executed SQL:

```sql
SET @DisplayText = 'Agenda (' + @AgendaNo + ')'
SET @Prefix      = @Prefix1 + '-' + @Prefix2 + '-'
```

**Result: no dynamic-SQL injection surface exists at the stored-procedure layer.** This closes the
Critical tier's last remaining uncertainty.

### 3.3 Procedure count

The document says 129 stored procedures. The export contains **133**, and the C# calls 139 distinct
procedure names — of which **seven do not exist in the database**:

```
spr_AddEditRole      spr_GetRoleByRoleId    spr_GetAgenda
spr_DeleteRoleByRoleId  spr_GetNextRoleCode  spr_GetNextCommitteeMemberCode
spr_GetNextMeetingMemberCode
```

`sys.procedures` should be queried on the live server to confirm, but if these are genuinely absent
then Role management (except `spr_GetRole`) and the "get all agendas" list throw
"Could not find stored procedure" at runtime. Notably this means `spr_DeleteRoleByRoleId` is dead
code, not a live risk.

### 3.4 Database platform

The instance is already **SQL Server 2019** (`MSSQL15.MSSQLSERVER`, per the data-file paths in the
export). The recommendation to "upgrade to a current SQL Server version" is therefore unnecessary —
only `COMPATIBILITY_LEVEL` needs raising, which the existing instance supports without a migration.

---

## 4. Cross-document and internal inconsistencies

1. **Governance parity vs. behavioural change.** `BMMS-Current-State-Architecture.md` states that
   the listed governance workflows "must not be functionally altered during modernization." The
   delete-procedure guards in the same folder **do** alter behaviour: deletes that previously
   succeeded will now be refused. This needs an explicit, recorded sanction as a defect fix,
   otherwise the change reads as a parity violation.
2. **Sequencing conflict.** The architecture document places "Security Modernization" at Phase 5
   (⏳ Planned), while the recommendations call the Critical tier "Immediate." An unauthenticated
   endpoint that deletes every account cannot wait for Phase 5.
3. **Repository path.** Both `BMMS-Current-State-Architecture.md` and `modernization.txt` give the
   development repository as `C:\Repository\BMMS-Legacy` (singular). The actual path is
   `C:\Repositories\BMMS-Legacy` (plural). Minor, but it appears in a document marked
   "Approved Baseline."
4. **`ResetDatabase.aspx.cs` carried `className = "MinutesFinalization"`** — a copy/paste leftover
   that set the wrong page title. Corrected as part of the authorization fix.

---

## 5. Limitations of this errata

- The schema findings are drawn from **one** export. Anything not present there (procedures created
  later, permissions, SQL Agent jobs, linked servers) is outside this verification. The seven
  missing procedures in §3.3 should be confirmed against `sys.procedures`.
- Procedure definitions confirm *declared* behaviour, not runtime behaviour under load or with
  unusual data.
- No SQL Server instance was available here, so the corrected T-SQL changesets have been reviewed
  and reasoned about but **not executed**. They should be tested against the `C:\BMMS\BMMS\Source`
  recovery baseline before production.
- The item in "What Would Sharpen This Further" concerning actual usage data cannot be answered
  from the repository.
