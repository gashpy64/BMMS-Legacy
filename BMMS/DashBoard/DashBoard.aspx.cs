using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Web;
using System.Web.Security;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Web.UI.WebControls.WebParts;
using System.Web.UI.HtmlControls;
using BMMS.Controls;
using BMMSBAL;

namespace BMMS.DashBoard
{
    public partial class DashBoard : System.Web.UI.Page
    {
        private string className = "DashBoard";

        // The approval or rejection is saved before the mail goes out (step M3); the mail error itself is in the error log
        private const string ApprovedMailNotSentMessage = "The item was approved, but the mail could not be sent. The error is in the error log.";
        private const string RejectedMailNotSentMessage = "The item was rejected, but the mail could not be sent. The error is in the error log.";

        // After the meeting date an agenda item can no longer be approved or rejected, for every role (step M6a)
        private const string MeetingDatePassedMessage = "The meeting date has passed, so this item can no longer be approved or rejected. It will be rejected when the agenda is finalized.";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadAlertGRV();
                LoadActionItemGRV();
                pnlAgenda.Visible = false;
                pnlActionItemDetails.Visible = false;
            }
        }
        #endregion

        #region LoadAlertGRV
        // Step UN6c1: the Alerts card from spr_GetDashboardAlerts (step 43). The procedure reads the role from the
        // acting user id and lists by its one rule (an Admin gets no functional alerts); the page sends the acting
        // user id, the mode chosen with the three links and the page number, and the procedure checks both. Only
        // the page shown is read; nothing is kept in ViewState but the mode and the page number.
        private const string AlertsFailedMessage = "The alerts could not be loaded. Reload the page to try again.";
        private const string AlertsBusyMessage = "The server is busy and the alerts could not be loaded. Wait a moment, then reload the page.";
        private const string AlertsInactiveMessage = "The alerts are not available: your account is not active. Sign in again.";
        private const string AlertNotInListMessage = "This alert is not in your list.";
        private const string AlertNotRemovedMessage = "The alert could not be removed from your list. Try again.";

        // R recent (the default), U unread, A all
        private string AlertMode
        {
            get
            {
                string mode = Convert.ToString(ViewState["AlertMode"]);
                return mode == "U" || mode == "A" ? mode : "R";
            }
            set { ViewState["AlertMode"] = value; }
        }

        private int AlertPage
        {
            get
            {
                object page = ViewState["AlertPage"];
                return page is int && (int)page > 0 ? (int)page : 1;
            }
            set { ViewState["AlertPage"] = value; }
        }

        private void LoadAlertGRV()
        {
            int UserId;
            string RoleName;
            if (!HasSessionUser(out UserId, out RoleName))
                return;

            MarkCurrent(lnkRecent, AlertMode == "R");
            MarkCurrent(lnkUnread, AlertMode == "U");
            MarkCurrent(lnkAll, AlertMode == "A");

            try
            {
                int reason, totalRows, unreadCount, pageShown;
                DataTable dtAlert = AlertMgr.GetDashboardAlerts(UserId, AlertMode, AlertPage, out reason, out totalRows, out unreadCount, out pageShown);

                if (reason != 0)
                    ShowAlertsMessage(reason == 8 ? AlertsInactiveMessage : AlertsFailedMessage);
                else
                {
                    AlertPage = pageShown;
                    pAlertsMessage.Visible = false;
                    grvAlert.Visible = true;
                    grvAlert.VirtualItemCount = totalRows;
                    grvAlert.PageIndex = pageShown - 1;
                    grvAlert.DataSource = dtAlert;
                    grvAlert.DataBind();
                }
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "LoadAlertGRV", ex.ToString());
                ShowAlertsMessage(Common.IsServerBusy(ex) ? AlertsBusyMessage : AlertsFailedMessage);
            }

            // Every action of the page that can change the count reloads this list (Approve, Reject, Remove from my
            // list, the three links): the header count follows, without a page reload
            if (IsPostBack)
                RefreshHeaderCount();
        }

        // The link of the list that is shown: the class (bold in the card, bmms-workbench.css) and aria-current
        private static void MarkCurrent(LinkButton link, bool current)
        {
            link.CssClass = current ? "bmms-filter-current" : "";
            if (current)
                link.Attributes["aria-current"] = "true";
            else
                link.Attributes.Remove("aria-current");
        }

        // A failed load: the message instead of the list and its pager
        private void ShowAlertsMessage(string message)
        {
            pAlertsMessage.InnerText = message;
            pAlertsMessage.Visible = true;
            grvAlert.Visible = false;
        }

        // "Alerts (n)" in the header (Main.Master), which UpdatePanel1 does not redraw
        private void RefreshHeaderCount()
        {
            BMMS.MasterPage.Main master = Master as BMMS.MasterPage.Main;
            if (master != null)
                master.RefreshAlertCount();
        }
        #endregion

        #region LoadActionItemGRV
        // Step UN6c1: the card from spr_GetDashboardActionItems (step 43). The procedure decides the rows from the
        // acting user id and the role it reads from the database: a Controller and Management get every item that is
        // not confirmed, a Manager and a User those of their departments with finalised or confirmed minutes, each
        // with the person's own read state and IsOverdue. For a role without the card (MD Secretariat, Admin) it
        // answers Reason 4 and the card is hidden. A failed load shows a message instead of the list.
        private const string ActionItemNotSavedMessage = "You cannot change this action item: your role can only read it, or it is not an item of your department. Nothing was saved.";
        private const string ActionItemInactiveMessage = "Your account is not active. Nothing was saved. Sign in again.";
        private const string ActionItemSaveFailedMessage = "The action text could not be saved. Nothing was saved. Try again.";
        private const string ActionItemSaveBusyMessage = "The server is busy and the action text could not be saved. Nothing was saved. Wait a moment, then try again.";
        private const string ActionItemsFailedMessage = "The action items could not be loaded. Reload the page to try again.";
        private const string ActionItemsBusyMessage = "The server is busy and the action items could not be loaded. Wait a moment, then reload the page.";
        private const string ActionItemsInactiveMessage = "The action items are not available: your account is not active. Sign in again.";

        // A all (Show All, the default), R read, U unread. The link chosen stays chosen until another is clicked:
        // every load and every page of the list uses this mode, and the mark on the links is set from it in
        // LoadActionItemGRV only (owner's test of UN6c1: after opening an item the mark said Unread and the list
        // showed everything).
        private string ActionMode
        {
            get
            {
                string mode = Convert.ToString(ViewState["ActionMode"]);
                return mode == "R" || mode == "U" ? mode : "A";
            }
            set { ViewState["ActionMode"] = value; }
        }

        private void LoadActionItemGRV()
        {
            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            MarkCurrent(lnkActShowall, ActionMode == "A");
            MarkCurrent(lnkActRead, ActionMode == "R");
            MarkCurrent(lnkActUnRead, ActionMode == "U");

            try
            {
                int reason;
                DataTable dtActionItem = ActionItemMgr.GetDashboardActionItems(UserId, out reason);

                if (reason == 4)
                {
                    // The server's answer, not the role in the session: this role has no Action Items card
                    ViewState["dtActionItem"] = null;
                    cardActionItems.Visible = false;
                    return;
                }

                cardActionItems.Visible = true;

                if (reason != 0)
                {
                    ViewState["dtActionItem"] = null;
                    ShowActionItemsMessage(reason == 8 ? ActionItemsInactiveMessage : ActionItemsFailedMessage);
                    return;
                }

                pActionItemsMessage.Visible = false;
                grvActionItem.Visible = true;
                ViewState["dtActionItem"] = dtActionItem;
                BindActionItemGRV(dtActionItem);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "LoadActionItemGRV", ex.ToString());
                ViewState["dtActionItem"] = null;
                cardActionItems.Visible = true;
                ShowActionItemsMessage(Common.IsServerBusy(ex) ? ActionItemsBusyMessage : ActionItemsFailedMessage);
            }
        }

        private void ShowActionItemsMessage(string message)
        {
            pActionItemsMessage.InnerText = message;
            pActionItemsMessage.Visible = true;
            grvActionItem.Visible = false;
        }
        #endregion

        #region BindActionItemGRV
        // Binds the rows of the mode chosen (ActionMode) from the whole list
        private void BindActionItemGRV(DataTable dtActionItem)
        {
            if (dtActionItem != null && ActionMode != "A")
            {
                DataView dv = new DataView(dtActionItem);
                dv.RowFilter = ActionMode == "R" ? "ReadStatus = 1" : "ReadStatus = 0";
                dtActionItem = dv.ToTable("dtActionItem");
            }

            // A page that no longer exists (the last row of the last page left the list): the last page there is
            int rows = dtActionItem == null ? 0 : dtActionItem.Rows.Count;
            int lastPage = rows == 0 ? 0 : (rows - 1) / grvActionItem.PageSize;
            if (grvActionItem.PageIndex > lastPage)
                grvActionItem.PageIndex = lastPage;

            grvActionItem.DataSource = dtActionItem;
            grvActionItem.DataBind();
        }
        #endregion

        #region AlertMode_Click
        // Step UN6c1: Recent, Unread, All (the CommandArgument R, U, A); the list starts at its first page again
        protected void AlertMode_Click(object sender, EventArgs e)
        {
            AlertMode = ((LinkButton)sender).CommandArgument;
            AlertPage = 1;
            LoadAlertGRV();
        }
        #endregion

        #region Action Items: Show All, Read, Unread
        protected void lnkActShowall_Click(object sender, EventArgs e)
        {
            ChooseActionMode("A");
        }

        protected void lnkActRead_Click(object sender, EventArgs e)
        {
            ChooseActionMode("R");
        }

        protected void lnkActUnRead_Click(object sender, EventArgs e)
        {
            ChooseActionMode("U");
        }

        // The list of the link clicked, from its first page
        private void ChooseActionMode(string mode)
        {
            ActionMode = mode;
            grvActionItem.PageIndex = 0;
            LoadActionItemGRV();
        }
        #endregion

        #region lnkSource_Click
        // Step F1: an alert whose item is gone or whose id is unusable (SourceTypeId NULL) shows a short warning
        // instead of an error page; the alert is still marked as read when its own id is valid. A session
        // without a usable user id is treated as expired, as Common.InitSetup does.
        protected void lnkSource_Click(object sender, EventArgs e)
        {
            MsgHide();

            pnlAgenda.Visible = false;
            pnlMeeting.Visible = false;
            pnlCommittee.Visible = false;

            int UserId;
            if (Session["UserId"] == null || !int.TryParse(Session["UserId"].ToString(), out UserId))
            {
                Response.Redirect("~/", true);
                return;
            }

            hdnAlertUserId.Value = "0";

            LinkButton link = (LinkButton)sender;
            GridViewRow gv = (GridViewRow)(link.Parent.Parent);
            LinkButton lnkSource = (LinkButton)gv.FindControl("lnkSource");
            Label lblSourceType = (Label)gv.FindControl("lblSourceType");
            Label lblSourceTypeId = (Label)gv.FindControl("lblSourceTypeId");
            Label lblAlertUserId = (Label)gv.FindControl("lblAlertUserId");
            Label lblAlert = (Label)gv.FindControl("lblAlert");
            gv.CssClass = "contentTabletd bmms-row-read";

            hdnAlertUserId.Value = lblAlertUserId.Text.Trim();

            int SourceTypeId;
            bool hasSourceId = int.TryParse(lblSourceTypeId.Text.Trim(), out SourceTypeId);
            bool found = true;

            if (lblSourceType.Text.Equals("Meeting"))
            {
                found = hasSourceId && BindMeetingDetails(SourceTypeId);
                if (found)
                {
                    pnlMeeting.Visible = true;
                    MpCommittee.Show();
                }
            }
            if (lblSourceType.Text.Equals("Committee"))
            {
                found = hasSourceId && BindCommitteeDetails(SourceTypeId);
                if (found)
                {
                    pnlCommittee.Visible = true;
                    MpCommittee.Show();
                }
            }

            if (lblSourceType.Text.Equals("Agenda"))
            {
                found = hasSourceId && BindAgendaDetails(SourceTypeId);
                if (found)
                    pnlAgenda.Visible = true;
            }

            if (!found)
                MsgDisplay("This item no longer exists.", MessageKind.Warning);

            // The procedure marks the row of this alert that belongs to the session's user id, no other
            int AlertId;
            if (int.TryParse(lblAlert.Text.Trim(), out AlertId))
            {
                try
                {
                    AlertMgr.UpdateAlertByUserId(UserId, AlertId);
                }
                finally
                {
                    // Step UN6c1: the alert is read now. The list is read again in the mode chosen (under Unread
                    // the alert leaves the list; its panel stays open), and with it the header count
                    // (LoadAlertGRV), also when the mark could not be written.
                    LoadAlertGRV();
                }
            }

        }

        #endregion

        #region lnkActionItem_Click
        // Step F2: an action item whose id is unusable or that no longer exists shows a short warning instead of
        // an error page.
        // Step UN6c1: the item is opened through spr_OpenDashboardActionItem (step 43), which allows only an item
        // the acting user sees in the card, marks the person's own read row (creating it when the person has
        // none) and returns the item; an item outside the person's scope gets the same warning and nothing is
        // written.
        protected void lnkActionItem_Click(object sender, EventArgs e)
        {
            MsgHide();

            pnlActionItemDetails.Visible = false;

            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            switch (RoleCode)
            {
                case "controller":
                    ftxtActualResolution.ReadOnly = true;
                    ftxtActionText.ReadOnly = false;
                    btnActionItemClose.Visible = true;
                    break;
                case "manager":
                    ftxtActualResolution.ReadOnly = true;
                    ftxtActionText.ReadOnly = false;
                    btnActionItemClose.Visible = false;
                    break;
                case "user":
                    ftxtActualResolution.ReadOnly = true;
                    ftxtActionText.ReadOnly = false;
                    btnActionItemClose.Visible = false;
                    break;
                default:
                    ftxtActualResolution.ReadOnly = true;
                    ftxtActionText.ReadOnly = true;
                    btnActionItemClose.Visible = true;
                    break;

            }

            LinkButton link = (LinkButton)sender;
            GridViewRow gv = (GridViewRow)(link.Parent.Parent);
            Label lblActionItemId = (Label)gv.FindControl("lblActionItemId");
            gv.CssClass = "contentTabletd bmms-row-read";

            int ActionItemId;
            if (int.TryParse(lblActionItemId.Text.Trim(), out ActionItemId))
            {
                try
                {
                    int reason;
                    DataTable dtOpened = ActionItemMgr.OpenDashboardActionItem(UserId, ActionItemId, out reason);
                    if (reason == 8)
                    {
                        pnlActionItemDetails.Visible = false;
                        MsgDisplay(ActionItemsInactiveMessage);
                    }
                    else if (reason == 0 && BindActionItemDetails(dtOpened))
                        pnlActionItemDetails.Visible = true;
                    else
                        ShowItemGone();
                }
                finally
                {
                    // The list again in the mode chosen, also when the item could not be opened
                    LoadActionItemGRV();
                }
            }
            else
            {
                ShowItemGone();
                LoadActionItemGRV();
            }
        }
        #endregion

        #region BindActionItemDetails
        // The row that spr_OpenDashboardActionItem returned (step UN6c1)
        private bool BindActionItemDetails(DataTable dtActionItem)
        {
            if (dtActionItem == null || dtActionItem.Rows.Count == 0)
                return false;

            txtAgendaNumber.Text = dtActionItem.Rows[0]["AgendaNo"].ToString();
            hdnActionItemId.Value = dtActionItem.Rows[0]["ActionItemId"].ToString();
            txtSubjectNumber.Text = dtActionItem.Rows[0]["SubjectNo"].ToString();
            txtActionDepartment.Text = dtActionItem.Rows[0]["DepartmentName"].ToString();
            txtDecisionType.Text = dtActionItem.Rows[0]["DecisionTypeName"].ToString();
            //txtDueDate.Text = Convert.ToDateTime(dtActionItem.Rows[0]["DueDate"].ToString()).ToString("dd-MMM-yyyy"); ;
            ftxtActualResolution.Text = HtmlCleaner.Clean(dtActionItem.Rows[0]["ActualResolution"].ToString());
            ftxtActionText.Text = HtmlCleaner.Clean(dtActionItem.Rows[0]["ActionText"].ToString());

            return true;
        }
        #endregion

        #region grvAlert_RowDataBound
        protected void grvAlert_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                string read = Convert.ToString(DataBinder.Eval(e.Row.DataItem, "ReadStatus"));
                if (read.Equals("1"))
                {
                    e.Row.CssClass = "contentTabletd bmms-row-read";
                }
                else
                {
                    e.Row.Font.Bold = true;
                    e.Row.CssClass = "contentTabletd bmms-row-unread";
                }
            }
        }
        #endregion

        #region grvActionItem_RowDataBound
        protected void grvActionItem_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                string read = Convert.ToString(DataBinder.Eval(e.Row.DataItem, "ReadStatus"));
                if (read.Equals("1"))
                {
                    e.Row.CssClass = "contentTabletd bmms-row-read";
                }
                else
                {
                    e.Row.Font.Bold = true;
                    e.Row.CssClass = "contentTabletd bmms-row-unread";
                }
            }
        }
        #endregion

        #region BindCommitteeDetails
        private bool BindCommitteeDetails(int CommitteeId)
        {
            CommitteeBAL myCommittee = new CommitteeBAL();
            try
            {
                myCommittee = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
            }
            catch (IndexOutOfRangeException)
            {
                // CommitteeDB reads Rows[0] without a check: no row means the committee no longer exists (step F1)
                return false;
            }

            hdnCommitteeId.Value = myCommittee.CommitteeId.ToString();
            txtCommitteeCode.Text = myCommittee.CommitteeCode;
            txtCommitteeName.Text = myCommittee.CommitteeName;
            txtIncorporationDate.Text = myCommittee.IncorporationDate == DateTime.MinValue ? string.Empty : myCommittee.IncorporationDate.ToString("dd-MMM-yyyy");

            return true;
        }
        #endregion

        #region BindMeetingDetails
        private bool BindMeetingDetails(int MeetingId)
        {
            DataTable dtMeeting = new DataTable();
            dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);
            if (dtMeeting == null || dtMeeting.Rows.Count == 0)
                return false;

            hdnMeetingId.Value = dtMeeting.Rows[0]["MeetingId"].ToString();

            txtMeetingNo.Text = dtMeeting.Rows[0]["MeetingNo"].ToString();
            txtCommittee.Text = dtMeeting.Rows[0]["CommitteeName"].ToString();
            txtVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
            txtMeetingDate.Text = FormatDate(dtMeeting.Rows[0]["MeetingDate"]);
            txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();
            txtAgendaSubmissionDate.Text = FormatDate(dtMeeting.Rows[0]["AgendaSubmissionDate"]);

            return true;
        }
        #endregion

        #region BindAgendaDetails
        private bool BindAgendaDetails(int AgendaId)
        {
            DataTable dtAgendaEdit = new DataTable();
            dtAgendaEdit = AgendaMgr.GetAgendaByAgendaId(AgendaId);
            if (dtAgendaEdit == null || dtAgendaEdit.Rows.Count == 0)
                return false;

            // Step F2: int, not Int16 (MeetingId can pass 32767); an agenda item without a usable meeting is treated as gone
            int MeetingId;
            if (!int.TryParse(dtAgendaEdit.Rows[0]["MeetingId"].ToString(), out MeetingId))
                return false;

            txtAgendaNo.Text = dtAgendaEdit.Rows[0]["AgendaNo"].ToString();
            txtSubjectNo.Text = dtAgendaEdit.Rows[0]["SubjectNo"].ToString();
            hdnAgendaId.Value = dtAgendaEdit.Rows[0]["AgendaId"].ToString();
            txtAgendaCommittee.Text = dtAgendaEdit.Rows[0]["CommitteeName"].ToString();
            hdnAgendaCommittee.Value = dtAgendaEdit.Rows[0]["CommitteeId"].ToString();
            txtAgendaMeeting.Text = dtAgendaEdit.Rows[0]["MeetingNo"].ToString();
            hdnAgendaMeeting.Value = dtAgendaEdit.Rows[0]["MeetingId"].ToString();
            txtDateOfMeeting.Text = FormatDate(dtAgendaEdit.Rows[0]["MeetingDate"]);
            txtAgendaDepartment.Text = dtAgendaEdit.Rows[0]["DepartmentName"].ToString();
            txtSubjectType.Text = dtAgendaEdit.Rows[0]["SubjectTypeName"].ToString();
            txtShortText.Text = dtAgendaEdit.Rows[0]["ShortText"].ToString();

            if (dtAgendaEdit.Rows[0]["AgendaType"].ToString() == "Entry")
            {
                ftxtAgendaText.Visible = true;
                aAgendaText.Visible = false;
                ftxtAgendaText.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["AgendaText"].ToString());
            }
            else
            {
                ftxtAgendaText.Visible = false;
                ftxtAgendaText.Text = string.Empty;   // step A3: no text of an earlier item stays in the hidden editor
                aAgendaText.Visible = true;
                aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + Uri.EscapeDataString(dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString()));
            }

            ftxtProposedResolution.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["ProposedResolution"].ToString());

            string[] attFiles = dtAgendaEdit.Rows[0]["FilePath"].ToString().Split(',');
            DataTable dtAttFiles = new DataTable();
            dtAttFiles.Columns.Add("FilePathOrg");
            dtAttFiles.Columns.Add("FilePath");
            dtAttFiles.Columns.Add("DisplayName");

            for (int i = 0; i < attFiles.Length; i++)
            {
                DataRow dr = dtAttFiles.NewRow();
                dr["FilePathOrg"] = attFiles[i].ToString();
                dr["FilePath"] = "../Files/AgendaAttach/" + Uri.EscapeDataString(attFiles[i].ToString());
                dr["DisplayName"] = attFiles[i].ToString();
                dtAttFiles.Rows.Add(dr);
            }

            grvAttachedFiles.DataSource = dtAttFiles;
            grvAttachedFiles.DataBind();

            ftxtManagerComments.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["MgrComments"].ToString());
            ftxtControllerComments.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["ControllerComments"].ToString());
            ShowCommentCaptions(dtAgendaEdit.Rows[0]);   // step UN4

            DataTable dtAgenda = new DataTable();
            dtAgenda = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId);

            // Step C1: whether Approve / Reject are shown, kept here because btnApprove.Visible reads false while
            // pnlAgenda is still hidden (lnkSource_Click shows it only after this method returns)
            bool canDecide = false;

            if (dtAgenda.Rows.Count <= 0)
            {
                txtShortText.ReadOnly = true;
                ftxtAgendaText.ReadOnly = true;
                ftxtProposedResolution.ReadOnly = true;
                ftxtManagerComments.ReadOnly = true;
                ftxtControllerComments.ReadOnly = true;
                btnApprove.Visible = false;
                btnReject.Visible = false;
                canDecide = false;
                btnDeleteAgendaAlert.Visible = true;
            }
            else
            {

                txtShortText.ReadOnly = true;
                ftxtAgendaText.ReadOnly = true;
                ftxtProposedResolution.ReadOnly = true;
                btnApprove.Visible = false;
                btnReject.Visible = false;
                canDecide = false;
                btnDeleteAgendaAlert.Visible = true;

                switch (Convert.ToString(Session["RoleCode"]))
                {
                    case "controller":
                        txtShortText.ReadOnly = false;
                        ftxtProposedResolution.ReadOnly = false;
                        ftxtManagerComments.ReadOnly = true;
                        ftxtControllerComments.ReadOnly = false;

                        if (dtAgendaEdit.Rows[0]["AgendaStatusCode"].ToString() == "AMA")
                        {
                            btnApprove.Visible = true;
                            btnReject.Visible = true;
                            canDecide = true;
                            btnDeleteAgendaAlert.Visible = false;
                        }

                        break;
                    case "manager":
                        ftxtManagerComments.ReadOnly = true;
                        ftxtControllerComments.ReadOnly = true;
                        if (dtAgendaEdit.Rows[0]["AgendaStatusCode"].ToString() == "AC")
                        {
                            ftxtManagerComments.ReadOnly = false;
                            btnApprove.Visible = true;
                            btnReject.Visible = true;
                            canDecide = true;
                            btnDeleteAgendaAlert.Visible = false;
                        }

                        break;
                    case "user":
                        ftxtManagerComments.ReadOnly = true;
                        ftxtControllerComments.ReadOnly = true;
                        btnApprove.Visible = false;
                        btnReject.Visible = false;
                        canDecide = false;
                        btnDeleteAgendaAlert.Visible = true;
                        break;
                    default:
                        // Admin, mgmt and md_sect do not sign off agenda items: view only
                        // (BMMS-Fix-AgendaRouting-Step20.sql refuses them too, Reason 14)
                        ftxtManagerComments.ReadOnly = true;
                        ftxtControllerComments.ReadOnly = true;
                        btnApprove.Visible = false;
                        btnReject.Visible = false;
                        canDecide = false;
                        btnDeleteAgendaAlert.Visible = true;
                        break;

                }

                // The protected system account takes no part in the workflow (BMMS-Fix-SystemAccount-Stage3.sql)
                if (Common.IsSystemAccountSession())
                {
                    btnApprove.Visible = false;
                    btnReject.Visible = false;
                    canDecide = false;
                    btnDeleteAgendaAlert.Visible = true;
                }

                // An item the user could decide, of a meeting whose date has passed: shown read-only with the
                // message (step M6a); Approve and Reject check again
                if (btnApprove.Visible && !MeetingMgr.IsMeetingOpenForChange(dtAgendaEdit.Rows[0]["MeetingDate"], DateTime.Today))
                {
                    txtShortText.ReadOnly = true;
                    ftxtProposedResolution.ReadOnly = true;
                    ftxtManagerComments.ReadOnly = true;
                    ftxtControllerComments.ReadOnly = true;
                    btnApprove.Visible = false;
                    btnReject.Visible = false;
                    canDecide = false;
                    btnDeleteAgendaAlert.Visible = true;
                    MsgDisplay(MeetingDatePassedMessage, MessageKind.Warning);
                }

                // Step C1: a comment is editable only for the role that writes it, and only while Approve / Reject
                // can save it (before, the Controller's comment was editable on every item, with nothing to save it)
                string commentRole = Convert.ToString(Session["RoleCode"]);
                ftxtManagerComments.ReadOnly = !(canDecide && commentRole == "manager");
                ftxtControllerComments.ReadOnly = !(canDecide && commentRole == "controller");
            }

            return true;
        }
        #endregion

        #region OnPaging
        // Step UN6c1: the page asked is read from the server
        protected void OnPaging(object sender, GridViewPageEventArgs e)
        {
            AlertPage = e.NewPageIndex + 1;
            LoadAlertGRV();
        }
        #endregion

        #region OnPagingAction
        protected void OnPagingAction(object sender, GridViewPageEventArgs e)
        {
            // The page asked for, of the list in the mode chosen (not of the whole list)
            grvActionItem.PageIndex = e.NewPageIndex;
            BindActionItemGRV((DataTable)ViewState["dtActionItem"]);
        }
        #endregion

        #region btnApprove_Click
        protected void btnApprove_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            // Step A3: rich text over the limit (Web.config): nothing is saved, no mail, the panel stays open
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            int AgendaId;
            int MeetingId;
            object MeetingDate;
            DataRow itemBefore;   // step ML2b: the item before the save, for the comment row of the mail
            if (!TryGetAgenda(out AgendaId, out MeetingId, out MeetingDate, out itemBefore))
            {
                ShowItemGone();
                LoadAlertGRV();
                return;
            }

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = AgendaId;
            agendaBal.ShortText = txtShortText.Text.Trim();
            agendaBal.ProposedResolution = ftxtProposedResolution.Text.Trim();
            agendaBal.MgrComments = ftxtManagerComments.Text.Trim();
            agendaBal.ControllerComments = ftxtControllerComments.Text.Trim();
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            // Finalized since the alert was opened: refuse before any mail (BMMS-Fix-MeetingLocks-Step16.sql)
            if (!MeetingMgr.IsAgendaOpen(MeetingId))
            {
                ShowAlert(MeetingChangeReason.AgendaFinalizedMessage);
                pnlAgenda.Visible = false;
                LoadAlertGRV();
                return;
            }

            // The item's own saved meeting date (step M6a): nothing changes, no subject number, no mail
            if (!MeetingMgr.IsMeetingOpenForChange(MeetingDate, DateTime.Today))
            {
                MsgDisplay(MeetingDatePassedMessage, MessageKind.Warning);
                pnlAgenda.Visible = false;
                LoadAlertGRV();
                return;
            }

            if (RoleCode == "manager")
                agendaBal.MgrApprovedStatus = "Approved";

            if (RoleCode == "controller")
                agendaBal.ControllerApprovedStatus = "Approved";

            agendaBal.UpdatedBy = UserId;

            // Who may approve at which stage is checked by the procedure (BMMS-Fix-AgendaRouting-Step20.sql);
            // the mail goes out only once it is done
            MeetingChangeResult approveResult = AgendaMgr.UpdateAgendaByAgendaId(agendaBal);

            if (approveResult.Result == 1)
            {
                // The subject number before the mail, so a mail problem cannot leave it out (step M3)
                AgendaMgr.GenerateSubjectNoByMeetingId(MeetingId, AgendaId);

                string mailResult = "Success";
                if (agendaBal.MgrApprovedStatus == "Approved")
                    mailResult = GenerateMail("approved by Manager", "AMA", RoleCode, itemBefore);
                if (agendaBal.ControllerApprovedStatus == "Approved")
                    mailResult = GenerateMail("approved by Controller", "ACA", RoleCode, itemBefore);

                // Nothing is shown on success, as before; the mail error itself is in the error log
                if (mailResult != "Success")
                    MsgDisplay(ApprovedMailNotSentMessage, MessageKind.Warning);

                ClearAgendaEditors();   // step A3: saved, the panel closes
                MeetingSummary1.Reload();   // step UN6b: the meeting counts follow the approval
            }
            else if (approveResult.Reason == MeetingChangeReason.NotFound)
                ShowItemGone();
            else
                ShowAlert(approveResult.RefusalMessage());

            pnlAgenda.Visible = false;

            LoadAlertGRV();
        }
        #endregion

        #region btnReject_Click
        protected void btnReject_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            // Step A3: rich text over the limit (Web.config): nothing is saved, no mail, the panel stays open
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            int AgendaId;
            int MeetingId;
            object MeetingDate;
            DataRow itemBefore;   // step ML2b: the item before the save, for the comment row of the mail
            if (!TryGetAgenda(out AgendaId, out MeetingId, out MeetingDate, out itemBefore))
            {
                ShowItemGone();
                LoadAlertGRV();
                return;
            }

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = AgendaId;
            agendaBal.ShortText = txtShortText.Text.Trim();
            agendaBal.ProposedResolution = ftxtProposedResolution.Text.Trim();
            agendaBal.MgrComments = ftxtManagerComments.Text.Trim();
            agendaBal.ControllerComments = ftxtControllerComments.Text.Trim();
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            // Finalized since the alert was opened: refuse before any mail (BMMS-Fix-MeetingLocks-Step16.sql)
            if (!MeetingMgr.IsAgendaOpen(MeetingId))
            {
                ShowAlert(MeetingChangeReason.AgendaFinalizedMessage);
                pnlAgenda.Visible = false;
                LoadAlertGRV();
                return;
            }

            // The item's own saved meeting date (step M6a): nothing changes, no subject number, no mail
            if (!MeetingMgr.IsMeetingOpenForChange(MeetingDate, DateTime.Today))
            {
                MsgDisplay(MeetingDatePassedMessage, MessageKind.Warning);
                pnlAgenda.Visible = false;
                LoadAlertGRV();
                return;
            }

            if (RoleCode == "manager")
                agendaBal.MgrApprovedStatus = "Rejected";

            if (RoleCode == "controller")
                agendaBal.ControllerApprovedStatus = "Rejected";

            agendaBal.UpdatedBy = UserId;

            // Who may reject at which stage is checked by the procedure (BMMS-Fix-AgendaRouting-Step20.sql);
            // the mail goes out only once it is done
            MeetingChangeResult rejectResult = AgendaMgr.UpdateAgendaByAgendaId(agendaBal);

            if (rejectResult.Result == 1)
            {
                string mailResult = "Success";
                if (agendaBal.MgrApprovedStatus == "Rejected")
                    mailResult = GenerateMail("rejected by Manager", "AMR", RoleCode, itemBefore);
                if (agendaBal.ControllerApprovedStatus == "Rejected")
                    mailResult = GenerateMail("rejected by Controller", "ACR", RoleCode, itemBefore);

                // Nothing is shown on success, as before; the mail error itself is in the error log (step M3)
                if (mailResult != "Success")
                    MsgDisplay(RejectedMailNotSentMessage, MessageKind.Warning);

                ClearAgendaEditors();   // step A3: saved, the panel closes
                MeetingSummary1.Reload();   // step UN6b: the meeting counts follow the rejection
            }
            else if (rejectResult.Reason == MeetingChangeReason.NotFound)
                ShowItemGone();
            else
                ShowAlert(rejectResult.RefusalMessage());

            pnlAgenda.Visible = false;
            LoadAlertGRV();
        }
        #endregion

        #region TryGetAgenda
        // Step F2: the agenda item behind Approve / Reject must still exist; its MeetingId is read from the item
        // itself, not from the hidden field. False sends no mail and changes nothing. MeetingDate is the item's
        // own saved meeting date (step M6a). Before is the item as read here, before the save (step ML2b).
        private bool TryGetAgenda(out int AgendaId, out int MeetingId, out object MeetingDate, out DataRow Before)
        {
            MeetingId = 0;
            MeetingDate = null;
            Before = null;

            if (!int.TryParse(hdnAgendaId.Value.Trim(), out AgendaId))
                return false;

            DataTable dtAgenda = AgendaMgr.GetAgendaByAgendaId(AgendaId);
            if (dtAgenda == null || dtAgenda.Rows.Count == 0)
                return false;

            MeetingDate = dtAgenda.Rows[0]["MeetingDate"];
            Before = dtAgenda.Rows[0];
            return int.TryParse(dtAgenda.Rows[0]["MeetingId"].ToString(), out MeetingId);
        }
        #endregion

        #region ShowAlert
        private void ShowAlert(string message)
        {
            ScriptManager.RegisterStartupScript(this, this.GetType(), "refusal",
                "alert('" + HttpUtility.JavaScriptStringEncode(HttpUtility.HtmlDecode(message)) + "');", true);
        }
        #endregion

        #region GenerateMail
        // Step ML2b: after the saved decision. The item is read again for the Subject No (given on approval) and the
        // comment row of the acting role (AgendaMail.DecisionCommentRow, with Before, the item read before the save).
        // If that read fails, the mail still goes out without the comment row (the Subject No as shown on the page)
        // and the error is logged; the decision is saved either way.
        private string GenerateMail(string AgendaStatus, string MailCode, string RoleCode, DataRow Before)
        {
            try
            {
                string ToMailId = string.Empty;
                string Bcc = string.Empty;
                int AgendaId = int.Parse(hdnAgendaId.Value);
                int UserId = int.Parse(Session["UserId"].ToString());

                UserBAL userBal = UserMgr.GetUserByUserId(UserId);
                ToMailId = userBal.EmailId.ToString();

                Bcc = AlertMgr.GetAlertMailId(MailCode, UserId, AgendaId);

                // Step ML2c: the item as saved now, or null (logged as before; the mail then goes without the comment row)
                DataRow itemAfter = AgendaMail.ReadItemAfterSave(AgendaId, className, "the decision");

                string subjectNo = itemAfter != null ? itemAfter["SubjectNo"].ToString() : txtSubjectNo.Text;

                string Subject = "Agenda (" + txtAgendaNo.Text.Trim() + ") has been " + AgendaStatus.ToString();
                string BodyText = string.Empty;
                BodyText += "<table>";
                BodyText += AgendaMail.DetailRows(txtAgendaNo.Text, subjectNo, txtAgendaCommittee.Text, txtAgendaMeeting.Text,
                    txtDateOfMeeting.Text, txtAgendaDepartment.Text, txtSubjectType.Text, txtShortText.Text);
                if (itemAfter != null)
                    BodyText += AgendaMail.DecisionCommentRow(RoleCode, Before, itemAfter);
                BodyText += "</table>";

                return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);
            }
            catch (Exception ex)
            {
                // The approval or rejection is already saved: log, and let the page say the mail was not sent
                Utilities.WriteErrorLog(className, "GenerateMail", ex.ToString());
                return "Error";
            }
        }
        #endregion

        #region btnActionItemApprove_Click
        protected void btnActionItemApprove_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            // Step A3: rich text over the limit (Web.config): nothing is saved, the panel stays open
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            // Step F2: an unusable id shows the warning.
            // Step UN6c1: the save goes through spr_SaveDashboardActionText (step 43), which decides on the server,
            // from the acting user id and the role it reads from the database, whatever the page sent: only a
            // Controller, a Manager or a User, and only an item in that person's scope. Management (which sees every
            // item, read-only), MD Secretariat, Admin and an item of another department are refused; nothing is
            // saved then. It writes the action text only, as before.
            int ActionItemId;
            if (!int.TryParse(hdnActionItemId.Value.Trim(), out ActionItemId))
            {
                ShowItemGone();
                return;
            }

            string ActionText = ftxtActionText.Text.Trim();

            int reason;
            try
            {
                reason = ActionItemMgr.SaveDashboardActionText(UserId, ActionItemId, ActionText);
            }
            catch (Exception ex)
            {
                // A failed save: the panel stays open with the text typed, so the person can try again
                Utilities.WriteErrorLog(className, "btnActionItemApprove_Click", ex.ToString());
                MsgDisplay(Common.IsServerBusy(ex) ? ActionItemSaveBusyMessage : ActionItemSaveFailedMessage);
                return;
            }

            pnlActionItemDetails.Visible = false;
            ClearActionItemEditors();   // step A3: saved or refused, the panel closes

            if (reason == 8)
                MsgDisplay(ActionItemInactiveMessage);
            else if (reason != 0)
                MsgDisplay(ActionItemNotSavedMessage);
        }
        #endregion

        #region btnActionItemClose_Click
        // Close and the X button of the panel
        protected void btnActionItemClose_Click(object sender, EventArgs e)
        {
            pnlActionItemDetails.Visible = false;
            ClearActionItemEditors();   // step A3
        }
        #endregion

        #region btnActionItemCancel_Click
        protected void btnActionItemCancel_Click(object sender, EventArgs e)
        {
            pnlActionItemDetails.Visible = false;
            ClearActionItemEditors();   // step A3
        }
        #endregion

        #region ClearAgendaEditors
        // Step A3: a closed agenda panel keeps no text in its editors (else the texts of the item travel in view
        // state with every later postback of the Dashboard). Called only after a done action or Close, never on an
        // error or too-long path, where the panel and the typed text stay.
        private void ClearAgendaEditors()
        {
            ftxtAgendaText.Text = string.Empty;
            ftxtProposedResolution.Text = string.Empty;
            ftxtManagerComments.Text = string.Empty;
            ftxtControllerComments.Text = string.Empty;
            ShowCommentCaptions(null);   // step UN4
        }
        #endregion

        #region ShowCommentCaptions
        // Step UN4: who wrote each comment and when, on its own line under the label ("MohanKumar, 11-Oct-2026 16:49";
        // nothing for a comment saved before step 35). The name is HTML-encoded here. The editor's accessible name is
        // the whole caption. Item = the saved row, or null when the panel is cleared.
        private void ShowCommentCaptions(DataRow Item)
        {
            string mgrBy = Item == null ? string.Empty : AgendaMgr.CommentAuthor(Item["MgrApprovedBy"], Item["MgrApprovedDate"]);
            string ctlBy = Item == null ? string.Empty : AgendaMgr.CommentAuthor(Item["ControllerApprovedBy"], Item["ControllerApprovedDate"]);

            lblManagerCommentBy.Text = HttpUtility.HtmlEncode(mgrBy);
            lblManagerCommentBy.Visible = mgrBy.Length > 0;
            ftxtManagerComments.Label = AgendaMgr.CommentCaption(AgendaMgr.ManagerCommentLabel, mgrBy);

            lblControllerCommentBy.Text = HttpUtility.HtmlEncode(ctlBy);
            lblControllerCommentBy.Visible = ctlBy.Length > 0;
            ftxtControllerComments.Label = AgendaMgr.CommentCaption(AgendaMgr.ControllerCommentLabel, ctlBy);
        }
        #endregion

        #region ClearActionItemEditors
        // Step A3: the same for the action item panel
        private void ClearActionItemEditors()
        {
            ftxtActualResolution.Text = string.Empty;
            ftxtActionText.Text = string.Empty;
        }
        #endregion

        #region btnClose_Click
        protected void btnClose_Click(object sender, EventArgs e)
        {
            LoadAlertGRV();
        }
        #endregion

        #region btnAgendaClose_Click
        protected void btnAgendaClose_Click(object sender, EventArgs e)
        {
            pnlAgenda.Visible = false;
            ClearAgendaEditors();   // step A3
            LoadAlertGRV();
        }
        #endregion

        #region btnDeleteAlert_Click
        // "Remove from my list" (step UN6c1; the button was "Delete"). The id of the row comes back from the page in a
        // hidden field, so the procedure (spr_RemoveAlertForUser, step 43) removes it only when it is the acting
        // user's own row; another user's row or an unknown id changes nothing. Nothing is deleted: the alert leaves
        // this person's list, and an edit of the item shows it again, unread (step 36).
        protected void btnDeleteAlert_Click(object sender, EventArgs e)
        {
            MsgHide();

            int UserId;
            string RoleCode;
            if (!HasSessionUser(out UserId, out RoleCode))
                return;

            // Step F2: int, not Int16 (AlertUserId passes 32767 in normal use); an unusable id removes nothing
            int AlertUserId;
            if (!int.TryParse(hdnAlertUserId.Value.Trim(), out AlertUserId) || AlertUserId <= 0)
            {
                ShowItemGone();
                LoadAlertGRV();
                return;
            }

            try
            {
                int reason = AlertMgr.RemoveAlertForUser(UserId, AlertUserId);
                if (reason == 8)
                    MsgDisplay(AlertsInactiveMessage, MessageKind.Warning);
                else if (reason != 0)
                    MsgDisplay(AlertNotInListMessage, MessageKind.Warning);
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "btnDeleteAlert_Click", ex.ToString());
                MsgDisplay(AlertNotRemovedMessage, MessageKind.Error);
            }

            hdnAlertUserId.Value = "0";
            pnlAgenda.Visible = false;
            ClearAgendaEditors();   // step A3: alert removed, the panel closes
            LoadAlertGRV();
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

        #region HasSessionUser
        // Step F2: a session without a usable user id or role is treated as expired, as Common.InitSetup and
        // lnkSource_Click (step F1) do
        private bool HasSessionUser(out int UserId, out string RoleCode)
        {
            UserId = 0;
            RoleCode = Convert.ToString(Session["RoleCode"]);

            if (Session["UserId"] == null || !int.TryParse(Session["UserId"].ToString(), out UserId) || RoleCode == string.Empty)
            {
                Response.Redirect("~/", true);
                return false;
            }

            return true;
        }
        #endregion

        #region ShowItemGone
        // Step F2: the item behind a link or button is gone or its id is unusable: close the panels, show the F1 warning
        private void ShowItemGone()
        {
            pnlAgenda.Visible = false;
            pnlActionItemDetails.Visible = false;
            pnlMeeting.Visible = false;
            pnlCommittee.Visible = false;

            MsgDisplay("This item no longer exists.", MessageKind.Warning);
        }
        #endregion

        #region FormatDate
        // Step F2: the same text as Convert.ToDateTime(value.ToString()).ToString("dd-MMM-yyyy") (current culture,
        // both ways); a NULL, empty or unreadable date gives an empty string instead of an error. Protected since
        // step UN6b: the Alerts card binds its date with it.
        protected static string FormatDate(object value)
        {
            DateTime date;
            if (value == null || value == DBNull.Value || !DateTime.TryParse(value.ToString(), out date))
                return string.Empty;

            return date.ToString("dd-MMM-yyyy");
        }
        #endregion

        #region Alerts card (step UN6b)
        // The time of the alert's CreatedOn as HH:mm (shown under the date, as in the Meetings card); empty when
        // the value is missing or unreadable
        protected static string FormatTimeOfDay(object value)
        {
            DateTime date;
            if (value is DateTime)
                date = (DateTime)value;
            else if (value == null || value == DBNull.Value || !DateTime.TryParse(value.ToString(), out date))
                return string.Empty;

            return date.ToString("HH:mm");
        }

        // The person who caused the alert (step UN6c1): the name, or a dash when nobody is recorded (a decision made
        // before the approver was stored); the login ID is the tooltip, empty with the dash
        protected static string ActorName(object value)
        {
            string name = value == null || value == DBNull.Value ? string.Empty : value.ToString().Trim();
            return name.Length == 0 ? "-" : name;
        }

        protected static string ActorLogin(object value)
        {
            return value == null || value == DBNull.Value ? string.Empty : value.ToString().Trim();
        }

        // The Action Items card (step UN6c1): IsOverdue of spr_GetDashboardActionItems
        protected static bool IsOverdue(object value)
        {
            return value != null && value != DBNull.Value && Convert.ToInt32(value) == 1;
        }

        // The muted line under the Source link: alert type, committee and department, the empty ones left out.
        // Plain text; the markup encodes it.
        protected static string AlertDetails(object alertType, object committee, object department)
        {
            System.Collections.Generic.List<string> parts = new System.Collections.Generic.List<string>();
            foreach (object value in new object[] { alertType, committee, department })
            {
                string text = value == null || value == DBNull.Value ? string.Empty : value.ToString().Trim();
                if (text.Length > 0)
                    parts.Add(text);
            }
            return string.Join(" | ", parts.ToArray());
        }
        #endregion

    }
}
