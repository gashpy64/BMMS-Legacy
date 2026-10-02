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
    public partial class SittingFeesApplicable : System.Web.UI.Page
    {
        private string className = "SittingFeesApplicable";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                LoadCommittee();
                //BindSittingFeesApplicable();
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

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                grvSittingFeesApplicable.Visible = false;
                int _intCommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByCommitteeId(_intCommitteeId);

                Common.LoadDropdownlist(ddlMeeting, dtMeeting, "MeetingNo", "MeetingId", true);


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

        #region ddlMeeting_SelectedIndexChanged
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                grvSittingFeesApplicable.Visible = false;

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ddlMeeting_SelectedIndexChanged", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region BindSittingFeesApplicable
        private void BindSittingFeesApplicable()
        {
            try
            {
                grvSittingFeesApplicable.DataSource = (DataTable)ViewState["dtSittingFee"];
                grvSittingFeesApplicable.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindSittingFeesApplicable", ex);
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
                ViewState["dtSittingFee"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtSittingFee"]);

                BindSittingFeesApplicable();
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
            int MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue);
            int CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);

            grvSittingFeesApplicable.Visible = false;

            if (MeetingId != 0 && CommitteeId != 0)
            {
                grvSittingFeesApplicable.Visible = true;


                int UserId = int.Parse(Session["UserId"].ToString());

                DataTable dtSittingFee = new DataTable();

                dtSittingFee = CommitteeMemberMgr.GetSittingFeesApplicable(MeetingId, CommitteeId);

                ViewState["dtSittingFee"] = dtSittingFee;

                BindSittingFeesApplicable();
            }
        }
        #endregion

    }
}
