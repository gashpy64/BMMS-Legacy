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
    public partial class AuditTrail : System.Web.UI.Page
    {
        private string className = "AuditTrail";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                txtFromDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");
                txtToDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");
                BindUsers();
                BindGridView();
            }

        }
        #region BindUsers
        private void BindUsers()
        {
            try
            {
                DataTable dtUsers = new DataTable();
                dtUsers = UserMgr.GetUserList();
                ViewState["dtUsers"] = dtUsers;

                DataRow dr = dtUsers.NewRow();
                dr["LoginName"] = "- All -";
                dr["UserId"] = "0";    // 0 for All

                dtUsers.Rows.InsertAt(dr, 0);

                ddlUsers.DataSource = dtUsers;
                ddlUsers.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindUsers", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            try
            {

                DateTime FromDate = Convert.ToDateTime(txtFromDate.Text);
                DateTime ToDate = Convert.ToDateTime(txtToDate.Text);
                int UserId = Convert.ToInt16(ddlUsers.SelectedValue.ToString());
                DateTime From_Date = Convert.ToDateTime(Convert.ToDateTime(txtFromDate.Text.Trim()).ToString("dd-MMM-yyyy"));
                DateTime To_Date = Convert.ToDateTime(Convert.ToDateTime(txtToDate.Text.Trim()).ToString("dd-MMM-yyyy"));

                DataTable dtAuditTrail = new DataTable();
                dtAuditTrail = AuditTrail_Mgr.GetAuditTrailMasterByUserId(UserId, From_Date, To_Date);

                ViewState["dtAuditTrail"] = dtAuditTrail;

                grvAuditTrail.DataSource = dtAuditTrail;
                grvAuditTrail.DataBind();
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

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtAuditTrail"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtAuditTrail"]);

                BindGridView();
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
            grvAuditTrail.Visible = true;
            BindGridView();
        }
        #endregion
    }
}
