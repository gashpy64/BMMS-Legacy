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
using iTextSharp.text;
using iTextSharp.text.pdf;
using System.IO;

namespace BMMS.Report
{
    public partial class Followup : System.Web.UI.Page
    {
        private string className = "followup_report";
        private string reportCode = string.Empty;

        // Step RA1b: Management's path (role read from the database in Page_Load for every request). Step FU2b: it
        // decides the minutes status (column, lines, Summary column); both roles read spr_GetFollowupReport (step 49)
        private bool forManagement = false;
        private int reportReason = 0;

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {

            // Step RA1b: Followup and Followup Summary for the Controller and Management, checked on the server with the
            // role read from the database; any other report code (or none) is refused. Step FU2b: both roles read their
            // rows through spr_GetFollowupReport (step 49); Management's rows carry the minutes status.
            string fc = Request.QueryString["fc"];
            if (fc != "followup" && fc != "summary")
                BMMS.Security.PageAccessModule.RefuseRequest("unknown report code");
            BMMS.Security.PageAccessModule.RequireRole("controller", "mgmt");
            forManagement = BMMS.Security.PageAccessModule.HasRole("mgmt");
            // Step RA1b: a Management session whose role could not be read from the database here (a database error)
            // is refused, rather than given the Controller's path without the minutes status
            if (!forManagement && (Session["RoleCode"] as string) == "mgmt")
                BMMS.Security.PageAccessModule.RefuseRequest("role could not be read for the Management path");

            ViewState["reportCode"] = fc;
            reportCode = fc;

            Common.InitSetup(className);

            switch (reportCode)
            {
                case "followup":
                    lblPageHeader.Text = ":: Followup Report";
                    break;
                case "summary":
                    lblPageHeader.Text = ":: Followup Summary Report";
                    break;
            }

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();

                pnlViewFollowup.Visible = false;

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
            // Step RA1b: back to the same report (the page needs fc; without it the page is refused)
            Response.Redirect("~/Report/Followup.aspx?fc=" + HttpUtility.UrlEncode(reportCode));
        }
        #endregion

        #region btnViewFollowup_Click
        protected void btnViewFollowup_Click(object sender, EventArgs e)
        {
            MsgHide();
            string sMsg = string.Empty;
            try
            {
                GetReportDetails();

                // Step RA1b: the procedure refused (Reason 8 or 4): its message, no grid. Step FU2b: for both roles
                if (reportReason != 0)
                {
                    pnlViewFollowup.Visible = false;
                    MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
                    return;
                }

                // Step RA1b: the Minutes status column (last) only for Management
                grvFollowup.Columns[grvFollowup.Columns.Count - 1].Visible = forManagement;
                BindGridView();

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnViewFollowup_Click", ex);
            }

        }
        #endregion


        #region StatusMarkText
        // Step RA1b: the Minutes status column of the grid (Management only)
        protected string StatusMarkText(object DataItem)
        {
            DataRowView row = DataItem as DataRowView;
            return row == null ? string.Empty : HttpUtility.HtmlEncode(ReportsMgr.StatusMarkOf(row.Row));
        }
        #endregion

        #region Followup status (step FU2b)
        // The status of one row, the texts of the Followup page (FollowupStatusText): the word ("Pending", "Confirmed",
        // "Confirmed (before history)") and the line of who confirmed or reopened it (and the reason). The Followup
        // Summary shows the word Pending or Confirmed only. Plain text: the callers encode it.
        private bool IsSummary
        {
            get { return Convert.ToString(ViewState["reportCode"]) == "summary"; }
        }

        private static string StatusWordOf(DataRow Row, bool WordOnly)
        {
            return FollowupStatusText.Word(FollowupStatusText.IsSet(Row["IsConfirmed"]), StatusValue(Row, "StatusAction"), WordOnly);
        }

        private static string StatusLineOf(DataRow Row)
        {
            return FollowupStatusText.Line(FollowupStatusText.IsSet(Row["IsConfirmed"]), StatusValue(Row, "StatusAction"),
                StatusValue(Row, "StatusReason"), StatusValue(Row, "StatusOn"), StatusValue(Row, "StatusByName"),
                StatusValue(Row, "StatusByLogin"), StatusValue(Row, "StatusByActive"));
        }

        private static object StatusValue(DataRow Row, string Column)
        {
            return Row.Table.Columns.Contains(Column) ? Row[Column] : DBNull.Value;
        }

