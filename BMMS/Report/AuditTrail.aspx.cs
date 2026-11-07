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
                LoadAuditTrail();
            }

        }
        #region BindUsers
        // Step UN3: every user (inactive ones and the system account included) as "Name (login)", " (inactive)"
        // added, sorted by name, then login, after "- All -" (value 0). The value is UserId; the filter reads only
        // that. The user table is no longer kept in ViewState: it was never read back, and View_Users carries the
        // password hash (finding F-1).
        private void BindUsers()
        {
            try
            {
                DataTable dtUsers = UserMgr.WithUserDisplayName(UserMgr.GetUserList());

                ddlUsers.DataSource = dtUsers;
                ddlUsers.DataBind();
                ddlUsers.Items.Insert(0, new ListItem("- All -", "0"));    // 0 for All
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

        #region LoadAuditTrail
        // Reads the rows for the filter (UserId, dates), adds the "Update By" text by Update_By (step UN3:
        // "Name (login)", " (inactive)" added, "(unknown user)" for a user that no longer exists), keeps them in
        // ViewState for the header sort and shows them. Step UN3 (F-2): the query is here and no longer in
        // BindGridView, so a header sort no longer reads the rows again and loses its order.
        private void LoadAuditTrail()
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
                UserMgr.AddUserDisplayColumn(dtAuditTrail, "Update_By");

                ViewState["dtAuditTrail"] = dtAuditTrail;

                BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadAuditTrail", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region BindGridView
        // Shows the rows kept in ViewState (LoadAuditTrail), in the order of the last header sort
        private void BindGridView()
        {
            grvAuditTrail.DataSource = (DataTable)ViewState["dtAuditTrail"];
            grvAuditTrail.DataBind();
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
            LoadAuditTrail();
        }
        #endregion
    }
}
