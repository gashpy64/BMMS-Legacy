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
    public partial class AgendaFinalization : System.Web.UI.Page
    {
        private string className = "AgendaFinalization";

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
            btnFinalize.Attributes.Add("onclick", "return AgendaFinalizeValidation()");
            //ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

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

                LoadAgenda();

                BindGridView();
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

                LoadAgenda();

                BindGridView();
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

        #region LoadAgenda
        private void LoadAgenda()
        {
            int CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);

            int MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue); ;

            int UserId = int.Parse(Session["UserId"].ToString());

            DataTable dtAgenda = new DataTable();
            dtAgenda = AgendaMgr.CheckAgendaApprovedByMeetingId(MeetingId);

            ViewState["dtAgenda"] = dtAgenda;

        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            DataTable dtAgenda = new DataTable();
            dtAgenda = (DataTable)ViewState["dtAgenda"];

            if (dtAgenda.Rows.Count <= 0)
            {
                pnlPendingAgenda.Visible = false;
            }
            else
            {
                pnlPendingAgenda.Visible = true;
                grvAgenda.DataSource = dtAgenda;
                grvAgenda.DataBind();
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

        #region btnFinalize_Click
        protected void btnFinalize_Click(object sender, EventArgs e)
        {

            string sMsg = string.Empty;
            if (PageValidation())
            {
                try
                {
                    int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                    DataTable dtAgenda = new DataTable();
                    dtAgenda = AgendaMgr.CheckAgendaByMeetingId(MeetingId);

                    if (dtAgenda.Rows.Count <= 0)
                    {
                        sMsg = "No Agenda For the selected Committee/Meeting";
                        MsgDisplay(sMsg);
                    }
                    else
                    {
                        dtAgenda = new DataTable();
                        dtAgenda = (DataTable)ViewState["dtAgenda"];

                        if (dtAgenda.Rows.Count > 0)
                        {
                            for(int i=0; i<= dtAgenda.Rows.Count-1;i++)
                            {
                                int AgendaId = int.Parse(dtAgenda.Rows[i]["AgendaId"].ToString());
                                RejectAgenda(AgendaId, dtAgenda, i);
                            }
                        }

                        int result = AgendaMgr.AgendaFinalizeByMeetingId(MeetingId);

                        sMsg = "Agenda Finalized";

                        MsgDisplay(sMsg);

                    }

                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnFinalize_Click", ex);
                }
            }

        }
        #endregion

        #region RejectAgenda
        private void RejectAgenda(int AgendaId, DataTable dtAgenda, int CurrentRow)
        {

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = AgendaId;
            agendaBal.ShortText = "";
            agendaBal.ProposedResolution = "";
            agendaBal.MgrComments = "";
            agendaBal.ControllerComments = "Agenda rejected by Controller on agenda finalized.";
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            agendaBal.ControllerApprovedStatus = "Rejected";
            GenerateMail("rejected by Controller on agenda finalized", "ACR", dtAgenda, CurrentRow);
            
            agendaBal.UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

            AgendaMgr.UpdateAgendaByAgendaId(agendaBal);
        }
        #endregion

        #region GenerateMail
        private string GenerateMail(string AgendaStatus, string MailCode, DataTable dtAgenda, int CurrentRow)
        {
            string ToMailId = string.Empty;
            string Bcc = string.Empty;
            int AgendaId = int.Parse(dtAgenda.Rows[CurrentRow]["AgendaId"].ToString());
            int UserId = int.Parse(Session["UserId"].ToString());

            UserBAL userBal = UserMgr.GetUserByUserId(UserId);
            ToMailId = userBal.EmailId.ToString();

            Bcc = AlertMgr.GetAlertMailId(MailCode, UserId, AgendaId);

            string Subject = "Agenda (" + dtAgenda.Rows[CurrentRow]["AgendaNo"].ToString() + ") has been " + AgendaStatus.ToString();
            string BodyText = string.Empty;
            BodyText += "<table>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Agenda No <br /><br />";
            BodyText += "Committee Name <br /><br />";
            BodyText += "Meeting No <br /><br />";
            BodyText += "Meeting Date <br /><br />";
            BodyText += "Department <br /><br />";
            BodyText += "Subject Type <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["AgendaNo"].ToString() + "<br /><br />";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["CommitteeName"].ToString() + "<br /><br />";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["MeetingNo"].ToString() + "<br /><br />";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["MeetingDate"].ToString() + "<br /><br />";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["DepartmentName"].ToString() + "<br /><br />";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["SubjectTypeName"].ToString() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Short Text <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + dtAgenda.Rows[CurrentRow]["ShortText"].ToString() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "</table>";

            string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);

            

            return result;
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

                DataTable dtMeeting = new DataTable();
                dtMeeting = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId);

                if (dtMeeting.Rows.Count <= 0)
                {
                    MsgDisplay("Agenda already finalized");
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                    result = false;
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

        #region grvAgenda_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvAgenda_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    //e.Row.Attributes.Add("onmouseover", "MouseEvents(this, event)");
                    //e.Row.Attributes.Add("onmouseout", "MouseEvents(this, event)");

                    //Label LblEmployeeCode = (Label)e.Row.FindControl("LblEmployeeCode");
                    //if (LblEmployeeCode.Text == string.Empty)
                    //    for (int i = 0; i < e.Row.Cells.Count; i++)
                    //        e.Row.Controls[i].Visible = false;
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvAgenda_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtAgenda"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtAgenda"]);

                BindGridView();
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