        // The Status cell of the View grid: the word and the line (Followup) or the word only (Summary), each encoded,
        // in the classes of the Followup page's Status cell
        protected string StatusCellHtml(object DataItem)
        {
            DataRowView row = DataItem as DataRowView;
            if (row == null)
                return string.Empty;

            string html = "<span class=\"wb-followup-status\">" + HttpUtility.HtmlEncode(StatusWordOf(row.Row, IsSummary)) + "</span>";
            string line = IsSummary ? string.Empty : StatusLineOf(row.Row);
            if (line.Length > 0)
                html += "<span class=\"wb-followup-status-line\">" + HttpUtility.HtmlEncode(line) + "</span>";
            return html;
        }

        // The status block of an item in the Followup report (Print, Export to Pdf, Export to Word): the heading, the word
        // in bold and the line under it; a long reason wraps inside the report's width
        private static string StatusBlockHtml(DataRow Row)
        {
            string line = StatusLineOf(Row);
            string html = "<div style='float:left; width:100%; text-align:left; font-weight:bold;'>FOLLOWUP STATUS</div>";
            html += "<div style='float:left; width:100%; text-align:left; word-wrap:break-word; overflow-wrap:break-word;'>";
            html += "<b>" + HttpUtility.HtmlEncode(StatusWordOf(Row, false)) + "</b>";
            if (line.Length > 0)
                html += "<br />" + HttpUtility.HtmlEncode(line);
            html += "<br /><br /><br /></div>";
            return html;
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            DataTable dtFollowup = new DataTable();
            dtFollowup = (DataTable)ViewState["dtFollowup"];

            grvFollowup.DataSource = dtFollowup;
            grvFollowup.DataBind();
        }
        #endregion


        #region btnGenerateReport_Click
        protected void btnGenerateReport_Click(object sender, EventArgs e)
        {
            if (CheckValidataion())
            {
                try
                {
                    MsgHide();

                    DataTable dtReportsDetails = new DataTable();
                    dtReportsDetails = GetReportDetails();

                    if (reportReason != 0)
                    {
                        // Step RA1b: the procedure refused (Reason 8 or 4). Step FU2b: for both roles
                        MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
                    }
                    else if (dtReportsDetails.Rows.Count <= 0)
                    {
                        MsgDisplay(Session["NoRecord"].ToString());
                        ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                    }
                    else
                    {
                        GenReport(dtReportsDetails);
                    }
                }
                catch (Exception ex)
                {
                    BMMSBAL.Utilities.GoToErrPage(className, "btnGenerateReport_Click", ex);
                }
            }
        }
        #endregion

        #region GenReport
        private void GenReport(DataTable dtReportsDetails)
        {
            reportCode = ViewState["reportCode"].ToString();

            // Step RA1b: which report ViewReport.aspx shows; it lets Management open only its own report kinds. Cleared
            // first and set again only once the report is stored below, so a failed build leaves no kind (refused)
            Session.Remove("ViewReportKind");

            switch (reportCode)
            {
                case "followup":
                    Session["ViewReport"] = CreateFollowupReportHTML(dtReportsDetails);
                    Session["ViewReportName"] = "Followup";   // ViewReport.aspx, Export to Pdf (step 25)
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(" + Common.GetReportSettings("FollowupReport_Width") + ",500,'ViewReport.aspx','Followup Report');", true);
                    break;
                case "summary":
                    Session["ViewReport"] = CreateFollowupSummaryReportHTML(dtReportsDetails);
                    Session["ViewReportName"] = "FollowupSummary";   // ViewReport.aspx, Export to Pdf (step 25)
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(" + Common.GetReportSettings("FollowupReport_Width") + ",500,'ViewReport.aspx','Followup Summary Report');", true);
                    break;
            }

            // Step RA1b: the report is stored; now ViewReport.aspx may show it (see above)
            Session["ViewReportKind"] = reportCode;
        }
        #endregion

        #region CheckValidataion
        private bool CheckValidataion()
        {
            bool result = true;

            try
            {
                if (ddlCommittee.SelectedValue.ToString() == "0")
                {
                    MsgDisplay("Select committee name.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                    result = false;
                }
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "CheckValidataion", ex.ToString());
            }
            return result;
        }
        #endregion

        #region GetReportDetails
        private DataTable GetReportDetails()
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

            // Step FU2b (BMMS-Fix-FollowupReports-Step49.sql): one procedure for the Controller and Management, with the
            // acting user; the role is read in the database (Reason 8 or 4: no rows). Management's rows carry the minutes
            // status. The From and To dates are not used, as before.
            DataTable dtFollowup = ReportsMgr.GetFollowupReport(int.Parse(Session["UserId"].ToString()), CommitteeId,
                MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId, DepartmentId, ConfirmStatus, out reportReason);

