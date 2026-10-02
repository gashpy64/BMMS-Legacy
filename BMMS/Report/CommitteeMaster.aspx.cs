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
    public partial class CommitteeMaster : System.Web.UI.Page
    {
        private string className = "CommitteeMaster";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadCommittee();
                LoadStatus();
                BindCommittee();
            }
        }
        #endregion

        #region LoadCommittee
        public void LoadCommittee()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDDLwithAll(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
        }
        #endregion

        #region LoadStatus
        private void LoadStatus()
        {
            try
            {
                DataTable dtStatus = new DataTable();
                dtStatus = SysCodeMgr.GetSysCodeSetting("Status");

                Common.LoadDDLwithAll(ddlStatus, dtStatus, "DisplayName", "SubCode", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindGridView", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region BindCommittee
        private void BindCommittee()
        {
            try
            {
                DataTable dtCommittee = new DataTable();

                string strCommittee = ddlCommittee.SelectedValue.ToString();
                string strStatus = ddlStatus.SelectedValue.ToString();
                string strWhereCond = string.Empty;

                dtCommittee = CommitteeMgr.GetCommitteeList(1);


                if (strCommittee == "All" && strStatus == "All")
                    strWhereCond = "1=1";

                if (strCommittee == "All" && strStatus != "All")
                    strWhereCond = "StatusId = " + strStatus;

                if (strCommittee != "All" && strStatus == "All")
                    strWhereCond = "CommitteeId = " + strCommittee;

                if (strCommittee != "All" && strStatus != "All")
                    strWhereCond = "CommitteeId = " + strCommittee + " and " + " StatusId = " + strStatus;

                DataView dv = new DataView(dtCommittee);
                dv.RowFilter = strWhereCond;

                dtCommittee = dv.ToTable("dtCommittee");

                grvCommittee.DataSource = dtCommittee;
                grvCommittee.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindCommittee", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            grvCommittee.Visible = false;
        }
        #endregion

        #region ddlStatus_SelectedIndexChanged
        protected void ddlStatus_SelectedIndexChanged(object sender, EventArgs e)
        {
            grvCommittee.Visible = false;
        }
        #endregion

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            grvCommittee.Visible = true;
            BindCommittee();
        }
        #endregion
        
    }
}
