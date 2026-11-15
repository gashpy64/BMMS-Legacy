using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Collections.Generic;
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
        private const string ConfirmedSavedMessage = "The confirmations were saved.";
        private const string ConfirmedFailedMessage = "The confirmations could not be saved. Nothing was saved. Try again.";
        private const string ConfirmedBusyMessage = "The server is busy and the confirmations could not be saved. Nothing was saved. Wait a moment, then try again.";

        #region CanSave
        // Step UN6d: only the Controller may change the followups; every other role that opens the page (MD
        // Secretariat) reads them. This decides what the page SHOWS only (Save, Submit, the ticks, the read-only
        // line); every save is decided on the server from the acting user id, with the role read from the database.
        private bool CanSave
        {
            get { return Convert.ToString(Session["RoleCode"]) == "controller"; }
        }
        #endregion

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            // Step UN6d: Submit and the read-only line by role, on every request
            btnSubmit.Visible = CanSave;
            pFollowupReadOnly.InnerText = ReadOnlyMessage;
            pFollowupReadOnly.Visible = !CanSave;

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();

                pnlViewFollowup.Visible = false;
                pnlActualResolution.Visible = false;
                pnlActionText.Visible = false;

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
            string sMsg = string.Empty;
            try
            {
                DataTable dtFollowup = new DataTable();
                dtFollowup = GetFollowup();

                grvFollowup.DataSource = dtFollowup;
                grvFollowup.DataBind();

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnViewFollowup_Click", ex);
            }

        }
        #endregion


        #region GetFollowup
        private DataTable GetFollowup()
        {
            pnlViewFollowup.Visible = true;

            DateTime FromMeetingDate = Convert.ToDateTime(txtFromDate.Text.Trim());
            DateTime ToMeetingDate = Convert.ToDateTime(txtToDate.Text.Trim());
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

            DataTable dtFollowup = ReportsMgr.GetFollowupReport(FromMeetingDate, ToMeetingDate, CommitteeId,
                MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId, DepartmentId, ConfirmStatus);

            ViewState["GetFollowup"] = dtFollowup;

            return dtFollowup;
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

                    Label lblIsConfirmed = (Label)e.Row.FindControl("lblIsConfirmed");

                    CheckBox chkIsConfirmed = (CheckBox)e.Row.FindControl("chkIsConfirmed");

                    if (lblIsConfirmed.Text.Trim() == "1")
                        chkIsConfirmed.Checked = true;
                    else
                        chkIsConfirmed.Checked = false;

                    // Step UN6d: a role that can only read sees the ticks disabled and "View" for the action text
                    if (!CanSave)
                    {
                        chkIsConfirmed.Enabled = false;
                        Button btnActionText = (Button)e.Row.FindControl("btnActionText");
                        if (btnActionText != null)
                            btnActionText.Text = "View";
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowDataBound", ex);
            }
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

                    // Step UN6d: Save only for the Controller; another role reads the text, with the read-only line
                    bool canSave = CanSave;
                    ftxtActionText.ReadOnly = !canSave;
                    btnActionTextSave.Visible = canSave;
                    btnActionTextCancel.Text = canSave ? "Cancel" : "Close";
                    litActionTextTitle.Text = canSave ? ":: Edit Action Text" : ":: View Action Text";
                    if (canSave)
                        HideActionTextPanelMessage();
                    else
                        ShowActionTextPanelMessage(ReadOnlyMessage);
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowCommand", ex);
            }
        }
        #endregion

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
            else
                MsgDisplay(NotSavedMessage);
        }
        #endregion


        #region btnSubmit_Click
        // Step UN6d: every row of the list in ONE call to spr_SaveFollowupConfirmed (step 46), in one transaction: all
        // rows are saved or none. The server decides from the acting user id: only an active Controller; one row that
        // is not allowed (an item that no longer exists) refuses the whole Submit. It writes for each row what the page
        // wrote before (IsComplied 0, IsConfirmed the tick; a tick sets the item's mapping rows to StatusId 0).
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            if (!HasSessionUser(out UserId))
                return;

            List<KeyValuePair<int, bool>> rows = new List<KeyValuePair<int, bool>>();
            foreach (GridViewRow gr in grvFollowup.Rows)
            {
                if (gr.RowType != DataControlRowType.DataRow)
                    continue;

                int ActionItemId;
                Label lblActionItemId = (Label)gr.FindControl("lblActionItemId");
                CheckBox chkIsConfirmed = (CheckBox)gr.FindControl("chkIsConfirmed");
                if (lblActionItemId == null || chkIsConfirmed == null || !int.TryParse(lblActionItemId.Text.Trim(), out ActionItemId))
                {
                    // A row whose item cannot be read: nothing is sent, nothing is saved
                    MsgDisplay(NotSavedMessage);
                    return;
                }

                rows.Add(new KeyValuePair<int, bool>(ActionItemId, chkIsConfirmed.Checked));
            }

            int reason;
            int saved;
            try
            {
                reason = ActionItemMgr.SaveFollowupConfirmed(UserId, rows, out saved);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnSubmit_Click", ex.ToString());
                MsgDisplay(Common.IsServerBusy(ex) ? ConfirmedBusyMessage : ConfirmedFailedMessage);
                return;
            }

            if (reason == 0)
                MsgDisplay(ConfirmedSavedMessage, MessageKind.Success);
            else if (reason == 8)
                MsgDisplay(InactiveMessage);
            else
                MsgDisplay(NotSavedMessage);

            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
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
