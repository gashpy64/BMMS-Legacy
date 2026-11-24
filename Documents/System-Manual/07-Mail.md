# Mail

- Title: Mail
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UD1c (step 54: section "Recipients and addresses", one paragraph: no recipient change, the department in the Created mail of a Manager); UD1b (step 53: section "Recipients and addresses", the table of recipients); UN6c2a (section "Recipients and addresses", one paragraph: no mail change, who may decide); UN6c1 (section "Recipients and addresses", the Admin role left out); the rest user-ud1a
- Commit: 42cb88c
- Last updated by: UD1c, based on 42cb88c
- Status: Draft
- Verified against: for UD1c: BMMS/Master/Agenda.aspx.cs (diff: the department text in GenerateMail), Database/README.md (section Step UD1c); the mail procedures were not changed by step 54 (not in the Fix script's list of objects); for UD1b: Database/BMMS-Fix-DepartmentApprovers-Step53.sql (spr_GetAlertMailId, spr_GetAgendaUpdateMailId, spr_GetAgendaCreationMailId, read in full), BMMS/Master/Agenda.aspx.cs (diff: GenerateMail, the Controller line, the Admin Bcc rule); for UN6c2a: BMMS/DashBoard/DashBoard.aspx.cs (btnApprove_Click and btnReject_Click read in full: the mail after Result 1 only), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (spr_UpdateAgendaByAgendaId: nothing written or mailed changes); for UN6c1: Database/BMMS-Fix-DashboardAlerts-Step43.sql (the two mail procedures, comment and text), BMMS-Rollback-DashboardAlerts-Step43.sql (messages), Database/README.md (section Step UN6c1: callers checked)
- To confirm: chapter not written yet (WF2b2), except the Admin rule of step UN6c1 and the recipient table of step UD1b

## Mail server settings

[[CONFIRM: not written yet (WF2b2)]]

## When mail is sent

[[CONFIRM: not written yet (WF2b2)]]

## Recipients and addresses

Only the part changed in step UN6c1 is written here; the rest is still to be written (WF2b2).

No functional mail goes to the Admin role (step 43, owner decision UN6c: the Admin role gets no functional
alerts). Both recipient procedures leave it out:

- `spr_GetAlertMailId` (called from BMMS/DashBoard/DashBoard.aspx.cs for the approve and reject mail and from
  BMMS/Master/AgendaFinalization.aspx.cs) leaves the Admin role out in every branch: AMR the creator, AMA the
  Controllers and the creator, ACA and ACR the users of the item's alert.
- `spr_GetAgendaUpdateMailId` (called from BMMS/Master/Agenda.aspx.cs for the update mail) leaves it out too.

The Controller, the Manager and the creator get their mails as before; the other conditions (active users, not
the protected system account, with an address) are unchanged. No other procedure calls either of the two. The
five procedures that write alerts added alert rows for Admins until step UD1b (step 53 stopped that; older rows stay); those rows are not listed and
get no mail. To undo, BMMS-Rollback-DashboardAlerts-Step43.sql puts both procedures back as the texts of steps 18
and 37.

Step 44 (UN6c2a) changes no recipient and no mail text. It changes who is offered Approve and Reject and who is
refused: the page asks the server (`spr_GetAgendaApprovalState`, from `fn_AgendaWaitingFor`) before it shows the
buttons, and again before a decision, and the approval procedure refuses an acting user the rule does not allow
(Reason 14). In BMMS/DashBoard/DashBoard.aspx.cs the mail for "approved by Manager", "approved by Controller" and
the two rejections is generated only after the procedure returns Result 1, as before; so a refusal (Reason 14, a
meeting date that has passed, or a state that cannot be read) sends no mail. A mail that fails after the decision
leaves the decision saved and shows the existing "not sent" warning.

Step 53 (UD1b, any Manager of the item's department approves) changes the recipient lists below. The Admin role is in none of
them, and no mail text changes except the one added line of the Created mail.

| Mail | Recipients since step 53 | Where it lives |
|---|---|---|
| "Agenda created" of a User's new item (BMMS/Master/Agenda.aspx.cs, GenerateMail) | Route M (waits at AC): every active Manager of the item's department other than the creator, in Bcc. Route C (straight to the Controllers): the active Controllers. When the item was sent to the Controller because the department had no active Manager (setting "Sent to the Controller"), the body adds "Sent to the Controller: the department had no active Manager." | spr_GetAgendaCreationMailId (@DepartmentId); fn_AgendaRoute; fn_DepartmentManagers |
| "Agenda created" of a Manager's or the Controller's own item | The Reporting Person gets a Bcc as before, except when the Reporting Person has the Admin role (no Bcc) | BMMS/Master/Agenda.aspx.cs (GenerateMail) |
| Approved or rejected by a Manager (AMA, AMR) | As before (the Controllers and the creator for AMA; the creator for AMR), and also every other active Manager of the item's department (the Manager who decided is left out) | spr_GetAlertMailId |
| Approved or rejected by the Controller (ACA, ACR) | The users of the item's alert as before, but not a row marked as handled: a Manager who was handled ('H', 'N' or 'M') gets no later mail of the item | spr_GetAlertMailId |
| "Agenda updated" | The users the refreshed alert is shown to, as before, but not a row marked as handled | spr_GetAgendaUpdateMailId |

Step 54 (UD1c, lists for Managers with several departments) changes no recipient list. In the Created mail of a Manager's new item the
Department row names the department he chose in the form (BMMS/Master/Agenda.aspx.cs, GenerateMail: the name without the "(home)"
mark); a new item of a Manager now also gives an alert (not a mail) to the other active Managers of its department (chapter 04,
"Step 54 (UD1c)"). A refusal of Reason 30 sends no mail.

The Created mail is sent after the database accepted the item, so a refusal (Reason 29, 11 or 15) sends none. If the mail fails,
the item stays saved and the "not sent" message carries the Controller line too ("Sent to the Controller: the department had no
active Manager."). Alerts for the Admin role are no longer written by the procedures of the agenda, the meeting and the committee
(chapter 04, "Step 53 (UD1b)"); the older rows stay and are not listed.

[[CONFIRM: the rest of this section (who gets which mail) is not written yet (WF2b2)]]

## Mail failure after a save

[[CONFIRM: not written yet (WF2b2)]]

## Mail log

[[CONFIRM: not written yet (WF2b2)]]
