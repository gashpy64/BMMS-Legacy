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


                    string strResult = "Success";

                    //if (btnSave.Text == "Save")
                    //    strResult = GenerateMail("Created");
                    //if (btnSave.Text == "Update")
                    //    strResult = GenerateMail("Updated");

                    if (strResult == "Success")
                    {
                        int result = myCommitteeMgr.AddEditCommittee(myCommittee);
                        sMsg = "Successfully Saved";
                    }
                    else
                    {
                        sMsg = strResult;
                    }
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

                MsgDisplay(sMsg);

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
                dv.RowFilter = " CommitteeName = '" + txtCommitteeName.Text.Trim().ToLower() + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " CommitteeName = '" + txtCommitteeName.Text.Trim().ToLower() + "' and CommitteeId <> " + hdnCommitteeId.Value;


            DataTable dtFilter = dv.ToTable("dtCommittee");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Committee Name not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtCommitteeName.ClientID);
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
        private string GenerateMail(string SubjectStatus)
        {
            string ToMailId = string.Empty;
            string Bcc = string.Empty;

            DataTable dtUser = UserMgr.GetUserList();
            if (dtUser.Rows.Count > 0)
            {
                for (int i = 0; i <= dtUser.Rows.Count - 1; i++)
                {
                    if (dtUser.Rows[i]["UserId"].ToString() == Session["UserId"].ToString())
                    {
                        ToMailId = dtUser.Rows[i]["EmailId"].ToString();
                    }
                    else
                    {
                        if (i == dtUser.Rows.Count - 1)
                            Bcc += dtUser.Rows[i]["EmailId"].ToString();
                        else
                            Bcc += dtUser.Rows[i]["EmailId"].ToString() + ", ";
                    }
                }
            }


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
            BodyText += ": " + txtCommitteeCode.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtCommitteeName.Text.Trim() + "<br /><br />";
            if (chkBoard.Checked)
                BodyText += ": Yes<br /><br />";
            else
                BodyText += ": No<br /><br />";
            BodyText += ": " + txtIncorporationDate.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "</table>";


            string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);

            

            return result;
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
                    txtIncorporationDate.Text = myCommittee.IncorporationDate.ToString("dd-MMM-yyyy");
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
                            CommitteeMgr.DeleteCommitteeByCommitteeId(CommitteeId);

                            MsgDisplay(Common.GetAppSetting("delete_msg"));
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
