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
    public partial class Meeting : System.Web.UI.Page
    {
        private string className = "Meeting";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                pnlViewMeeting.Visible = true;
                pnlEditMeeting.Visible = false;
                LoadCommittee();

            }
        } 
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return MeetingValidation()");
            ddlCommittee.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtPlace.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtPlace.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtVenue.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtMeetingDate.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtMeetingTime.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtMeetingTime.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtAgendaSubmissionDate.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtAgendaSubmissionDate.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + btnSave.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            //txtColor.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtColor.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadCommittee
        private void LoadCommittee()
        {
            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(1);

                Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
                Common.LoadDropdownlist(ddlCommitteeSearch, dtCommittee, "CommitteeName", "CommitteeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadCommittee", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region LoadMeeting
        private void LoadMeeting()
        {
            pnlViewMeeting.Visible = true;
            pnlEditMeeting.Visible = false;

            try
            {
                int CommitteeId = int.Parse(ddlCommitteeSearch.SelectedValue);

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

                ViewState["DataTable"] = dtMeeting;
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
            grvMeeting.DataSource = (DataTable)ViewState["DataTable"];
            grvMeeting.DataBind();
        }
        #endregion

        #region grvMeeting_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMeeting_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvMeeting_RowDataBound", ex);
            }
        }
        #endregion

        #region grvMeeting_RowCommand
        protected void grvMeeting_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                int MeetingId = Convert.ToInt32(e.CommandArgument);

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

                DateTime MeetingDate = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString());

                if (MeetingDate > System.DateTime.Now)
                {

                    if (e.CommandName == "EditRec")
                    {
                        pnlViewMeeting.Visible = false;
                        pnlEditMeeting.Visible = true;
                        ddlCommittee.Enabled = false;

                        hdnMeetingId.Value = dtMeeting.Rows[0]["MeetingId"].ToString();

                        txtMeetingNo.Text = dtMeeting.Rows[0]["MeetingNo"].ToString();
                        ddlCommittee.Text = dtMeeting.Rows[0]["CommitteeId"].ToString();
                        txtPlace.Text = dtMeeting.Rows[0]["Place"].ToString();
                        txtVenue.Text = dtMeeting.Rows[0]["Venue"].ToString();
                        txtMeetingDate.Text = MeetingDate.ToString("dd-MMM-yyyy");
                        hdnMeetingDate.Value = MeetingDate.ToString("dd-MMM-yyyy");
                        txtMeetingTime.Text = dtMeeting.Rows[0]["MeetingTime"].ToString();
                        txtAgendaSubmissionDate.Text = Convert.ToDateTime(dtMeeting.Rows[0]["AgendaSubmissionDate"].ToString()).ToString("dd-MMM-yyyy");
                        //txtColor.Value = dtMeeting.Rows[0]["MeetingColorCode"].ToString();
                        //txtColor.Attributes.Add("style", "width:80px; background-color:" + dtMeeting.Rows[0]["MeetingColorCode"].ToString() + "; text-align:center;");

                        ScriptManager.GetCurrent(this).SetFocus(txtPlace.ClientID);
                        btnSave.Text = "Update";
                        MsgHide();
                    }
                    if (e.CommandName == "DeleteRec")
                    {
                        try
                        {

                            int Result = MeetingMgr.DeleteMeetingByMeetingId(MeetingId);

                            if (Result == 1)
                                MsgDisplay("Record Deleted Successfully");
                            else
                                MsgDisplay(Common.GetAppSetting("delete_reference"));
                        }
                        catch (Exception ex)
                        {
                            string _ErrMsg = Common.GetAppSetting("delete_reference");
                            MsgDisplay(_ErrMsg);
                        }

                        LoadMeeting();
                    }
                }
                else
                {
                    MsgDisplay("This meeting was closed.");
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvBranchDetails_RowCommand", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["DataTable"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["DataTable"]);

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

            int CommitteeId = int.Parse(ddlCommitteeSearch.SelectedValue);

            if (CommitteeId > 0)
            {
                DataTable dtCommitteMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(CommitteeId, 0);

                if (dtCommitteMember.Rows.Count != 0)
                {
                    pnlViewMeeting.Visible = false;
                    pnlEditMeeting.Visible = true;
                    ClearText();

                    ddlCommittee.Text = CommitteeId.ToString();
                    txtMeetingNo.Text = MeetingMgr.GetNextMeetingNo(CommitteeId);
                    ddlCommittee.Enabled = false;

                    ScriptManager.GetCurrent(this).SetFocus(txtPlace.ClientID);
                    btnSave.Text = "Save";
                }
                else
                {
                    MsgDisplay("Member not tagged for this committee.");
                }
            }
            else
            {
                string sMsg = "Committee Name is required Field";
                MsgDisplay(sMsg);
            }
        }
        #endregion

        #region ddlCommitteeSearch_SelectedIndexChanged
        protected void ddlCommitteeSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            MsgHide();
            LoadMeeting();
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                MeetingBAL myMeeting = new MeetingBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myMeeting.Code = "Save";
                    if (btnSave.Text == "Update")
                        myMeeting.Code = "Update";

                    myMeeting.MeetingId = Convert.ToInt16(hdnMeetingId.Value);
                    myMeeting.MeetingNo = txtMeetingNo.Text.Trim();
                    myMeeting.CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
                    myMeeting.Place = txtPlace.Text.Trim();
                    myMeeting.Venue = txtVenue.Text.Trim();
                    myMeeting.MeetingDate = Convert.ToDateTime(txtMeetingDate.Text.Trim());
                    myMeeting.MeetingTime = txtMeetingTime.Text.Trim();
                    myMeeting.AgendaSubmissionDate = Convert.ToDateTime(txtAgendaSubmissionDate.Text.Trim());
                    myMeeting.MeetingColorCode = ""; // txtColor.Value.Trim();

                    myMeeting.CreatedOn = System.DateTime.Now;
                    myMeeting.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myMeeting.UpdatedOn = System.DateTime.Now;
                    myMeeting.UpdatedBy = int.Parse(Session["UserId"].ToString());


                    string strResult = "Success";

                    if (btnSave.Text == "Save")
                        strResult = GenerateMail("Created");
                    if (btnSave.Text == "Update")
                        strResult = GenerateMail("Updated");

                    if (strResult == "Success")
                    {
                        int result = MeetingMgr.AddEditMeeting(myMeeting);
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
                    myMeeting = null;
                }

                MsgDisplay(sMsg);

                pnlViewMeeting.Visible = true;
                pnlEditMeeting.Visible = false;
                LoadMeeting();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            int CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
            DateTime MeetingDate = Convert.ToDateTime(txtMeetingDate.Text.Trim());
            DateTime AgendaSubmissionDate = Convert.ToDateTime(txtAgendaSubmissionDate.Text.Trim());

            int @MeetingId = Convert.ToInt16(hdnMeetingId.Value);

            DataTable dtLastMeeting = MeetingMgr.GetLastMeetingByCommitteeId(CommitteeId, MeetingId);

            if (dtLastMeeting.Rows.Count > 0)
            {
                DateTime LastMeetingDate = Convert.ToDateTime(dtLastMeeting.Rows[0]["MeetingDate"].ToString());

                if (MeetingDate <= LastMeetingDate)
                {
                    MsgDisplay("The meeting date should be greater than the previous meeting date for the same committee");
                    ScriptManager.GetCurrent(this).SetFocus(txtMeetingDate.ClientID);
                    return false;
                }
            }

            if (MeetingDate <= AgendaSubmissionDate)
            {
                MsgDisplay("Agenda Submission Date should be less than Meeting Date");
                ScriptManager.GetCurrent(this).SetFocus(txtAgendaSubmissionDate.ClientID);
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


            string Subject = "Meeting (" + txtMeetingNo.Text.Trim() + ") has been " + SubjectStatus;
            string BodyText = string.Empty;
            BodyText += "<table>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold;'>";
            BodyText += "Meeting No <br /><br />";
            BodyText += "Committee Name <br /><br />";
            BodyText += "Place <br /><br />";
            BodyText += "Venue <br /><br />";
            BodyText += "Meeting Date <br /><br />";
            BodyText += "Meeting Time <br /><br />";
            BodyText += "Agenda Submission Date <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + txtMeetingNo.Text.Trim() + "<br /><br />";
            BodyText += ": " + ddlCommittee.SelectedItem.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtPlace.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtVenue.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtMeetingDate.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtMeetingTime.Text.Trim() + "  Hrs.<br /><br />";
            BodyText += ": " + txtAgendaSubmissionDate.Text.Trim() + "<br /><br />";
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
            pnlViewMeeting.Visible = true;
            pnlEditMeeting.Visible = false;
        }
        #endregion

        #region ClearText
        private void ClearText()
        {
            hdnMeetingId.Value = "0";
            txtMeetingNo.Text = "";
            ddlCommittee.Text = "0";
            txtPlace.Text = string.Empty;
            txtVenue.Text = string.Empty;
            txtMeetingDate.Text = string.Empty;
            hdnMeetingDate.Value = string.Empty;
            txtMeetingTime.Text = string.Empty;
            txtAgendaSubmissionDate.Text = string.Empty;
            //txtColor.Value = "#FFFFFF";
            //txtColor.Attributes.Add("style", "width:80px; background-color:#FFFFFF; text-align:center;");


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
