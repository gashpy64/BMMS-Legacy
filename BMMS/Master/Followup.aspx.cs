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
    public partial class Followup : System.Web.UI.Page
    {
        private string className = "Followup";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();

                pnlViewFollowup.Visible = false;
                pnlActualResolution.Visible = false;
                pnlActionText.Visible = false;

                txtFromDate.Text = Common.GetFinStartDate();
                txtToDate.Text = DateTime.Now.ToString("dd-MMM-yyyy");
                LoadCommittee();
                rdoMeatingNoSearch.Enabled = false;
                LoadDepartment();
                pnlMeetingNoParticular.Visible = true;
                pnlMeetingNoParticular.Enabled = true;
                pnlMeetingNoBetween.Visible = false;
                MeetingNoSearchChanged();
            }
        } 
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnViewFollowup.Attributes.Add("onclick", "return MinutesFinalizeValidation()");
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

                Common.LoadDDLwithAllNew(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
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

        #region LoadDepartment
        private void LoadDepartment()
        {
            try
            {
                DataTable dtDepartment = new DataTable();
                dtDepartment = DepartmentMgr.GetDepartmentList(1);

                Common.LoadDDLwithAllNew(ddlDepartment, dtDepartment, "DepartmentName", "DepartmentId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadDepartment", ex);
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
                pnlViewFollowup.Visible = false;

                MeetingNoSearchChanged();
                
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

        #region rdoMeatingNoSearch_SelectedIndexChanged
        protected void rdoMeatingNoSearch_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MeetingNoSearchChanged();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "rdoMeatingNoSearch_SelectedIndexChanged", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region MeetingNoSearchChanged
        private void MeetingNoSearchChanged()
        {
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());

            pnlMeetingNoParticular.Visible = true;
            pnlMeetingNoParticular.Enabled = false;
            pnlMeetingNoBetween.Visible = false;
            rdoMeatingNoSearch.Enabled = false;

            if (CommitteeId > 0)
            {
                rdoMeatingNoSearch.Enabled = true;

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByCommitteeId(CommitteeId);

                if (rdoMeatingNoSearch.SelectedValue == "0")  // 0 for Particular
                {
                    pnlMeetingNoParticular.Enabled = true;

                    Common.LoadDDLwithAllNew(ddlMeetingNo, dtMeeting, "MeetingNo", "MeetingId", true);

                    if (dtMeeting.Rows.Count > 0)
                        ddlMeetingNo.SelectedIndex = 0;
                }
                if (rdoMeatingNoSearch.SelectedValue == "1")  // 0 for Between
                {
                    pnlMeetingNoParticular.Visible = false;
                    pnlMeetingNoParticular.Enabled = false;
                    pnlMeetingNoBetween.Visible = true;

                    Common.LoadDropdownlist(ddlMeetingNoFrom, dtMeeting, "MeetingNo", "MeetingId", false);
                    Common.LoadDropdownlist(ddlMeetingNoTo, dtMeeting, "MeetingNo", "MeetingId", false);

                    if (dtMeeting.Rows.Count > 0)
                    {
                        ddlMeetingNoFrom.SelectedIndex = 0;
                        ddlMeetingNoTo.SelectedIndex = ddlMeetingNoTo.Items.Count - 1;
                    }
                }
            }
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            Response.Redirect("~/Master/Followup.aspx");
        }
        #endregion

        #region btnViewFollowup_Click
        protected void btnViewFollowup_Click(object sender, EventArgs e)
        {
            MsgHide();
            string sMsg = string.Empty;
            try
            {
                DataTable dtFollowup = new DataTable();
                dtFollowup = GetFollowup();

                grvFollowup.DataSource = dtFollowup;
                grvFollowup.DataBind();

            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnViewFollowup_Click", ex);
            }

        }
        #endregion


        #region GetFollowup
        private DataTable GetFollowup()
        {
            pnlViewFollowup.Visible = true;

            DateTime FromMeetingDate = Convert.ToDateTime(txtFromDate.Text.Trim());
            DateTime ToMeetingDate = Convert.ToDateTime(txtToDate.Text.Trim());
            int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString().Trim());
            int MeetingNoSearch = int.Parse(rdoMeatingNoSearch.SelectedValue.ToString().Trim());

            int MeetingId = 0;
            int FromMeetingId = 0;
            int ToMeetingId = 0;

            if (CommitteeId > 0)
            {
                if (MeetingNoSearch == 0)
                    MeetingId = int.Parse(ddlMeetingNo.SelectedValue.ToString().Trim());

                if (MeetingNoSearch == 1)
                {
                    FromMeetingId = int.Parse(ddlMeetingNoFrom.SelectedValue.ToString().Trim());
                    ToMeetingId = int.Parse(ddlMeetingNoTo.SelectedValue.ToString().Trim());
                }
            }

            int DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString().Trim());
            int ConfirmStatus = int.Parse(rdoConfirmStatus.SelectedValue.ToString().Trim());

            DataTable dtFollowup = ReportsMgr.GetFollowupReport(FromMeetingDate, ToMeetingDate, CommitteeId,
                MeetingNoSearch, MeetingId, FromMeetingId, ToMeetingId, DepartmentId, ConfirmStatus);

            ViewState["GetFollowup"] = dtFollowup;

            return dtFollowup;
        } 
        #endregion





        #region grvFollowup_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvFollowup_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    //e.Row.Attributes.Add("onmouseover", "MouseEvents(this, event)");
                    //e.Row.Attributes.Add("onmouseout", "MouseEvents(this, event)");

                    Label lblIsConfirmed = (Label)e.Row.FindControl("lblIsConfirmed");

                    CheckBox chkIsConfirmed = (CheckBox)e.Row.FindControl("chkIsConfirmed");

                    if (lblIsConfirmed.Text.Trim() == "1")
                        chkIsConfirmed.Checked = true;
                    else
                        chkIsConfirmed.Checked = false;
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowDataBound", ex);
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

        #region grvFollowup_RowCommand
        protected void grvFollowup_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                MsgHide();

                int ActionItemId = int.Parse(e.CommandArgument.ToString());

                ViewState["ActionItemId"] = ActionItemId.ToString();

                DataTable dtActionItem = new DataTable();
                dtActionItem = ActionItemMgr.GetActionItemByActionItemId(ActionItemId);

                if (e.CommandName == "ViewActualResolution")
                {
                    pnlActualResolution.Visible = true;
                    ftxtActualResolution.Text = dtActionItem.Rows[0]["ActualResolution"].ToString();
                }

                if (e.CommandName == "ViewActionText")
                {
                    pnlActionText.Visible = true;
                    ftxtActionText.Text = dtActionItem.Rows[0]["ActionText"].ToString();
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvFollowup_RowCommand", ex);
            }
        }
        #endregion

        #region btnActualResolutionCancel_Click
        protected void btnActualResolutionCancel_Click(object sender, EventArgs e)
        {
            pnlActualResolution.Visible = false;
        }
        #endregion

        #region btnActionTextCancel_Click
        protected void btnActionTextCancel_Click(object sender, EventArgs e)
        {
            pnlActionText.Visible = false;
        }
        #endregion

        #region btnActionTextSave_Click
        protected void btnActionTextSave_Click(object sender, EventArgs e)
        {
            string Code = "ActionText";
            int ActionItemId = Convert.ToInt16(ViewState["ActionItemId"].ToString());
            string ActualResolution = "";
            string ActionText = ftxtActionText.Text.Trim();
            int IsComplied = 0;
            int IsConfirmed = 0;

            ActionItemMgr.UpdateActionItem(Code, ActionItemId, ActualResolution, ActionText, IsComplied, IsConfirmed);


            pnlActionText.Visible = false;
        }
        #endregion


        #region btnSubmit_Click
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            MsgHide();
            string strMsg = string.Empty;

            foreach (GridViewRow gr in grvFollowup.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    string Code = "All";
                    int ActionItemId = int.Parse(((Label)gr.FindControl("lblActionItemId")).Text);
                    string ActualResolution = "";
                    string ActionText = "";

                    int IsComplied = 0;

                    CheckBox chkIsConfirmed = (CheckBox)gr.FindControl("chkIsConfirmed");

                    int IsConfirmed = 0;
                    if (chkIsConfirmed.Checked)
                        IsConfirmed = 1;

                    ActionItemMgr.UpdateActionItem(Code, ActionItemId, ActualResolution, ActionText, IsComplied, IsConfirmed);
                }
            }

            strMsg = "Successfully Saved";

            MsgDisplay(strMsg);

            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);

            //btnViewFollowup_Click(this, e);
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
