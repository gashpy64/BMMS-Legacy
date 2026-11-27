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
                LoadMeetings(true);
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

        #region LoadMeetings
        // Step AF1 (R3, R6): only the meetings whose minutes are finalized and not confirmed. A committee with none
        // keeps "- Select -" alone and, when showEmpty, the message says so. Not shown after a Confirm (R4: the
        // success message stays).
        private void LoadMeetings(bool showEmpty)
        {
            int _intCommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
            DataTable dtMeeting = MeetingMgr.GetMeetingsToActOn(_intCommitteeId, MeetingAction.MinutesConfirm);

            ViewState["dtMeeting"] = dtMeeting;
            Common.LoadDropdownlist(ddlMeeting, dtMeeting, "MeetingNo", "MeetingId", true);

            if (showEmpty && ddlCommittee.SelectedValue != "0" && dtMeeting.Rows.Count == 0)
                MsgDisplay(NoMeetingMessage);
        }

        private const string NoMeetingMessage = "This committee has no meeting with finalized minutes waiting for confirmation.";
        #endregion

        #region ddlMeeting_SelectedIndexChanged
        // Step MF1: the Minutes Items list follows the meeting chosen (owner-approved new handler; AutoPostBack was
        // already set)
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            LoadMinutesItems();
        }
        #endregion

        #region LoadMinutesItems
        // Step MF1 (D1, D3): the meeting's items (MinutesMgr.GetMinutesItemList) and the Confirm confirm with the count
        // of the same rows (fixed text and the count only). Hidden, with the default confirm, when the committee or
        // the meeting is -Select-.
        private void LoadMinutesItems()
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

                btnConfirm.OnClientClick = ConfirmScript(DefaultConfirmText + " Items: " + list.Total + ".");
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
            btnConfirm.OnClientClick = ConfirmScript(DefaultConfirmText);
        }

        // The text of the markup's confirm (OnClientClick of btnConfirm)
        private const string DefaultConfirmText = "Do you want to Confirm this Meeting Minutes?";

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
                        // Refused if another tab confirmed it first (BMMS-Fix-MeetingLocks.sql)
                        MeetingChangeResult result = AgendaMgr.MinutesConfirmByMeetingId(MeetingId, int.Parse(Session["UserId"].ToString()));

                        sMsg = result.Result == 1 ? "Minutes confirmed." : result.RefusalMessage();

                        MsgDisplay(sMsg, sMsg == "Minutes confirmed." ? MessageKind.Success : MessageKind.Warning);

                        if (result.Result == 1)
                        {
                            // Step AF1 (R4): the meeting drops out of the list; Meeting No is "- Select -", the
                            // Minutes Items list is hidden and the confirm is the markup's; the message stays
                            LoadMeetings(false);
                            HideMinutesItems();
                            return;
                        }
                    }
                    LoadMinutesItems();     // step MF1: the list of the meeting, read again; the message stays
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnConfirm_Click", ex);
                }
            }
            else
                LoadMinutesItems();         // step MF1: the page's message stays; the list follows the choice

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
                        MsgDisplay(MeetingChangeReason.MinutesNotFinalizedForConfirmMessage);   // step 23 wording
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
