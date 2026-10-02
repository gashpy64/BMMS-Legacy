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
    public partial class AttendanceDetails : System.Web.UI.Page
    {
        private string className = "AttendanceDetails";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                pnlAttendance.Visible = false;
                InitCtrlAttributes();
                LoadCommittee();
            }
        }


        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            //btnFinalize.Attributes.Add("onclick", "return AgendaFinalizeValidation()");
            //ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadCommittee
        private void LoadCommittee()
        {
            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(1);

                ViewState["dtCommittee"] = dtCommittee;
                Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadMeeting", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                pnlAttendance.Visible = false;

                int _intCommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByCommitteeId(_intCommitteeId);

                ViewState["dtMeeting"] = dtMeeting;
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
                MsgHide();
                pnlAttendance.Visible = true;

                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());
                int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

                DataTable dtAttendanceMember = new DataTable();

                dtAttendanceMember = AttendanceMgr.GetAttendanceByMeetingId(MeetingId, "All");

                ViewState["dtAttendanceMember"] = dtAttendanceMember;

                BindAttendanceMember();

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

        #region BindAttendanceMember
        private void BindAttendanceMember()
        {
            try
            {

                grvAttendanceMember.DataSource = (DataTable)ViewState["dtAttendanceMember"];
                grvAttendanceMember.DataBind();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindAttendanceMember", ex);
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
                ViewState["dtAttendanceMember"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtAttendanceMember"]);

                BindAttendanceMember();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
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

    }
}
