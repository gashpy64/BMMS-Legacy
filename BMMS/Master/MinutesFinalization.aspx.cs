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
    public partial class MinutesFinalization : System.Web.UI.Page
    {
        private string className = "MinutesFinalization";

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
            btnFinalize.Attributes.Add("onclick", "return MinutesFinalizeValidation()");
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
                HideMinutesItems();     // step MF1: the meeting is -Select- again

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
        // Step MF1: the Minutes Items list follows the meeting chosen (owner-approved new handler; AutoPostBack was
        // already set)
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            LoadMinutesItems(true);
        }
        #endregion

        #region LoadMinutesItems
        // Step MF1 (D1, D3): the meeting's items (MinutesMgr.GetMinutesItemList) and the Finalize confirm built from the
        // same rows. Hidden, with the default confirm, when the committee or the meeting is -Select-. The confirm holds
        // fixed text and counts only (T1 to T4); Finalize stays clickable. A meeting created after step 23 with a minute
        // not saved in Update Minutes, or any meeting without minutes, is refused by the server (Reason 19, or "No
        // Minutes" for an older meeting): the confirm says nothing will be finalized and, when showWarning, the message
        // block shows the server's text in advance (C7; for a meeting created after step 23 MinutesNotUpdatedMessage with
        // the counts of the list, only with the agenda finalized and attendance recorded (C8); for an older meeting
        // NoMinutesMessage).
        private void LoadMinutesItems(bool showWarning)
        {
            try
            {
                if (ddlCommittee.SelectedValue == "0" || string.IsNullOrEmpty(ddlMeeting.SelectedValue) || ddlMeeting.SelectedValue == "0")
                {
                    HideMinutesItems();
                    return;
                }

                int MeetingId = int.Parse(ddlMeeting.SelectedValue);
                MinutesItemList list = MinutesMgr.GetMinutesItemList(MeetingId);

                grvMinutesItems.DataSource = list.Items;
                grvMinutesItems.DataBind();
                pnlMinutesItems.Visible = true;

                MeetingWorkflowState state = MeetingMgr.GetMeetingWorkflowState(MeetingId);
                string text;
                bool refused = false;

                if (list.Total == 0)
                {
                    text = "This meeting has no minutes to finalize. Nothing will be finalized.";                       // T4
                    refused = true;
                }
                else if (list.NotSaved == 0)
                    text = DefaultConfirmText + " Items: " + list.Total + ".";                                          // T1
                else if (!state.IsNew)
                    text = DefaultConfirmText + " Items: " + list.Total + ". Not yet saved in Update Minutes: " + list.NotSaved + ".";  // T2
                else
                {
                    text = "Items: " + list.Total + ". Not yet saved in Update Minutes: " + list.NotSaved + ". These minutes cannot be"
                         + " finalized until every item is saved in Update Minutes. Nothing will be finalized.";        // T3
                    refused = true;
                }

                btnFinalize.OnClientClick = ConfirmScript(text);

                // C7: the text the server gives after OK, with the counts of the same rows as the confirm (D3). A
                // meeting created after step 23: Reason 19 (MinutesNotUpdatedMessage, 'not saved/total'), only when the
                // agenda is finalized and attendance recorded (C8: otherwise the procedure refuses first with Reason 17
                // or 18, which is not forecast, so no warning); an older meeting without minutes: the page's own
                // refusal of btnFinalize_Click.
                if (showWarning && refused)
                {
                    if (!state.IsNew)
                        MsgDisplay(NoMinutesMessage, MessageKind.Warning);
                    else if (state.AgendaFinalized && state.AttendanceRecorded)
                        MsgDisplay(MeetingChangeReason.MinutesNotUpdatedMessage(list.NotSaved + "/" + list.Total), MessageKind.Warning);
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadMinutesItems", ex);
            }
        }

        // The list hidden and the confirm of the markup back
        private void HideMinutesItems()
        {
            pnlMinutesItems.Visible = false;
            grvMinutesItems.DataSource = null;
            grvMinutesItems.DataBind();
            btnFinalize.OnClientClick = ConfirmScript(DefaultConfirmText);
        }

        // The page's refusal of an older meeting without minutes (btnFinalize_Click; also shown in advance, C7)
        private const string NoMinutesMessage = "No Minutes For the selected Committee/Meeting";

        // The text of the markup's confirm (OnClientClick of btnFinalize)
        private const string DefaultConfirmText = "Do you want to Finalize this Meeting Minutes?";

        private static string ConfirmScript(string text)
        {
            return "return confirm('" + HttpUtility.JavaScriptStringEncode(text) + "');";
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

                    // A meeting created after step 23: the procedure checks the order (agenda finalized, attendance
                    // entered, every minute updated) and its refusal is shown (BMMS-Fix-WorkflowOrder-Step23.sql).
                    // Older meetings keep the checks below.
                    if (MeetingMgr.GetMeetingWorkflowState(MeetingId).IsNew)
                    {
                        MeetingChangeResult newResult = AgendaMgr.MinutesFinalizeByMeetingId(MeetingId, int.Parse(Session["UserId"].ToString()));
                        MsgDisplay(newResult.Result == 1 ? "Minutes Finalized" : newResult.RefusalMessage(), newResult.Result == 1 ? MessageKind.Success : MessageKind.Warning);
                        LoadMinutesItems(false);    // step MF1: the list of the meeting, read again; the message stays
                        return;
                    }

                    DataTable dtAgenda = new DataTable();
                    dtAgenda = AgendaMgr.CheckMinutesByMeetingId(MeetingId);

                    if (dtAgenda.Rows.Count <= 0)
                    {
                        sMsg = NoMinutesMessage;
                        MsgDisplay(sMsg);
                    }
                    else
                    {
                        DataTable dtMeetingChairman = MeetingMgr.GetMeetingChairman(MeetingId);

                        string MeetingChairman = dtMeetingChairman.Rows[0]["MeetingChairman"].ToString();
                        if (MeetingChairman != string.Empty)
                        {

                            // Refused if another tab finalized it first (BMMS-Fix-MeetingLocks.sql)
                            MeetingChangeResult result = AgendaMgr.MinutesFinalizeByMeetingId(MeetingId, int.Parse(Session["UserId"].ToString()));

                            sMsg = result.Result == 1 ? "Minutes Finalized" : result.RefusalMessage();

                            MsgDisplay(sMsg, sMsg == "Minutes Finalized" ? MessageKind.Success : MessageKind.Warning);
                        }
                        else
                        {
                            sMsg = "Attendance details not entered for this meeting. So you cannot finalize minutes.";

                            MsgDisplay(sMsg, sMsg == "Minutes Finalized" ? MessageKind.Success : MessageKind.Warning);
                        }
                    }
                    LoadMinutesItems(false);    // step MF1: the list of the meeting, read again; the message stays
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnFinalize_Click", ex);
                }
            }
            else
                LoadMinutesItems(false);        // step MF1: the page's message stays; the list follows the choice
            
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

                    if (dtMeeting.Rows.Count > 0)
                    {
                        MsgDisplay("Minutes already finalized");
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
            HideMinutesItems();     // step MF1 (C4); Cancel then leaves for the Dashboard, as before
            Response.Redirect("~/DashBoard/DashBoard.aspx");
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
