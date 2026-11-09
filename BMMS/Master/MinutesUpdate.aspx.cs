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
using BMMS.Controls;
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

                    // A meeting created after step 23: the database's workflow state decides, with the same messages
                    // as the procedures (BMMS-Fix-WorkflowOrder-Step23.sql). Older meetings keep the checks below.
                    MeetingWorkflowState state = MeetingMgr.GetMeetingWorkflowState(MeetingId);

                    if (state.IsNew)
                    {
                        if (!state.AgendaFinalized)
                            MsgDisplay(MeetingChangeReason.AgendaNotFinalizedMessage);
                        else if (!state.AttendanceRecorded)
                            MsgDisplay(MeetingChangeReason.AttendanceNotRecordedMessage);
                        else
                        {
                            pnlViewMinute.Visible = true;
                            grvMinutes.DataSource = MinutesMgr.GetMinutesByMeetingId(MeetingId, -1, -1);
                            grvMinutes.DataBind();
                        }
                        return;
                    }

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
                    Button btnDirections = (Button)e.Row.FindControl("btnDirections");

                    ddlDecisionType.Text = lblDecisionTypeId.Text.Trim();
                    if (lblDecisionTypeId.Text == "1")
                    {
                        btnDirections.Enabled = true;
                        btnDirections.Visible = true;
                    }
                    else
                    {
                        btnDirections.Enabled = false;
                        btnDirections.Visible = false;
                    }

                    // Step UN6a: the stored due date (dd-MMM-yyyy), and the box only for a Followup decision
                    TextBox txtDueDate = (TextBox)e.Row.FindControl("txtDueDate");
                    DataRowView drv = e.Row.DataItem as DataRowView;
                    object dueDate = drv == null || !drv.Row.Table.Columns.Contains("DueDate") ? null : drv["DueDate"];
                    txtDueDate.Text = dueDate == null || dueDate == DBNull.Value ? string.Empty : Convert.ToDateTime(dueDate).ToString("dd-MMM-yyyy");
                    SetDueDateBox(e.Row, lblDecisionTypeId.Text.Trim() == FollowupDecisionTypeId);

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
                            ftxtDirections.Text = HtmlCleaner.Clean(dtMinutes.Rows[0]["ActualResolution"].ToString());
                        else
                            ftxtDirections.Text = HtmlCleaner.Clean(dtMinutes.Rows[0]["Directions"].ToString());

                    }
                    if (e.CommandName == "ViewProposedResolution")
                    {
                        pnlProposedResolution.Visible = true;
                        ftxtProposedResolution.Text = HtmlCleaner.Clean(dtMinutes.Rows[0]["ProposedResolution"].ToString());

                    }
                    if (e.CommandName == "EditActualResolution")
                    {
                        pnlActualResolution.Visible = true;
                        ftxtActualResolution.Text = HtmlCleaner.Clean(dtMinutes.Rows[0]["ActualResolution"].ToString());
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

            Button btnDirections = (Button)gv.FindControl("btnDirections");

            if (ddl.SelectedItem.Text.Equals("Followup"))
            {
                btnDirections.Enabled = true;
                btnDirections.Visible = true;
            }
            else
            {
                btnDirections.Enabled = false;
                btnDirections.Visible = false;
            }

            // Step UN6a: the due date box follows the decision (by its id: Followup = 1); another decision empties it
            SetDueDateBox(gv, ddl.SelectedValue == FollowupDecisionTypeId);
        }

        // Step UN6a: the decision id of Followup (Decision_Type, DT001); only it can have a due date
        private const string FollowupDecisionTypeId = "1";

        // Step UN6a: enables the due date box, its calendar and its Clear button for a Followup row; for any other
        // decision they are disabled and the box is emptied (the procedure stores NULL for it anyway)
        private void SetDueDateBox(GridViewRow Row, bool IsFollowup)
        {
            TextBox txtDueDate = (TextBox)Row.FindControl("txtDueDate");
            ImageButton imgCalendar = (ImageButton)Row.FindControl("imgCalendar");
            AjaxControlToolkit.CalendarExtender calDueDate = (AjaxControlToolkit.CalendarExtender)Row.FindControl("CalendarExtender1");
            System.Web.UI.HtmlControls.HtmlInputButton btnClearDueDate = (System.Web.UI.HtmlControls.HtmlInputButton)Row.FindControl("btnClearDueDate");

            if (!IsFollowup)
                txtDueDate.Text = string.Empty;

            txtDueDate.Enabled = IsFollowup;
            imgCalendar.Enabled = IsFollowup;
            calDueDate.Enabled = IsFollowup;
            btnClearDueDate.Disabled = !IsFollowup;
            btnClearDueDate.Attributes["onclick"] = "document.getElementById('" + txtDueDate.ClientID + "').value = ''; return false;";
        }
        #endregion


        #region btnDirectionsSave_Click
        protected void btnDirectionsSave_Click(object sender, EventArgs e)
        {
            // Step A2a: rich text over the limit (Web.config): nothing is saved, the editor stays open
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            MinutesBAL myMinutesBAL = new MinutesBAL();

            myMinutesBAL.Code = "Directions";
            myMinutesBAL.MinutesId = int.Parse(hdnMinutesId.Value);
            myMinutesBAL.Directions = ftxtDirections.Text.Trim();
            myMinutesBAL.ActualResolution = "";
            myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

            ShowRefusal(MinutesMgr.UpdateMinutes(myMinutesBAL));

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
            // Step A2a: rich text over the limit (Web.config): nothing is saved, the editor stays open
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            MinutesBAL myMinutesBAL = new MinutesBAL();

            myMinutesBAL.Code = "ActualResolution";
            myMinutesBAL.MinutesId = int.Parse(hdnMinutesId.Value);
            myMinutesBAL.Directions = "";
            myMinutesBAL.ActualResolution = ftxtActualResolution.Text.Trim();
            //myMinutesBAL.ActualResolution = txtaActualResolution.InnerHtml.ToString();
            myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

            ShowRefusal(MinutesMgr.UpdateMinutes(myMinutesBAL));

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

            ShowRefusal(AgendaMgr.UpdateAgendaShortText(myAgenda));

            pnlShortText.Visible = false;
        }
        #endregion

        #region ShowRefusal
        // Minutes confirmed in another tab since the list was shown (BMMS-Fix-MeetingLocks-Step16.sql)
        private void ShowRefusal(MeetingChangeResult result)
        {
            if (result.Result != 1)
            {
                MsgDisplay(result.RefusalMessage());
                ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0);", true);
            }
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

            // Step UN6a, first pass: every Followup due date must be a date and not before the meeting date; on the
            // first wrong row nothing is saved (the procedure checks the meeting date again, Reason 22)
            System.Collections.Generic.Dictionary<int, DateTime?> dueDates = new System.Collections.Generic.Dictionary<int, DateTime?>();
            string dueDateError = CheckDueDates(dueDates);
            if (dueDateError != null)
            {
                MsgDisplay(dueDateError);
                ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0);", true);
                return;
            }

            foreach (GridViewRow gr in grvMinutes.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    MinutesBAL myMinutesBAL = new MinutesBAL();

                    int MinutesId = int.Parse(((Label)gr.FindControl("lblMinutesId")).Text);
                    int AgendaId = int.Parse(((Label)gr.FindControl("lblAgendaId")).Text);
                    string ShortText = ((TextBox)gr.FindControl("txtShortText")).Text;
                    int DecisionTypeId = int.Parse(((DropDownList)gr.FindControl("ddlDecisionType")).SelectedValue);

                    myMinutesBAL.Code = "All";
                    myMinutesBAL.MinutesId = MinutesId;
                    myMinutesBAL.DecisionTypeId = DecisionTypeId;

                    // Step UN6a: the date checked above (null: no due date, and always null for another decision)
                    myMinutesBAL.DueDate = dueDates.ContainsKey(gr.RowIndex) ? dueDates[gr.RowIndex] : null;

                    myMinutesBAL.ShortText = ShortText.Trim();
                    myMinutesBAL.Directions = "";
                    myMinutesBAL.ActualResolution = "";
                    myMinutesBAL.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    MeetingChangeResult result = MinutesMgr.UpdateMinutes(myMinutesBAL);

                    if (result.Result != 1)
                    {
                        // Confirmed in another tab: every row is refused the same way
                        strMsg = result.RefusalMessage();
                        break;
                    }

                    int MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue.ToString());
                    AlertMgr.UpdateAlertByMeetingId(MeetingId);

                    strMsg = "Successfully Saved";
                }
            }
            MsgDisplay(strMsg, strMsg == "Successfully Saved" ? MessageKind.Success : MessageKind.Warning);
            ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0);", true);
            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
        }
        #endregion

        #region CheckDueDates
        // Step UN6a: reads the due date of every row. A Followup row with a date gets it in DueDates (by row index),
        // without its time; an empty box and any other decision get null. Returns null when all are right, or the
        // message for the first wrong row: not a date, or before the meeting date (no limit for a meeting without
        // a date). The page checks first; the procedure checks the meeting date again (Reason 22).
        private string CheckDueDates(System.Collections.Generic.Dictionary<int, DateTime?> DueDates)
        {
            int meetingId;
            DateTime? meetingDate = null;
            if (int.TryParse(ddlMeeting.SelectedValue, out meetingId))
            {
                DataTable dtMeeting = MeetingMgr.GetMeetingByMeetingId(meetingId);
                DateTime md;
                if (dtMeeting.Rows.Count > 0 && dtMeeting.Rows[0]["MeetingDate"] != DBNull.Value
                    && DateTime.TryParse(dtMeeting.Rows[0]["MeetingDate"].ToString(), out md))
                    meetingDate = md.Date;
            }

            foreach (GridViewRow gr in grvMinutes.Rows)
            {
                if (gr.RowType != DataControlRowType.DataRow)
                    continue;

                string agendaNo = ((Label)gr.FindControl("lblAgendaNo")).Text.Trim();
                bool isFollowup = ((DropDownList)gr.FindControl("ddlDecisionType")).SelectedValue == FollowupDecisionTypeId;
                string text = ((TextBox)gr.FindControl("txtDueDate")).Text.Trim();

                if (!isFollowup || text == string.Empty)
                {
                    DueDates[gr.RowIndex] = null;
                    continue;
                }

                DateTime dueDate;
                if (!DateTime.TryParse(text, out dueDate))
                    return "Agenda " + HttpUtility.HtmlEncode(agendaNo) + ": the due date is not a valid date (dd-MMM-yyyy). Nothing was saved.";

                if (meetingDate.HasValue && dueDate.Date < meetingDate.Value)
                    return "Agenda " + HttpUtility.HtmlEncode(agendaNo) + ": the due date cannot be before the meeting date ("
                         + meetingDate.Value.ToString("dd-MMM-yyyy") + "). Nothing was saved.";

                DueDates[gr.RowIndex] = dueDate.Date;
            }

            return null;
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
