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
    public partial class MeetingCalendar : System.Web.UI.Page
    {
        private string className = "MeetingCalendar";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                txtFromDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");
                txtToDate.Text = System.DateTime.Now.ToString("dd-MMM-yyyy");  
                BindGridView();
            }
           
        }


        #region BindGridView
        private void BindGridView()
        {
            try
            {

                DateTime FromDate = Convert.ToDateTime(txtFromDate.Text);
                DateTime ToDate = Convert.ToDateTime(txtToDate.Text);
                string SortOption = rdoSortOption.Text.Trim();
                string strSortOption = string.Empty;
                string strWhereCond = string.Empty;

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingList();

                strWhereCond = "MeetingDate >= '" + FromDate + "' AND MeetingDate <= '" + ToDate + "'";

                if (SortOption == "Committee")
                    strSortOption = "CommitteeCode, MeetingDate";

                if (SortOption == "MeetingDate")
                    strSortOption = "MeetingDate";

                DataView dv = new DataView(dtMeeting);
                dv.RowFilter = strWhereCond;
                dv.Sort = strSortOption;

                dtMeeting = dv.ToTable("dtMeeting");

                ViewState["dtMeeting"] = dtMeeting;

                grvMeetingCalendar.DataSource = dtMeeting;
                grvMeetingCalendar.DataBind();
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
                ViewState["dtMeeting"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtMeeting"]);

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
            grvMeetingCalendar.Visible = true;
            BindGridView();
        }
        #endregion
    }
}
