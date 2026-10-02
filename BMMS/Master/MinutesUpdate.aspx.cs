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
    public partial class MinutesUpdate : System.Web.UI.Page
    {
        private string className = "MinutesUpdate";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                pnlViewMinute.Visible = false;
                pnlDirections.Visible = false;
                pnlShortText.Visible = false;
                pnlProposedResolution.Visible = false;
                pnlActualResolution.Visible = false;
                InitCtrlAttributes();
                LoadCommittee();
                LoadMember();
            }
        } 
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnUpdateMinutes.Attributes.Add("onclick", "return MinutesFinalizeValidation()");
            //ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                pnlViewMinute.Visible = false;
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

        #region LoadDecisionType
        public DataTable LoadDecisionType()
        {
            DataTable dtDecisionType = new DataTable();
            try
            {
                dtDecisionType = DecisionTypeMgr.GetDecisionTypeList(1);

                DataRow dr = dtDecisionType.NewRow();

                ViewState["dtDecisionType"] = dtDecisionType;
                //Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadDecisionType", ex);
            }
            finally
            {

            }
            return dtDecisionType;
        }
        #endregion

        #region btnUpdateMinutes_Click
        protected void btnUpdateMinutes_Click(object sender, EventArgs e)
        {
            MsgHide();
            string sMsg = string.Empty;
            if (PageValidation())
            {
                try
                {
                    int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                    DataTable dtAgendaFinalize = new DataTable();
                    dtAgendaFinalize = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId); // MinutesMgr.GetMinutesByMeetingId(MeetingId);

                    if (dtAgendaFinalize.Rows.Count <= 0)
                    {
                        DataTable dtMeetingChairman = MeetingMgr.GetMeetingChairman(MeetingId);

                        string MeetingChairman = dtMeetingChairman.Rows[0]["MeetingChairman"].ToString();
                        if (MeetingChairman != string.Empty)
                        {
                            pnlViewMinute.Visible = true;

                            DataTable dtMinutes = new DataTable();
                            dtMinutes = MinutesMgr.GetMinutesByMeetingId(MeetingId, -1, -1);

                            grvMinutes.DataSource = dtMinutes;
                            grvMinutes.DataBind();
                        }
                        else
                        {
                            sMsg = "Attendance details not entered for this meeting.";

                            MsgDisplay(sMsg);
                        }
                    }
                    else
                    {
                        sMsg = "Aganda not finalized for this meeting.  So you cannot update minutes.";
                        MsgDisplay(sMsg);
                    }

                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnUpdateMinutes_Click", ex);
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

                DataTable dtMeeting = new DataTable();
                dtMeeting = AgendaMgr.CheckMinutesConfirmByMeetingId(MeetingId);

                if (dtMeeting.Rows.Count > 0)
                {
                    MsgDisplay("Minutes already confirmed");
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
            Response.Redirect("~/Master/MinutesUpdate.aspx");
        }
        #endregion


        #region grvMinutes_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMinutes_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    //e.Row.Attributes.Add("onmouseover", "MouseEvents(this, event)");
                    //e.Row.Attributes.Add("onmouseout", "MouseEvents(this, event)");

                    DropDownList ddlDecisionType = (DropDownList)e.Row.FindControl("ddlDecisionType");
                    Label lblDecisionTypeId = (Label)e.Row.FindControl("lblDecisionTypeId");
                    //Label lblDueDate = (Label)e.Row.FindControl("lblDueDate");
                    //TextBox txtDueDate = (TextBox)e.Row.FindControl("txtDueDate");
                    //ImageButton imgCalendar = (ImageButton)e.Row.FindControl("imgCalendar");
                    Button btnDirections = (Button)e.Row.FindControl("btnDirections");

                    ddlDecisionType.Text = lblDecisionTypeId.Text.Trim();
                    if (lblDecisionTypeId.Text == "1")
                    {
                        //txtDueDate.Enabled = true;
                        //txtDueDate.Text = Convert.ToDateTime(lblDueDate.Text).ToString("dd-MMM-yyyy");
                        //imgCalendar.Enabled = true;
                        btnDirections.Enabled = true;
                        btnDirections.Visible = true;
                    }
                    else
                    {
                        //txtDueDate.Enabled = false;
                        //txtDueDate.Text = string.Empty;
                        //imgCalendar.Enabled = false;
                        btnDirections.Enabled = false;
                        btnDirections.Visible = false;
                    }

                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvMinutes_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                //ViewState["DataTable"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["DataTable"]);

                //BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region grvMinutes_RowCommand
        protected void grvMinutes_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                MsgHide();

                if (e.CommandName == "ViewShortText")
                {
                    int AgendaId = int.Parse(e.CommandArgument.ToString());
                    hdnAgendaId.Value = AgendaId.ToString();

                    DataTable dtAgenda = new DataTable();
                    dtAgenda = AgendaMgr.GetAgendaByAgendaId(AgendaId);

                    pnlShortText.Visible = true;
                    txtShortText.Text = dtAgenda.Rows[0]["ShortText"].ToString();

                }
                else
                {
                    int MinutesId = int.Parse(e.CommandArgument.ToString());
                    hdnMinutesId.Value = MinutesId.ToString();

                    DataTable dtMinutes = new DataTable();
                    dtMinutes = MinutesMgr.GetMinutesByMinutesId(MinutesId);

                    if (e.CommandName == "AddDirections")
                    {
                        pnlDirections.Visible = true;
                        
                        if (dtMinutes.Rows[0]["Directions"].ToString().Trim() == string.Empty)
                            ftxtDirections.Text = dtMinutes.Rows[0]["ActualResolution"].ToString();
                        else
                            ftxtDirections.Text = dtMinutes.Rows[0]["Directions"].ToString();

                    }
                    if (e.CommandName == "ViewProposedResolution")
                    {
                        pnlProposedResolution.Visible = true;
                        ftxtProposedResolution.Text = dtMinutes.Rows[0]["ProposedResolution"].ToString();

                    }
                    if (e.CommandName == "EditActualResolution")
                    {
                        pnlActualResolution.Visible = true;
                        ftxtActualResolution.Text = dtMinutes.Rows[0]["ActualResolution"].ToString();
                        //txtaActualResolution.InnerText = dtMinutes.Rows[0]["ProposedResolution"].ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvBranchDetails_RowCommand", ex);
            }
        }
        #endregion


        #region ddlDecision_SelectedIndexChanged
        protected void ddlDecision_SelectedIndexChanged(object sender, EventArgs e)
        {
            DropDownList ddl = ((DropDownList)sender);

            GridViewRow gv = (GridViewRow)(ddl.Parent.Parent);

            //TextBox txtDueDate = (TextBox)gv.Cells[5].FindControl("txtDueDate");
            //ImageButton imgCalendar = (ImageButton)gv.Cells[5].FindControl("imgCalendar");
            Button btnDirections = (Button)gv.Cells[6].FindControl("btnDirections");

            if (ddl.SelectedItem.Text.Equals("Followup"))
            {
                //txtDueDate.Enabled = true;
                //imgCalendar.Enabled = true;
                btnDirections.Enabled = true;
                btnDirections.Visible = true;
            }
            else
            {
                //txtDueDate.Enabled = false;
                //txtDueDate.Text = string.Empty;
                //imgCalendar.Enabled = false;
                btnDirections.Enabled = false;
                btnDirections.Visible = false;
            }
        }
        #endregion


        #region btnDirectionsSave_Click
        protected void btnDirectionsSave_Click(object sender, EventArgs e)
        {
            MinutesBAL myMinutesBAL = new MinutesBAL();

            myMinutesBAL.Code = "Directions";
            myMinutesBAL.MinutesId = int.Parse(hdnMinutesId.Value);
            myMinutesBAL.Directions = ftxtDirections.Text.Trim();
            myMinutesBAL.ActualResolution = "";
            myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

            MinutesMgr.UpdateMinutes(myMinutesBAL);

            pnlDirections.Visible = false;
        }
        #endregion

        #region btnDirectionsCancel_Click
        protected void btnDirectionsCancel_Click(object sender, EventArgs e)
        {
            pnlDirections.Visible = false;
        }
        #endregion

        #region btnShortTextCancel_Click
        protected void btnShortTextCancel_Click(object sender, EventArgs e)
        {
            pnlShortText.Visible = false;
        }
        #endregion

        #region btnProposedResolutionCancel_Click
        protected void btnProposedResolutionCancel_Click(object sender, EventArgs e)
        {
            pnlProposedResolution.Visible = false;
        }
        #endregion

        #region btnActualResolutionSave_Click
        protected void btnActualResolutionSave_Click(object sender, EventArgs e)
        {
            MinutesBAL myMinutesBAL = new MinutesBAL();

            myMinutesBAL.Code = "ActualResolution";
            myMinutesBAL.MinutesId = int.Parse(hdnMinutesId.Value);
            myMinutesBAL.Directions = "";
            myMinutesBAL.ActualResolution = ftxtActualResolution.Text.Trim();
            //myMinutesBAL.ActualResolution = txtaActualResolution.InnerHtml.ToString();
            myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

            MinutesMgr.UpdateMinutes(myMinutesBAL);

            pnlActualResolution.Visible = false;
        }
        #endregion

        #region btnShortTextSave_Click
        protected void btnShortTextSave_Click(object sender, EventArgs e)
        {
            AgendaBAL myAgenda = new AgendaBAL();

            myAgenda.AgendaId = Convert.ToInt16(hdnAgendaId.Value.Trim());
            myAgenda.ShortText = txtShortText.Text.Trim();
            myAgenda.UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

            AgendaMgr.UpdateAgendaShortText(myAgenda);
            
            pnlShortText.Visible = false;
        }
        #endregion

        #region btnActualResolutionCancel_Click
        protected void btnActualResolutionCancel_Click(object sender, EventArgs e)
        {
            pnlActualResolution.Visible = false;
        }
        #endregion

        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            MsgHide();
            string strMsg = string.Empty;

            foreach (GridViewRow gr in grvMinutes.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    MinutesBAL myMinutesBAL = new MinutesBAL();

                    int MinutesId = int.Parse(((Label)gr.FindControl("lblMinutesId")).Text);
                    int AgendaId = int.Parse(((Label)gr.FindControl("lblAgendaId")).Text);
                    string ShortText = ((TextBox)gr.FindControl("txtShortText")).Text;
                    int DecisionTypeId = int.Parse(((DropDownList)gr.FindControl("ddlDecisionType")).SelectedValue);
                    //string txtDueDate = ((TextBox)gr.FindControl("txtDueDate")).Text.Trim();

                    myMinutesBAL.Code = "All";
                    myMinutesBAL.MinutesId = MinutesId;
                    myMinutesBAL.DecisionTypeId = DecisionTypeId;

                    //if (txtDueDate != string.Empty)
                    //    myMinutesBAL.DueDate = Convert.ToDateTime(txtDueDate);
                    //else
                    //    myMinutesBAL.DueDate = System.DateTime.Now;

                    myMinutesBAL.ShortText = ShortText.Trim();
                    myMinutesBAL.Directions = "";
                    myMinutesBAL.ActualResolution = "";
                    myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    MinutesMgr.UpdateMinutes(myMinutesBAL);

                    int MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue.ToString());
                    AlertMgr.UpdateAlertByMeetingId(MeetingId);

                    strMsg = "Successfully Saved";
                }
            }
            MsgDisplay(strMsg);
            ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0);", true);
            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
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
