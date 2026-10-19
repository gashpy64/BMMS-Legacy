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
    public partial class SittingFees : System.Web.UI.Page
    {
        private string className = "SittingFees";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {

                if (System.DateTime.Now.Month <= 3)
                {
                    txtFromDate.Text = "01-Apr-" + System.DateTime.Now.AddYears(-1).ToString("yyyy");
                    txtToDate.Text = "31-Mar-" + System.DateTime.Now.ToString("yyyy");
                }
                else
                {
                    txtFromDate.Text = "01-Apr-" + System.DateTime.Now.ToString("yyyy");
                    txtToDate.Text = "31-Mar-" + System.DateTime.Now.AddYears(1).ToString("yyyy");
                }
                pnlIndividual.Visible = false;
                pnlDesignation.Visible = false;
                pnlConsolidated.Visible = false;

                pnlIndividual.Visible = true;
                LoadMember();
            }
        }
        #endregion

        #region btnGenerateReport_Click
        protected void btnGenerateReport_Click(object sender, EventArgs e)
        {
            try
            {
                // Built in memory and opened by ViewReport.aspx?pdf=1; nothing is written to ~/Files/PDF (step 26).
                // Two pop-ups of the same user at once: the last one built wins.
                byte[] pdf = null;
                string name = string.Empty;

                switch (rdoReportType.SelectedValue)
                {
                    case "Individual":
                        pdf = GenerateIndividualReport();
                        name = "SittingFees_Individual";
                        break;
                    case "Designation":
                        pdf = GenerateDesignationReport();
                        name = "SittingFees_Designation";
                        break;
                    case "Consolidated":
                        pnlConsolidated.Visible = true;
                        pdf = GenerateConsolidatedReport();
                        name = "SittingFees_Consolidated";
                        break;
                }

                if (pdf != null)
                {
                    Session["ReportPdf"] = pdf;
                    Session["ReportPdfName"] = name;
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'ViewReport.aspx?pdf=1','Report');", true);
                }
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "btnGenerateReport_Click", ex);
            }
        }
        #endregion

        #region GenerateIndividualReport
        public byte[] GenerateIndividualReport()
        {

            int MemberId = int.Parse(ddlMember.SelectedValue.ToString());
            DateTime FromDate = Convert.ToDateTime(txtFromDate.Text.ToString().Trim());
            DateTime ToDate = Convert.ToDateTime(txtToDate.Text.ToString().Trim());

            DataTable dtMember = new DataTable();

            if (MemberId == -1)
                dtMember = AttendanceMgr.GetAttendanceMembersByDesignId(-1, FromDate, ToDate);
            else
                dtMember = MemberMgr.GetMemberDTbyMemberId(MemberId);

            // No member, or no sitting fee in the period: the same message as Designation and Consolidated (step 26)
            byte[] pdf = null;

            if (dtMember.Rows.Count > 0)
                pdf = PDF_Reports.GenerateSittingFeeIndividual(dtMember, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());

            if (pdf == null)
                ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('No such record found');", true);

            return pdf;
        }
        #endregion

        #region GenerateDesignationReport
        // The PDF bytes; null when there is nothing to print (a message is shown instead)
        public byte[] GenerateDesignationReport()
        {

            int DesignationId = int.Parse(ddlDesignation.SelectedValue.ToString());
            DateTime FromDate = Convert.ToDateTime(txtFromDate.Text.ToString().Trim());
            DateTime ToDate = Convert.ToDateTime(txtToDate.Text.ToString().Trim());

            DataTable dtDesignation = new DataTable();

            if (DesignationId == 0)
                ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('Please select Designation Name.');", true);
            else
            {
                dtDesignation = AttendanceMgr.GetAttendanceMembersByDesignId(DesignationId, FromDate, ToDate);

                if (dtDesignation.Rows.Count > 0)
                    return PDF_Reports.GenerateSittingFeeDesignation(dtDesignation, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());
                else
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('No such record found');", true);
            }

            return null;
        }
        #endregion

        #region GenerateConsolidatedReport
        // The PDF bytes; null when there is nothing to print (a message is shown instead)
        public byte[] GenerateConsolidatedReport()
        {

            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());
            DateTime FromDate = Convert.ToDateTime(txtFromDate.Text.ToString().Trim());
            DateTime ToDate = Convert.ToDateTime(txtToDate.Text.ToString().Trim());

            DataTable dtMeeting = new DataTable();
            DataTable dtMember = new DataTable();
            DataTable dtTemp = new DataTable();

            dtMeeting = MeetingMgr.GetMeetingByFromToDate(CommitteeId, FromDate, ToDate);
            dtTemp = CommitteeMemberMgr.GetCommitteeMemberList();

            dtMember = dtTemp.DefaultView.ToTable(true, "MemberId", "MemberName");

            if (dtMeeting.Rows.Count > 0)
                return PDF_Reports.GenerateSittingFeeConsolidated(dtMeeting, dtMember, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());
            else
                ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('No such record found');", true);

            return null;
        }
        #endregion

        #region LoadMember
        public void LoadMember()
        {
            DateTime FromDate = Convert.ToDateTime(txtFromDate.Text.ToString().Trim());
            DateTime ToDate = Convert.ToDateTime(txtToDate.Text.ToString().Trim());

            DataTable dtMember = new DataTable();
            dtMember = AttendanceMgr.GetAttendanceMembersByDesignId(-1, FromDate, ToDate);

            Common.LoadDDLwithAllNew(ddlMember, dtMember, "MemberName", "MemberId", true);
        }
        #endregion

        #region LoadDesignation
        public void LoadDesignation()
        {
            DataTable dtDesignation = new DataTable();
            dtDesignation = DesignationMgr.GetDesignationList(1);

            Common.LoadDropdownlist(ddlDesignation, dtDesignation, "DesignationName", "DesignationId", true);
        }
        #endregion


        #region LoadCommittee
        public void LoadCommittee()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDDLwithAllNew(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
        }
        #endregion


        #region rdoReportType_SelectedIndexChanged
        protected void rdoReportType_SelectedIndexChanged(object sender, EventArgs e)
        {
            pnlIndividual.Visible = false;
            pnlDesignation.Visible = false;
            pnlConsolidated.Visible = false;

            switch (rdoReportType.SelectedValue)
            {
                case "Individual":
                    btnGenerateReport.Visible = true;
                    pnlIndividual.Visible = true;
                    LoadMember();
                    break;
                case "Designation":
                    btnGenerateReport.Visible = false;
                    pnlDesignation.Visible = true;
                    LoadDesignation();
                    break;
                case "Consolidated":
                    btnGenerateReport.Visible = true;
                    pnlConsolidated.Visible = true;
                    LoadCommittee();
                    break;
            }
        }
        #endregion

        #region ddlDepartment_SelectedIndexChanged
        protected void ddlDepartment_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
        #endregion

        #region ddlMember_SelectedIndexChanged
        protected void ddlMember_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
        #endregion

        #region ddlDesignation_SelectedIndexChanged
        protected void ddlDesignation_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (ddlDesignation.SelectedValue.ToString() == "0")
                btnGenerateReport.Visible = false;
            else
                btnGenerateReport.Visible = true;
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
        #endregion

    }
}