            ViewState["dtFollowup"] = dtFollowup;

            return dtFollowup;

        }
        #endregion

        #region CreateFollowupReportHTML
        private string CreateFollowupReportHTML(DataTable dtFollowup)
        {

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            string htmlTxt = string.Empty;

            try
            {
                DataTable dtDepartment = new DataTable();
                DataView dv = new DataView(dtFollowup);
                dtDepartment = dv.ToTable("dtFollowup", true, "DepartmentId", "DepartmentName");

                string para = string.Empty;

                for (int i = 0; i < dtDepartment.Rows.Count; i++)
                {
                    DataTable dtFollowupFilter = new DataTable();
                    DataView dvFollowup = new DataView(dtFollowup);
                    dvFollowup.RowFilter = "DepartmentId = " + int.Parse(dtDepartment.Rows[i]["DepartmentId"].ToString());
                    dtFollowupFilter = dvFollowup.ToTable("dtFollowup");


                    htmlTxt += "<div style='font-size:12pt; font-family: Times New Roman; width: " + Common.GetReportSettings("FollowupReport_Width") + "px;'>";

                    htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt; font-weight:bold'>";
                    htmlTxt += "DEPARTMENT : " + HttpUtility.HtmlEncode(dtDepartment.Rows[i]["DepartmentName"].ToString()) + "<br /><br /></div>";

                    for (int j = 0; j < dtFollowupFilter.Rows.Count; j++)
                    {
                        htmlTxt += "<div style='float:left; width:100%;'>";
                        htmlTxt += "<b>" + HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["SubjectNo"].ToString());
                        htmlTxt += "   (" + Convert.ToDateTime(dtFollowupFilter.Rows[j]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy") + ")";
                        htmlTxt += "</b><br /><br /></div>";

                        // Step RA1b: Management's Followup shows the minutes status of each item; a draft also the bordered note.
                        // Step FU2b: by the role read from the database (the Controller's rows carry no mark)
                        string statusMark = forManagement ? ReportsMgr.StatusMarkOf(dtFollowupFilter.Rows[j]) : string.Empty;
                        if (statusMark.Length > 0)
                        {
                            htmlTxt += HTML_Report.MinutesStatusLine(statusMark);
                            if (HTML_Report.IsDraftMark(statusMark))
                                htmlTxt += HTML_Report.DraftNote();
                        }

                        htmlTxt += "<div style='float:left; width:100%;text-aligh:justify;'>";
                        htmlTxt += "<b>" + HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["ShortText"].ToString()) + "</b>";
                        htmlTxt += "<br /><br /></div>";

                        htmlTxt += "<div style='float:left; width:100%;text-aligh:justify;'>";
                        htmlTxt += HTML_Report.ReplaceRichTextFont(HtmlCleaner.Clean(dtFollowupFilter.Rows[j]["ProposedResolution"].ToString()));
                        htmlTxt += "<br /><br /></div>";

                        htmlTxt += "<div style='float:left; width:100%;text-aligh:justify;font-weight:bold;'>";
                        htmlTxt += "ACTION TAKEN";
                        htmlTxt += "<br />" + HTML_Report.ReplaceRichTextFont(HtmlCleaner.Clean(dtFollowupFilter.Rows[j]["ActionText"].ToString()));
                        htmlTxt += "<br /><br /></div>";

                        // Step FU2b: who confirmed or reopened the item (the texts of the Followup page)
                        htmlTxt += StatusBlockHtml(dtFollowupFilter.Rows[j]);

                    }

                    htmlTxt += "</div>";

                    if (i != dtDepartment.Rows.Count - 1)
                        htmlTxt += HTML_Report.HTML_PageBreak();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {

            }

            return htmlTxt;

        }
        #endregion

