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
                // Same rows as GetUserList, plus CanEdit / CanChangeRole / CanDelete for the logged-in user
                dtUser = UserMgr.GetUserListForUserPage(ActingUserId());

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
                    // Visual only: the procedures refuse these anyway
                    DataRowView drv = (DataRowView)e.Row.DataItem;

                    if (Convert.ToInt32(drv["CanEdit"]) != 1)
                    {
                        Button btnEdit = (Button)e.Row.FindControl("btnEdit");
                        btnEdit.Enabled = false;
                        btnEdit.ToolTip = "You cannot edit this user";
                    }

                    if (Convert.ToInt32(drv["CanDelete"]) != 1)
                    {
                        Button btnDelete = (Button)e.Row.FindControl("btnDelete");
                        btnDelete.Enabled = false;
                        btnDelete.ToolTip = "You cannot delete this user";
                    }

                    // Status (BMMS-Fix-UserStatus-Stage2a.sql): one button, Deactivate or Activate
                    Button btnStatus = (Button)e.Row.FindControl("btnStatus");
                    string login = HttpUtility.JavaScriptStringEncode(drv["LoginName"].ToString());

                    if (Convert.ToInt32(drv["AccountStatus"]) == 1)
                    {
                        int managed = Convert.ToInt32(drv["ManagedCount"]);
                        string confirmText = "Deactivate " + login + "? They will no longer be able to log in. Their history is kept.";
                        if (managed > 0)
                            confirmText += " They are the reporting person for " + managed + " active user" + (managed == 1 ? "" : "s")
                                         + "; those users keep them as manager, and new agenda items from those who are not Managers or Controllers will be refused until they get an active manager.";

                        btnStatus.Text = "Deactivate";
                        btnStatus.ToolTip = "Deactivate";
                        btnStatus.CommandName = "DeactivateRec";
                        btnStatus.OnClientClick = "return confirm('" + confirmText + "');";

                        if (Convert.ToInt32(drv["CanDeactivate"]) != 1)
                        {
                            btnStatus.Enabled = false;
                            btnStatus.ToolTip = "You cannot deactivate this user";
                        }
                    }
                    else
                    {
                        e.Row.CssClass = (e.Row.CssClass + " wb-row-inactive").Trim();

                        btnStatus.Text = "Activate";
                        btnStatus.ToolTip = "Activate";
                        btnStatus.CommandName = "ActivateRec";
                        btnStatus.OnClientClick = "return confirm('Activate " + login + "? They will be able to log in again.');";

                        if (Convert.ToInt32(drv["CanActivate"]) != 1)
                        {
                            btnStatus.Enabled = false;
                            btnStatus.ToolTip = "You cannot activate this user";
                        }
                    }

                    // The protected system account (BMMS-Fix-SystemAccount-Stage3.sql): shown greyed with a label;
                    // the flags above are already 0, and the procedures refuse it anyway (Reason 7)
                    if (Common.IsSystemAccountRow(drv.Row))
                    {
                        e.Row.CssClass = (e.Row.CssClass + " wb-row-inactive").Trim();

                        Label lblStatus = (Label)e.Row.FindControl("lblStatus");
                        lblStatus.Text = HttpUtility.HtmlEncode(drv["Status"].ToString()) + " (System account)";

                        string tip = "Protected system account";
                        ((Button)e.Row.FindControl("btnEdit")).ToolTip = tip;
                        ((Button)e.Row.FindControl("btnDelete")).ToolTip = tip;
                        btnStatus.ToolTip = tip;
                    }

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

        #region ActingUserId
        // The logged-in user, from the server-side session only (0 when missing; the procedures refuse 0)
        private int ActingUserId()
        {
            int userId;
            return (Session["UserId"] != null && int.TryParse(Session["UserId"].ToString(), out userId)) ? userId : 0;
        }
        #endregion

        #region btnAdd_Click
        protected void btnAdd_Click(object sender, EventArgs e)
        {
            MsgHide();
            LoadDDLlist();
            ClearText();
            ddlRole.Enabled = true;
            hdnUserId.Value = "0";
            ViewState["CurrentManagerId"] = 0;
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

                    myUser.Password = (btnSave.Text == "Save") ? Common.HashPassword(txtPassword.Text) : string.Empty;


                    // Acting user: the server-side session only
                    myUser.CreatedOn = System.DateTime.Now;
                    myUser.CreatedBy = ActingUserId();
                    myUser.UpdatedOn = System.DateTime.Now;
                    myUser.UpdatedBy = ActingUserId();

                    UserChangeResult result = myUserMgr.AddEditUser(myUser);

                    if (result.Result == 1)
                        sMsg = "Successfully Saved";
                    else if (result.Reason != UserChangeReason.None)
                        sMsg = result.RefusalMessage(myUser.Code == "Save" ? "create a user with this role" : "make this change to this user", className);
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

                MsgDisplay(sMsg, sMsg == "Successfully Saved" ? MessageKind.Success : sMsg == "Record Not Saved" ? MessageKind.Error : MessageKind.Warning);

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

                    UserChangeResult canEdit = UserMgr.CheckUserChange(ActingUserId(), UserId, "Edit", 0);
                    if (canEdit.Result != 1)
                    {
                        MsgDisplay(canEdit.RefusalMessage("edit this user", className));
                        return;
                    }

                    pnlViewUser.Visible = false;
                    pnlEditUser.Visible = true;
                    LoadDDLlist();
                    UserBAL myUser = new UserBAL();
                    myUser = UserMgr.GetUserByUserId(UserId);

                    hdnUserId.Value = myUser.UserId.ToString();
                    txtUserName.Text = myUser.UserName;
                    ddlDepartment.Text = myUser.DepartmentId.ToString();
                    // keep the current manager in the list even if inactive (stage 2a)
                    ViewState["CurrentManagerId"] = myUser.ManagerId;
                    LoadMgrController(myUser.DepartmentId);
                    ddlDesignation.Text = myUser.DesignationId.ToString();
                    ddlManager.Text = myUser.ManagerId.ToString();
                    
                    ddlRole.Text = myUser.RoleId.ToString();
                    if (ddlRole.SelectedItem.Text.ToLower() == "user")
                        ddlManager.Enabled = true;
                    else
                        ddlManager.Enabled = false;

                    // Visual only: spr_AddEditUser refuses a role change anyway
                    ddlRole.Enabled = UserMgr.CheckUserChange(ActingUserId(), UserId, "RoleChange", 0).Result == 1;

                    txtEmailId.Text = myUser.EmailId;
                    txtLoginName.Text = myUser.LoginName;
                    txtLoginName.Enabled = false;
                    txtPassword.Text = string.Empty;
                    txtConfirmPassword.Text = string.Empty;
                    pnlPwd.Visible = false;

                    ScriptManager.GetCurrent(this).SetFocus(txtUserName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int UserId = Convert.ToInt32(e.CommandArgument);

                    // An unexpected error is not "in use": it goes to the outer catch and the error page
                    UserChangeResult result = UserMgr.DeleteUserByUserId(UserId, ActingUserId());

                    if (result.Result == 1)
                        MsgDisplay("Record Deleted Successfully", MessageKind.Success);
                    else
                        MsgDisplay(result.RefusalMessage("delete this user", className));

                    LoadUser();
                }
                if (e.CommandName == "DeactivateRec" || e.CommandName == "ActivateRec")
                {
                    int UserId = Convert.ToInt32(e.CommandArgument);
                    bool activate = e.CommandName == "ActivateRec";

                    // spr_SetUserStatusByUserId checks the rules again under its lock
                    UserChangeResult result = UserMgr.SetUserStatusByUserId(UserId, activate ? 1 : 0, ActingUserId());

                    if (result.Result == 1)
                        MsgDisplay(activate ? "User activated" : "User deactivated", MessageKind.Success);
                    else
                        MsgDisplay(result.RefusalMessage(activate ? "activate this user" : "deactivate this user", className));

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
            // Active Managers / Controllers, plus the edited user's current manager ("login (inactive)")
            int currentManagerId = ViewState["CurrentManagerId"] == null ? 0 : (int)ViewState["CurrentManagerId"];
            DataTable dtMgrController = UserMgr.GetMgrControllerByDeptId(DepartmentId, currentManagerId);

            Common.LoadDropdownlist(ddlManager, dtMgrController, "ManagerText", "UserId", true);
        }
        #endregion
        
    }
}
