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
    public partial class Reports : System.Web.UI.Page
    {
        private string reportCode = "Reports";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            ViewState["reportCode"] = Request.QueryString.Get("rc").ToString();
            reportCode = Request.QueryString.Get("rc").ToString();

            Common.InitSetup(reportCode);

            switch (reportCode)
            {
                case "minutes":
                    lblPageHeader.Text = ":: Minutes Report";
                    break;
                case "minutes_extract":
                    lblPageHeader.Text = ":: Minutes Extract Report";
                    break;
                case "agenda_summary":
                    lblPageHeader.Text = ":: Agenda Summary";
                    break;
                case "agenda_details":
                    lblPageHeader.Text = ":: Agenda Details";
                    break;

            }

            if (!IsPostBack)
            {
                LoadCommittee();
                LoadDepartment();

                MeetingNoSearchChanged();

            }
        }
        #endregion

        #region LoadCommittee
        public void LoadCommittee()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
        }
        #endregion

        #region LoadDepartment
        public void LoadDepartment()
        {
            DataTable dtDepartment = new DataTable();
            dtDepartment = DepartmentMgr.GetDepartmentList(1);

            Common.LoadDDLwithAllNew(ddlDepartment, dtDepartment, "DepartmentName", "DepartmentId", true);

            UserBAL userBal = new UserBAL();
            userBal = UserMgr.GetUserByUserId(int.Parse(Session["UserId"].ToString()));

            if (Session["RoleCode"].ToString() == "manager")
            {
                ddlDepartment.Text = userBal.DepartmentId.ToString();
                ddlDepartment.Enabled = false;
            }
            else
            {
                ddlDepartment.Text = "All";
                ddlDepartment.Enabled = true;
            }
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewReport.Visible = false;

            MeetingNoSearchChanged();
            SubjectNoSearchChanged();
        }
        #endregion

        #region MeetingNoSearchChanged
        private void MeetingNoSearchChanged()
        {
            pnlViewReport.Visible = false;

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            rdoSubjectNoSearch.Enabled = false;
            ddlSubjectNoFrom.Items.Clear();
            ddlSubjectNoTo.Items.Clear();
            ddlSubjectNoFrom.Enabled = false;
            ddlSubjectNoTo.Enabled = false;

            pnlMeetingNoParticular.Visible = true;
            pnlMeetingNoBetween.Visible = false;
            ddlMeetingNo.Enabled = false;

            if (CommitteeId <= 0)
            {
                rdoMeatingNoSearch.Enabled = false;
            }
            else
            {
                rdoMeatingNoSearch.Enabled = true;
                if (rdoMeatingNoSearch.SelectedValue == "0")
                {
                    ddlMeetingNo.Enabled = true;

                    DataTable dtMeetingNo = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);
                    Common.LoadDDLwithAllNew(ddlMeetingNo, dtMeetingNo, "MeetingNo", "MeetingId", true);

                    if (dtMeetingNo.Rows.Count > 0)
                        ddlMeetingNo.SelectedIndex = 0;

                }
                if (rdoMeatingNoSearch.SelectedValue == "1")
                {
                    pnlMeetingNoParticular.Visible = false;
                    pnlMeetingNoBetween.Visible = true;
                    ddlMeetingNoFrom.Enabled = true;
                    ddlMeetingNoTo.Enabled = true;

                    DataTable dtMeetingNo = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);
                    Common.LoadDDLwithAllNew(ddlMeetingNoFrom, dtMeetingNo, "MeetingNo", "MeetingId", false);
                    Common.LoadDDLwithAllNew(ddlMeetingNoTo, dtMeetingNo, "MeetingNo", "MeetingId", false);

                    if (dtMeetingNo.Rows.Count > 0)
                    {
                        ddlMeetingNoFrom.SelectedIndex = 0;
                        ddlMeetingNoTo.SelectedIndex = ddlMeetingNoTo.Items.Count - 1;
                    }
                }
            }
        }
        #endregion

        #region ddlMeetingNo_SelectedIndexChanged
        protected void ddlMeetingNo_SelectedIndexChanged(object sender, EventArgs e)
        {
            SubjectNoSearchChanged();
        }
        #endregion

        #region SubjectNoSearchChanged
        private void SubjectNoSearchChanged()
        {
            pnlViewReport.Visible = false;

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());
            int DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString());

            if (CommitteeId > 0 && ddlMeetingNo.SelectedIndex > 0)
            {
                rdoSubjectNoSearch.Enabled = true;

                if (rdoSubjectNoSearch.SelectedValue == "0")
                {
                    ddlSubjectNoFrom.Items.Clear();
                    ddlSubjectNoTo.Items.Clear();
                    ddlSubjectNoFrom.Enabled = false;
                    ddlSubjectNoTo.Enabled = false;
                }
                if (rdoSubjectNoSearch.SelectedValue == "1")
                {
                    ddlSubjectNoFrom.Items.Clear();
                    ddlSubjectNoTo.Items.Clear();
                    ddlSubjectNoFrom.Enabled = true;
                    ddlSubjectNoTo.Enabled = true;

                    int MeetingId = int.Parse(ddlMeetingNo.SelectedValue.ToString());

                    DataTable dtSubjectNo = MinutesMgr.GetMinutesByMeetingId(MeetingId, 1, DepartmentId);

                    Common.LoadDDLwithAll(ddlSubjectNoFrom, dtSubjectNo, "SubjectNo", "SubjectNo", false);
                    Common.LoadDDLwithAll(ddlSubjectNoTo, dtSubjectNo, "SubjectNo", "SubjectNo", false);

                    if (dtSubjectNo.Rows.Count > 0)
                    {
                        ddlSubjectNoFrom.SelectedIndex = 0;
                        ddlSubjectNoTo.SelectedIndex = ddlSubjectNoTo.Items.Count - 1;
                    }
                }
            }

        }
        #endregion

        #region ddlDepartment_SelectedIndexChanged
        protected void ddlDepartment_SelectedIndexChanged(object sender, EventArgs e)
        {

            SubjectNoSearchChanged();
        }
        #endregion

        #region rdoMeatingNoSearch_SelectedIndexChanged
        protected void rdoMeatingNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            MeetingNoSearchChanged();
        }
        #endregion

        #region rdoSubjectNoSearch_SelectedIndexChanged
        protected void rdoSubjectNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            SubjectNoSearchChanged();
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
                Utilities.WriteErrorLog(reportCode, "CheckValidataion", ex.ToString());
            }
            return result;
        }
        #endregion

        #region btnView_Click
        protected void btnView_Click(object sender, EventArgs e)
        {
            if (CheckValidataion())
            {
                pnlViewReport.Visible = true;

                DataTable dtReportDetails = GetReportDetails();

                grvMinutes.DataSource = dtReportDetails;
                grvMinutes.DataBind();
            }
        }
        #endregion



        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtMinutes"] = BMMSBAL.Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtMinutes"]);

                BindGridView();
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(reportCode, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            DataTable dtMinutes = (DataTable)ViewState["dtMinutes"];

            grvMinutes.DataSource = dtMinutes;
            grvMinutes.DataBind();

        }
        #endregion



        #region MsgDisplay
        private void MsgDisplay(string errMsg)
        {
            divErrLogin.Attributes.Add("class", "divError");
            spanErrLogin.InnerHtml = errMsg;
        }
        #endregion

        #region MsgHide
        private void MsgHide()
        {
            divErrLogin.Attributes.Add("class", "divErrorHide");
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

                    if (dtReportsDetails.Rows.Count <= 0)
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
                    BMMSBAL.Utilities.GoToErrPage(reportCode, "btnGenerateReport_Click", ex);
                }
            }
        }
        #endregion



        #region GetReportDetails
        private DataTable GetReportDetails()
        {
            DataTable dtReportsDetails = null;
            dtReportsDetails = new DataTable();

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString().Trim());
            int DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString().Trim());

            int MeetingNoSearch = int.Parse(rdoMeatingNoSearch.SelectedValue.ToString().Trim());

            int MeetingId = 0;
            int FromMeetingId = 0;
            int ToMeetingId = 0;

            if (MeetingNoSearch == 0)
                MeetingId = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());

            if (MeetingNoSearch == 1)
            {
                FromMeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());
                ToMeetingId = int.Parse(ddlMeetingNoTo.SelectedValue.ToString().Trim());
            }

            int SubjectNoSearch = int.Parse(rdoSubjectNoSearch.SelectedValue.ToString().Trim());
            int FromSubjectNo = 0;
            int ToSubjectNo = 0;

            if (SubjectNoSearch == 1)
            {
                if (ddlSubjectNoFrom.Items.Count > 0)
                {
                    FromSubjectNo = int.Parse(ddlSubjectNoFrom.SelectedValue.ToString().Trim());
                    ToSubjectNo = int.Parse(ddlSubjectNoTo.SelectedValue.ToString().Trim());
                }
            }

            reportCode = ViewState["reportCode"].ToString();

            switch (reportCode)
            {
                case "minutes":
                    dtReportsDetails = ReportsMgr.GetMinutesReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                        SubjectNoSearch, FromSubjectNo, ToSubjectNo);
                    break;
                case "minutes_extract":
                    dtReportsDetails = ReportsMgr.GetMinutesExtractReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                        SubjectNoSearch, FromSubjectNo, ToSubjectNo);
                    break;
                case "agenda_summary":

                    if (MeetingNoSearch == 1 || (MeetingNoSearch == 0 && MeetingId <= 0))
                        dtReportsDetails = ReportsMgr.GetAgendaSummaryFullReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                            SubjectNoSearch, FromSubjectNo, ToSubjectNo);
                    else
                        dtReportsDetails = ReportsMgr.GetAgendaSummaryReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                            SubjectNoSearch, FromSubjectNo, ToSubjectNo);
                    break;
                case "agenda_details":
                    dtReportsDetails = ReportsMgr.GetAgendaDetailsReport(CommitteeId, DepartmentId, MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId,
                        SubjectNoSearch, FromSubjectNo, ToSubjectNo);
                    break;
            }

            ViewState["dtReportsDetails"] = dtReportsDetails;

            return dtReportsDetails;
        }
        #endregion

        #region GenReport
        private void GenReport(DataTable dtReportsDetails)
        {
            reportCode = ViewState["reportCode"].ToString();
            string sFilePDF = string.Empty;

            switch (reportCode)
            {
                case "minutes":
                    Session["ViewReport"] = CreateMinutesReportHTML(dtReportsDetails);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(" + Common.GetReportSettings("MinutesReport_Width") + ",500,'ViewReport.aspx','Minutes Report');", true);
                    break;
                case "minutes_extract":
                    Session["ViewReport"] = CreateMinutesExtractReportHTML(dtReportsDetails);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(" + Common.GetReportSettings("MinutesExtractReport_Width") + ",500,'ViewReport.aspx','Minutes Extract Report');", true);
                    break;
                case "agenda_summary":
                    sFilePDF = Server.MapPath("~/Files/PDF") + "\\AgendaSummary.pdf";

                    int MeetingNoSearch = int.Parse(rdoMeatingNoSearch.SelectedValue.ToString().Trim());
                    string fromMNO = string.Empty;
                    string toMNO = string.Empty;
                    int MeetingId = 0;

                    if (MeetingNoSearch == 0)
                    {
                        MeetingId = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());
                        if (MeetingId <= 0)
                        {
                            fromMNO = ddlMeetingNo.Items[1].Text.ToString();
                            toMNO = ddlMeetingNo.Items[ddlMeetingNo.Items.Count - 1].Text.ToString();
                        }
                    }
                    else if (MeetingNoSearch == 1)
                    {
                        fromMNO = ddlMeetingNoFrom.SelectedItem.Text.ToString().Trim();
                        toMNO = ddlMeetingNoTo.SelectedItem.Text.ToString().Trim();
                    }

                    if (MeetingNoSearch == 1 || (MeetingNoSearch == 0 && MeetingId <= 0))
                        CreateAgendaSummaryFullPDF(dtReportsDetails, sFilePDF, fromMNO, toMNO);
                    else
                        CreateAgendaSummaryPDF(dtReportsDetails, sFilePDF);

                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(1000,600,'../Files/PDF/AgendaSummary.pdf','Agenda Summary Report');", true);
                    break;
                case "agenda_details":
                    sFilePDF = Server.MapPath("~/Files/PDF") + "\\AgendaDetails.pdf";
                    CreateAgendaDetailsPDF(dtReportsDetails, sFilePDF);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(1000,600,'../Files/PDF/AgendaDetails.pdf','Agenda Details Report');", true);
                    break;
            }

        }
        #endregion




        #region CreateMinutesReportHTML
        private string CreateMinutesReportHTML(DataTable dtMinutes)
        {
            int MeetingIdFrom = 0;
            int MeetingIdTo = 0;

            if (rdoMeatingNoSearch.SelectedValue == "0")
            {
                MeetingIdFrom = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());
                MeetingIdTo = MeetingIdFrom;
            }
            if (rdoMeatingNoSearch.SelectedValue == "1")
            {
                MeetingIdFrom = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());
                MeetingIdTo = int.Parse(ddlMeetingNoTo.SelectedValue.ToString().Trim());
            }

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            DataTable dtMeetingList = MeetingMgr.GetMeetingByMeetingNoFromTo(CommitteeId, MeetingIdFrom, MeetingIdTo);

            CommitteeBAL commiteeBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);
            bool IsBoard = false;
            if (commiteeBal.Board == 1)
                IsBoard = true;

            string htmlTxt = string.Empty;


            try
            {
                for (int i = 0; i < dtMeetingList.Rows.Count; i++)
                {

                    int MeetingId = int.Parse(dtMeetingList.Rows[i]["MeetingId"].ToString());

                    DataTable dtMinutesFilter = new DataTable();

                    DataView dv = new DataView(dtMinutes);
                    dv.RowFilter = "MeetingId = " + MeetingId;
                    dtMinutesFilter = dv.ToTable();

                    if (dtMinutesFilter.Rows.Count > 0)
                    {
                        DataTable dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

                        DataTable dtPresentCommitteeMember = CommitteeMemberMgr.GetPresentCommitteeMemberByCommitteeId(CommitteeId, MeetingId); // MemberMgr.GetMemberByMemberType("Director", CommitteeId, MeetingId);

                        DataTable dtInviteeMember = MeetingMemberMgr.GetMeetingMemberByMeetingIdMemberTypeId(MeetingId, 2);  // 2 for Invitee

                        DataTable dtSpecialInviteeMember = MeetingMemberMgr.GetMeetingMemberByMeetingIdMemberTypeId(MeetingId, 6); // 6 for Special Invitee


                        DataTable dtMeetingChairman = MeetingMgr.GetMeetingChairman(MeetingId);

                        string MeetingChairman = string.Empty;
                        string MeetingChairmanDesign = string.Empty;

                        if (dtMeetingChairman.Rows.Count > 0)
                        {
                            MeetingChairman = dtMeetingChairman.Rows[0]["MeetingChairman"].ToString();
                            MeetingChairmanDesign = dtMeetingChairman.Rows[0]["DesignationName"].ToString();
                        }

                        DataTable dtCompanySecretary = UserMgr.GetCompanySecretary(MeetingId);
                        string CompanySecretary = string.Empty;
                        string CompanySecretaryDesign = string.Empty;

                        if (dtCompanySecretary.Rows.Count > 0)
                        {
                            CompanySecretary = dtCompanySecretary.Rows[0]["CompanySecretary"].ToString();
                            CompanySecretaryDesign = dtCompanySecretary.Rows[0]["DesignationName"].ToString();
                        }

                        string strReportBanner = Server.MapPath("~/Images") + "\\report_banner-top.jpg";

                        htmlTxt += "<div style='font-size:12pt; font-family: Times New Roman; width: " + Common.GetReportSettings("MinutesReport_Width") + "px;'>";

                        //htmlTxt += "<div style='float:left; width:100%; text-align:center;'><img src='../Images/report_banner-top.jpg' /></div>";
                        //htmlTxt += "<div style='float:left; width:100%; text-align:center;'><img src='" + strReportBanner.ToString() + "' /></div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt; padding-top:10px;'>THE LAKSHMI VILAS BANK LIMITED., REGD & ADMIN OFFICE, KARUR - 6</div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'><br /></div>";

                        htmlTxt += "<div style='float:left; width:100%; border-bottom-style:dashed; border-bottom-width:thin'></div>";

                        string para = "Minutes of the  " + BMMSBAL.Utilities.ConvertOrdinalValue(int.Parse(dtMeeting.Rows[0]["MeetingNo"].ToString())) + " meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                        para += " held on " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dddd") + " the " + BMMSBAL.Utilities.ConvertOrdinalValue(Convert.ToInt16(Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd"))) + " " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("MMMM yyyy") +
                                    " at " + dtMeeting.Rows[0]["MeetingTime"].ToString() + "Hrs. at " + dtMeeting.Rows[0]["Place"].ToString() + ".</b>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:justify; font-size:12pt;font-weight: bold; padding-top: 5px; padding-bottom: 5px;'>" + para + "</div>";

                        htmlTxt += "<div style='float:left; width:100%; border-bottom-style:dashed; border-bottom-width:thin'></div>";

                        //htmlTxt += "<table>";
                        //htmlTxt += "<tr>";
                        //htmlTxt += "<td>";
                        //htmlTxt += "</td>";
                        //htmlTxt += "</tr>";
                        //htmlTxt += "</table>";

                        //htmlTxt += "<br />";

                        htmlTxt += "<table style='float:left; width:100%;'>";

                        htmlTxt += "<tr>";
                        htmlTxt += "<td style='width:40%'>";
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='width:60%'>";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        htmlTxt += "<tr>";
                        htmlTxt += "<td colspan='2'>";
                        htmlTxt += "<b><u>PRESENT</u></b><br />";
                        htmlTxt += "<b><u>Sarvashree</u></b>";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        htmlTxt += "<tr>";
                        htmlTxt += "<td>";
                        htmlTxt += MeetingChairman;
                        htmlTxt += "</td>";
                        htmlTxt += "<td>";

                        if (IsBoard)
                        {
                            if (MeetingChairmanDesign.ToLower().Trim() == "chairman")
                                htmlTxt += "-  Chairman";
                            else
                                htmlTxt += "-  Chairman of the Meeting";
                        }
                        else
                        {
                            if (MeetingChairmanDesign.ToLower().Trim() == "chairman")
                                htmlTxt += "-  Chairman";
                            else
                                htmlTxt += "-  Chairman of the Committee";
                        }

                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        for (int j = 0; j < dtPresentCommitteeMember.Rows.Count; j++)
                        {
                            if (MeetingChairman != dtPresentCommitteeMember.Rows[j]["MemberName"].ToString())
                            {
                                htmlTxt += "<tr>";
                                htmlTxt += "<td>";
                                htmlTxt += dtPresentCommitteeMember.Rows[j]["MemberName"].ToString();
                                htmlTxt += "</td>";

                                htmlTxt += "<td>";
                                if (IsBoard)
                                    htmlTxt += "-  " + dtPresentCommitteeMember.Rows[j]["DesignationName"].ToString();
                                else
                                    htmlTxt += "-  " + dtPresentCommitteeMember.Rows[j]["MemberTypeName"].ToString();
                                htmlTxt += "</td>";
                                htmlTxt += "</tr>";
                            }
                        }

                        for (int n = 0; n < dtSpecialInviteeMember.Rows.Count; n++)
                        {
                            htmlTxt += "<tr>";
                            htmlTxt += "<td>";
                            htmlTxt += dtSpecialInviteeMember.Rows[n]["MemberName"].ToString();
                            htmlTxt += "</td>";
                            htmlTxt += "<td>";
                            htmlTxt += "-  " + dtSpecialInviteeMember.Rows[n]["DesignationName"].ToString();
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";
                        }

                        htmlTxt += "<tr>";
                        htmlTxt += "<td colspan='2'>";
                        htmlTxt += "<br />";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        if (dtInviteeMember.Rows.Count > 0)
                        {
                            htmlTxt += "<tr>";
                            htmlTxt += "<td colspan='2'>";
                            htmlTxt += "<b><u>ON INVITATION</u></b><br />";
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";
                        }

                        for (int n1 = 0; n1 < dtInviteeMember.Rows.Count; n1++)
                        {
                            if (CompanySecretary != dtInviteeMember.Rows[n1]["MemberName"].ToString())
                            {
                                htmlTxt += "<tr>";
                                htmlTxt += "<td>";
                                htmlTxt += dtInviteeMember.Rows[n1]["MemberName"].ToString();
                                htmlTxt += "</td>";
                                htmlTxt += "<td>";
                                htmlTxt += "-  " + dtInviteeMember.Rows[n1]["DesignationName"].ToString();
                                htmlTxt += "</td>";
                                htmlTxt += "</tr>";
                            }
                        }

                        if (dtInviteeMember.Rows.Count > 0)
                        {
                            htmlTxt += "<tr>";
                            htmlTxt += "<td colspan='2'>";
                            htmlTxt += "<br /><br />";
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";
                        }

                        if (CompanySecretary != string.Empty)
                        {
                            htmlTxt += "<tr>";
                            htmlTxt += "<td colspan='2'>";
                            htmlTxt += "<b><u>IN ATTENDANCE</u></b><br />";
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";

                            htmlTxt += "<tr>";
                            htmlTxt += "<td>";
                            htmlTxt += CompanySecretary;
                            htmlTxt += "</td>";
                            htmlTxt += "<td>";
                            htmlTxt += "-  " + CompanySecretaryDesign;
                            htmlTxt += "</td>";
                            htmlTxt += "</tr>";

                        }

                        htmlTxt += "<tr>";
                        htmlTxt += "<td colspan='2'>";
                        htmlTxt += "<br />";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        htmlTxt += "</table>";



                        for (int k = 0; k < dtMinutesFilter.Rows.Count; k++)
                        {
                            htmlTxt += "<table style='float:left; width:100%;'>";
                            htmlTxt += "<tr>";
                            htmlTxt += "<td valign='top' style='width:5%;'>";
                            htmlTxt += dtMinutesFilter.Rows[k]["SubjectNo"].ToString();
                            htmlTxt += "</td>";
                            htmlTxt += "<td style='width:95%; text-align: justify;'><b>";
                            htmlTxt += dtMinutesFilter.Rows[k]["ShortText"].ToString();
                            htmlTxt += "</b></td>";
                            htmlTxt += "</tr>";
                            //htmlTxt += "<tr>";
                            //htmlTxt += "<td>&nbsp;</td>";
                            //htmlTxt += "<td style='text-align:justify;'>" + Common.ReplaceFont(dtMinutesFilter.Rows[k]["ActualResolution"].ToString().Trim()) + "</td>";
                            //htmlTxt += "</tr>";
                            htmlTxt += "<tr style='height:5px'><td colspan='2'></td>";
                            htmlTxt += "</tr>";
                            htmlTxt += "</table>";

                            //htmlTxt += "<table style='float:left; width:100%;'>";
                            //htmlTxt += "<tr>";
                            //htmlTxt += "<td>&nbsp;</td>";
                            //htmlTxt += "<td style='text-align:justify;'>" + Common.ReplaceFont(dtMinutesFilter.Rows[k]["ActualResolution"].ToString().Trim()) + "</td>";
                            //htmlTxt += "</tr>";
                            //htmlTxt += "</table>";

                            htmlTxt += "<div style='text-align:justify; padding-left:35px;'>";
                            htmlTxt += HTML_Report.ReplaceRichTextFont(dtMinutesFilter.Rows[k]["ActualResolution"].ToString());
                            htmlTxt += "</div>";
                            htmlTxt += "<br />";

                        }


                        htmlTxt += "<br />";

                        htmlTxt += "<table style='float:left; width:100%;'>";
                        htmlTxt += "<tr>";
                        htmlTxt += "<td colspan='2' valign='top' style='text-align: center'>";
                        htmlTxt += "THE MEETING ENDED WITH A VOTE OF THANKS TO THE CHAIR.";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        htmlTxt += "<tr>";
                        htmlTxt += "<td colspan='2'>";
                        htmlTxt += "<br /><br /><br />";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";

                        htmlTxt += "<tr>";
                        htmlTxt += "<td style='text-align: center'>";

                        if (CompanySecretary != string.Empty)
                            htmlTxt += "(" + CompanySecretary + ")";
                        else
                            htmlTxt += CompanySecretary;

                        htmlTxt += "<br />" + CompanySecretaryDesign;
                        htmlTxt += "</td>";

                        htmlTxt += "<td style='text-align: center'>";
                        if (MeetingChairman != string.Empty)
                            htmlTxt += "(" + MeetingChairman + ")";
                        else
                            htmlTxt += MeetingChairman;

                        htmlTxt += "<br />";

                        if (IsBoard)
                        {
                            if (MeetingChairmanDesign.ToLower().Trim() == "chairman")
                                htmlTxt += "CHAIRMAN";
                            else
                                htmlTxt += "CHAIRMAN OF THE MEETING";
                        }
                        else
                        {
                            if (MeetingChairmanDesign.ToLower().Trim() == "chairman")
                                htmlTxt += "CHAIRMAN";
                            else
                                htmlTxt += "CHAIRMAN OF THE COMMITTEE";

                        }

                        htmlTxt += "</td></tr>";

                        htmlTxt += "</table><br />";

                        htmlTxt += "</div>";

                        if (i != dtMeetingList.Rows.Count-1)
                            htmlTxt += HTML_Report.HTML_PageBreak();
                    }

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

        #region CreateMinutesExtractReportHTML
        protected string CreateMinutesExtractReportHTML(DataTable dtMinutes)
        {
            int MeetingIdFrom = 0;
            int MeetingIdTo = 0;

            if (rdoMeatingNoSearch.SelectedValue == "0")
            {
                MeetingIdFrom = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());
                MeetingIdTo = MeetingIdFrom;
            }
            if (rdoMeatingNoSearch.SelectedValue == "1")
            {
                MeetingIdFrom = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());
                MeetingIdTo = int.Parse(ddlMeetingNoTo.SelectedValue.ToString().Trim());
            }

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue);

            Document pdfDocument = new Document(PageSize.A4, 100f, 75f, 50f, 50f);

            string htmlTxt = string.Empty;

            try
            {
                DataTable dtMeetingList = MeetingMgr.GetMeetingByMeetingNoFromTo(CommitteeId, MeetingIdFrom, MeetingIdTo);


                string para = string.Empty;

                for (int j = 0; j < dtMeetingList.Rows.Count; j++)
                {

                    int MeetingId = int.Parse(dtMeetingList.Rows[j]["MeetingId"].ToString());

                    DataTable dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

                    DataTable dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByMeetingId(MeetingId); // MemberMgr.GetMemberByMemberType("Director", CommitteeId, MeetingId);

                    DataTable dtMeetingMember = MeetingMemberMgr.GetMeetingMemberByMeetingId(MeetingId); // MemberMgr.GetMemberByMemberType("Invitee", CommitteeId, MeetingId);

                    DataTable dtMeetingChairman = MeetingMgr.GetMeetingChairman(MeetingId);

                    string MeetingChairman = string.Empty;
                    string MeetingChairmanDesign = string.Empty;

                    if (dtMeetingChairman.Rows.Count > 0)
                    {
                        MeetingChairman = dtMeetingChairman.Rows[0]["MeetingChairman"].ToString();
                        MeetingChairmanDesign = dtMeetingChairman.Rows[0]["DesignationName"].ToString();
                    }

                    string mailSub = "<b>Minutes Extract of the  " + BMMSBAL.Utilities.ConvertOrdinalValue(int.Parse(dtMeeting.Rows[0]["MeetingNo"].ToString())) + " meeting of the " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                    ViewState["MailSubject"] = mailSub.Substring(3, mailSub.Length - 3);

                    htmlTxt += "<div style='font-size:12pt; font-family: Times New Roman; width: " + Common.GetReportSettings("MinutesExtractReport_Width") + "px;'>";

                    for (int i = 0; i < dtMinutes.Rows.Count; i++)
                    {
                        htmlTxt += "<div style='float:left; width:100%; text-align:center;'><img src='../Images/report_banner-top.jpg' /></div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt;'>THE LAKSHMI VILAS BANK LIMITED</div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'>REGD & ADMIN OFFICE, KATHAPARAI</div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'>SALEM ROAD, KARUR 639 006<br /></div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:11pt;'><br /></div>";

                        htmlTxt += "<div style='float:left; width:100%; border-bottom-style:dashed; border-bottom-width:thin'></div>";

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt;'><br />CERTIFIED TRUE COPY OF THE RESOLUTION</div>";

                        para = "PASSED BY THE " + dtMeeting.Rows[0]["CommitteeName"].ToString();

                        htmlTxt += "<div style='float:left; width:100%; text-align:center; font-size:13pt;'>" + para + "</div>";

                        htmlTxt += "<div style='float:left; width:100%;'>";

                        htmlTxt += "<table>";
                        htmlTxt += "<tr>";
                        htmlTxt += "<td>";
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";
                        htmlTxt += "</table>";

                        htmlTxt += "<br /><br />";

                        htmlTxt += "<table style='float:left; width:100%;'>";
                        htmlTxt += "<tr>";
                        htmlTxt += "<td style='width:40%'>";
                        htmlTxt += "MEETING NO : " + int.Parse(dtMeeting.Rows[0]["MeetingNo"].ToString());
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='width:30%'>";
                        htmlTxt += "DATE : " + Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='width:30%; text-align: right'>";
                        htmlTxt += "PLACE : " + dtMeeting.Rows[0]["Place"].ToString();
                        htmlTxt += "</td>";
                        htmlTxt += "</tr>";
                        htmlTxt += "</table>";

                        htmlTxt += "<br /><br /><br />";

                        htmlTxt += "<table style='float:left; width:100%;'>";
                        htmlTxt += "<tr>";
                        htmlTxt += "<td valign='top' style='width:5%;'>";
                        htmlTxt += dtMinutes.Rows[i]["SubjectNo"].ToString();
                        htmlTxt += "</td>";
                        htmlTxt += "<td style='width:95%; text-align: justify;'><b>";
                        htmlTxt += dtMinutes.Rows[i]["ShortText"].ToString();
                        htmlTxt += "</b></td>";
                        htmlTxt += "</tr>";
                        htmlTxt += "<tr>";
                        htmlTxt += "<td>&nbsp;</td>";
                        htmlTxt += "<td><br />";
                        htmlTxt += HTML_Report.ReplaceRichTextFont(dtMinutes.Rows[i]["ActualResolution"].ToString());
                        htmlTxt += "<br /><br /></td>";
                        htmlTxt += "</tr>";
                        htmlTxt += "</table><br />";
                        //htmlTxt += dtMinutes.Rows[i]["ActualResolution"].ToString();

                        htmlTxt += "</div>";
                        htmlTxt += HTML_Report.HTML_PageBreak();
                    }
                    htmlTxt += "</div>";
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

        #region CreateAgendaSummaryPDF
        private void CreateAgendaSummaryPDF(DataTable dtAgenda, string sFilePDF)
        {

            Document pdfDocument = new Document(PageSize.A4, 45f, 45f, 30f, 30f);
            ///string sFilePDF = Server.MapPath("~/Files/PDF") + "\\AgendaSummary.pdf";

            try
            {
                int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

                Font fnt12Normal = new Font(Font.TIMES_ROMAN, 12, Font.NORMAL);
                Font fnt10Normal = new Font(Font.TIMES_ROMAN, 10, Font.NORMAL);
                Font fnt12Bold = new Font(Font.TIMES_ROMAN, 12, Font.BOLD);

                PdfWriter writer = PdfWriter.GetInstance(pdfDocument,
                                             new FileStream(sFilePDF, FileMode.Create));
                pdfDocument.Open();

                Paragraph paragraph = new Paragraph(" ");
                pdfDocument.Add(paragraph);

                pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                PDFUtilities.AddHeaderPageNo(pdfDocument);

                HeaderFooter header = new HeaderFooter(new Phrase("Page No: "), true);
                header.Border = Rectangle.NO_BORDER;
                header.Alignment = Element.ALIGN_RIGHT;
                pdfDocument.Header = header;

                PDFUtilities.AddParagraph(pdfDocument, "THE LAKSHMI VILAS BANK LTD., REGD & ADMIN OFFICE, KARUR - 6", fnt12Normal, Element.ALIGN_CENTER);


                PDFUtilities.AddParagraph(pdfDocument, "-".PadRight(150, '-'), fnt10Normal, Element.ALIGN_CENTER);

                string htmlTxt = "Agenda of the  " + BMMSBAL.Utilities.ConvertOrdinalValue(int.Parse(dtAgenda.Rows[0]["MeetingNo"].ToString())) + " meeting of the " + dtAgenda.Rows[0]["CommitteeName"].ToString();

                PDFUtilities.AddParagraph(pdfDocument, htmlTxt, fnt12Bold, Element.ALIGN_CENTER);

                htmlTxt = " held on " + Convert.ToDateTime(dtAgenda.Rows[0]["MeetingDate"].ToString()).ToString("dd-MM-yyyy") +
                        " at " + dtAgenda.Rows[0]["MeetingTime"].ToString() + " Hrs." +
                        " at " + dtAgenda.Rows[0]["Place"].ToString() + ".";

                PDFUtilities.AddParagraph(pdfDocument, htmlTxt, fnt12Bold, Element.ALIGN_CENTER);

                pdfDocument.Add(new Paragraph(Environment.NewLine));

                PdfPTable table = new PdfPTable(2);
                table.DefaultCell.Border = 0;
                table.WidthPercentage = 100;
                table.SetWidths(new float[] { 10, 90 });
                table.HorizontalAlignment = 0;

                PdfPCell cell = new PdfPCell(new Phrase("S. No.", fnt12Bold));
                cell.Colspan = 1;
                cell.BorderWidthRight = 0.0f;
                cell.BorderWidthLeft = 0.0f;
                cell.BorderWidthTop = 0.5f;
                cell.BorderWidthBottom = 0.5f;
                cell.HorizontalAlignment = 1; //0=Left, 1=Centre, 2=Right

                table.AddCell(cell);

                cell = new PdfPCell(new Phrase("Subject in brief", fnt12Bold));
                cell.Colspan = 1;
                cell.BorderWidthRight = 0.0f;
                cell.BorderWidthLeft = 0.0f;
                cell.BorderWidthTop = 0.5f;
                cell.BorderWidthBottom = 0.5f;
                cell.HorizontalAlignment = 1; //0=Left, 1=Centre, 2=Right

                table.AddCell(cell);

                table.HeaderRows = 1;

                int _sNo = 1;
                string PrevDept = string.Empty;

                for (int j = 0; j < dtAgenda.Rows.Count; j++)
                {
                    cell = new PdfPCell(new Phrase(""));
                    cell.Colspan = 2;
                    cell.BorderWidth = 0.0f;
                    cell.FixedHeight = 10.0f;
                    table.AddCell(cell);

                    string AgendaNo = dtAgenda.Rows[j]["SubjectNo"].ToString();
                    table.AddCell(PDFUtilities.CreateDesignCell(AgendaNo, 0.0f, 1, 1, fnt12Normal));

                    string DeptName = dtAgenda.Rows[j]["DepartmentName"].ToString().ToUpper();
                    if (PrevDept == DeptName)
                        table.AddCell(PDFUtilities.CreateDesignCell(" ", 0.0f, 0, 1, fnt12Normal));
                    else
                    {
                        table.AddCell(PDFUtilities.CreateDesignCell(DeptName, 0.0f, 0, 1, fnt12Normal));
                        PrevDept = DeptName;
                    }

                    string space = "";
                    table.AddCell(PDFUtilities.CreateCell(space, 0.0f, 1, 1));

                    string ShortText = dtAgenda.Rows[j]["ShortText"].ToString();
                    table.AddCell(PDFUtilities.CreateDesignCell(ShortText, 0.0f, 0, 1, fnt12Normal));

                    _sNo += 1;

                }

                cell = new PdfPCell(new Phrase(" ", fnt12Normal));
                cell.Colspan = 2;
                cell.BorderWidth = 0.0f;
                cell.FixedHeight = 10.0f;
                table.AddCell(cell);

                cell = new PdfPCell(new Phrase(" ", fnt12Normal));
                cell.Colspan = 2;
                cell.BorderWidthRight = 0.0f;
                cell.BorderWidthLeft = 0.0f;
                cell.BorderWidthTop = 0.0f;
                cell.BorderWidthBottom = 0.5f;
                cell.HorizontalAlignment = 0; //0=Left, 1=Centre, 2=Right

                table.AddCell(cell);

                pdfDocument.Add(table);

                pdfDocument.Add(new Paragraph(Environment.NewLine));

                paragraph = new Paragraph("KARUR", fnt12Normal);
                pdfDocument.Add(paragraph);

                paragraph = new Paragraph(System.DateTime.Now.ToString("dd-MM-yyyy"), fnt12Normal);
                pdfDocument.Add(paragraph);

                PDFUtilities.AddParagraph(pdfDocument, "Company Secretary", fnt12Normal, Element.ALIGN_RIGHT);

                pdfDocument.NewPage();

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                pdfDocument.Close();
            }

            //System.Diagnostics.Process.Start(sFilePDF);
        }
        #endregion

        #region CreateAgendaSummaryFullPDF
        private void CreateAgendaSummaryFullPDF(DataTable dtAgenda, string sFilePDF, string fromMNO, string toMNO)
        {

            DataTable dtDepartment = new DataTable();
            DataView dv = new DataView(dtAgenda);
            dtDepartment = dv.ToTable("dtAgenda", true, "DepartmentId", "DepartmentName");

            string htmlTxt = string.Empty;

            Document pdfDocument = new Document(PageSize.A4, 45f, 45f, 30f, 30f);

            try
            {
                PdfWriter writer = PdfWriter.GetInstance(pdfDocument, new FileStream(sFilePDF, FileMode.Create));

                pdfDocument.Open();

                Paragraph paragraph = new Paragraph(" ");
                pdfDocument.Add(paragraph);

                for (int i = 0; i < dtDepartment.Rows.Count; i++)
                {
                    DataTable dtAgendaFilter = new DataTable();
                    DataView dvAgenda = new DataView(dtAgenda);
                    dvAgenda.RowFilter = "DepartmentId = " + int.Parse(dtDepartment.Rows[i]["DepartmentId"].ToString());
                    dtAgendaFilter = dvAgenda.ToTable("dtAgenda");

                    pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                    Paragraph para = new Paragraph("REGD & ADMIN OFFICE, KARUR");
                    para.Alignment = Element.ALIGN_CENTER;
                    pdfDocument.Add(para);

                    htmlTxt = "<div style='float:left; width:100%; text-align:center'>";
                    htmlTxt += "Subject wise report for the Department : " + dtDepartment.Rows[i]["DepartmentName"].ToString();

                    if (fromMNO == toMNO)
                        htmlTxt += "<br />Board No. :  " + fromMNO;
                    else
                        htmlTxt += "<br />Board No. from  " + fromMNO + "  to  " + toMNO;

                    htmlTxt += "</div>";

                    PDFUtilities.AddHTMLText(pdfDocument, htmlTxt);


                    pdfDocument.Add(new Paragraph(Environment.NewLine));

                    PdfPTable table = new PdfPTable(4);
                    table.DefaultCell.Border = 0;
                    table.WidthPercentage = 100;
                    table.SetWidths(new float[] { 8, 12, 8, 70 });
                    table.HorizontalAlignment = 0;


                    Font fnt12Bold = new Font(Font.TIMES_ROMAN, 12, Font.BOLD);
                    Font fnt12Normal = new Font(Font.TIMES_ROMAN, 12, Font.NORMAL);

                    PdfPCell cell = new PdfPCell(new Phrase("M.No.", fnt12Bold));
                    cell.Colspan = 1;
                    cell.BorderWidth = 0.5f;
                    cell.HorizontalAlignment = 1; //0=Left, 1=Centre, 2=Right
                    table.AddCell(cell);

                    table.AddCell(PDFUtilities.CreateDesignCell("Date", 0.5f, 1, 1, fnt12Bold));

                    table.AddCell(PDFUtilities.CreateDesignCell("S.No.", 0.5f, 1, 1, fnt12Bold));

                    table.AddCell(PDFUtilities.CreateDesignCell("Subject", 0.5f, 1, 1, fnt12Bold));

                    table.HeaderRows = 1;

                    string PrevMeetingNo = string.Empty;

                    for (int j = 0; j < dtAgendaFilter.Rows.Count; j++)
                    {

                        string currentMeetingNo = dtAgendaFilter.Rows[j]["MeetingNo"].ToString();

                        if (PrevMeetingNo == currentMeetingNo)
                        {
                            table.AddCell(PDFUtilities.CreateDesignCell("", 0.5f, 1, 1, fnt12Normal));
                            table.AddCell(PDFUtilities.CreateDesignCell("", 0.5f, 1, 1, fnt12Normal));
                        }
                        else
                        {
                            if (j != 0)
                            {
                                table.AddCell(PDFUtilities.CreateDesignCell(" ", 0.5f, 1, 1, fnt12Normal));
                                table.AddCell(PDFUtilities.CreateDesignCell(" ", 0.5f, 1, 1, fnt12Normal));
                                table.AddCell(PDFUtilities.CreateDesignCell(" ", 0.5f, 1, 1, fnt12Normal));
                                table.AddCell(PDFUtilities.CreateDesignCell(" ", 0.5f, 1, 1, fnt12Normal));
                            }
                            table.AddCell(PDFUtilities.CreateDesignCell(dtAgendaFilter.Rows[j]["MeetingNo"].ToString(), 0.5f, 1, 1, fnt12Normal));
                            table.AddCell(PDFUtilities.CreateDesignCell(Convert.ToDateTime(dtAgendaFilter.Rows[j]["MeetingDate"].ToString()).ToString("dd-MM-yyyy"), 0.5f, 1, 1, fnt12Normal));

                            PrevMeetingNo = currentMeetingNo;
                        }

                        table.AddCell(PDFUtilities.CreateDesignCell(dtAgendaFilter.Rows[j]["SubjectNo"].ToString(), 0.5f, 1, 1, fnt12Normal));
                        table.AddCell(PDFUtilities.CreateDesignCell(dtAgendaFilter.Rows[j]["ShortText"].ToString(), 0.5f, 0, 1, fnt12Normal));

                    }

                    pdfDocument.Add(table);

                    pdfDocument.NewPage();
                }

            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                pdfDocument.Close();
            }
        }
        #endregion

        #region CreateAgendaDetailsPDF
        private void CreateAgendaDetailsPDF(DataTable dtAgenda, string sFilePDF)
        {
            Document pdfDocument = new Document(PageSize.A4, 45f, 45f, 30f, 30f);

            try
            {
                int CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);

                string htmlTxt = string.Empty;

                PdfWriter writer = PdfWriter.GetInstance(pdfDocument,
                                             new FileStream(sFilePDF, FileMode.Create));
                pdfDocument.Open();

                for (int j = 0; j < dtAgenda.Rows.Count; j++)
                {
                    Paragraph paragraph = new Paragraph(" ");
                    pdfDocument.Add(paragraph);

                    pdfDocument.Add((PDFUtilities.PrintCompanyLogo()));

                    Paragraph para = new Paragraph("REGD & ADMIN OFFICE, KARUR");
                    para.Alignment = Element.ALIGN_CENTER;
                    pdfDocument.Add(para);

                    pdfDocument.Add(new Paragraph(Environment.NewLine));
                    pdfDocument.Add(new Paragraph(Environment.NewLine));

                    PdfPTable table = new PdfPTable(3);
                    table.DefaultCell.Border = 0;
                    table.WidthPercentage = 100;
                    table.SetWidths(new float[] { 60, 20, 20 });
                    table.HorizontalAlignment = 0;

                    string CommitteeName = "Note to the " + dtAgenda.Rows[j]["CommitteeName"].ToString();

                    ViewState["MailSubject"] = "Agenda Details of Next Meeting of the " + dtAgenda.Rows[j]["CommitteeName"].ToString();

                    Font fnt12Bold = new Font(1, 12, Font.BOLD);

                    PdfPCell cell = new PdfPCell(new Phrase(CommitteeName, fnt12Bold));
                    cell.Colspan = 1;
                    cell.BorderWidth = 0;
                    cell.HorizontalAlignment = 0; //0=Left, 1=Centre, 2=Right
                    table.AddCell(cell);

                    table.AddCell(PDFUtilities.CreateDesignCell("Subject No.", 1, 0, 1, fnt12Bold));

                    string SubjectNo = dtAgenda.Rows[j]["SubjectNo"].ToString(); // .Split('-').GetValue(2).ToString();
                    table.AddCell(PDFUtilities.CreateCell(SubjectNo, 1, 0, 1));

                    string SubjectType = "(" + dtAgenda.Rows[j]["SubjectTypeName"].ToString() + ")";
                    table.AddCell(PDFUtilities.CreateCell(SubjectType, 0, 0, 1));

                    table.AddCell(PDFUtilities.CreateDesignCell("Meeting Date", 1, 0, 1, fnt12Bold));

                    string MeetingNo = Convert.ToDateTime(dtAgenda.Rows[j]["MeetingDate"].ToString()).ToString("dd-MM-yyyy");
                    table.AddCell(PDFUtilities.CreateCell(MeetingNo, 1, 0, 1));

                    string EmptyString = "";
                    table.AddCell(PDFUtilities.CreateCell(EmptyString, 0, 0, 1));

                    table.AddCell(PDFUtilities.CreateDesignCell("Department", 1, 0, 1, fnt12Bold));

                    string DepartmentName = dtAgenda.Rows[j]["DepartmentName"].ToString();
                    table.AddCell(PDFUtilities.CreateCell(DepartmentName, 1, 0, 1));

                    table.AddCell(PDFUtilities.CreateCell(EmptyString, 0, 0, 2));

                    pdfDocument.Add(table);

                    pdfDocument.Add(new Paragraph(Environment.NewLine));

                    string htmlText = "<div style='width:100px; text-align:justify;'>";
                    htmlText += dtAgenda.Rows[j]["ShortText"].ToString();
                    htmlText += "</div>";

                    PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                    pdfDocument.Add(new Paragraph(Environment.NewLine));

                    #region Agenda Text

                    if (dtAgenda.Rows[j]["AgendaType"].ToString() == "Entry")
                    {
                        htmlText = "<div style='width:100px; text-align:justify; font-famil: Times New Roman; font-size:10pt;'>";
                        htmlText += HTML_Report.ReplaceRichTextFont(dtAgenda.Rows[j]["AgendaText"].ToString());
                        htmlText += "</div>";

                        PDFUtilities.AddHTMLText(pdfDocument, htmlText);
                        pdfDocument.NewPage();
                    }
                    else
                    {
                        string fPath = MapPath("~/Files/AgendaText/");
                        string fileName = fPath + dtAgenda.Rows[j]["AgendaTextPath"].ToString();

                        PDFUtilities.AddAgendaText(pdfDocument, writer, fileName);
                    }
                    #endregion

                    #region AgendaAttach

                    string[] attFiles = dtAgenda.Rows[j]["FilePath"].ToString().Split(',');

                    for (int i = 0; i < attFiles.Length; i++)
                    {
                        if (attFiles[i].ToString() != string.Empty)
                        {
                            string fPath = MapPath("~/Files/AgendaAttach/");
                            string fileName = fPath + attFiles[i].ToString();

                            PDFUtilities.AddAgendaText(pdfDocument, writer, fileName);
                        }
                    }
                    #endregion

                    //pdfDocument.Add(new Paragraph(Environment.NewLine));

                    //htmlText = dtAgenda.Rows[j]["ProposedResolution"].ToString();
                    //PDFUtilities.AddHTMLText(pdfDocument, htmlText);

                    //pdfDocument.Add(new Paragraph(Environment.NewLine));
                    //pdfDocument.Add(new Paragraph(Environment.NewLine));

                    //_sNo += 1;

                    ////PDFUtilities.AddFooterPageNo(pdfDocument);
                    //pdfDocument.NewPage();
                }


            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                pdfDocument.Close();
            }
        }
        #endregion

    }
}
