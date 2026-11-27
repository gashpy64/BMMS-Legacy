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

                LoadMeetings(true);

                LoadAgenda();

                BindGridView();

                SetFinalizeConfirm();
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

                SetFinalizeConfirm();
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

        #region LoadMeetings
        // Step AF1 (R1, R6): only the meetings whose agenda is still Open (MeetingMgr.GetMeetingsToActOn). A committee
        // with none keeps "- Select -" alone and, when showEmpty, the message says so. Not shown after a Finalize
        // (R4: the success message stays).
        private void LoadMeetings(bool showEmpty)
        {
            int _intCommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
            DataTable dtMeeting = MeetingMgr.GetMeetingsToActOn(_intCommitteeId, MeetingAction.AgendaFinalize);

            ViewState["dtMeeting"] = dtMeeting;
            Common.LoadDropdownlist(ddlMeeting, dtMeeting, "MeetingNo", "MeetingId", true);

            if (showEmpty && ddlCommittee.SelectedValue != "0" && dtMeeting.Rows.Count == 0)
                MsgDisplay(NoMeetingMessage);
        }

        private const string NoMeetingMessage = "This committee has no meeting with its agenda still to finalize.";
        #endregion

        #region SetFinalizeConfirm
        // Step AF1 (R5): the Finalize confirm, built on the server from the counts of the rows the server acts on:
        // approved = the meeting's Agenda rows (AgendaMgr.CheckAgendaByMeetingId, as btnFinalize_Click reads them)
        // with ControllerApprovedStatus 'Approved' (the rows spr_AgendaFinalizeByMeetingId copies to the minutes);
        // to be rejected = the list btnFinalize_Click rejects, each with a mail (ViewState dtAgenda, from
        // spr_CheckAgendaApprovedByMeetingId). Fixed text, the committee name, the meeting number and the counts,
        // through JavaScriptStringEncode. The markup's text when the committee or the meeting is "- Select -".
        private void SetFinalizeConfirm()
        {
            if (ddlCommittee.SelectedValue == "0" || string.IsNullOrEmpty(ddlMeeting.SelectedValue) || ddlMeeting.SelectedValue == "0")
            {
                btnFinalize.OnClientClick = ConfirmScript(DefaultConfirmText);
                return;
            }

            int MeetingId = int.Parse(ddlMeeting.SelectedValue);
            DataTable dtAll = AgendaMgr.CheckAgendaByMeetingId(MeetingId);
            DataTable dtToReject = (DataTable)ViewState["dtAgenda"];

            int approved = 0;
            foreach (DataRow row in dtAll.Rows)
            {
                if (row["ControllerApprovedStatus"] != DBNull.Value
                    && string.Equals(row["ControllerApprovedStatus"].ToString().Trim(), "Approved", StringComparison.OrdinalIgnoreCase))
                    approved += 1;
            }
            int toReject = dtToReject == null ? 0 : dtToReject.Rows.Count;

            string text = "Finalize the agenda of " + ddlCommittee.SelectedItem.Text + ", Meeting No " + ddlMeeting.SelectedItem.Text + "?";

            if (dtAll.Rows.Count == 0)
                text += " This meeting has no agenda items, so it will have no minutes.";
            else
            {
                if (approved > 0)
                    text += " Approved items that go to the minutes: " + approved + ".";
                else
                    text += " No item is approved, so no item goes to the minutes.";

                if (toReject > 0)
                    text += " Items not yet approved that will be rejected, with a mail for each: " + toReject + ".";
                else
                    text += " No item will be rejected.";
            }

            btnFinalize.OnClientClick = ConfirmScript(text);
        }

        // The text of the markup's confirm (OnClientClick of btnFinalize)
        private const string DefaultConfirmText = "Do you want to Finalize this Meeting Agenda?";

        private static string ConfirmScript(string text)
        {
            return "return confirm('" + HttpUtility.JavaScriptStringEncode(text) + "');";
        }

        // Step AF1 (R4): after a successful Finalize the meeting is no longer Open: the list of the committee is read
        // again, Meeting No is "- Select -", the pending list is hidden and the confirm is the markup's; the message stays
        private void ReloadAfterFinalize()
        {
            LoadMeetings(false);
            LoadAgenda();
            BindGridView();
            SetFinalizeConfirm();
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
                        // A meeting without agenda items can still be finalized, so its attendance can be entered
                        // (step 23); it has no minutes to finalize later (Reason 19)
                        MeetingChangeResult noItems = AgendaMgr.AgendaFinalizeByMeetingId(MeetingId);

                        sMsg = noItems.Result == 1 ? "Agenda Finalized (no agenda items)." : noItems.RefusalMessage();
                        MsgDisplay(sMsg, sMsg == "Agenda Finalized (no agenda items)." ? MessageKind.Success : MessageKind.Warning);

                        if (noItems.Result == 1)
                            ReloadAfterFinalize();      // step AF1 (R4)
                    }
                    else
                    {
                        dtAgenda = new DataTable();
                        dtAgenda = (DataTable)ViewState["dtAgenda"];

                        // Each rejection is saved before its mail goes out (step M3); refused rejections and
                        // mails that could not be sent are counted for the message
                        int notRejected = 0;
                        int mailsFailed = 0;

                        if (dtAgenda.Rows.Count > 0)
                        {
                            for(int i=0; i<= dtAgenda.Rows.Count-1;i++)
                            {
                                int AgendaId = int.Parse(dtAgenda.Rows[i]["AgendaId"].ToString());
                                string rejectResult = RejectAgenda(AgendaId, dtAgenda, i);

                                if (rejectResult == "NotRejected")
                                    notRejected += 1;
                                else if (rejectResult != "Success")
                                    mailsFailed += 1;
                            }
                        }

                        // Refused if another tab finalized it first (BMMS-Fix-MeetingLocks.sql)
                        MeetingChangeResult result = AgendaMgr.AgendaFinalizeByMeetingId(MeetingId);

                        sMsg = result.Result == 1 ? "Agenda Finalized" : result.RefusalMessage();

                        string rejectNotes = string.Empty;
                        if (notRejected > 0)
                            rejectNotes += " " + notRejected + " item(s) could not be rejected.";
                        if (mailsFailed > 0)
                            rejectNotes += " " + mailsFailed + " rejection mail(s) could not be sent. The error is in the error log.";

                        if (rejectNotes != string.Empty)
                            MsgDisplay((result.Result == 1 ? "Agenda Finalized." : sMsg) + rejectNotes, MessageKind.Warning);
                        else
                            MsgDisplay(sMsg, (sMsg == "Agenda Finalized" || sMsg == "Agenda Finalized (no agenda items).") ? MessageKind.Success : MessageKind.Warning);

                        if (result.Result == 1)
                            ReloadAfterFinalize();      // step AF1 (R4)
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
        // Saves the rejection, then sends its mail only when the rejection was saved. Returns "Success",
        // "NotRejected" (refused: no mail), or the result of the mail ("Error..."; the item stays rejected).
        private string RejectAgenda(int AgendaId, DataTable dtAgenda, int CurrentRow)
        {
            // The item as saved now, not the list loaded with the page: the rejection keeps its Short Text and
            // Proposed Resolution (step N4; the procedure writes both). An item that is gone is not rejected.
            DataTable dtItem = AgendaMgr.GetAgendaByAgendaId(AgendaId);
            if (dtItem.Rows.Count == 0)
                return "NotRejected";

            AgendaBAL agendaBal = new AgendaBAL();

            agendaBal.AgendaId = AgendaId;
            agendaBal.ShortText = dtItem.Rows[0]["ShortText"].ToString();
            agendaBal.ProposedResolution = dtItem.Rows[0]["ProposedResolution"].ToString();
            agendaBal.MgrComments = "";
            agendaBal.ControllerComments = "Agenda rejected by Controller on agenda finalized.";
            agendaBal.MgrApprovedStatus = "";
            agendaBal.ControllerApprovedStatus = "";

            agendaBal.ControllerApprovedStatus = "Rejected";

            agendaBal.UpdatedBy = Convert.ToInt16(Session["UserId"].ToString());

            if (AgendaMgr.UpdateAgendaByAgendaId(agendaBal).Result != 1)
                return "NotRejected";

            // Step ML2b: dtItem (read before the save) gives the comment row its earlier who and when if unchanged
            return GenerateMail("rejected by Controller on agenda finalized", "ACR", dtAgenda, CurrentRow, dtItem.Rows[0]);
        }
        #endregion

        #region GenerateMail
        // Step ML2b: the item is read again after the rejection for the details (Meeting Date dd-MMM-yyyy, Subject No
        // only when it has a value) and the Controller's comment row (AgendaMail.DecisionCommentRow, with Before,
        // the item read before the save). If that read fails, the mail still goes out from the page's list row,
        // without the comment row, and the error is logged; the rejection is saved either way.
        private string GenerateMail(string AgendaStatus, string MailCode, DataTable dtAgenda, int CurrentRow, DataRow Before)
        {
            try
            {
                string ToMailId = string.Empty;
                string Bcc = string.Empty;
                int AgendaId = int.Parse(dtAgenda.Rows[CurrentRow]["AgendaId"].ToString());
                int UserId = int.Parse(Session["UserId"].ToString());

                UserBAL userBal = UserMgr.GetUserByUserId(UserId);
                ToMailId = userBal.EmailId.ToString();

                Bcc = AlertMgr.GetAlertMailId(MailCode, UserId, AgendaId);

                // Step ML2c: the item as saved now, or null (logged as before; the mail then goes without the comment row)
                DataRow itemAfter = AgendaMail.ReadItemAfterSave(AgendaId, className, "the rejection");

                DataRow listRow = dtAgenda.Rows[CurrentRow];

                string Subject = "Agenda (" + listRow["AgendaNo"].ToString() + ") has been " + AgendaStatus.ToString();
                string BodyText = string.Empty;
                BodyText += "<table>";
                if (itemAfter != null)
                {
                    BodyText += AgendaMail.DetailRows(itemAfter);
                    BodyText += AgendaMail.DecisionCommentRow("controller", Before, itemAfter);
                }
                else
                    BodyText += AgendaMail.DetailRows(listRow["AgendaNo"].ToString(),
                        listRow.Table.Columns.Contains("SubjectNo") ? listRow["SubjectNo"].ToString() : string.Empty,
                        listRow["CommitteeName"].ToString(), listRow["MeetingNo"].ToString(), listRow["MeetingDate"],
                        listRow["DepartmentName"].ToString(), listRow["SubjectTypeName"].ToString(), listRow["ShortText"].ToString());
                BodyText += "</table>";

                return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);
            }
            catch (Exception ex)
            {
                // The rejection is already saved: log, and let the page say the mail was not sent
                Utilities.WriteErrorLog(className, "GenerateMail", ex.ToString());
                return "Error";
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
