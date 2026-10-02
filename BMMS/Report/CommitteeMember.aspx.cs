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
    public partial class CommitteeMember : System.Web.UI.Page
    {
        private string className = "CommitteeMember";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadCommittee();
                BindCommitteeMember();
            }
           
        }

        #region LoadCommittee
        public void LoadCommittee()
        {
            DataTable dtCommittee = new DataTable();
            dtCommittee = CommitteeMgr.GetCommitteeList(1);

            Common.LoadDDLwithAll(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
        }

        #endregion

        #region BindCommitteeMember
        private void BindCommitteeMember()
        {
            try
            {
                DataTable dtCommitteeMember = new DataTable();

                string strCommittee = ddlCommittee.SelectedValue.ToString();
                string strWhereCond = string.Empty;

                dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberList();

                if (strCommittee == "All")
                    strWhereCond = "1=1";

                if (strCommittee != "All")
                    strWhereCond = "CommitteeId = " + strCommittee;

                DataView dv = new DataView(dtCommitteeMember);
                dv.RowFilter = strWhereCond;

                dtCommitteeMember = dv.ToTable("dtCommitteeMember");

                ViewState["dtCommitteeMember"] = dtCommitteeMember;

                grvCommitteeMember.DataSource = dtCommitteeMember;
                grvCommitteeMember.DataBind();
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
        
        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            grvCommitteeMember.Visible = false;
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtCommitteeMember"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtCommitteeMember"]);

                BindCommitteeMember();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            grvCommitteeMember.Visible = true;
            BindCommitteeMember();
        }
        #endregion
    }
}
