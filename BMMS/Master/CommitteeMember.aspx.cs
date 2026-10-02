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
    public partial class CommitteeMember : System.Web.UI.Page
    {
        private string className = "CommitteeMember";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDDLlist();
                LoadCommittee();
            }
        } 
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return CommitteeMemberValidation()");
            ddlMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtAppointmentDate.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtAppointmentDate.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtApplicableFee.ClientID + "');GoToNxtTxtBox(event,'" + imgAppointmentDate.ClientID + "')");
            txtApplicableFee.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtApplicableFee.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadDDLlist
        private void LoadDDLlist()
        {
            try
            {
                DataTable dtMemberType = MemberTypeMgr.GetMemberTypeList(1);

                DataView dv = new DataView(dtMemberType);
                dv.RowFilter = "MemberTypeId <> 2 AND MemberTypeId <> 3 AND MemberTypeId <> 6";

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

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                int _intCommitteeId = Convert.ToInt16(ddlCommittee.SelectedValue);

                DataTable dtCommitteeMember = new DataTable();
                dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeId(_intCommitteeId, -1);

                ViewState["DataTable"] = dtCommitteeMember;
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

        #region LoadCommittee
        private void LoadCommittee()
        {
            pnlViewCommitteeMember.Visible = true;
            pnlEditCommitteeMember.Visible = false;

            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(1);

                ViewState["dtCommittee"] = dtCommittee;
                Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
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

        #region LoadMember
        private void LoadUnTagMemberByCommitteeId()
        {

            try
            {
                int CommitteeId = Convert.ToInt16(ddlCommittee.Text);
                DataTable dtMember = new DataTable();
                dtMember = MemberMgr.GetUnTagMemberByCommitteeId(CommitteeId);

                Common.LoadDropdownlist(ddlMemberName, dtMember, "MemberName", "MemberId", true);
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
            grvCommitteeMember.DataSource = (DataTable)ViewState["DataTable"];
            grvCommitteeMember.DataBind();
        }
        #endregion

        #region grvCommitteeMember_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvCommitteeMember_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvCommitteeMember_RowDataBound", ex);
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
            if (ddlCommittee.Text != "0")
            {
                ddlMemberName.Visible = true;
                txtMemberName.Visible = false;
                LoadUnTagMemberByCommitteeId();

                if (ddlMemberName.Items.Count > 1)
                {
                    ClearText();
                    pnlViewCommitteeMember.Visible = false;
                    pnlEditCommitteeMember.Visible = true;

                    txtCommitteeName.Text = ddlCommittee.SelectedItem.ToString();
                    hdnCommitteeId.Value = ddlCommittee.SelectedValue;
                    hdnCommitteeMemberId.Value = "0";

                    ddlMemberName.Text = "0";
                    ddlMemberType.Text = "0";
                    rdoIsFeeApplicable.Text = "0";
                    txtApplicableFee.Enabled = false;
                    ScriptManager.GetCurrent(this).SetFocus(ddlMemberName.ClientID);
                    txtCessationDate.Enabled = false;
                    pnlCessationDate.Enabled = false;
                    btnSave.Text = "Save";
                }
                else
                {
                    MsgDisplay("No UnTagged Members Available for this Committee");
                }
            }
            else
            {
                MsgDisplay("Please Select Committee Name");
            }
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                CommitteeMemberMgr myCommitteeMemberMgr = new CommitteeMemberMgr();
                CommitteeMemberBAL myCommitteeMember = new CommitteeMemberBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myCommitteeMember.Code = "Save";
                    if (btnSave.Text == "Update")
                        myCommitteeMember.Code = "Update";

                    myCommitteeMember.CommitteeMemberId = Convert.ToInt16(hdnCommitteeMemberId.Value);
                    myCommitteeMember.CommitteeId = Convert.ToInt16(hdnCommitteeId.Value); ;
                    myCommitteeMember.MemberId = Convert.ToInt16(hdnMemberId.Value.ToString());
                    myCommitteeMember.MemberTypeId = Convert.ToInt16(ddlMemberType.SelectedValue.ToString());
                    myCommitteeMember.AppointmentDate = Convert.ToDateTime(txtAppointmentDate.Text.Trim());
                    if (txtCessationDate.Text.Trim() != string.Empty)
                        myCommitteeMember.CessationDate = Convert.ToDateTime(txtCessationDate.Text.Trim()).ToString("dd-MMM-yyyy");
                    else
                        myCommitteeMember.CessationDate = "";
                    myCommitteeMember.IsFeeApplicable = Convert.ToInt16(rdoIsFeeApplicable.SelectedValue);
                    if (rdoIsFeeApplicable.SelectedValue == "0" || txtApplicableFee.Text.Trim() == string.Empty)
                        myCommitteeMember.ApplicableFee = 0;
                    else
                        myCommitteeMember.ApplicableFee = Convert.ToDecimal(txtApplicableFee.Text.Trim());
                    myCommitteeMember.CreatedOn = System.DateTime.Now;
                    myCommitteeMember.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myCommitteeMember.UpdatedOn = System.DateTime.Now;
                    myCommitteeMember.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myCommitteeMemberMgr.AddEditCommitteeMember(myCommitteeMember);

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
                    myCommitteeMemberMgr = null;
                    myCommitteeMember = null;
                }

                MsgDisplay(sMsg);

                ltrlMemberDetails.Text = string.Empty;
                pnlViewCommitteeMember.Visible = true;
                pnlEditCommitteeMember.Visible = false;

                ddlCommittee_SelectedIndexChanged(this, e);
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            if (txtAppointmentDate.Text != string.Empty)
            {
                DateTime AppointmentDate = Convert.ToDateTime(txtAppointmentDate.Text.Trim());

                CommitteeBAL committeeBal = new CommitteeBAL();
                committeeBal = CommitteeMgr.GetCommitteeByCommitteeId(int.Parse(ddlCommittee.SelectedValue));

                DateTime CommitteeIncorporationDate = Convert.ToDateTime(committeeBal.IncorporationDate.ToString("dd-MMM-yyyy"));

                if (CommitteeIncorporationDate > AppointmentDate)
                {
                    MsgDisplay("Appointment Date should be greater than Committee Incorporation Date");
                    ScriptManager.GetCurrent(this).SetFocus(txtCommitteeName.ClientID);
                    return false;
                }
            }



            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            ltrlMemberDetails.Text = string.Empty;
            pnlViewCommitteeMember.Visible = true;
            pnlEditCommitteeMember.Visible = false;
            MsgHide();
        }
        #endregion

        #region grvCommitteeMember_RowCommand
        protected void grvCommitteeMember_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int CommitteeMemberId = Convert.ToInt32(e.CommandArgument);

                    pnlViewCommitteeMember.Visible = false;
                    pnlEditCommitteeMember.Visible = true;

                    DataTable dtCommitteeMember = CommitteeMemberMgr.GetCommitteeMemberByCommitteeMemberId(CommitteeMemberId);

                    hdnCommitteeMemberId.Value = dtCommitteeMember.Rows[0]["CommitteeMemberId"].ToString();
                    hdnCommitteeId.Value = dtCommitteeMember.Rows[0]["CommitteeId"].ToString();
                    txtCommitteeName.Text = dtCommitteeMember.Rows[0]["CommitteeName"].ToString();
                    ddlMemberName.Visible = false;
                    txtMemberName.Visible = true;
                    txtMemberName.Text = dtCommitteeMember.Rows[0]["MemberName"].ToString();
                    hdnMemberId.Value = dtCommitteeMember.Rows[0]["MemberId"].ToString();
                    ddlMemberType.Text = dtCommitteeMember.Rows[0]["MemberTypeId"].ToString();
                    txtAppointmentDate.Text = Convert.ToDateTime(dtCommitteeMember.Rows[0]["AppointmentDate"].ToString()).ToString("dd-MMM-yyyy");
                    txtCessationDate.Enabled = true;
                    pnlCessationDate.Enabled = true;
                    txtCessationDate.Text = dtCommitteeMember.Rows[0]["CessationDate"].ToString();
                    rdoIsFeeApplicable.Text = dtCommitteeMember.Rows[0]["IsFeeApplicable"].ToString();
                    txtApplicableFee.Text = dtCommitteeMember.Rows[0]["ApplicableFee"].ToString();

                    ScriptManager.GetCurrent(this).SetFocus(ddlMemberName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int CommitteeMemberId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        CommitteeMemberMgr.DeleteCommitteeMemberByCommitteeMemberId(CommitteeMemberId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }

                    ddlCommittee_SelectedIndexChanged(this, e);
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
            txtCommitteeName.Text = string.Empty;
            txtAppointmentDate.Text = string.Empty;
            txtCessationDate.Text = string.Empty;
            rdoIsFeeApplicable.Text = null;
            txtApplicableFee.Text = string.Empty;
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

        #region rdoIsFeeApplicable_SelectedIndexChanged
        protected void rdoIsFeeApplicable_SelectedIndexChanged(object sender, EventArgs e)
        {
            txtApplicableFee.Text = "0";
            if (rdoIsFeeApplicable.Text == "0")
                txtApplicableFee.Enabled = false;
            if (rdoIsFeeApplicable.Text == "1")
                txtApplicableFee.Enabled = true;

        }
        #endregion

    }
}
