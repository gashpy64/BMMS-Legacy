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
    public partial class User : System.Web.UI.Page
    {
        private string className = "User";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadUser();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            txtLoginName.Attributes.Add("MaxLength", Common.GetAppSetting("LoginIdMaxLength"));
            txtPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));
            txtConfirmPassword.Attributes.Add("MaxLength", Common.GetAppSetting("PasswordMaxLength"));

            btnSave.Attributes.Add("onclick", "return UserValidation()");
            txtUserName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + ddlDepartment.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlDepartment.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + ddlRole.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlRole.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + ddlDesignation.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlDesignation.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtEmailId.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtEmailId.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtLoginName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtLoginName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtPassword.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtConfirmPassword.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtConfirmPassword.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID +
                "','" + txtConfirmPassword.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadDDLlist
        private void LoadDDLlist()
        {
            try
            {
                //DataTable dtStatus = new DataTable();
                //dtStatus = SysCodeMgr.GetSysCodeSetting("Status");

                DataTable dtDept = DepartmentMgr.GetDepartmentList(1);
                DataTable dtDesignation = DesignationMgr.GetDesignationList(1);
                //DataTable dtMgrController = UserMgr.GetMgrController();
                DataTable dtRole = RoleMgr.GetRoleList();

                Common.LoadDropdownlist(ddlDepartment, dtDept, "DepartmentName", "DepartmentId", true);
                Common.LoadDropdownlist(ddlDesignation, dtDesignation, "DesignationName", "DesignationId", true);
                //Common.LoadDropdownlist(ddlManager, dtMgrController, "UserName", "UserId", true);
                Common.LoadDropdownlist(ddlRole, dtRole, "RoleName", "RoleId", true);
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

        #region LoadUser
        private void LoadUser()
        {
            pnlViewUser.Visible = true;
            pnlEditUser.Visible = false;

            try
            {
                DataTable dtUser = new DataTable();
                dtUser = UserMgr.GetUserList();

                ViewState["dtUser"] = dtUser;
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
            grvUser.DataSource = (DataTable)ViewState["dtUser"];
            grvUser.DataBind();
        }
        #endregion

        #region grvUser_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvUser_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvUser_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtUser"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtUser"]);

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
            hdnUserId.Value = "0";
            pnlViewUser.Visible = false;
            pnlEditUser.Visible = true;
            pnlPwd.Visible = true;
            ScriptManager.GetCurrent(this).SetFocus(txtUserName.ClientID);
            ddlManager.Enabled = false;
            txtLoginName.Enabled = true;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                UserMgr myUserMgr = new UserMgr();
                UserBAL myUser = new UserBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myUser.Code = "Save";
                    if (btnSave.Text == "Update")
                        myUser.Code = "Update";

                    myUser.UserId = Convert.ToInt16(hdnUserId.Value);
                    myUser.UserName = txtUserName.Text.Trim();
                    myUser.DepartmentId = Convert.ToInt16(ddlDepartment.SelectedValue);
                    myUser.DesignationId = Convert.ToInt16(ddlDesignation.SelectedValue);
                    myUser.ManagerId = Convert.ToInt16(ddlManager.SelectedValue);
                    myUser.RoleId = Convert.ToInt16(ddlRole.SelectedValue);
                    myUser.EmailId = txtEmailId.Text.Trim();
                    myUser.LoginName = txtLoginName.Text.Trim();
                    myUser.Password = Common.EncryptVal(txtPassword.Text);
                    myUser.CreatedOn = System.DateTime.Now;
                    myUser.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myUser.UpdatedOn = System.DateTime.Now;
                    myUser.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myUserMgr.AddEditUser(myUser);

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
                    myUserMgr = null;
                    myUser = null;
                }

                MsgDisplay(sMsg);

                pnlViewUser.Visible = true;
                pnlEditUser.Visible = false;
                LoadUser();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtUser = (DataTable)ViewState["dtUser"];

            DataView dv = new DataView(dtUser);

            dtUser.CaseSensitive = false;

            if (btnSave.Text == "Save")
            {
                dv.RowFilter = " LoginName = '" + txtLoginName.Text.Trim().ToLower() + "'";

                int PasswordMinLength = Convert.ToInt16(Common.GetAppSetting("PasswordMinLength"));
                if (txtPassword.Text.Trim().Length <= PasswordMinLength)
                {
                    MsgDisplay("Password length minimum of " + PasswordMinLength.ToString() + " characters in length");
                    ScriptManager.GetCurrent(this).SetFocus(txtPassword.ClientID);
                    return false;
                }
            }
            if (btnSave.Text == "Update")
                dv.RowFilter = " LoginName = '" + txtLoginName.Text.Trim().ToLower() + "' and UserId <> " + hdnUserId.Value;


            DataTable dtFilter = dv.ToTable("dtDepartment");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Login User Id not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtLoginName.ClientID);
                return false;
            }



            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewUser.Visible = true;
            pnlEditUser.Visible = false;
        }
        #endregion

        #region grvUser_RowCommand
        protected void grvUser_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int UserId = Convert.ToInt32(e.CommandArgument);

                    pnlViewUser.Visible = false;
                    pnlEditUser.Visible = true;
                    LoadDDLlist();
                    UserBAL myUser = new UserBAL();
                    myUser = UserMgr.GetUserByUserId(UserId);

                    hdnUserId.Value = myUser.UserId.ToString();
                    txtUserName.Text = myUser.UserName;
                    ddlDepartment.Text = myUser.DepartmentId.ToString();
                    LoadMgrController(myUser.DepartmentId);
                    ddlDesignation.Text = myUser.DesignationId.ToString();
                    ddlManager.Text = myUser.ManagerId.ToString();
                    
                    ddlRole.Text = myUser.RoleId.ToString();
                    if (ddlRole.SelectedItem.Text.ToLower() == "user")
                        ddlManager.Enabled = true;
                    else
                        ddlManager.Enabled = false;

                    txtEmailId.Text = myUser.EmailId;
                    txtLoginName.Text = myUser.LoginName;
                    txtLoginName.Enabled = false;
                    txtPassword.Text = myUser.Password;
                    txtConfirmPassword.Text = myUser.Password;
                    pnlPwd.Visible = false;

                    ScriptManager.GetCurrent(this).SetFocus(txtUserName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int UserId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        UserMgr.DeleteUserByUserId(UserId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }
                    LoadUser();
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
            txtUserName.Text = string.Empty;
            ddlDepartment.Text = "0";
            ddlDesignation.Text = "0";
            ddlManager.Text = "0";
            ddlRole.Text = "0";
            txtEmailId.Text = string.Empty;
            txtLoginName.Text = string.Empty;
            txtPassword.Text = string.Empty;
            txtConfirmPassword.Text = string.Empty;
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

        #region ddlRole_SelectedIndexChanged
        protected void ddlRole_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (ddlRole.SelectedItem.Text.ToLower() == "user")
            {
                ddlManager.Enabled = true;
            }
            else
            {
                ddlManager.Enabled = false;
            }
        }
        #endregion

        #region ddlDepartment_SelectedIndexChanged
        protected void ddlDepartment_SelectedIndexChanged(object sender, EventArgs e)
        {
            int DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString());

            LoadMgrController(DepartmentId);
        }
        #endregion


        #region LoadMgrController
        private void LoadMgrController(int DepartmentId)
        {
            DataTable dtMgrController = UserMgr.GetMgrControllerByDeptId(DepartmentId);

            Common.LoadDropdownlist(ddlManager, dtMgrController, "LoginName", "UserId", true);
        }
        #endregion
        
    }
}
