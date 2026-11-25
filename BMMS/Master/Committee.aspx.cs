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
    public partial class Committee : System.Web.UI.Page
    {
        private string className = "Committee";

        // Step IU1: the messages of the Meeting page
        private const string MailNotSentMessage = "The committee was saved, but the mail could not be sent. The error is in the error log.";
        private const string NoRecipientsMessage = "The committee was saved. No mail was sent because there were no recipients.";
        private const string NoRecipientsResult = "NoRecipients";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadCommittee();
                LoadStatus();
            }
        }


        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return CommitteeValidation()");
            txtCommitteeCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtCommitteeName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtCommitteeName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtColor.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtColor.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtIncorporationDate.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtIncorporationDate.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlStatus.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadStatus
        private void LoadStatus()
        {
            try
            {
                DataTable dtStatus = new DataTable();
                dtStatus = SysCodeMgr.GetSysCodeSetting("Status");

                Common.LoadDropdownlist(ddlStatus, dtStatus, "DisplayName", "SubCode", false);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindGridView", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region LoadCommittee
        private void LoadCommittee()
        {
            pnlViewCommittee.Visible = true;
            pnlEditCommittee.Visible = false;

            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(-1);

                ViewState["dtCommittee"] = dtCommittee;
                BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "BindGridView", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            grvCommittee.DataSource = (DataTable)ViewState["dtCommittee"];
            grvCommittee.DataBind();
        }
        #endregion

        #region grvCommittee_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvCommittee_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvCommittee_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtCommittee"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtCommittee"]);

                BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region btnAdd_Click
        protected void btnAdd_Click(object sender, EventArgs e)
        {
            MsgHide();
            ClearText();
            hdnCommitteeId.Value = "0";
            pnlViewCommittee.Visible = false;
            pnlEditCommittee.Visible = true;
            txtCommitteeCode.Text = CommitteeMgr.GetNextCommitteeCode();
            ScriptManager.GetCurrent(this).SetFocus(txtCommitteeName.ClientID);
            chkBoard.Checked = false;
            txtCessationDate.Enabled = false;
            imgCessationDate.Enabled = false;
            imgIncorporationDate.Enabled = true;
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                CommitteeMgr myCommitteeMgr = new CommitteeMgr();
                CommitteeBAL myCommittee = new CommitteeBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myCommittee.Code = "Save";
                    if (btnSave.Text == "Update")
                        myCommittee.Code = "Update";

                    myCommittee.CommitteeId = Convert.ToInt16(hdnCommitteeId.Value);
                    myCommittee.CommitteeCode = txtCommitteeCode.Text.Trim();
                    myCommittee.CommitteeName = txtCommitteeName.Text.Trim();
                    if (chkBoard.Checked)
                        myCommittee.Board = 1;
                    else
                        myCommittee.Board = 0;
                    myCommittee.IncorporationDate = Convert.ToDateTime(txtIncorporationDate.Text.Trim());
                    myCommittee.MeetingStartNo = int.Parse(txtMeetingStartNo.Text.Trim());
                    myCommittee.CommitteeColorCode = txtColor.Value.Trim();

                    if (txtCessationDate.Text.Trim() != string.Empty)
                        myCommittee.CessationDate = Convert.ToDateTime(txtCessationDate.Text.Trim()).ToString("dd-MMM-yyyy");
                    else
                        myCommittee.CessationDate = "";
                    myCommittee.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myCommittee.CreatedOn = System.DateTime.Now;
                    myCommittee.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myCommittee.UpdatedOn = System.DateTime.Now;
                    myCommittee.UpdatedBy = int.Parse(Session["UserId"].ToString());


                    // Step IU1: save first; the "Committee Created / Updated" mail goes out only after the save, as on the
                    // Meeting page. A save error goes to the error page as before (nothing is mailed then).
                    int result = myCommitteeMgr.AddEditCommittee(myCommittee);

                    string strResult = "Success";

                    if (btnSave.Text == "Save")
                        strResult = GenerateMail("Created");
                    else if (btnSave.Text == "Update")
                        strResult = GenerateMail("Updated");

                    // The committee is saved either way; the mail error itself is in the error log
                    sMsg = strResult == "Success" ? "Successfully Saved"
                         : strResult == NoRecipientsResult ? NoRecipientsMessage
                         : MailNotSentMessage;
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnSave_Click", ex);
                }
                finally
                {
                    myCommitteeMgr = null;
                    myCommittee = null;
                }

                MsgDisplay(sMsg, (sMsg == "Successfully Saved" || sMsg == NoRecipientsMessage) ? MessageKind.Success : MessageKind.Warning);

                pnlViewCommittee.Visible = true;
                pnlEditCommittee.Visible = false;
                LoadCommittee();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtCommittee = (DataTable)ViewState["dtCommittee"];

            DataView dv = new DataView(dtCommittee);

            dtCommittee.CaseSensitive = false;

            if (btnSave.Text == "Save")
                dv.RowFilter = " CommitteeName = '" + txtCommitteeName.Text.Trim().ToLower().Replace("'", "''") + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " CommitteeName = '" + txtCommitteeName.Text.Trim().ToLower().Replace("'", "''") + "' and CommitteeId <> " + hdnCommitteeId.Value;


            DataTable dtFilter = dv.ToTable("dtCommittee");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Committee Name not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtCommitteeName.ClientID);
                return false;
            }

            if (txtIncorporationDate.Text.Trim() == string.Empty)
            {
                MsgDisplay("Incorporation Date is required.");
                ScriptManager.GetCurrent(this).SetFocus(txtIncorporationDate.ClientID);
                return false;
            }

            if (int.Parse(txtMeetingStartNo.Text.Trim()) <= 0)
            {
                MsgDisplay("Meeting starting no must be greater then zero.");
                ScriptManager.GetCurrent(this).SetFocus(txtMeetingStartNo.ClientID);
                return false;
            }


            return true;
        }
        #endregion

        #region GenerateMail
        // Step IU1: "Success", NoRecipientsResult (nothing sent), or an error: Mail_Mgr logs its own failures; anything
        // else here is logged once below. The rule of the Meeting mail (BMMS-Fix-InactiveUsers-Step55.sql).
        private string GenerateMail(string SubjectStatus)
        {
            try
            {
                string ToMailId = MailToActingUser();

                // The Bcc is the users the CC / CU alert rows were written for (active, not the system account, not the
                // Admin role, not the person who saved), with an address
                int reason;
                string Bcc = AlertMgr.GetMeetingCommitteeMailId(int.Parse(Session["UserId"].ToString()), out reason);

                if (reason != 0)
                {
                    Utilities.WriteErrorLog(className, "GenerateMail", "spr_GetMeetingCommitteeMailId refused the acting user: Reason " + reason);
                    return "Error";
                }

                if (Bcc.Trim() == string.Empty)
                    return NoRecipientsResult;

                string Subject = "Committee (" + txtCommitteeCode.Text.Trim() + ") has been " + SubjectStatus;
                string BodyText = string.Empty;
                BodyText += "<table>";

                BodyText += "<tr>";
                BodyText += "<td style='text-align:left; font-weight:bold;'>";
                BodyText += "Committee Code <br /><br />";
                BodyText += "Committee Name <br /><br />";
                BodyText += "Is Board <br /><br />";
                BodyText += "Incorporation Date <br /><br />";
                BodyText += "</td>";

                BodyText += "<td style='text-align:left; font-weight:normal;'>";
                BodyText += ": " + HttpUtility.HtmlEncode(txtCommitteeCode.Text.Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(txtCommitteeName.Text.Trim()) + "<br /><br />";
                if (chkBoard.Checked)
                    BodyText += ": Yes<br /><br />";
                else
                    BodyText += ": No<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(txtIncorporationDate.Text.Trim()) + "<br /><br />";
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "</table>";


                string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);

                return result;
            }
            catch (Exception ex)
            {
                // The committee is already saved: log, and let the page say the mail was not sent
                Utilities.WriteErrorLog(className, "GenerateMail", ex.ToString());
                return "Error";
            }
        }
        #endregion

        #region MailToActingUser
        // The To of the Committee mail: the address of the person who saved (an active user other than the system
        // account; empty otherwise), as on the Meeting page
        private string MailToActingUser()
        {
            DataTable dtUser = UserMgr.GetActiveUserList();   // active users only (stage 2a)

            foreach (DataRow row in dtUser.Rows)
                if (row["UserId"].ToString() == Session["UserId"].ToString())
                    return row["EmailId"].ToString();

            return string.Empty;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewCommittee.Visible = true;
            pnlEditCommittee.Visible = false;
        }
        #endregion

        #region grvCommittee_RowCommand
        protected void grvCommittee_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int CommitteeId = Convert.ToInt32(e.CommandArgument);

                    pnlViewCommittee.Visible = false;
                    pnlEditCommittee.Visible = true;

                    CommitteeBAL myCommittee = new CommitteeBAL();
                    myCommittee = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);

                    hdnCommitteeId.Value = myCommittee.CommitteeId.ToString();
                    txtCommitteeCode.Text = myCommittee.CommitteeCode;
                    txtCommitteeName.Text = myCommittee.CommitteeName;
                    if (myCommittee.Board == 1)
                        chkBoard.Checked = true;
                    else
                        chkBoard.Checked = false;
                    txtIncorporationDate.Text = myCommittee.IncorporationDate == DateTime.MinValue ? string.Empty : myCommittee.IncorporationDate.ToString("dd-MMM-yyyy");
                    txtMeetingStartNo.Text = myCommittee.MeetingStartNo.ToString();

                    DataTable dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);
                    if (dtMeeting.Rows.Count > 0)
                        txtMeetingStartNo.Enabled = false;
                    else
                        txtMeetingStartNo.Enabled = true;

                    txtColor.Value = myCommittee.CommitteeColorCode;
                    txtColor.Attributes.Add("style", "width:80px; background-color:" + myCommittee.CommitteeColorCode + "; text-align:center;");

                    txtCessationDate.Enabled = true;
                    imgCessationDate.Enabled = true;
                    txtCessationDate.Text = myCommittee.CessationDate.ToString();
                    ddlStatus.Enabled = false;
                    ddlStatus.Text = myCommittee.StatusId.ToString();

                    ScriptManager.GetCurrent(this).SetFocus(txtCommitteeName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int CommitteeId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        CommitteeBAL commBal = CommitteeMgr.GetCommitteeByCommitteeId(CommitteeId);

                        if (commBal.IsDelete == 1)
                        {
                            MsgDisplay(Common.GetAppSetting("data.notDelete"));
                        }
                        else
                        {
                            int Result = CommitteeMgr.DeleteCommitteeByCommitteeId(CommitteeId);

                            if (Result == 1)
                                MsgDisplay(Common.GetAppSetting("delete_msg"), MessageKind.Success);
                            else
                                MsgDisplay(Common.GetAppSetting("delete_reference"));
                        }
                    }
                    catch (Exception ex)
                    {
                        MsgDisplay(Common.GetAppSetting("delete_reference"));
                    }

                    LoadCommittee();
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvBranchDetails_RowCommand", ex);
            }
        }
        #endregion

        #region ClearText
        private void ClearText()
        {
            txtCommitteeCode.Text = string.Empty;
            txtCommitteeName.Text = string.Empty;
            chkBoard.Checked = false;
            txtIncorporationDate.Text = string.Empty;
            txtMeetingStartNo.Text = "1";
            txtColor.Value = "#FFFFFF";
            txtColor.Attributes.Add("style", "width:80px; background-color:#FFFFFF; text-align:center;");
            txtCessationDate.Text = string.Empty;
            ddlStatus.Text = "1";
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
