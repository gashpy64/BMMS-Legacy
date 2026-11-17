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

namespace BMMS.Report
{
    // Step RA1c2: "Followup by Department" (the Controller's Reports menu, after Followup Summary). The follow-up
    // items of one committee, a meeting or a range of meetings, all departments or one, and all subjects or a
    // range; View shows the grid, Print builds the report for ViewReport.aspx (Print, Export to Pdf, Export to Word).
    // Controller only, checked with the role read from the database (as RA1a and RA1b). The Send Mail code, whose
    // button was commented out, was removed in RA1c2.
    // Step FU2b (BMMS-Fix-FollowupReports-Step49.sql): the rows come from spr_GetFollowupByDepartmentReport with the
    // acting user (the Controller only, the role read in the database), the committee and the subject range in the
    // procedure (whole numbers), and each item's Followup status (who confirmed or reopened it) in the grid and the
    // report. A refusal (Reason 8 or 4) shows ReportsMgr.ReportRefusedMessage, as on the Followup report.
    public partial class FollowupActionTaken : System.Web.UI.Page
    {
        private string className = "FollowupActionTaken";
        private int reportReason = 0;

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            // Step RA1c2: Controller only (role read from the database; ends the request otherwise)
            BMMS.Security.PageAccessModule.RequireRole("controller");

            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadDropDownList();
                rdoMeatingNoSearch.SelectedIndex = 0;
                lblMeetingNo.Visible = false;
                ddlMeetingNoTo.Visible = false;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = true;
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
            }
        }
        #endregion

        #region btnCreatePDF_Click
        // "Generate Report": the report HTML for ViewReport.aspx
        protected void btnCreatePDF_Click(object sender, EventArgs e)
        {
            // Step RA1c2: checked again before the action
            BMMS.Security.PageAccessModule.RequireRole("controller");

            try
            {
                MsgHide();
                // Step RA1c2 (security review): the same checks as Submit (committee, meeting, ranges)
                if (!CheckValidataion())
                    return;

                DataTable dtFollowup = GetFollowup();

                if (reportReason != 0)
                    MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
                else if (dtFollowup.Rows.Count <= 0)
                {
                    MsgDisplay(Convert.ToString(Session["NoRecord"]));
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                }
                else
                {
                    // Step RA1c2: no report kind of an earlier Minutes or Followup report stays behind (RA1b review)
                    Session.Remove("ViewReportKind");
                    Session["ViewReport"] = CreateReportHTML(dtFollowup);
                    Session["ViewReportName"] = "FollowupByDepartment";   // ViewReport.aspx, Export to Pdf (step 25)
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'ViewReport.aspx','Followup by Department');", true);
                }
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "btnCreatePDF_Click", ex);
            }
        }
        #endregion

        #region CreateReportHTML
        // The report of the rows given (the same rows as the grid: committee, meetings, department and subjects)
        private string CreateReportHTML(DataTable dtFollowup)
        {
            string htmlTxt = string.Empty;

            DataTable dtMeeting = MeetingMgr.GetMeetingList();

            htmlTxt += "<div style='float:left; width: 650px;'>";

            htmlTxt += OrganisationDetails.ReportBannerHtml();

            if (OrganisationDetails.Current.HeaderLine != string.Empty)
                htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt; padding-top:10px;'>" + OrganisationDetails.Html(OrganisationDetails.Current.HeaderLine) + "</div>";

            htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'><br /></div>";

            // border='1', not '1px': the PDF export (HTMLWorker) reads the border as a number and fails on a unit
            htmlTxt += "<table cellpadding='0' cellspacing='0' border='1' style='float:left; width:100%;'>";

            htmlTxt += "<tr>";
            htmlTxt += "<th style='width:10%'>M.No.";
            htmlTxt += "</th>";
            htmlTxt += "<th style='width:10%'>Date";
            htmlTxt += "</th>";
            htmlTxt += "<th style='width:10%'>Sub.No";
            htmlTxt += "</th>";
            htmlTxt += "<th style='width:70%'>Subject";
            htmlTxt += "</th>";
            htmlTxt += "</tr>";

            for (int i = 0; i < dtMeeting.Rows.Count; i++)
            {
                DataView dv = new DataView(dtFollowup);
                dv.RowFilter = "MeetingId = " + int.Parse(dtMeeting.Rows[i]["MeetingId"].ToString());
                DataTable dtFollowupFilter = dv.ToTable("dtFollowup");

                if (dtFollowupFilter.Rows.Count > 0)
                {
                    htmlTxt += "<tr>";
                    htmlTxt += "<td>";
                    htmlTxt += HttpUtility.HtmlEncode(dtFollowupFilter.Rows[0]["MeetingNo"].ToString());
                    htmlTxt += "</td>";
                    htmlTxt += "<td>";
                    htmlTxt += Convert.ToDateTime(dtFollowupFilter.Rows[0]["MeetingDate"].ToString()).ToString("dd/MM/yyyy");
                    htmlTxt += "</td>";
                    htmlTxt += "<td>";
                    htmlTxt += "</td>";
                    htmlTxt += "<td>";
                    htmlTxt += "</td>";
                    htmlTxt += "</tr>";

                    for (int j = 0; j < dtFollowupFilter.Rows.Count; j++)
                    {
                        htmlTxt += "<tr>";
                        htmlTxt += "<td>";
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";
                        htmlTxt += HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["SubjectNo"].ToString());
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='word-wrap:break-word; overflow-wrap:break-word;'>";
                        htmlTxt += HttpUtility.HtmlEncode(dtFollowupFilter.Rows[j]["ShortText"].ToString());
                        // Step FU2b: the Followup status under the subject (the texts of the Followup page), encoded
                        htmlTxt += "<br /><b>" + HttpUtility.HtmlEncode(StatusWordOf(dtFollowupFilter.Rows[j])) + "</b>";
                        string statusLine = StatusLineOf(dtFollowupFilter.Rows[j]);
                        if (statusLine.Length > 0)
                            htmlTxt += "<br /><span style='font-size:10pt;'>" + HttpUtility.HtmlEncode(statusLine) + "</span>";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";
                    }
                }
            }
            htmlTxt += "</table><br />";
            htmlTxt += "<spana style='color:white'>.</spana>";
            htmlTxt += "</div>";

            return htmlTxt;
        }
        #endregion

        #region LoadMeeting
        public void LoadMeeting(int CommitteeId)
        {
            DataTable dtMeeting = new DataTable();
            dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

            if (dtMeeting.Rows.Count <= 0)
            {
                ddlMeetingNoFrom.Enabled = false;
                ddlMeetingNoTo.Enabled = false;
            }
            else
            {
                Common.LoadDropdownlist(ddlMeetingNoFrom, dtMeeting, "MeetingNo", "MeetingId", true);
                Common.LoadDropdownlist(ddlMeetingNoTo, dtMeeting, "MeetingNo", "MeetingId", true);
            }
        }
        #endregion

        #region LoadDropDownList
        public void LoadDropDownList()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);

            DataTable dtDepartment = new DataTable();
            dtDepartment = DepartmentMgr.GetDepartmentList(1);

            Common.LoadDDLwithAll(ddlDeparment, dtDepartment, "DepartmentName", "DepartmentId", true);

            // Step RA1c2: Controller only, so every department can be chosen (the Manager's fixed home department
            // of the baseline is gone with the Manager's access)
            ddlDeparment.Text = "All";
            ddlDeparment.Enabled = true;
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            ddlMeetingNoFrom.Items.Clear();
            ddlMeetingNoTo.Items.Clear();
            ClearSubjectNo();
            pnlPrintReport.Visible = false;
            pnlViewReport.Visible = false;

            if (ddlCommittee.SelectedIndex > 0)
                LoadMeeting(Convert.ToInt32(ddlCommittee.SelectedValue));
        }
        #endregion

        #region ddlMeetingNoFrom_SelectedIndexChanged
        protected void ddlMeetingNoFrom_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region ddlMeetingNoTo_SelectedIndexChanged
        protected void ddlMeetingNoTo_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region ddlDeparment_SelectedIndexChanged
        protected void ddlDeparment_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
        }
        #endregion

        #region GetCommitteeFollowupRows
        // Step RA1c2: the follow-up rows of the chosen committee, meeting (or range of meetings) and department
        // (-1: all departments), or an empty table while no committee or meeting is chosen.
        // Step FU2b: through spr_GetFollowupByDepartmentReport (step 49), which takes the committee itself (the
        // RowFilter of RA1c2 is gone), the subject range as two whole numbers (null: no range) and the acting user;
        // reportReason is its Reason (0 allowed; 8 or 4 refused, then no rows).
        private DataTable GetCommitteeFollowupRows(int DepartmentId)
        {
            return GetCommitteeFollowupRows(DepartmentId, null, null);
        }

        private DataTable GetCommitteeFollowupRows(int DepartmentId, int? SubjectNoFrom, int? SubjectNoTo)
        {
            reportReason = 0;
            int committeeId, meetingNoFrom, meetingNoTo;

            if (!int.TryParse(ddlCommittee.SelectedValue, out committeeId) || committeeId <= 0)
                return new DataTable();
            if (ddlMeetingNoFrom.SelectedIndex <= 0 || !int.TryParse(ddlMeetingNoFrom.SelectedItem.Text.Trim(), out meetingNoFrom))
                return new DataTable();

            meetingNoTo = meetingNoFrom;
            if (rdoMeatingNoSearch.SelectedValue == "1")
            {
                if (ddlMeetingNoTo.SelectedIndex <= 0 || !int.TryParse(ddlMeetingNoTo.SelectedItem.Text.Trim(), out meetingNoTo))
                    return new DataTable();
            }

            int userId;
            if (!int.TryParse(Convert.ToString(Session["UserId"]), out userId))
                userId = 0;   // no session user: the procedure answers Reason 8

            return ActionItemMgr.GetFollowupByDepartmentReport(userId, committeeId, meetingNoFrom, meetingNoTo, DepartmentId,
                SubjectNoFrom, SubjectNoTo, out reportReason);
        }

        // A number shown in a list (meeting number "00001", subject number); -1 when it is not a number
        private static int SelectedNumber(string text)
        {
            int n;
            return int.TryParse((text ?? string.Empty).Trim(), out n) ? n : -1;
        }

        // The department chosen in the list: -1 for "- All -"
        private int SelectedDepartmentId()
        {
            int departmentId;
            if (ddlDeparment.SelectedValue != "All" && int.TryParse(ddlDeparment.SelectedValue, out departmentId))
                return departmentId;
            return -1;
        }
        #endregion

        #region BindSubjectNo, ClearSubjectNo
        // Step RA1c2: the Subject No lists offer exactly the subjects of the rows the grid and the report show for
        // the chosen committee, meetings and department (before RA1c2 they came from another query, which got the
        // department id as its "confirmed" filter)
        private void BindSubjectNo()
        {
            MsgHide();
            ClearSubjectNo();
            // Step RA1c2 (UX review): a grid or Print panel of earlier choices is not left on the page
            pnlViewReport.Visible = false;
            pnlPrintReport.Visible = false;

            DataTable dtRows = GetCommitteeFollowupRows(SelectedDepartmentId());

            // Step FU2b: refused by the procedure (Reason 8 or 4): its message, no subjects
            if (reportReason != 0)
            {
                MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
                return;
            }

            if (dtRows.Rows.Count <= 0)
            {
                ddlSubjectNoFrom.Enabled = false;
                ddlSubjectNoTo.Enabled = false;
                return;
            }

            DataView dv = new DataView(dtRows);
            dv.Sort = "SubjectNo";
            DataTable dtSubjects = dv.ToTable("dtSubjectNo", true, "SubjectNo");

            ddlSubjectNoFrom.DataSource = dtSubjects;
            ddlSubjectNoFrom.DataBind();

            ddlSubjectNoTo.DataSource = dtSubjects;
            ddlSubjectNoTo.DataBind();

            ddlSubjectNoFrom.SelectedIndex = 0;
            ddlSubjectNoTo.SelectedIndex = ddlSubjectNoTo.Items.Count - 1;

            bool between = rdoMeatingNoSearch.SelectedValue == "0" && rdoSubjectNoSearch.SelectedValue == "1";
            ddlSubjectNoFrom.Enabled = between;
            ddlSubjectNoTo.Enabled = between;
        }

        private void ClearSubjectNo()
        {
            ddlSubjectNoFrom.Items.Clear();
            ddlSubjectNoTo.Items.Clear();
        }
        #endregion

        #region rdoMeatingNoSearch_SelectedIndexChanged
        protected void rdoMeatingNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (rdoMeatingNoSearch.SelectedValue == "0")  // 0 for Particular
            {
                lblMeetingNo.Visible = false;
                ddlMeetingNoTo.Visible = false;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = true;
            }
            if (rdoMeatingNoSearch.SelectedValue == "1")  // 1 for Between
            {
                lblMeetingNo.Visible = true;
                ddlMeetingNoTo.Visible = true;
                rdoSubjectNoSearch.SelectedIndex = 0;
                rdoSubjectNoSearch.Enabled = false;
            }
            BindSubjectNo();
        }
        #endregion

        #region rdoSubjectNoSearch_SelectedIndexChanged
        protected void rdoSubjectNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            BindSubjectNo();
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
                else if (ddlMeetingNoFrom.SelectedIndex <= 0 || (rdoMeatingNoSearch.SelectedValue == "1" && ddlMeetingNoTo.SelectedIndex <= 0))
                {
                    MsgDisplay("Select meeting no.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                    result = false;
                }
                // Step RA1c2 (UX review): a range the wrong way round gives a message, not an empty result
                else if (rdoMeatingNoSearch.SelectedValue == "1" && SelectedNumber(ddlMeetingNoFrom.SelectedItem.Text) > SelectedNumber(ddlMeetingNoTo.SelectedItem.Text))
                {
                    MsgDisplay("Meeting No. From must not be greater than To.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                    result = false;
                }
                else if (rdoMeatingNoSearch.SelectedValue == "0" && rdoSubjectNoSearch.SelectedValue == "1" && ddlSubjectNoFrom.Items.Count > 0
                    && SelectedNumber(ddlSubjectNoFrom.SelectedValue) > SelectedNumber(ddlSubjectNoTo.SelectedValue))
                {
                    MsgDisplay("Subject No. From must not be greater than To.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlSubjectNoFrom.ClientID);
                    result = false;
                }
                // Step RA1c2: the committee's own follow-up items in all departments (before RA1c2: one meeting counted
                // only unconfirmed items, and a range counted the items of every committee)
                else if (GetCommitteeFollowupRows(-1).Rows.Count <= 0)
                {
                    // Step FU2b: a refusal (Reason 8 or 4) shows its own message
                    MsgDisplay(reportReason != 0 ? ReportsMgr.ReportRefusedMessage(reportReason) : "Followup not generated for this meeting.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeetingNoFrom.ClientID);
                    result = false;
                }
            }
            catch (Exception ex)
            {
                Utilities.WriteErrorLog(className, "CheckValidataion", ex.ToString());
                result = false;
            }
            return result;
        }
        #endregion

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            pnlViewReport.Visible = false;
            pnlPrintReport.Visible = false;

            if (CheckValidataion())
            {
                if (rdoViewFormat.Text == "View")
                {
                    pnlViewReport.Visible = true;
                    pnlPrintReport.Visible = false;

                    DataTable dtFollowup = GetFollowup();

                    // Step FU2b: refused by the procedure (Reason 8 or 4): its message, no grid
                    if (reportReason != 0)
                    {
                        pnlViewReport.Visible = false;
                        MsgDisplay(ReportsMgr.ReportRefusedMessage(reportReason));
                        return;
                    }

                    grvFollowup.DataSource = dtFollowup;
                    grvFollowup.DataBind();

                    // Step RA1c2 (UX review): a department with no items for these meetings gets the no-record message
                    if (dtFollowup.Rows.Count <= 0)
                        MsgDisplay(Convert.ToString(Session["NoRecord"]));
                }
                if (rdoViewFormat.Text == "Print")
                {
                    pnlViewReport.Visible = false;
                    pnlPrintReport.Visible = true;
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

        #region BindGridView
        private void BindGridView()
        {
            DataTable dtFollowup = (DataTable)ViewState["dtFollowup"];

            grvFollowup.DataSource = dtFollowup;
            grvFollowup.DataBind();
        }
        #endregion

        #region GetFollowup
        // The rows of the grid and of the report: the committee's follow-up items of the chosen meetings and
        // department, and with "Between" the chosen subject range. Kept in ViewState for the grid's sorting.
        // Step FU2b: the subject range goes to the procedure as two whole numbers (both parsed here; no RowFilter)
        private DataTable GetFollowup()
        {
            int? subjectFrom = null, subjectTo = null;
            int from, to;
            if (rdoMeatingNoSearch.SelectedValue == "0" && rdoSubjectNoSearch.SelectedValue == "1"
                && int.TryParse(ddlSubjectNoFrom.SelectedValue, out from) && int.TryParse(ddlSubjectNoTo.SelectedValue, out to))
            {
                subjectFrom = from;
                subjectTo = to;
            }

            DataTable dtFollowup = GetCommitteeFollowupRows(SelectedDepartmentId(), subjectFrom, subjectTo);

            ViewState["dtFollowup"] = dtFollowup;
            return dtFollowup;
        }

        #region Followup status (step FU2b)
        // The status of one row, the texts of the Followup page (FollowupStatusText): the word ("Pending", "Confirmed",
        // "Confirmed (before history)") and the line of who confirmed or reopened it (and the reason). Plain text:
        // the callers encode it.
        private static string StatusWordOf(DataRow Row)
        {
            return FollowupStatusText.Word(FollowupStatusText.IsSet(Row["IsConfirmed"]), StatusValue(Row, "StatusAction"), false);
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

        // The Status cell of the View grid: the word and the line, each encoded, in the classes of the Followup page
        protected string StatusCellHtml(object DataItem)
        {
            DataRowView row = DataItem as DataRowView;
            if (row == null)
                return string.Empty;

            string html = "<span class=\"wb-followup-status\">" + HttpUtility.HtmlEncode(StatusWordOf(row.Row)) + "</span>";
            string line = StatusLineOf(row.Row);
            if (line.Length > 0)
                html += "<span class=\"wb-followup-status-line\">" + HttpUtility.HtmlEncode(line) + "</span>";
            return html;
        }
        #endregion
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