        #region CreateFollowupSummaryReportHTML
        private string CreateFollowupSummaryReportHTML(DataTable dtFollowup)
        {

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            string htmlTxt = string.Empty;

            try
            {
                DataTable dtDepartment = new DataTable();
                DataView dv = new DataView(dtFollowup);
                dtDepartment = dv.ToTable("dtFollowup", true, "DepartmentId", "DepartmentName");

                string para = string.Empty;

                for (int i = 0; i < dtDepartment.Rows.Count; i++)
                {
                    DataTable dtFollowupFilter = new DataTable();
                    DataView dvFollowup = new DataView(dtFollowup);
                    dvFollowup.RowFilter = "DepartmentId = " + int.Parse(dtDepartment.Rows[i]["DepartmentId"].ToString());
                    dtFollowupFilter = dvFollowup.ToTable("dtFollowup");


                    htmlTxt += "<div style='font-size:12pt; font-family: Times New Roman; width: " + Common.GetReportSettings("FollowupReport_Width") + "px;'>";

                    htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:12pt; font-weight:bold'>";
                    htmlTxt += "DEPARTMENT : " + HttpUtility.HtmlEncode(dtDepartment.Rows[i]["DepartmentName"].ToString()) + "<br /><br /></div>";


                    htmlTxt += "<div style='float:left; width:100%;'>";
                    htmlTxt += "<table width='100%' border='1' cellspacing='0' cellpadding='0'>";
                    htmlTxt += "<tr>";
                    htmlTxt += "<td style='text-align:center; font-weight:bold;'>M.No.";
                    htmlTxt += "</td>";
                    htmlTxt += "<td style='text-align:center; font-weight:bold;'>Date";
                    htmlTxt += "</td>";
                    htmlTxt += "<td style='text-align:center; font-weight:bold;'>Sub.No";
                    htmlTxt += "</td>";
                    htmlTxt += "<td style='text-align:center; font-weight:bold;'>Subject";
                    htmlTxt += "</td>";
                    // Step FU2b: the Followup status of each item, the word Pending or Confirmed only
                    htmlTxt += "<td style='text-align:center; font-weight:bold;'>Followup status";
                    htmlTxt += "</td>";
                    // Step RA1b: Management's Followup Summary has a Minutes status column. Step FU2b: by the role read
                    // from the database (every row has the column since step 49)
                    bool withStatus = forManagement;
                    if (withStatus)
                    {
                        htmlTxt += "<td style='text-align:center; font-weight:bold;'>Minutes status";
                        htmlTxt += "</td>";
                    }
                    htmlTxt += "</tr>";

                    string PrevMeetingNo = string.Empty;

                    for (int j = 0; j < dtFollowupFilter.Rows.Count; j++)
                    {
                        string currentMeetingNo = dtFollowupFilter.Rows[j]["MeetingNo"].ToString();

                        htmlTxt += "<tr>";
                        if (PrevMeetingNo == currentMeetingNo)
                        {
                            htmlTxt += "<td style='text-align:center;'>&nbsp;";
                            htmlTxt += "</td>";
                            htmlTxt += "<td style='text-align:center;'>&nbsp;";
                            htmlTxt += "</td>";
                        }
                        else
                        {
                            htmlTxt += "<td style='text-align:center;'>" + HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["MeetingNo"].ToString());
                            htmlTxt += "</td>";
                            htmlTxt += "<td style='text-align:center;'>" + Convert.ToDateTime(dtFollowupFilter.Rows[j]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
                            htmlTxt += "</td>";                          

                            PrevMeetingNo = currentMeetingNo;
                        }
                        
                        htmlTxt += "<td style='text-align:center;'>" + HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["SubjectNo"].ToString());
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='text-align:left;'>" + HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["ShortText"].ToString());
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='text-align:left;'>" + HttpUtility.HtmlEncode(StatusWordOf(dtFollowupFilter.Rows[j], true));
                        htmlTxt += "</td>";
                        if (withStatus)
                        {
                            // Step RA1b: the mark as plain bold text in the bordered cell
                            htmlTxt += "<td style='text-align:left; font-weight:bold;'>"
                                     + HttpUtility.HtmlEncode(ReportsMgr.StatusMarkOf(dtFollowupFilter.Rows[j]));
                            htmlTxt += "</td>";
                        }
                        htmlTxt += "</tr>";
                    }

                    htmlTxt += "</table>";
                    htmlTxt += "</div>";

                    htmlTxt += "</div>";

                    if (i != dtDepartment.Rows.Count - 1)
                        htmlTxt += HTML_Report.HTML_PageBreak();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {

            }

            return htmlTxt;

        }
        #endregion



        #region btnSendMail_Click
        protected void btnSendMail_Click(object sender, EventArgs e)
        {
            MsgHide();
            DataTable dtFollowup = new DataTable();
            dtFollowup = GetReportDetails();

            // Step FU2b: a refusal is not "no record" (this handler has no button in the page)
            if (reportReason != 0)
                MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
            else if (dtFollowup.Rows.Count <= 0)
            {
                MsgDisplay(Session["NoRecord"].ToString());
                ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
            }
            else
            {
                CreateBodyText();
                MsgDisplay("Mail was sent to all members.", MessageKind.Success);
            }
        }
        #endregion

        #region CreateBodyText
        private void CreateBodyText()
        {
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);
            int MeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue);

