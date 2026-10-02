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
    public partial class Member : System.Web.UI.Page
    {
        private string className = "Member";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadMember();
            }
        } 
        #endregion


        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return MemberValidation()");
            txtMemberName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlSex.ClientID + "');GoToNxtTxtBox(event,'" + ddlSex.ClientID + "')");
            ddlSex.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlDesignation.ClientID + "');GoToNxtTxtBox(event,'" + ddlDesignation.ClientID + "')");
            ddlDesignation.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtAddress1.ClientID + "');GoToNxtTxtBox(event,'" + txtAddress1.ClientID + "')");
            txtAddress1.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtAddress2.ClientID + "');GoToNxtTxtBox(event,'" + txtAddress2.ClientID + "')");
            txtAddress2.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtAddress3.ClientID + "');GoToNxtTxtBox(event,'" + txtAddress3.ClientID + "')");
            txtAddress3.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtCityName.ClientID + "');GoToNxtTxtBox(event,'" + txtCityName.ClientID + "')");
            txtCityName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlState.ClientID + "');GoToNxtTxtBox(event,'" + ddlState.ClientID + "')");
            ddlState.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtPinCode.ClientID + "');GoToNxtTxtBox(event,'" + txtPinCode.ClientID + "')");
            txtPinCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtDinNo.ClientID + "');GoToNxtTxtBox(event,'" + txtDinNo.ClientID + "')");
            txtEmailId.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtEmailId.ClientID + "');GoToNxtTxtBox(event,'" + txtEmailId.ClientID + "')");
            txtDinNo.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtPhotoPath.ClientID + "');GoToNxtTxtBox(event,'" + txtPhotoPath.ClientID + "')");
            txtPhotoPath.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtResumePath.ClientID + "');GoToNxtTxtBox(event,'" + txtResumePath.ClientID + "')");
            txtResumePath.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + ddlStatus.ClientID + "')");
            ddlStatus.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadDDLlist
        private void LoadDDLlist()
        {
            try
            {
                DataTable dtState = new DataTable();
                dtState = Utilities.GetStateMaster();

                DataTable dtStatus = new DataTable();
                dtStatus = SysCodeMgr.GetSysCodeSetting("Status");

                DataTable dtSex = new DataTable();
                dtSex = SysCodeMgr.GetSysCodeSetting("Sex");

                DataTable dtDesignation = DesignationMgr.GetDesignationList(1);
                DataTable dtRole = RoleMgr.GetRoleList();

                Common.LoadDropdownlist(ddlDesignation, dtDesignation, "DesignationName", "DesignationId", true);
                Common.LoadDropdownlist(ddlSex, dtSex, "DisplayName", "SysCodeId", true);
                Common.LoadDropdownlist(ddlStatus, dtStatus, "DisplayName", "SubCode", false);
                Common.LoadDropdownlist(ddlState, dtState, "State_Name", "State_Id", true);
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

        #region LoadMember
        private void LoadMember()
        {
            pnlViewMember.Visible = true;
            pnlEditMember.Visible = false;

            try
            {
                DataTable dtMember = new DataTable();
                dtMember = MemberMgr.GetMemberList(-1);

                ViewState["DataTable"] = dtMember;
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
            grvMember.DataSource = (DataTable)ViewState["DataTable"];
            grvMember.DataBind();
        }
        #endregion

        #region grvMember_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMember_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvMember_RowDataBound", ex);
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
            LoadDDLlist();
            ClearText();
            hdnMemberId.Value = "0";
            pnlViewMember.Visible = false;
            pnlEditMember.Visible = true;
            txtMemberCode.Text = MemberMgr.GetNextMemberCode();
            ddlStatus.Enabled = false;
            ScriptManager.GetCurrent(this).SetFocus(txtMemberName.ClientID);
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                MemberMgr myMemberMgr = new MemberMgr();
                MemberBAL myMember = new MemberBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myMember.Code = "Save";
                    if (btnSave.Text == "Update")
                        myMember.Code = "Update";

                    myMember.MemberId = Convert.ToInt16(hdnMemberId.Value);
                    myMember.MemberCode = txtMemberCode.Text.Trim();
                    myMember.MemberName = txtMemberName.Text.Trim();
                    myMember.DesignationId = Convert.ToInt16(ddlDesignation.SelectedValue);
                    myMember.SexId = Convert.ToInt16(ddlSex.SelectedValue);
                    myMember.DOB = txtDOB.Text.Trim();
                    myMember.Address1 = txtAddress1.Text.Trim();
                    myMember.Address2 = txtAddress2.Text.Trim();
                    myMember.Address3 = txtAddress3.Text.Trim();
                    myMember.CityName = txtCityName.Text.Trim();
                    myMember.State_Id = Convert.ToInt16(ddlState.SelectedValue.Trim());
                    myMember.PinCode = txtPinCode.Text.Trim();
                    myMember.DOJ = txtDOJ.Text.Trim();
                    myMember.EmailId = txtEmailId.Text.Trim();
                    myMember.DinNo = txtDinNo.Text.Trim();

                    if (txtPhotoPath.Text.Trim() == string.Empty)
                        txtPhotoPath.Text = "~/Files/MemberPhoto/MalePhoto.png";
                    if (fileUploadPhotoPath.HasFile)
                    {
                        string fName = string.Empty;
                        string fNameWithPath = string.Empty;

                        fName = "~/Files/MemberPhoto/" + txtMemberCode.Text + "-Photo.jpg";
                        fNameWithPath = MapPath(fName);

                        fileUploadPhotoPath.SaveAs(fNameWithPath);

                        txtPhotoPath.Text = fName;
                    }
                    myMember.PhotoPath = txtPhotoPath.Text.Trim();

                    if (fileUploadReasumePath.HasFile)
                    {
                        string fName = string.Empty;
                        string fNameWithPath = string.Empty;

                        fName = "~/Files/MemberResume/" + txtMemberCode.Text + "-Resume.Doc";
                        fNameWithPath = MapPath(fName);

                        fileUploadReasumePath.SaveAs(fNameWithPath);

                        txtResumePath.Text = fName;
                    }
                    myMember.ResumePath = txtResumePath.Text.Trim();

                    myMember.RelievingDate = txtRelievingDate.Text.Trim();
                    myMember.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myMember.CreatedOn = System.DateTime.Now;
                    myMember.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myMember.UpdatedOn = System.DateTime.Now;
                    myMember.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myMemberMgr.AddEditMember(myMember);

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
                    myMemberMgr = null;
                    myMember = null;
                }

                MsgDisplay(sMsg);

                pnlViewMember.Visible = true;
                pnlEditMember.Visible = false;
                LoadMember();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            if (txtDOB.Text != string.Empty && txtDOJ.Text != string.Empty)
            {
                DateTime dob = Convert.ToDateTime(txtDOB.Text.Trim());
                DateTime doj = Convert.ToDateTime(txtDOJ.Text.Trim());

                if (dob >= System.DateTime.Now)
                {
                    MsgDisplay("Date of Birth should not be greater than current date");
                    ScriptManager.GetCurrent(this).SetFocus(imgDOB.ClientID);
                    return false;
                }
                else if (doj > System.DateTime.Now)
                {
                    MsgDisplay("Date of Join should not be greater than current date");
                    ScriptManager.GetCurrent(this).SetFocus(imgDOJ.ClientID);
                    return false;
                }
                else if (doj <= dob)
                {
                    MsgDisplay("Date of Join should be greater than Date of Birth");
                    ScriptManager.GetCurrent(this).SetFocus(imgDOJ.ClientID);
                    return false;
                }
            }

            if (txtDOJ.Text != string.Empty && txtRelievingDate.Text != string.Empty)
            {
                DateTime doj = Convert.ToDateTime(txtDOJ.Text.Trim());
                DateTime dor = Convert.ToDateTime(txtRelievingDate.Text.Trim());

                if (dor <= doj)
                {
                    MsgDisplay("Date of Relieving should be greater than Date of Join");
                    ScriptManager.GetCurrent(this).SetFocus(imgRelievingDate.ClientID);
                    return false;
                }
            }

            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewMember.Visible = true;
            pnlEditMember.Visible = false;
        }
        #endregion

        #region grvMember_RowCommand
        protected void grvMember_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int MemberId = Convert.ToInt32(e.CommandArgument);

                    pnlViewMember.Visible = false;
                    pnlEditMember.Visible = true;
                    LoadDDLlist();
                    MemberBAL myMember = new MemberBAL();
                    myMember = MemberMgr.GetMemberByMemberId(MemberId);

                    hdnMemberId.Value = myMember.MemberId.ToString();
                    txtMemberCode.Text = myMember.MemberCode;
                    txtMemberName.Text = myMember.MemberName;
                    ddlSex.Text = myMember.SexId.ToString();
                    ddlDesignation.Text = myMember.DesignationId.ToString();
                    txtDOB.Text = myMember.DOB;
                    txtAddress1.Text = myMember.Address1;
                    txtAddress2.Text = myMember.Address2;
                    txtAddress3.Text = myMember.Address3;
                    txtCityName.Text = myMember.CityName;
                    ddlState.Text = myMember.State_Id.ToString();
                    txtPinCode.Text = myMember.PinCode;
                    txtDOJ.Text = myMember.DOJ;
                    txtEmailId.Text = myMember.EmailId;
                    txtDinNo.Text = myMember.DinNo;
                    txtPhotoPath.Text = myMember.PhotoPath;
                    txtResumePath.Text = myMember.ResumePath;
                    txtRelievingDate.Text = myMember.RelievingDate;
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myMember.StatusId.ToString();

                    ScriptManager.GetCurrent(this).SetFocus(txtMemberName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int MemberId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        int Result = MemberMgr.DeleteMemberByMemberId(MemberId);

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
                    LoadMember();
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
            txtMemberCode.Text = string.Empty;
            txtMemberName.Text = string.Empty;
            ddlSex.Text = "0";
            ddlDesignation.Text = "0";
            txtDOB.Text = string.Empty;
            txtAddress1.Text = string.Empty;
            txtAddress2.Text = string.Empty;
            txtAddress3.Text = string.Empty;
            txtCityName.Text = string.Empty;
            ddlState.Text = "0";
            txtPinCode.Text = string.Empty;
            txtDOJ.Text = string.Empty;
            txtEmailId.Text = string.Empty;
            txtDinNo.Text = string.Empty;
            txtPhotoPath.Text = string.Empty;
            txtResumePath.Text = string.Empty;
            txtRelievingDate.Text = string.Empty;
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
