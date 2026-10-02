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
                switch (rdoReportType.SelectedValue)
                {
                    case "Individual":
                        GenerateIndividualReport();
                        ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'../Files/PDF/SFR_Individual.pdf','Report');", true);
                        break;
                    case "Designation":
                        GenerateDesignationReport();
                        ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'../Files/PDF/SFR_Designation.pdf','Report');", true);
                        break;
                    case "Consolidated":
                        pnlConsolidated.Visible = true;
                        GenerateConsolidatedReport();
                        ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:popup(825,500,'../Files/PDF/SFR_Consolidated.pdf','Report');", true);
                        break;
                }
            }
            catch (Exception ex)
            {
                BMMSBAL.Utilities.GoToErrPage(className, "btnGenerateReport_Click", ex);
            }
        }
        #endregion

        #region GenerateIndividualReport
        public void GenerateIndividualReport()
        {

            int MemberId = int.Parse(ddlMember.SelectedValue.ToString());
            DateTime FromDate = Convert.ToDateTime(txtFromDate.Text.ToString().Trim());
            DateTime ToDate = Convert.ToDateTime(txtToDate.Text.ToString().Trim());

            DataTable dtMember = new DataTable();

            if (MemberId == -1)
                dtMember = AttendanceMgr.GetAttendanceMembersByDesignId(-1, FromDate, ToDate);
            else
                dtMember = MemberMgr.GetMemberDTbyMemberId(MemberId);

            PDF_Reports.GenerateSittingFeeIndividual(dtMember, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());
        }
        #endregion

        #region GenerateDesignationReport
        public void GenerateDesignationReport()
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
                    PDF_Reports.GenerateSittingFeeDesignation(dtDesignation, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());
                else
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('No such record found');", true);
            }
        }
        #endregion

        #region GenerateConsolidatedReport
        public void GenerateConsolidatedReport()
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
                PDF_Reports.GenerateSittingFeeConsolidated(dtMeeting, dtMember, FromDate, ToDate, txtAuthorizedPersionName.Text.Trim(), txtAuthorizedPersionDesign.Text.Trim());
            else
                ScriptManager.RegisterStartupScript(this, this.GetType(), "r", "javascript:alert('No such record found');", true);

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