            DataTable dtCommitteeMember = new DataTable();
            dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);

            DataTable dtCompanySecretary = UserMgr.GetCompanySecretary(int.Parse(ddlMeetingNoFrom.SelectedValue.ToString()));
            string CompanySecretary = string.Empty;
            string CompanySecretaryDesign = string.Empty;

            if (dtCompanySecretary.Rows.Count > 0)
            {
                CompanySecretary = dtCompanySecretary.Rows[0]["CompanySecretary"].ToString();
                CompanySecretaryDesign = dtCompanySecretary.Rows[0]["DesignationName"].ToString();
            }

            if (dtCommitteeMember.Rows.Count <= 0)
            {
                ScriptManager.RegisterStartupScript(this, this.GetType(), "msg", "alert('No Committee-Member or Meeting-Members Available');", true);
                ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
            }
            else
            {
                try
                {
                    string ToMailId = string.Empty;

                    int UserId = Convert.ToInt16(Session["UserId"].ToString());
                    UserBAL userBal = UserMgr.GetUserByUserId(UserId);
                    ToMailId = userBal.EmailId.ToString();

                    string Bcc = string.Empty;

                    for (int i = 0; i < dtCommitteeMember.Rows.Count; i++)
                    {
                        if (i == dtCommitteeMember.Rows.Count - 1)
                            Bcc += dtCommitteeMember.Rows[i]["EmailId"].ToString();
                        else
                            Bcc += dtCommitteeMember.Rows[i]["EmailId"].ToString() + ", ";
                    }

                    string BodyText = string.Empty;


                    //pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                    BodyText += "<table>";

                    BodyText += OrganisationDetails.Current.MailHeaderRowHtml();

                    BodyText += "<tr>";
                    BodyText += "<td colspan='2' style='text-align:right'>";
                    BodyText += "Date : " + System.DateTime.Now.ToString("dd-MM-yyyy");
                    BodyText += "</td>";
                    BodyText += "</tr>";

                    BodyText += "<tr>";
                    BodyText += "<td colspan='2' style='text-align:left'>";
                    BodyText += "Dear Sir/Madam,<br />";
                    BodyText += "<br />";
                    BodyText += "<b>Subject : " + HttpUtility.HtmlEncode(ViewState["MailSubject"].ToString()) + "</b><br />";
                    BodyText += "<br />";
                    BodyText += "Please find attached the Followup for the meeting as given below.";
                    BodyText += "<br />";
                    BodyText += "<br />";
                    BodyText += "Committee Name : " + HttpUtility.HtmlEncode(ddlCommittee.SelectedItem.Text.Trim());
                    BodyText += "<br />";

                    if (rdoMeatingNoSearch.SelectedValue.ToString() == "0")
                    {
                        BodyText += "Meeting No : " + HttpUtility.HtmlEncode(ddlMeetingNoFrom.SelectedItem.Text.Trim());
                        BodyText += "<br />";
                    }
                    if (rdoMeatingNoSearch.SelectedValue.ToString() == "1")
                    {
                        BodyText += "Meeting No : " + HttpUtility.HtmlEncode(ddlMeetingNoFrom.SelectedItem.Text.Trim());
                        BodyText += " to " + HttpUtility.HtmlEncode(ddlMeetingNoTo.SelectedItem.Text.Trim());
                        BodyText += "<br />";
                    }
                    BodyText += "<br />";
                    BodyText += "<br />";
                    BodyText += "Thanking You,<br />";
                    BodyText += "<br />";
                    BodyText += "Yours faithfully,<br />";
                    BodyText += "<br />";
                    BodyText += "<br />";
                    BodyText += "<br />";

                    if (CompanySecretary != string.Empty)
                    {
                        BodyText += "<b>(" + HttpUtility.HtmlEncode(CompanySecretary) + ")</b><br />";
                        BodyText += "<b>" + HttpUtility.HtmlEncode(CompanySecretaryDesign) + "</b>";
                    }
                    else
                    {
                        BodyText += "<b>Authorized Signatory</b>";
                    }

                    BodyText += "<br />";
                    BodyText += "</td>";
                    BodyText += "</tr>";
                    BodyText += "</table>";

                    string Subject = ViewState["MailSubject"].ToString();
                    string AttachFileName = Server.MapPath("~/Files/PDF") + "\\Followup.pdf";
                    Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, AttachFileName, Bcc);



                }
                catch (Exception ex)
                {
                    throw ex;
                }
                finally
                {

                }
            }
        }
        #endregion


        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtFollowup"] = BMMSBAL.Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtFollowup"]);

                BindGridView();
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
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
