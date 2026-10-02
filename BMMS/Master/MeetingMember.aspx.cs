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
    public partial class MeetingMember : System.Web.UI.Page
    {
        private string className = "MeetingMember";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDDLlist();
                LoadStatus();
                pnlEditMeetingMember.Visible = false;
                LoadCommittee();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnAdd.Attributes.Add("onclick", "return MeetingMemberValidation()");
            btnSave.Attributes.Add("onclick", "return MeetingMemberEditValidation()");
            ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
         
        }
        #endregion

        #region LoadDDLlist
        private void LoadDDLlist()
        {
            try
            {
                DataTable dtMemberType = MemberTypeMgr.GetMemberTypeList(1);

                DataView dv = new DataView(dtMemberType);
                dv.RowFilter = "MemberTypeId = 2 OR MemberTypeId = 3 OR MemberTypeId = 6";

                dtMemberType = dv.ToTable("dtMemberType");

                Common.LoadDropdownlist(ddlMemberType, dtMemberType, "MemberTypeName", "MemberTypeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadDDLlist", ex);
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
                int _intMeetingId = Convert.ToInt16(ddlMeeting.SelectedValue);
                DataTable dtMeetingMember = new DataTable();
                dtMeetingMember = MeetingMemberMgr.GetMeetingMemberByMeetingId(_intMeetingId);

                ViewState["DataTable"] = dtMeetingMember;
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

        #region ddlMemberName_SelectedIndexChanged
        protected void ddlMemberName_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                int MemberId = Convert.ToInt16(ddlMemberName.SelectedValue);
                hdnMemberId.Value = MemberId.ToString();
                ltrlMemberDetails.Text = Common.LoadMemberDetails(MemberId);
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

        #region LoadUnTagMember
        private void LoadUnTagMember()
        {

            try
            {
                int CommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);
                int MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue);

                DataTable dtUnTagMember = new DataTable();
                dtUnTagMember = MemberMgr.GetUnTagMemberByMeetingId(CommitteeId, MeetingId);

                ViewState["dtUnTagMember"] = dtUnTagMember;
                Common.LoadDropdownlist(ddlMemberName, dtUnTagMember, "MemberName", "MemberId", true);
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

        #region BindGridView
        private void BindGridView()
        {
            grvMeetingMember.DataSource = (DataTable)ViewState["DataTable"];
            grvMeetingMember.DataBind();
        }
        #endregion

        #region grvMeetingMember_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMeetingMember_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvMeetingMember_RowDataBound", ex);
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
            if (ddlMeeting.Text != "0")
            {
                ddlMemberName.Visible = true;
                LoadUnTagMember();

                if (ddlMemberName.Items.Count > 1)
                {

                    ClearText();
                    pnlViewMeetingMember.Visible = false;
                    pnlEditMeetingMember.Visible = true;

                    txtCommitteeName.Text = ddlCommittee.SelectedItem.ToString();
                    hdnCommitteeId.Value = ddlCommittee.SelectedValue;

                    txtMeetingNo.Text = ddlMeeting.SelectedItem.ToString();
                    hdnMeetingId.Value = ddlMeeting.SelectedValue;
                    hdnMeetingMemberId.Value = "0";

                    ddlMemberName.Text = "0";
                    ddlMemberType.Text = "0";
                    txtMemberName.Visible = false;
                    hdnMemberId.Value = "0";
                    ddlStatus.Enabled = false;
                    ScriptManager.GetCurrent(this).SetFocus(ddlMemberName.ClientID);
                    btnSave.Text = "Save";
                }
                else
                {
                    MsgDisplay("No UnTagged Members Available for this Meeting");
                }
            }
            else
            {
                MsgDisplay("Please Select Meeting No");
            }
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                MeetingMemberMgr myMeetingMemberMgr = new MeetingMemberMgr();
                MeetingMemberBAL myMeetingMember = new MeetingMemberBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myMeetingMember.Code = "Save";
                    if (btnSave.Text == "Update")
                        myMeetingMember.Code = "Update";

                    myMeetingMember.MeetingMemberId = Convert.ToInt16(hdnMeetingMemberId.Value);
                    myMeetingMember.MeetingId = Convert.ToInt16(hdnMeetingId.Value); ;
                    myMeetingMember.MemberId = Convert.ToInt16(hdnMemberId.Value);
                    myMeetingMember.MemberTypeId = Convert.ToInt16(ddlMemberType.SelectedValue.ToString());
                    myMeetingMember.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myMeetingMember.CreatedOn = System.DateTime.Now;
                    myMeetingMember.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myMeetingMember.UpdatedOn = System.DateTime.Now;
                    myMeetingMember.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myMeetingMemberMgr.AddEditMeetingMember(myMeetingMember);

                    if (result == 1)
                        sMsg = "Successfully Saved";
                    else
                        sMsg = "Record Not Saved";
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnSave_Click", ex);
                }
                finally
                {
                    myMeetingMemberMgr = null;
                    myMeetingMember = null;
                }

                MsgDisplay(sMsg);

                ltrlMemberDetails.Text = string.Empty;
                pnlViewMeetingMember.Visible = true;
                pnlEditMeetingMember.Visible = false;
                ddlMeeting_SelectedIndexChanged(this,e);
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {




            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            ltrlMemberDetails.Text = string.Empty;
            pnlViewMeetingMember.Visible = true;
            pnlEditMeetingMember.Visible = false;
            
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

                ddlMeeting_SelectedIndexChanged(this, e);
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

        #region grvMeetingMember_RowCommand
        protected void grvMeetingMember_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int MeetingMemberId = Convert.ToInt32(e.CommandArgument);

                    pnlViewMeetingMember.Visible = false;
                    pnlEditMeetingMember.Visible = true;

                    DataTable dtMeetingMember = new DataTable();
                    dtMeetingMember = MeetingMemberMgr.GetMeetingMemberByMeetingMemberId(MeetingMemberId);


                    txtCommitteeName.Text = ddlCommittee.SelectedItem.Text.ToString();
                    hdnCommitteeId.Value = ddlCommittee.SelectedValue.ToString();

                    hdnMeetingMemberId.Value = dtMeetingMember.Rows[0]["MeetingMemberId"].ToString();
                    hdnMeetingId.Value = dtMeetingMember.Rows[0]["MeetingId"].ToString();
                    txtMeetingNo.Text = dtMeetingMember.Rows[0]["MeetingNo"].ToString();
                    
                    ddlMemberName.Visible = false;
                    txtMemberName.Visible = true;
                    txtMemberName.Text = dtMeetingMember.Rows[0]["MemberName"].ToString();
                    hdnMemberId.Value = dtMeetingMember.Rows[0]["MemberId"].ToString();
                    ddlMemberType.Text = dtMeetingMember.Rows[0]["MemberTypeId"].ToString();

                    ddlStatus.Enabled = true;
                    ddlStatus.Text = dtMeetingMember.Rows[0]["StatusId"].ToString();

                    ScriptManager.GetCurrent(this).SetFocus(ddlMemberName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int MeetingMemberId = Convert.ToInt32(e.CommandArgument);
                    
                    try
                    {
                        int Result = MeetingMemberMgr.DeleteMeetingMemberByMeetingMemberId(MeetingMemberId);

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

                    int _intMeetingId = Convert.ToInt16(ddlMeeting.SelectedValue);
                    DataTable dtMeetingMember = new DataTable();
                    dtMeetingMember = MeetingMemberMgr.GetMeetingMemberByMeetingId(_intMeetingId);

                    ViewState["DataTable"] = dtMeetingMember;
                    BindGridView();
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
            txtMeetingNo.Text = string.Empty;
            ddlMemberName.Text = "0";
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
