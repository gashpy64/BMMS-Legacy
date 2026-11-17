using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using BMMS.Controls;
using BMMSBAL;

namespace BMMS.Master
{
    public partial class Followup : System.Web.UI.Page
    {
        private string className = "Followup";

        // Step UN6d: the messages of the two saves (decided on the server, BMMS-Fix-FollowupSave-Step46.sql)
        private const string ReadOnlyMessage = "You can read the followups. Your role cannot change them.";
        private const string NotSavedMessage = "You cannot change the followups: your role can only read them, or an item on the list no longer exists. Nothing was saved. Click View to read the list again.";
        private const string InactiveMessage = "Your account is not active. Nothing was saved. Sign in again.";
        private const string ActionTextSavedMessage = "The action text was saved.";
        private const string ActionTextFailedMessage = "The action text could not be saved. Nothing was saved. Try again.";
        private const string ActionTextBusyMessage = "The server is busy and the action text could not be saved. Nothing was saved. Wait a moment, then try again.";
        private const string ConfirmedFailedMessage = "The confirmations could not be saved. Nothing was saved. Try again.";
        private const string ConfirmedBusyMessage = "The server is busy and the confirmations could not be saved. Nothing was saved. Wait a moment, then try again.";

        // Step FU1 (BMMS-Fix-FollowupFinal-Step47.sql): a confirmed followup is final; the Controller can reopen it with a
        // reason. The Submit message gives the counts (ConfirmedMessage).
        private const string NothingChangedMessage = "No followup was changed to Confirmed. Nothing was saved.";
        private const string ActionTextConfirmedMessage = "This followup is confirmed and can no longer be changed. Nothing was saved. Click View to read the list again.";
        private const string ReopenedMessage = "The followup was reopened.";
        private const string ReopenNotConfirmedMessage = "This followup is no longer confirmed. Nothing was saved. Click View to read the list again.";
        private const string ReopenBlankMessage = "Enter the reason for reopening.";
        private const string ReopenTooLongMessage = "The reason can be at most 500 characters.";
        private const string ReopenFailedMessage = "The followup could not be reopened. Nothing was saved. Try again.";
        private const string ReopenBusyMessage = "The server is busy and the followup could not be reopened. Nothing was saved. Wait a moment, then try again.";
        private const string ListRefusedMessage = "You cannot read the followups: your role has no access to them.";
        private const string ListInactiveMessage = "Your account is not active. Sign in again.";

        #region CanSave
        // Step UN6d: only the Controller may change the followups; every other role that opens the page (MD
        // Secretariat) reads them. This decides what the page SHOWS only (Save, Submit, the drop-downs, Reopen, the
        // read-only line); every save is decided on the server from the acting user id, with the role read from the
        // database.
        private bool CanSave
        {
            get { return Convert.ToString(Session["RoleCode"]) == "controller"; }
        }
        #endregion

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            // Step UN6d: Submit and the read-only line by role, on every request. Step FU1: Submit only while the list
            // shown has a Pending row (kept in ViewState when the list is bound)
            btnSubmit.Visible = CanSave && Convert.ToBoolean(ViewState["HasPending"] ?? false);
            pFollowupReadOnly.InnerText = ReadOnlyMessage;
            pFollowupReadOnly.Visible = !CanSave;

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();

                pnlViewFollowup.Visible = false;
                pnlActualResolution.Visible = false;
                pnlActionText.Visible = false;
                pnlReopen.Visible = false;

                txtFromDate.Text = Common.GetFinStartDate();
                txtToDate.Text = DateTime.Now.ToString("dd-MMM-yyyy");
                LoadCommittee();
                rdoMeatingNoSearch.Enabled = false;
                LoadDepartment();
                pnlMeetingNoParticular.Visible = true;
                pnlMeetingNoParticular.Enabled = true;
                pnlMeetingNoBetween.Visible = false;
                MeetingNoSearchChanged();
            }
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnViewFollowup.Attributes.Add("onclick", "return MinutesFinalizeValidation()");
            //ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

