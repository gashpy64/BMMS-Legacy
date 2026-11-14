# Mail

- Title: Mail
- Audience: Developers and installers (internal)
- Shipped: No
- Applies to: UN6c2a (section "Recipients and addresses", one paragraph: no mail change, who may decide); UN6c1 (section "Recipients and addresses", the Admin role left out); the rest user-ud1a
- Last updated by: UN6c2a, based on 493cb45
- Status: Draft
- Verified against: for UN6c2a: BMMS/DashBoard/DashBoard.aspx.cs (btnApprove_Click and btnReject_Click read in full: the mail after Result 1 only), Database/BMMS-Fix-AgendaWaitingFor-Step44.sql (spr_UpdateAgendaByAgendaId: nothing written or mailed changes); for UN6c1: Database/BMMS-Fix-DashboardAlerts-Step43.sql (the two mail procedures, comment and text), BMMS-Rollback-DashboardAlerts-Step43.sql (messages), Database/README.md (section Step UN6c1: callers checked)
- To confirm: chapter not written yet (WF2b2), except the Admin rule of step UN6c1

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
five procedures that write alerts still add alert rows for Admins until step UD1b; those rows are not listed and
get no mail. To undo, BMMS-Rollback-DashboardAlerts-Step43.sql puts both procedures back as the texts of steps 18
and 37.

Step 44 (UN6c2a) changes no recipient and no mail text. It changes who is offered Approve and Reject and who is
refused: the page asks the server (`spr_GetAgendaApprovalState`, from `fn_AgendaWaitingFor`) before it shows the
buttons, and again before a decision, and the approval procedure refuses an acting user the rule does not allow
(Reason 14). In BMMS/DashBoard/DashBoard.aspx.cs the mail for "approved by Manager", "approved by Controller" and
the two rejections is generated only after the procedure returns Result 1, as before; so a refusal (Reason 14, a
meeting date that has passed, or a state that cannot be read) sends no mail. A mail that fails after the decision
leaves the decision saved and shows the existing "not sent" warning.

[[CONFIRM: the rest of this section (who gets which mail) is not written yet (WF2b2)]]

## Mail failure after a save

[[CONFIRM: not written yet (WF2b2)]]

## Mail log

[[CONFIRM: not written yet (WF2b2)]]
