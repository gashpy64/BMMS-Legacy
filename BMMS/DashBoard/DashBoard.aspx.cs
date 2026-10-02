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
using BMMSBAL;

namespace BMMS.DashBoard
{
    public partial class DashBoard : System.Web.UI.Page
    {
        private string className = "DashBoard";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                lnkActShowall.Attributes.Add("style", "color:#da251d");
                lnkActRead.Attributes.Add("style", "color:#333333");
                lnkActUnRead.Attributes.Add("style", "color:#333333");
                lnkShowAll.Attributes.Add("style", "color:#da251d");
                lnkRead.Attributes.Add("style", "color:#333333");
                lnkUnread.Attributes.Add("style", "color:#333333");

                LoadAlertGRV();
                LoadActionItemGRV();
                pnlAgenda.Visible = false;
                pnlActionItemDetails.Visible = false;
            }
        }
        #endregion

        #region LoadAlertGRV
        private void LoadAlertGRV()
        {
            DataTable dtAlert = new DataTable();

            string RoleName = Session["RoleCode"].ToString();
            int UserId = int.Parse(Session["UserId"].ToString());

            dtAlert = AlertMgr.GetAlertByUserId(RoleName, UserId);
            ViewState["dtAlert"] = dtAlert;
            BindAlertGRV(dtAlert);
        }
        #endregion

        #region LoadActionItemGRV
        private void LoadActionItemGRV()
        {
            DataTable dtActionItem = new DataTable();
            dtActionItem = ActionItemMgr.GetActionItemByUserId(int.Parse(Session["UserId"].ToString()));
            ViewState["dtActionItem"] = dtActionItem;
            BindActionItemGRV(dtActionItem);
        }
        #endregion

        #region BindAlertGRV
        private void BindAlertGRV(DataTable dtAlert)
        {
            grvAlert.DataSource = dtAlert;
            grvAlert.DataBind();
        }
        #endregion

        #region BindActionItemGRV
        private void BindActionItemGRV(DataTable dtActionItem)
        {
            grvActionItem.DataSource = dtActionItem;
            grvActionItem.DataBind();
        }
        #endregion

        #region lnkShowAll_Click
        protected void lnkShowAll_Click(object sender, EventArgs e)
        {
            lnkShowAll.Attributes.Add("style", "color:#da251d");
            lnkRead.Attributes.Add("style", "color:#333333");
            lnkUnread.Attributes.Add("style", "color:#333333");

            LoadAlertGRV();
        }
        #endregion

        #region lnkActShowall_Click
        protected void lnkActShowall_Click(object sender, EventArgs e)
        {
            lnkActShowall.Attributes.Add("style", "color:#da251d");
            lnkActRead.Attributes.Add("style", "color:#333333");
            lnkActUnRead.Attributes.Add("style", "color:#333333");

            LoadActionItemGRV();
        }
        #endregion


        #region lnkRead_Click
        protected void lnkRead_Click(object sender, EventArgs e)
        {
            lnkShowAll.Attributes.Add("style", "color:#333333");
            lnkRead.Attributes.Add("style", "color:#da251d");
            lnkUnread.Attributes.Add("style", "color:#333333");

            LoadAlertGRV();
            DataTable dtAlert = new DataTable();
            dtAlert = (DataTable)ViewState["dtAlert"];
            if (dtAlert != null)
            {
                DataView dv = new DataView(dtAlert);
                dv.RowFilter = "ReadStatus = 1";

                dtAlert = dv.ToTable("dtAlert");

                BindAlertGRV(dtAlert);
            }
        }
        #endregion

        #region lnkActRead_Click
        protected void lnkActRead_Click(object sender, EventArgs e)
        {
            lnkActShowall.Attributes.Add("style", "color:#333333");
            lnkActRead.Attributes.Add("style", "color:#da251d");
            lnkActUnRead.Attributes.Add("style", "color:#333333");

            LoadActionItemGRV();
            DataTable dtActionItem = new DataTable();
            dtActionItem = (DataTable)ViewState["dtActionItem"];
            if (dtActionItem != null)
            {
                DataView dv = new DataView(dtActionItem);
                dv.RowFilter = "ReadStatus = 1";

                dtActionItem = dv.ToTable("dtActionItem");

                BindActionItemGRV(dtActionItem);
            }
        }
        #endregion

        #region lnkUnread_Click
        protected void lnkUnread_Click(object sender, EventArgs e)
        {
            lnkShowAll.Attributes.Add("style", "color:#333333");
            lnkRead.Attributes.Add("style", "color:#333333");
            lnkUnread.Attributes.Add("style", "color:#da251d");

            LoadAlertGRV();
            DataTable dtAlert = new DataTable();
            dtAlert = (DataTable)ViewState["dtAlert"];
            if (dtAlert != null)
            {
                DataView dv = new DataView(dtAlert);
                dv.RowFilter = "ReadStatus = 0";

                dtAlert = dv.ToTable("dtAlert");

                BindAlertGRV(dtAlert);
            }
        }
        #endregion

        #region lnkActUnRead_Click
        protected void lnkActUnRead_Click(object sender, EventArgs e)
        {
            lnkActShowall.Attributes.Add("style", "color:#333333");
            lnkActRead.Attributes.Add("style", "color:#333333");
            lnkActUnRead.Attributes.Add("style", "color:#da251d");

            LoadActionItemGRV();
            DataTable dtActionItem = new DataTable();
            dtActionItem = (DataTable)ViewState["dtActionItem"];
            if (dtActionItem != null)
            {
                DataView dv = new DataView(dtActionItem);
                dv.RowFilter = "ReadStatus = 0";

                dtActionItem = dv.ToTable("dtActionItem");

                BindActionItemGRV(dtActionItem);
            }
        }
        #endregion

        #region lnkSource_Click
        protected void lnkSource_Click(object sender, EventArgs e)
        {

            pnlAgenda.Visible = false;
            pnlMeeting.Visible = false;
            pnlCommittee.Visible = false;

            hdnAlertUserId.Value = "0";

            LinkButton link = (LinkButton)sender;
            GridViewRow gv = (GridViewRow)(link.Parent.Parent);
            LinkButton lnkSource = (LinkButton)gv.FindControl("lnkSource");
            Label lblSourceType = (Label)gv.FindControl("lblSourceType");
            Label lblSourceTypeId = (Label)gv.FindControl("lblSourceTypeId");
            Label lblAlertUserId = (Label)gv.FindControl("lblAlertUserId");
            Label lblAlert = (Label)gv.FindControl("lblAlert");
            gv.BackColor = System.Drawing.Color.FromName("#FEE2C3");

            hdnAlertUserId.Value = lblAlertUserId.Text.Trim();

            if (lblSourceType.Text.Equals("Meeting"))
            {
                pnlMeeting.Visible = true;

                BindMeetingDetails(int.Parse(lblSourceTypeId.Text));

                MpCommittee.Show();
            }
            if (lblSourceType.Text.Equals("Committee"))
            {
                pnlCommittee.Visible = true;

                BindCommitteeDetails(int.Parse(lblSourceTypeId.Text));

                MpCommittee.Show();
            }

            if (lblSourceType.Text.Equals("Agenda"))
            {
                pnlAgenda.Visible = true;

                BindAgendaDetails(int.Parse(lblSourceTypeId.Text));

            }

            AlertMgr.UpdateAlertByUserId(int.Parse(Session["UserId"].ToString()), int.Parse(lblAlert.Text));

        }

        #endregion

        #region lnkActionItem_Click
        protected void lnkActionItem_Click(object sender, EventArgs e)
        {
            pnlActionItemDetails.Visible = true;

            switch (Session["RoleCode"].ToString())
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
            gv.BackColor = System.Drawing.Color.FromName("#FEE2C3");

            BindActionItemDetails(int.Parse(lblActionItemId.Text));

            ActionItemMgr.UpdateActionItemByUserId(int.Parse(Session["UserId"].ToString()), int.Parse(lblActionItemId.Text));

            LoadActionItemGRV();
        }
        #endregion

        #region BindActionItemDetails
        private void BindActionItemDetails(int ActionItemId)
        {
            DataTable dtActionItem = new DataTable();
            dtActionItem = ActionItemMgr.GetActionItemByActionItemIdUserId(ActionItemId, int.Parse(Session["UserId"].ToString()));

            txtAgendaNumber.Text = dtActionItem.Rows[0]["AgendaNo"].ToString();
            hdnActionItemId.Value = dtActionItem.Rows[0]["ActionItemId"].ToString();
            txtSubjectNumber.Text = dtActionItem.Rows[0]["SubjectNo"].ToString();
            txtActionDepartment.Text = dtActionItem.Rows[0]["DepartmentName"].ToString();
            txtDecisionType.Text = dtActionItem.Rows[0]["DecisionTypeName"].ToString();
            //txtDueDate.Text = Convert.ToDateTime(dtActionItem.Rows[0]["DueDate"].ToString()).ToString("dd-MMM-yyyy"); ;
            ftxtActualResolution.Text = dtActionItem.Rows[0]["ActualResolution"].ToString();
            ftxtActionText.Text = dtActionItem.Rows[0]["ActionText"].ToString();
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
                    e.Row.BackColor = System.Drawing.Color.FromName("#FEE2C3");
                }
                else
                {
                    e.Row.Font.Bold = true;
                    e.Row.BackColor = System.Drawing.Color.FromName("#FFCF9A");
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
                    e.Row.BackColor = System.Drawing.Color.FromName("#FEE2C3");
                }
                else
                {
                    e.Row.Font.Bold = true;
                    e.Row.BackColor = System.Drawing.Color.FromName("#FFCF9A");
                }
            }
        }
        #endregion

        #region BindCommitteeDetails
        private void BindCommitteeDetails(int CommitteeId)
        {
            CommitteeBAL myCommittee = new CommitteeBAL();
            myCommittee = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);

            hdnCommitteeId.Value = myCommittee.CommitteeId.ToString();
            txtCommitteeCode.Text = myCommittee.CommitteeCode;
            txtCommitteeName.Text = myCommittee.CommitteeName;
            txtIncorporationDate.Text = myCommittee.IncorporationDate.ToString("dd-MMM-yyyy");

        }
        #endregion

        #region BindMeetingDetails
        private void BindMeetingDetails(int MeetingId)
        {
            DataTable dtMeeting = new DataTable();
            dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

            hdnMeetingId.Value = dtMeeting.Rows[0]["MeetingId"].ToString();

            txtMeetingNo.Text = dtMeeting.Rows[0]["MeetingNo"].ToString();
            txtCommittee.Text = dtMeeting.Rows[0]["CommitteeName"].ToString();
            txtVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
            txtMeetingDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
            txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();
            txtAgendaSubmissionDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["AgendaSubmissionDate"].ToString()).ToString("dd-MMM-yyyy");
        }
        #endregion

        #region BindAgendaDetails
        private void BindAgendaDetails(int AgendaId)
        {
            DataTable dtAgendaEdit = new DataTable();
            dtAgendaEdit = AgendaMgr.GetAgendaByAgendaId(AgendaId);

            txtAgendaNo.Text = dtAgendaEdit.Rows[0]["AgendaNo"].ToString();
            txtSubjectNo.Text = dtAgendaEdit.Rows[0]["SubjectNo"].ToString();
            hdnAgendaId.Value = dtAgendaEdit.Rows[0]["AgendaId"].ToString();
            txtAgendaCommittee.Text = dtAgendaEdit.Rows[0]["CommitteeName"].ToString();
            hdnAgendaCommittee.Value = dtAgendaEdit.Rows[0]["CommitteeId"].ToString();
            txtAgendaMeeting.Text = dtAgendaEdit.Rows[0]["MeetingNo"].ToString();
            hdnAgendaMeeting.Value = dtAgendaEdit.Rows[0]["MeetingId"].ToString();
            int MeetingId = Convert.ToInt16(dtAgendaEdit.Rows[0]["MeetingId"].ToString());
            txtDateOfMeeting.Text = Convert.ToDateTime(dtAgendaEdit.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy"); ;
            txtAgendaDepartment.Text = dtAgendaEdit.Rows[0]["DepartmentName"].ToString();
            txtSubjectType.Text = dtAgendaEdit.Rows[0]["SubjectTypeName"].ToString();
            txtShortText.Text = dtAgendaEdit.Rows[0]["ShortText"].ToString();

            if (dtAgendaEdit.Rows[0]["AgendaType"].ToString() == "Entry")
            {
                ftxtAgendaText.Visible = true;
                aAgendaText.Visible = false;
                ftxtAgendaText.Text = dtAgendaEdit.Rows[0]["AgendaText"].ToString();
            }
            else
            {
                ftxtAgendaText.Visible = false;
                aAgendaText.Visible = true;
                aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString());
            }

            ftxtProposedResolution.Text = dtAgendaEdit.Rows[0]["ProposedResolution"].ToString();

            string[] attFiles = dtAgendaEdit.Rows[0]["FilePath"].ToString().Split(',');
            DataTable dtAttFiles = new DataTable();
            dtAttFiles.Columns.Add("FilePathOrg");
            dtAttFiles.Columns.Add("FilePath");
            dtAttFiles.Columns.Add("DisplayName");

            for (int i = 0; i < attFiles.Length; i++)
            {
                DataRow dr = dtAttFiles.NewRow();
                dr["FilePathOrg"] = attFiles[i].ToString();
                dr["FilePath"] = "../Files/AgendaAttach/" + attFiles[i].ToString();
                dr["DisplayName"] = attFiles[i].ToString();
                dtAttFiles.Rows.Add(dr);
            }

            grvAttachedFiles.DataSource = dtAttFiles;
            grvAttachedFiles.DataBind();

            ftxtManagerComments.Text = dtAgendaEdit.Rows[0]["MgrComments"].ToString();
            ftxtControllerComments.Text = dtAgendaEdit.Rows[0]["ControllerComments"].ToString();

            DataTable dtAgenda = new DataTable();
            dtAgenda = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId);

            if (dtAgenda.Rows.Count <= 0)
            {
                txtShortText.ReadOnly = true;
                ftxtAgendaText.ReadOnly = true;
                ftxtProposedResolution.ReadOnly = true;
                ftxtManagerComments.ReadOnly = true;
                ftxtControllerComments.ReadOnly = true;
                btnApprove.Visible = false;
                btnReject.Visible = false;
                btnDeleteAgendaAlert.Visible = true;
            }
            else
            {

                txtShortText.ReadOnly = true;
                ftxtAgendaText.ReadOnly = true;
                ftxtProposedResolution.ReadOnly = true;
                btnApprove.Visible = false;
                btnReject.Visible = false;
                btnDeleteAgendaAlert.Visible = true;

                switch (Session["RoleCode"].ToString())
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
                            btnDeleteAgendaAlert.Visible = false;
                        }

                        break;
                    case "user":
                        ftxtManagerComments.ReadOnly = true;
                        ftxtControllerComments.ReadOnly = true;
                        btnApprove.Visible = false;
                        btnReject.Visible = false;
                        btnDeleteAgendaAlert.Visible = true;
                        break;
                    default:
                        ftxtManagerComments.ReadOnly = false;
                        ftxtControllerComments.ReadOnly = false;
                        if (dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() != "Approved" && dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() != "Rejected")
                        {
                            btnApprove.Visible = true;
                            btnReject.Visible = true;
                            btnDeleteAgendaAlert.Visible = false;
                        }
                        break;

                }
            }
        }
        #endregion

        #region OnPaging
        protected void OnPaging(object sender, GridViewPageEventArgs e)
        {
            DataTable dtAlert = (DataTable)ViewState["dtAlert"];
            grvAlert.DataSource = dtAlert;
            grvAlert.PageIndex = e.NewPageIndex;
            grvAlert.DataBind();
        }
        #endregion

        #region OnPagingAction
        protected void OnPagingAction(object sender, GridViewPageEventArgs e)
        {
            DataTable dtActionItem = (DataTable)ViewState["dtActionItem"];
            grvActionItem.DataSource = dtActionItem;
            grvActionItem.PageIndex = e.NewPageIndex;
            grvActionItem.DataBind();
        }
        #endregion

        #region btnApprove_Click
        protected void btnApprove_Click(object sender, EventArgs e)
        {
            int MeetingId = int.Parse(hdnAgendaMeeting.Value);
            int AgendaId = int.Parse(hdnAgendaId.Value);

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = int.Parse(hdnAgendaId.Value);
            agendaBal.ShortText = txtShortText.Text.Trim();
            agendaBal.ProposedResolution = ftxtProposedResolution.Text.Trim();
            agendaBal.MgrComments = ftxtManagerComments.Text.Trim();
            agendaBal.ControllerComments = ftxtControllerComments.Text.Trim();
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            if (Session["RoleCode"].ToString() == "manager")
            {
                agendaBal.MgrApprovedStatus = "Approved";
                GenerateMail("approved by Manager", "AMA");
            }

            if (Session["RoleCode"].ToString() == "controller")
            {
                agendaBal.ControllerApprovedStatus = "Approved";
                GenerateMail("approved by Controller", "ACA");
            }

            agendaBal.UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

            AgendaMgr.UpdateAgendaByAgendaId(agendaBal);

            int result = AgendaMgr.GenerateSubjectNoByMeetingId(MeetingId, AgendaId);

            pnlAgenda.Visible = false;

            LoadAlertGRV();
        }
        #endregion

        #region btnReject_Click
        protected void btnReject_Click(object sender, EventArgs e)
        {
            int MeetingId = int.Parse(hdnAgendaMeeting.Value);
            int AgendaId = int.Parse(hdnAgendaId.Value);

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = int.Parse(hdnAgendaId.Value);
            agendaBal.ShortText = txtShortText.Text.Trim();
            agendaBal.ProposedResolution = ftxtProposedResolution.Text.Trim();
            agendaBal.MgrComments = ftxtManagerComments.Text.Trim();
            agendaBal.ControllerComments = ftxtControllerComments.Text.Trim();
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            if (Session["RoleCode"].ToString() == "manager")
            {
                agendaBal.MgrApprovedStatus = "Rejected";
                GenerateMail("rejected by Manager", "AMR");
            }

            if (Session["RoleCode"].ToString() == "controller")
            {
                agendaBal.ControllerApprovedStatus = "Rejected";
                GenerateMail("rejected by Controller", "ACR");
            }

            agendaBal.UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

            AgendaMgr.UpdateAgendaByAgendaId(agendaBal);

            pnlAgenda.Visible = false;
            LoadAlertGRV();
        }
        #endregion

        #region GenerateMail
        private string GenerateMail(string AgendaStatus, string MailCode)
        {
            string ToMailId = string.Empty;
            string Bcc = string.Empty;
            int AgendaId = int.Parse(hdnAgendaId.Value);
            int UserId = int.Parse(Session["UserId"].ToString());

            UserBAL userBal = UserMgr.GetUserByUserId(UserId);
            ToMailId = userBal.EmailId.ToString();

            Bcc = AlertMgr.GetAlertMailId(MailCode, UserId, AgendaId);

            string Subject = "Agenda (" + txtAgendaNo.Text.Trim() + ") has been " + AgendaStatus.ToString();
            string BodyText = string.Empty;
            BodyText += "<table>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Agenda No <br /><br />";
            BodyText += "Committee Name <br /><br />";
            BodyText += "Meeting No <br /><br />";
            BodyText += "Meeting Date <br /><br />";
            BodyText += "Department <br /><br />";
            BodyText += "Subject Type <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + txtAgendaNo.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtAgendaCommittee.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtAgendaMeeting.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtDateOfMeeting.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtAgendaDepartment.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtSubjectType.Text.Trim() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Short Text <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + txtShortText.Text.Trim() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "</table>";

            string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);

            

            return result;

        }
        #endregion

        #region btnActionItemApprove_Click
        protected void btnActionItemApprove_Click(object sender, EventArgs e)
        {
            string Code = "ActionText";
            int ActionItemId = int.Parse(hdnActionItemId.Value);
            string Directions = string.Empty;
            string ActualResolution = ftxtActualResolution.Text.Trim();
            string ActionText = ftxtActionText.Text.Trim();
            int IsComplied = 0;
            int IsConfirmed = 0;

            ActionItemMgr.UpdateActionItem(Code, ActionItemId, Directions, ActionText, IsComplied, IsConfirmed);

            pnlActionItemDetails.Visible = false;
        }
        #endregion

        #region btnActionItemClose_Click
        protected void btnActionItemClose_Click(object sender, EventArgs e)
        {
            pnlActionItemDetails.Visible = false;
        }
        #endregion

        #region btnActionItemCancel_Click
        protected void btnActionItemCancel_Click(object sender, EventArgs e)
        {
            pnlActionItemDetails.Visible = false;
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
            LoadAlertGRV();
        }
        #endregion

        #region btnDeleteAlert_Click
        protected void btnDeleteAlert_Click(object sender, EventArgs e)
        {
            int AlertUserId = Convert.ToInt16(hdnAlertUserId.Value.Trim());
            AlertMgr.UpdateAlertByAlertUserId(AlertUserId);
            pnlAgenda.Visible = false;
            LoadAlertGRV();
        }
        #endregion

    }
}
