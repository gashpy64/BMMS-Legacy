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
    public partial class Attendance : System.Web.UI.Page
    {
        private string className = "Attendance";

        #region Page_Load
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
        #endregion

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
                ddlChairmanName.Items.Clear();

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

                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());
                int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

                pnlAttendance.Visible = false;
                ddlChairmanName.Items.Clear();

                if (MeetingId != 0 && CommitteeId != 0)
                {
                    pnlAttendance.Visible = true;

                    DataTable dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, MeetingId);

                    ddlChairmanName.DataSource = dtCommitteeMember;
                    ddlChairmanName.DataValueField = "MemberId";
                    ddlChairmanName.DataTextField = "MemberName";
                    ddlChairmanName.DataBind();
                    ddlChairmanName.Items.Insert(0, new ListItem("-Select-", "0"));

                    grvCommitteeMember.DataSource = dtCommitteeMember;
                    grvCommitteeMember.DataBind();

                    DataTable dtMeetingMember = MeetingMemberMgr.GetMeetingMemberByMeetingId(MeetingId);

                    grvMeetingMember.DataSource = dtMeetingMember;
                    grvMeetingMember.DataBind();

                    DataTable dtMeetingChairman = MeetingMgr.GetMeetingChairman(MeetingId);

                    string MeetingChairmanName = dtMeetingChairman.Rows[0]["MeetingChairman"].ToString();
                    string ChairmanNameId = dtMeetingChairman.Rows[0]["ChairmanNameId"].ToString();

                    if (MeetingChairmanName != string.Empty)
                    {
                        ddlChairmanName.Text = ChairmanNameId;
                    }

                    DataTable dtCommitteeAttendance = AttendanceMgr.GetAttendanceByMeetingId(MeetingId, "C");

                    if (dtCommitteeAttendance.Rows.Count > 0)
                    {
                        for (int i = 0; i < dtCommitteeAttendance.Rows.Count; i++)
                            foreach (GridViewRow gr in grvCommitteeMember.Rows)
                                if (gr.RowType == DataControlRowType.DataRow)
                                {
                                    Label lblMemberId = (Label)gr.FindControl("lblMemberId");
                                    CheckBox chkAttend = (CheckBox)gr.FindControl("cbMember");
                                    if (lblMemberId.Text == dtCommitteeAttendance.Rows[i]["MemberId"].ToString()
                                        && dtCommitteeAttendance.Rows[i]["Attendance"].ToString() == "P")
                                        chkAttend.Checked = true;
                                }
                    }

                    DataTable dtMeetingAttendance = AttendanceMgr.GetAttendanceByMeetingId(MeetingId, "M");

                    if (dtMeetingAttendance.Rows.Count > 0)
                    {
                        for (int i = 0; i < dtMeetingAttendance.Rows.Count; i++)
                            foreach (GridViewRow gr in grvMeetingMember.Rows)
                                if (gr.RowType == DataControlRowType.DataRow)
                                {
                                    Label lblMemberId = (Label)gr.FindControl("lblMemberId");
                                    CheckBox chkAttend = (CheckBox)gr.FindControl("cbMember");
                                    if (lblMemberId.Text == dtMeetingAttendance.Rows[i]["MemberId"].ToString()
                                        && dtMeetingAttendance.Rows[i]["Attendance"].ToString() == "P")
                                        chkAttend.Checked = true;
                                }
                    }
                }
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

        #region grvCommitteeMember_RowDataBound
        protected void grvCommitteeMember_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.Header)
            {
                //Find the checkbox control in header and add an attribute
                ((CheckBox)e.Row.FindControl("cbSelectAll")).Attributes.Add("onclick", "javascript:SelectAllCommitteeMember('" +
                        ((CheckBox)e.Row.FindControl("cbSelectAll")).ClientID + "')");
            }
        }
        #endregion

        #region grvMeetingMember_RowDataBound
        protected void grvMeetingMember_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.Header)
            {
                //Find the checkbox control in header and add an attribute
                ((CheckBox)e.Row.FindControl("cbSelectAll")).Attributes.Add("onclick", "javascript:SelectAllMeetingMember('" +
                        ((CheckBox)e.Row.FindControl("cbSelectAll")).ClientID + "')");
            }
        }
        #endregion

        #region btnUpdate_Click
        protected void btnUpdate_Click(object sender, EventArgs e)
        {
            MsgHide();
            if (PageValidation())
            {
                string sMsg = string.Empty;
                try
                {
                    int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());
                    int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());
                    int ChairmanNameId = int.Parse(ddlChairmanName.SelectedValue.ToString());

                    MeetingMgr.UpdateMeetingChairman(MeetingId, CommitteeId, ChairmanNameId);

                    UpdateCommitteeMember();

                    UpdateMeetingMember();

                    sMsg = "Attendance Successfully Updated";

                    MsgDisplay(sMsg);
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnUpdate_Click", ex);
                }
            }
        }
        #endregion

        #region UpdateCommitteeMember
        public void UpdateCommitteeMember()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            foreach (GridViewRow gr in grvCommitteeMember.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    AttendanceBAL myAttendance = new AttendanceBAL();

                    myAttendance.CommitteeId = CommitteeId;
                    myAttendance.MeetingId = MeetingId;
                    myAttendance.MemberOf = "C";

                    myAttendance.MemberId = int.Parse(((Label)gr.FindControl("lblMemberId")).Text);

                    CheckBox chkAttend = (CheckBox)gr.FindControl("cbMember");
                    if (chkAttend.Checked == true)
                    {
                        myAttendance.Attendance = "P";
                    }
                    else
                    {
                        myAttendance.Attendance = "A";
                    }
                    myAttendance.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    AttendanceMgr.UpdateAttendance(myAttendance);

                }
            }
        }
        #endregion

        #region UpdateMeetingMember
        public void UpdateMeetingMember()
        {
            int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            foreach (GridViewRow gr in grvMeetingMember.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    AttendanceBAL myAttendance = new AttendanceBAL();

                    myAttendance.CommitteeId = CommitteeId;
                    myAttendance.MeetingId = MeetingId;
                    myAttendance.MemberOf = "M";

                    myAttendance.MemberId = int.Parse(((Label)gr.FindControl("lblMemberId")).Text);

                    CheckBox chkAttend = (CheckBox)gr.FindControl("cbMember");
                    if (chkAttend.Checked == true)
                    {
                        myAttendance.Attendance = "P";
                    }
                    else
                    {
                        myAttendance.Attendance = "A";
                    }
                    myAttendance.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    AttendanceMgr.UpdateAttendance(myAttendance);

                }
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            if (ddlChairmanName.SelectedValue.ToString() == "0")
            {
                MsgDisplay("Please select Chairman Name");

                ScriptManager.GetCurrent(this).SetFocus(ddlChairmanName.ClientID);

                return false;
            }

            return true;
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