            // Step FU1 (decision D5): the reason is checked in the browser before the post (FollowupReopenCheck in the page)
            btnReopenSave.OnClientClick = "return FollowupReopenCheck();";
            txtReopenReason.Attributes["maxlength"] = ActionItemMgr.ReopenReasonMaxLength.ToString(CultureInfo.InvariantCulture);
        }
        #endregion

        #region LoadCommittee
        private void LoadCommittee()
        {
            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(1);

                Common.LoadDDLwithAllNew(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadMeeting", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region LoadDepartment
        private void LoadDepartment()
        {
            try
            {
                DataTable dtDepartment = new DataTable();
                dtDepartment = DepartmentMgr.GetDepartmentList(1);

                Common.LoadDDLwithAllNew(ddlDepartment, dtDepartment, "DepartmentName", "DepartmentId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadDepartment", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                pnlViewFollowup.Visible = false;

                MeetingNoSearchChanged();

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ddlCommittee_SelectedIndexChanged", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region rdoMeatingNoSearch_SelectedIndexChanged
        protected void rdoMeatingNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MeetingNoSearchChanged();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "rdoMeatingNoSearch_SelectedIndexChanged", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region MeetingNoSearchChanged
        private void MeetingNoSearchChanged()
        {
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            pnlMeetingNoParticular.Visible = true;
            pnlMeetingNoParticular.Enabled = false;
            pnlMeetingNoBetween.Visible = false;
            rdoMeatingNoSearch.Enabled = false;

            if (CommitteeId > 0)
            {
                rdoMeatingNoSearch.Enabled = true;

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

                if (rdoMeatingNoSearch.SelectedValue == "0")  // 0 for Particular
                {
                    pnlMeetingNoParticular.Enabled = true;

                    Common.LoadDDLwithAllNew(ddlMeetingNo, dtMeeting, "MeetingNo", "MeetingId", true);

                    if (dtMeeting.Rows.Count > 0)
                        ddlMeetingNo.SelectedIndex = 0;
                }
                if (rdoMeatingNoSearch.SelectedValue == "1")  // 0 for Between
                {
                    pnlMeetingNoParticular.Visible = false;
                    pnlMeetingNoParticular.Enabled = false;
                    pnlMeetingNoBetween.Visible = true;

                    Common.LoadDropdownlist(ddlMeetingNoFrom, dtMeeting, "MeetingNo", "MeetingId", false);
                    Common.LoadDropdownlist(ddlMeetingNoTo, dtMeeting, "MeetingNo", "MeetingId", false);

                    if (dtMeeting.Rows.Count > 0)
                    {
                        ddlMeetingNoFrom.SelectedIndex = 0;
                        ddlMeetingNoTo.SelectedIndex = ddlMeetingNoTo.Items.Count - 1;
                    }
                }
            }
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            Response.Redirect("~/Master/Followup.aspx");
        }
        #endregion

        #region btnViewFollowup_Click
        protected void btnViewFollowup_Click(object sender, EventArgs e)
        {
            MsgHide();
            try
            {
                int UserId;
                if (!HasSessionUser(out UserId))
                    return;

                SaveFilter();
                BindFollowup(UserId);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnViewFollowup_Click", ex);
            }

        }
        #endregion

        #region SaveFilter
        // Step FU1: the filters of the list as chosen at View, kept so that the list read again after a Submit or a
        // Reopen is the same list (a filter changed since, without View, does not count)
        private void SaveFilter()
        {
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString().Trim());
            int MeetingNoSearch = int.Parse(rdoMeatingNoSearch.SelectedValue.ToString().Trim());

            int MeetingId = 0;
            int FromMeetingId = 0;
            int ToMeetingId = 0;

            if (CommitteeId > 0)
            {
                if (MeetingNoSearch == 0)
                    MeetingId = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());

                if (MeetingNoSearch == 1)
                {
                    FromMeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());
                    ToMeetingId = int.Parse(ddlMeetingNoTo.SelectedValue.ToString().Trim());
                }
            }

            int DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString().Trim());
            int ConfirmStatus = int.Parse(rdoConfirmStatus.SelectedValue.ToString().Trim());

            ViewState["FollowupFilter"] = new int[] { CommitteeId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId, DepartmentId, ConfirmStatus };
        }
        #endregion

        #region BindFollowup
        // Step FU1 (step 47): the list through spr_GetFollowupList (the rows and the order of the query before, with the
        // latest status row of each item), for the filters kept at View. The procedure decides from the acting user id
        // (Controller or MD Secretariat); refused, the list is empty and a message says so. The meeting date boxes are
        // not used by the list, as before (Known items).
        private void BindFollowup(int UserId)
        {
            pnlViewFollowup.Visible = true;

            int[] f = ViewState["FollowupFilter"] as int[];
            if (f == null || f.Length != 7)
            {
                SaveFilter();
                f = (int[])ViewState["FollowupFilter"];
            }

            int reason;
            DataTable dtFollowup = ActionItemMgr.GetFollowupList(UserId, f[0], f[1], f[2], f[3], f[4], f[5], f[6], out reason);

            bool hasPending = false;
            if (reason == 0)
            {
                foreach (DataRow row in dtFollowup.Rows)
                {
                    if (!IsConfirmedValue(row["IsConfirmed"]))
                    {
                        hasPending = true;
                        break;
                    }
                }
            }
            else
            {
                dtFollowup.Rows.Clear();
                MsgDisplay(reason == 8 ? ListInactiveMessage : ListRefusedMessage);
            }

            // Step FU1: no Submit while the list has no Pending row (closes the UN6d UX Low on the empty list)
            ViewState["HasPending"] = hasPending;
            btnSubmit.Visible = CanSave && hasPending;

            grvFollowup.DataSource = dtFollowup;
            grvFollowup.DataBind();
        }
        #endregion

        #region IsConfirmedValue
        // Step FU1: a confirmed item, as everywhere IsConfirmed is read (ISNULL(IsConfirmed, 0) <> 0); NULL is Pending
        private static bool IsConfirmedValue(object value)
        {
            if (value == null || value == DBNull.Value)
                return false;
            int n;
            return int.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), out n) && n != 0;
        }
        #endregion

        #region grvFollowup_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvFollowup_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    //e.Row.Attributes.Add("onmouseover", "MouseEvents(this, event)");
                    //e.Row.Attributes.Add("onmouseout", "MouseEvents(this, event)");

                    // Step FU1 (step 47): the Status cell. Pending: the Controller's drop-down (Pending chosen), or the word
                    // for a role that only reads, and the latest reopen when there is one. Confirmed: final; who and when
                    // (or "before history"), the Action Text as View for every role, and Reopen for the Controller. Every
                    // text from the database is encoded here (HttpUtility.HtmlEncode); the Literal writes it as it is.
                    DataRowView data = (DataRowView)e.Row.DataItem;
                    bool confirmed = IsConfirmedValue(data["IsConfirmed"]);
                    string action = Convert.ToString(data["StatusAction"]);

                    DropDownList ddlStatus = (DropDownList)e.Row.FindControl("ddlStatus");
                    Literal litStatus = (Literal)e.Row.FindControl("litStatus");
                    Button btnReopen = (Button)e.Row.FindControl("btnReopen");
                    Button btnActionText = (Button)e.Row.FindControl("btnActionText");

                    string html;
                    if (confirmed)
                    {
                        // No history row: confirmed before step 47. A latest row that is not a Confirm (confirmed again
                        // by an older build after a rollback): "Confirmed" without who and when
                        // Step FU2a: the texts from FollowupStatusText, shared with the Dashboard's panel
                        if (action == "Confirm")
                            html = StatusWord(FollowupStatusText.ConfirmedWord)
                                 + StatusLine(FollowupStatusText.ConfirmedLine(data["StatusByName"], data["StatusByLogin"], data["StatusByActive"], data["StatusOn"]));
                        else if (action.Length == 0)
                            html = StatusWord(FollowupStatusText.ConfirmedBeforeHistory);
                        else
                            html = StatusWord(FollowupStatusText.ConfirmedWord);
                    }
                    else
                    {
                        html = CanSave ? string.Empty : StatusWord("Pending");
                        if (action == "Reopen")
                            html += StatusLine(FollowupStatusText.ReopenedLine(data["StatusByName"], data["StatusByLogin"], data["StatusByActive"],
                                data["StatusOn"], data["StatusReason"]));
                    }

                    litStatus.Text = html;
                    ddlStatus.Visible = CanSave && !confirmed;
                    ddlStatus.SelectedValue = "0";
                    // A name per row for a screen reader (ASP.NET encodes the attribute value)
                    ddlStatus.Attributes["aria-label"] = "Status of agenda no. " + Convert.ToString(data["AgendaNo"])
                        + ", subject no. " + Convert.ToString(data["SubjectNo"]);
                    btnReopen.Visible = CanSave && confirmed;

                    // Step UN6d: a role that can only read sees "View" for the action text. Step FU1: a confirmed row too,
                    // for every role, the Controller included
                    if (btnActionText != null)
                    {
                        bool canEdit = CanSave && !confirmed;
                        btnActionText.Text = canEdit ? "Edit" : "View";
                        btnActionText.ToolTip = canEdit ? "Edit the action text" : "View the action text";
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowDataBound", ex);
            }
        }
        #endregion

        #region Status cell texts
        // Step FU1: the parts of the Status cell, each encoded. Step FU2a: the texts themselves (who and when, "Name
        // (login)" with " (inactive)", the database server's time) come from FollowupStatusText, shared with the
        // Dashboard's Action Item Details panel.
        private static string StatusWord(string text)
        {
            return "<span class=\"wb-followup-status\">" + HttpUtility.HtmlEncode(text) + "</span>";
        }

        private static string StatusLine(string text)
        {
            return "<span class=\"wb-followup-status-line\">" + HttpUtility.HtmlEncode(text) + "</span>";
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                //ViewState["DataTable"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["DataTable"]);

                //BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region grvFollowup_RowCommand
        protected void grvFollowup_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                MsgHide();

                int ActionItemId = int.Parse(e.CommandArgument.ToString());

                ViewState["ActionItemId"] = ActionItemId.ToString();

                DataTable dtActionItem = new DataTable();
                dtActionItem = ActionItemMgr.GetActionItemByActionItemId(ActionItemId);

                if (e.CommandName == "ViewActualResolution")
                {
                    pnlActualResolution.Visible = true;
                    ftxtActualResolution.Text = HtmlCleaner.Clean(dtActionItem.Rows[0]["ActualResolution"].ToString());
                }

                if (e.CommandName == "ViewActionText")
                {
                    pnlActionText.Visible = true;
                    ftxtActionText.Text = HtmlCleaner.Clean(dtActionItem.Rows[0]["ActionText"].ToString());

                    // Step UN6d: Save only for the Controller; another role reads the text, with the read-only line.
                    // Step FU1: a confirmed item opens as View for every role (as read now; the server refuses a save of
                    // a confirmed item too, Reason 26)
                    bool confirmed = IsConfirmedValue(dtActionItem.Rows[0]["IsConfirmed"]);
                    bool canSave = CanSave && !confirmed;
                    ftxtActionText.ReadOnly = !canSave;
                    btnActionTextSave.Visible = canSave;
                    btnActionTextCancel.Text = canSave ? "Cancel" : "Close";
                    litActionTextTitle.Text = canSave ? ":: Edit Action Text" : ":: View Action Text";
                    if (canSave)
                        HideActionTextPanelMessage();
                    else if (CanSave)
                        ShowActionTextPanelMessage(ActionTextConfirmedReadMessage);
                    else
                        ShowActionTextPanelMessage(ReadOnlyMessage);
                }

                // Step FU1: Reopen, the Controller only and a confirmed item only (the button is not rendered otherwise;
                // the server decides the save)
                if (e.CommandName == "Reopen" && CanSave)
                {
                    ViewState["ReopenActionItemId"] = ActionItemId.ToString(CultureInfo.InvariantCulture);
                    pReopenItem.InnerText = "Agenda No. " + Convert.ToString(dtActionItem.Rows[0]["AgendaNo"])
                        + ", Subject No. " + Convert.ToString(dtActionItem.Rows[0]["SubjectNo"])
                        + ", meeting " + Convert.ToString(dtActionItem.Rows[0]["MeetingNo"]);
                    txtReopenReason.Text = string.Empty;
                    HideReopenPanelMessage();
                    pnlReopen.Visible = true;
                    ScriptManager.GetCurrent(this).SetFocus(txtReopenReason.ClientID);
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowCommand", ex);
            }
        }
        #endregion

        // Step FU1: the line inside the Action Text panel when the Controller opens a confirmed item
        private const string ActionTextConfirmedReadMessage = "This followup is confirmed and can no longer be changed. Reopen it to change the action text.";

        #region btnActualResolutionCancel_Click
        protected void btnActualResolutionCancel_Click(object sender, EventArgs e)
        {
            pnlActualResolution.Visible = false;
            ftxtActualResolution.Text = string.Empty;   // step A3: a closed panel keeps no text in view state
        }
        #endregion

        #region btnActionTextCancel_Click
        protected void btnActionTextCancel_Click(object sender, EventArgs e)
        {
            CloseActionTextPanel();
        }
        #endregion

        #region btnActionTextSave_Click
        // Step UN6d: the save goes through spr_SaveFollowupActionText (step 46), which decides on the server from the
        // acting user id: only an active Controller; it writes the action text only, as before. Saved or refused, the
        // panel closes with a message; a failed save keeps the panel open with the text typed and says so inside it.
        // Step FU1 (step 47): a confirmed item is refused (Reason 26), nothing saved.
        protected void btnActionTextSave_Click(object sender, EventArgs e)
        {
            MsgHide();

            // Step A3: rich text over the limit (Web.config): nothing is saved, the panel stays open.
            // Step UN6d: the message on the line inside the open panel (the page's message box lies under it)
            if (RichTextEditor.IsTooLong(this)) { ShowActionTextPanelMessage(RichTextLimits.TooLongMessage); return; }

            int UserId;
            if (!HasSessionUser(out UserId))
                return;

            int ActionItemId;
            if (!int.TryParse(Convert.ToString(ViewState["ActionItemId"]), out ActionItemId))
            {
                CloseActionTextPanel();
                MsgDisplay(NotSavedMessage);
                return;
            }

            string ActionText = ftxtActionText.Text.Trim();

            int reason;
            try
            {
                reason = ActionItemMgr.SaveFollowupActionText(UserId, ActionItemId, ActionText);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnActionTextSave_Click", ex.ToString());
                ShowActionTextPanelMessage(Common.IsServerBusy(ex) ? ActionTextBusyMessage : ActionTextFailedMessage);
                return;
            }

            CloseActionTextPanel();   // step A3: saved or refused, the panel closes and keeps no text

            if (reason == 0)
                MsgDisplay(ActionTextSavedMessage, MessageKind.Success);
            else if (reason == 8)
                MsgDisplay(InactiveMessage);
            else if (reason == 26)
                MsgDisplay(ActionTextConfirmedMessage);
            else
                MsgDisplay(NotSavedMessage);
        }
        #endregion


        #region btnSubmit_Click
        // Step FU1 (step 47): ONE call to spr_SaveFollowupConfirmed with only the rows changed from Pending to Confirmed;
        // rows left Pending and rows already confirmed are not sent. One transaction, all or nothing; the server decides
        // from the acting user id (only an active Controller), skips a row confirmed in between and refuses the whole
        // Submit when an item no longer exists. No row changed: nothing is sent. Afterwards the list is read again with
        // the filters of View.
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            if (!HasSessionUser(out UserId))
                return;

            List<int> ids = new List<int>();
            foreach (GridViewRow gr in grvFollowup.Rows)
            {
                if (gr.RowType != DataControlRowType.DataRow)
                    continue;

                Label lblActionItemId = (Label)gr.FindControl("lblActionItemId");
                Label lblIsConfirmed = (Label)gr.FindControl("lblIsConfirmed");
                DropDownList ddlStatus = (DropDownList)gr.FindControl("ddlStatus");
                if (lblActionItemId == null || lblIsConfirmed == null || ddlStatus == null)
                {
                    MsgDisplay(NotSavedMessage);
                    return;
                }

                // Only a Pending row (as read at View) whose drop-down was changed to Confirmed
                if (!ddlStatus.Visible || IsConfirmedValue(lblIsConfirmed.Text.Trim()) || ddlStatus.SelectedValue != "1")
                    continue;

                int ActionItemId;
                if (!int.TryParse(lblActionItemId.Text.Trim(), out ActionItemId))
                {
                    // A row whose item cannot be read: nothing is sent, nothing is saved
                    MsgDisplay(NotSavedMessage);
                    return;
                }

                ids.Add(ActionItemId);
            }

            if (ids.Count == 0)
            {
                MsgDisplay(NothingChangedMessage);
                return;
            }

            int reason;
            int saved;
            int skipped;
            try
            {
                reason = ActionItemMgr.SaveFollowupConfirmed(UserId, ids, out saved, out skipped);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnSubmit_Click", ex.ToString());
                MsgDisplay(Common.IsServerBusy(ex) ? ConfirmedBusyMessage : ConfirmedFailedMessage);
                return;
            }

            if (reason == 0)
            {
                RebindAfterSave(UserId);
                MsgDisplay(ConfirmedMessage(saved, skipped), saved > 0 ? MessageKind.Success : MessageKind.Warning);
            }
            else if (reason == 8)
                MsgDisplay(InactiveMessage);
            else
                MsgDisplay(NotSavedMessage);

            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
        }
        #endregion

        #region ConfirmedMessage
        // Step FU1: "3 followups were confirmed." / "1 followup was confirmed." / "No followup was confirmed.", and
        // "[m] had already been confirmed." for the rows skipped (another Controller, or the same one in another tab)
        private static string ConfirmedMessage(int saved, int skipped)
        {
            string text = saved == 0 ? "No followup was confirmed."
                        : saved == 1 ? "1 followup was confirmed."
                        : saved.ToString(CultureInfo.InvariantCulture) + " followups were confirmed.";
            if (skipped > 0)
                text += " " + skipped.ToString(CultureInfo.InvariantCulture) + " had already been confirmed.";
            return text;
        }
        #endregion

        #region btnReopenSave_Click
        // Step FU1 (step 47): the Save of the Reopen panel, one item at once, through spr_ReopenFollowup, which decides on
        // the server from the acting user id (only an active Controller) and reopens only an item still confirmed. The
        // reason is trimmed, not blank, at most 500 characters (checked here first; the panel stays open with the text).
        // Reopened or refused, the panel closes with a message and the list is read again; a failure keeps it open.
        protected void btnReopenSave_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            if (!HasSessionUser(out UserId))
                return;

            int ActionItemId;
            if (!CanSave || !int.TryParse(Convert.ToString(ViewState["ReopenActionItemId"]), out ActionItemId))
            {
                CloseReopenPanel();
                MsgDisplay(NotSavedMessage);
                return;
            }

            // A line break is posted as CR LF but counted as one character by the box: stored as LF, so the limit is the
            // same in the browser and here
            string text = (txtReopenReason.Text ?? string.Empty).Replace("\r\n", "\n").Trim();
            if (text.Length == 0)
            {
                ShowReopenPanelMessage(ReopenBlankMessage);
                ScriptManager.GetCurrent(this).SetFocus(txtReopenReason.ClientID);
                return;
            }
            if (text.Length > ActionItemMgr.ReopenReasonMaxLength)
            {
                ShowReopenPanelMessage(ReopenTooLongMessage);
                ScriptManager.GetCurrent(this).SetFocus(txtReopenReason.ClientID);
                return;
            }

            int reason;
            try
            {
                reason = ActionItemMgr.ReopenFollowup(UserId, ActionItemId, text);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnReopenSave_Click", ex.ToString());
                ShowReopenPanelMessage(Common.IsServerBusy(ex) ? ReopenBusyMessage : ReopenFailedMessage);
                return;
            }

            CloseReopenPanel();

            if (reason == 0)
            {
                // The Status choices not yet submitted (Confirmed on other Pending rows) are kept across the list read
                List<int> chosen = ChosenConfirmed();
                RebindAfterSave(UserId);
                ApplyChosenConfirmed(chosen);
                MsgDisplay(ReopenedMessage, MessageKind.Success);
            }
            else if (reason == 8)
                MsgDisplay(InactiveMessage);
            else if (reason == 27)
                MsgDisplay(ReopenNotConfirmedMessage);
            else
                MsgDisplay(NotSavedMessage);

            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
        }
        #endregion

        #region btnReopenCancel_Click
        protected void btnReopenCancel_Click(object sender, EventArgs e)
        {
            CloseReopenPanel();
        }
        #endregion

        #region RebindAfterSave
        // Step FU1: after a done Submit or Reopen, the list read again with the filters of View. A failure of that read
        // goes to the error page as View does; the save is done by then.
        private void RebindAfterSave(int UserId)
        {
            try
            {
                BindFollowup(UserId);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "RebindAfterSave", ex);
            }
        }
        #endregion

        #region ChosenConfirmed
        // Step FU1: the ids of the Pending rows whose drop-down is set to Confirmed but not yet submitted
        private List<int> ChosenConfirmed()
        {
            List<int> ids = new List<int>();
            foreach (GridViewRow gr in grvFollowup.Rows)
            {
                if (gr.RowType != DataControlRowType.DataRow)
                    continue;
                Label lblActionItemId = (Label)gr.FindControl("lblActionItemId");
                DropDownList ddlStatus = (DropDownList)gr.FindControl("ddlStatus");
                int id;
                if (lblActionItemId != null && ddlStatus != null && ddlStatus.Visible && ddlStatus.SelectedValue == "1"
                    && int.TryParse(lblActionItemId.Text.Trim(), out id))
                    ids.Add(id);
            }
            return ids;
        }

        // Step FU1: those choices set again on the rows that are still Pending after the list was read again
        private void ApplyChosenConfirmed(List<int> ids)
        {
            if (ids == null || ids.Count == 0)
                return;
            foreach (GridViewRow gr in grvFollowup.Rows)
            {
                if (gr.RowType != DataControlRowType.DataRow)
                    continue;
                Label lblActionItemId = (Label)gr.FindControl("lblActionItemId");
                DropDownList ddlStatus = (DropDownList)gr.FindControl("ddlStatus");
                int id;
                if (lblActionItemId != null && ddlStatus != null && ddlStatus.Visible
                    && int.TryParse(lblActionItemId.Text.Trim(), out id) && ids.Contains(id))
                    ddlStatus.SelectedValue = "1";
            }
        }
        #endregion

        #region CloseReopenPanel
        // Step FU1: the Reopen panel closed, with no text and no line
        private void CloseReopenPanel()
        {
            pnlReopen.Visible = false;
            txtReopenReason.Text = string.Empty;
            pReopenItem.InnerText = string.Empty;
            ViewState.Remove("ReopenActionItemId");
            HideReopenPanelMessage();
        }

        private void ShowReopenPanelMessage(string message)
        {
            pReopenPanelMessage.InnerText = message;
            pReopenPanelMessage.Visible = true;
        }

        private void HideReopenPanelMessage()
        {
            pReopenPanelMessage.InnerText = string.Empty;
            pReopenPanelMessage.Visible = false;
        }
        #endregion

        #region CloseActionTextPanel
        // Step UN6d: the Action Text panel closed, with no text in its editor (step A3) and no line
        private void CloseActionTextPanel()
        {
            pnlActionText.Visible = false;
            ftxtActionText.Text = string.Empty;
            HideActionTextPanelMessage();
        }
        #endregion

        #region ShowActionTextPanelMessage
        // Step UN6d: the line inside the Action Text panel, above its buttons (plain text): the read-only line, or a
        // failed save, a busy server or a text that is too long. Cleared when the panel opens and when it closes.
        private void ShowActionTextPanelMessage(string message)
        {
            pActionTextPanelMessage.InnerText = message;
            pActionTextPanelMessage.Visible = true;
        }

        private void HideActionTextPanelMessage()
        {
            pActionTextPanelMessage.InnerText = string.Empty;
            pActionTextPanelMessage.Visible = false;
        }
        #endregion

        #region HasSessionUser
        // Step UN6d: a session without a usable user id is treated as expired (as the Dashboard does, step F2)
        private bool HasSessionUser(out int UserId)
        {
            UserId = 0;
            if (Session["UserId"] == null || !int.TryParse(Session["UserId"].ToString(), out UserId))
            {
                Response.Redirect("~/", true);
                return false;
            }
            return true;
        }
        #endregion



        #region MsgDisplay
        // The message box. Only the fixed texts of this page and numbers are written here (InnerHtml), never a text
        // from the database.
        private void MsgDisplay(string errMsg, MessageKind kind = MessageKind.Warning)
        {
            divErrLogin.Attributes.Add("class", Common.MessageCss(kind));
            spanErrLogin.InnerHtml = errMsg;
        }
        #endregion

        #region MsgHide
        private void MsgHide()
        {
            divErrLogin.Attributes.Add("class", "divErrorHide");
        }
        #endregion

    }
}
