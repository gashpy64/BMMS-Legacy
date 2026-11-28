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
                ViewState["dtAttendanceMember"] = null;

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
        // Step AD1 (D1): choosing a meeting no longer fills the list; it hides a list already shown. The list
        // shows on View only. Before AD1, "- Select -" here showed an empty list.
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                pnlAttendance.Visible = false;
                ViewState["dtAttendanceMember"] = null;
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ddlMeeting_SelectedIndexChanged", ex);
            }
        }
        #endregion

        #region btnView_Click
        // Step AD1 (D1, D2, R2, R3): the list of the chosen meeting, read as before AD1 (same procedure, same rows)
        protected void btnView_Click(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                pnlAttendance.Visible = false;
                ViewState["dtAttendanceMember"] = null;

                if (!CheckValidation())
                    return;

                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                DataTable dtAttendanceMember = AttendanceMgr.GetAttendanceByMeetingId(MeetingId, "All");

                ViewState["dtAttendanceMember"] = dtAttendanceMember;

                BindAttendanceMember();

                pnlAttendance.Visible = true;
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnView_Click", ex);
            }
        }
        #endregion

        #region CheckValidation
        // Step AD1 (R2): the same texts as Followup by Department (FollowupActionTaken.aspx.cs, CheckValidataion)
        private bool CheckValidation()
        {
            if (ddlCommittee.SelectedValue.ToString() == "0")
            {
                MsgDisplay("Select committee name.");
                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                return false;
            }

            if (ddlMeeting.SelectedIndex <= 0)
            {
                MsgDisplay("Select meeting no.");
                ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                return false;
            }

            return true;
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
        private void MsgDisplay(string errMsg, MessageKind kind = MessageKind.Warning)
        {
            divErrLogin.Attributes.Add("class", Common.MessageCss(kind));
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
