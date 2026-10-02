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

namespace BMMS.Master
{
    public partial class MinutesConfirmation : System.Web.UI.Page
    {
        private string className = "MinutesConfirmation";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadCommittee();
                LoadMember();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {


        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
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

        #region LoadMember
        private void LoadMember()
        {

            try
            {
                DataTable dtMember = new DataTable();
                dtMember = MemberMgr.GetMemberList(1);

                ViewState["dtMember"] = dtMember;
                //Common.LoadDropdownlist(ddlMemberName, dtMember, "MemberName", "MemberId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadMember", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region btnConfirm_Click
        protected void btnConfirm_Click(object sender, EventArgs e)
        {
            string sMsg = string.Empty;
            if (PageValidation())
            {
                try
                {
                    int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                    DataTable dtAgenda = new DataTable();
                    dtAgenda = AgendaMgr.CheckMinutesByMeetingId(MeetingId);

                    if (dtAgenda.Rows.Count <= 0)
                    {
                        sMsg = "No Minutes For the selected Committee/Meeting";
                        MsgDisplay(sMsg);
                    }
                    else
                    {
                        int result = AgendaMgr.MinutesConfirmByMeetingId(MeetingId, int.Parse(Session["UserId"].ToString()));

                        sMsg = "Minutes confirmed.";

                        MsgDisplay(sMsg);
                    }
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnConfirm_Click", ex);
                }
            }

        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            bool result = true;

            if (ddlCommittee.Text == "0")
            {
                MsgDisplay("Please Select Committee Name");
                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                result = false;
            }
            else if (ddlMeeting.Text == "0")
            {
                MsgDisplay("Please Select Meeting No");
                ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                result = false;
            }
            else
            {
                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                DataTable dtMinutesConfirm = new DataTable();
                dtMinutesConfirm = AgendaMgr.CheckMinutesConfirmByMeetingId(MeetingId);

                if (dtMinutesConfirm.Rows.Count > 0)
                {
                    MsgDisplay("Minutes already confirmed");
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                    result = false;
                }
                else
                {
                    DataTable dtMeeting = new DataTable();
                    dtMeeting = AgendaMgr.CheckMinutesFinalizeByMeetingId(MeetingId);

                    if (dtMeeting.Rows.Count <= 0)
                    {
                        MsgDisplay("Minutes not finalize for this meeting.");
                        ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                        result = false;
                    }
                }
            }
            return result;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            Response.Redirect("~/DashBoard/DashBoard.aspx");
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
