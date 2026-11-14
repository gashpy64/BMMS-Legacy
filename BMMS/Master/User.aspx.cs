using System;
using System.Data;
using System.Configuration;
using System.Collections;
using System.Collections.Generic;
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
            // Step RA1a: Admin only (role read from the database; ends the request otherwise)
            BMMS.Security.PageAccessModule.RequireRole("admin");

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

                // Step UD1a: the Manager role (by RoleCode; RoleName when the list has no RoleCode) and the active
                // departments for "Departments managed". CheckBoxList does not encode its item text: encoded here.
                int managerRoleId = 0;
                foreach (DataRow row in dtRole.Rows)
                {
                    string code = dtRole.Columns.Contains("RoleCode") ? Convert.ToString(row["RoleCode"]).Trim() : string.Empty;
                    bool isManager = code.Length > 0
                        ? string.Equals(code, "manager", StringComparison.OrdinalIgnoreCase)
                        : string.Equals(Convert.ToString(row["RoleName"]).Trim(), "manager", StringComparison.OrdinalIgnoreCase);
                    if (isManager)
                    {
                        managerRoleId = Convert.ToInt32(row["RoleId"]);
                        break;
                    }
                }
                ViewState["ManagerRoleId"] = managerRoleId;

                cblDepartments.Items.Clear();
                if (HasUserHistory())
                {
                    foreach (DataRow row in dtDept.Rows)
                        cblDepartments.Items.Add(new ListItem(HttpUtility.HtmlEncode(Convert.ToString(row["DepartmentName"])),
                                                              Convert.ToString(row["DepartmentId"])));
                }
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
                AddDepartmentText(dtUser);

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

        #region Departments (step UD1a, BMMS-Fix-UserHistory-Step39.sql)
        // True when step 39 is installed; read once per page visit. Without it the page keeps one department per user.
        private bool HasUserHistory()
        {
            if (ViewState["HasUserHistory"] == null)
                ViewState["HasUserHistory"] = UserMgr.HasUserHistory();

            return (bool)ViewState["HasUserHistory"];
        }

        private bool ManagerRoleSelected()
        {
            int managerRoleId = ViewState["ManagerRoleId"] == null ? 0 : (int)ViewState["ManagerRoleId"];
            return HasUserHistory() && managerRoleId > 0 && ddlRole.SelectedValue == managerRoleId.ToString();
        }

        private bool EditedUserInactive()
        {
            return ViewState["EditedUserInactive"] != null && (bool)ViewState["EditedUserInactive"];
        }

        // Grid column DepartmentText: the department, or for a user with several "HRD (primary), Credit, Admin"
        private void AddDepartmentText(DataTable dtUser)
        {
            if (!dtUser.Columns.Contains("DepartmentText"))
                dtUser.Columns.Add("DepartmentText", typeof(string));

            Dictionary<int, List<string>> others = new Dictionary<int, List<string>>();
            Dictionary<int, string> homes = new Dictionary<int, string>();

            if (HasUserHistory())
            {
                foreach (DataRow map in UserMgr.GetUserDepartmentMap(0).Rows)
                {
                    int userId = Convert.ToInt32(map["UserId"]);
                    string name = Convert.ToString(map["DepartmentName"]);

                    if (Convert.ToInt32(map["IsHome"]) == 1)
                        homes[userId] = name;
                    else
                    {
                        if (!others.ContainsKey(userId))
                            others[userId] = new List<string>();
                        others[userId].Add(name);
                    }
                }
            }

            foreach (DataRow row in dtUser.Rows)
            {
                int userId = Convert.ToInt32(row["UserId"]);
                string home = homes.ContainsKey(userId) ? homes[userId] : Convert.ToString(row["DepartmentName"]);

                row["DepartmentText"] = others.ContainsKey(userId)
                    ? home + " (primary), " + string.Join(", ", others[userId].ToArray())
                    : Convert.ToString(row["DepartmentName"]);
            }
        }

        // Ticks the user's open mappings; a mapped department that is inactive now is added as "(inactive)"
        private void LoadUserDepartments(int UserId)
        {
            if (!HasUserHistory())
                return;

            foreach (DataRow map in UserMgr.GetUserDepartmentMap(UserId).Rows)
            {
                string id = Convert.ToString(map["DepartmentId"]);
                ListItem item = cblDepartments.Items.FindByValue(id);

                if (item == null)
                {
                    item = new ListItem(HttpUtility.HtmlEncode(Convert.ToString(map["DepartmentName"])) + " (inactive)", id);
                    cblDepartments.Items.Add(item);
                }

                item.Selected = true;
            }
        }

        // Shown for the Manager role only. The home department is ticked and cannot be unticked here (the procedure
        // refuses a list without it, Reason 23). An inactive user's departments are shown but not changed.
        private void ShowDepartments()
        {
            bool manager = ManagerRoleSelected();

            pnlDepartments.Visible = manager;
            litDepartmentLabel.Text = manager ? "Home department" : "Department";

            if (!manager)
                return;

            bool editable = !EditedUserInactive();
            string home = ddlDepartment.SelectedValue;

            foreach (ListItem item in cblDepartments.Items)
            {
                if (item.Value == home)
                {
                    item.Selected = true;
                    item.Enabled = false;
                    item.Attributes["title"] = "Home department: change it above to untick";
                }
                else
                {
                    item.Enabled = editable;
                    item.Attributes.Remove("title");
                }
            }

            litDepartmentsNote.Text = editable
                ? "The home department is always one of them and is the primary one."
                : "This user is inactive: the departments managed can be changed after Activate.";
        }

        // @DepartmentIds: built on the server from the list items (the browser posts only which are ticked) with the
        // home department first; null when step 39 is not installed or the user is inactive (the procedure keeps the rows)
        private string DepartmentIdsToSave()
        {
            if (!HasUserHistory() || EditedUserInactive())
                return null;

            int home;
            if (!int.TryParse(ddlDepartment.SelectedValue, out home) || home <= 0)
                return null;

            List<string> ids = new List<string>();
            ids.Add(home.ToString());

            if (ManagerRoleSelected())
            {
                foreach (ListItem item in cblDepartments.Items)
                {
                    int id;
                    if (item.Selected && int.TryParse(item.Value, out id) && id > 0 && !ids.Contains(id.ToString()))
                        ids.Add(id.ToString());
                }
            }

            return string.Join(",", ids.ToArray());
        }

        protected override void OnPreRender(EventArgs e)
        {
            base.OnPreRender(e);

            if (pnlEditUser.Visible)
            {
                ShowDepartments();
                ViewState["HomeDepartment"] = ddlDepartment.SelectedValue;
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
            ViewState["EditedUserInactive"] = false;
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

                    // Step UD1a: the departments (home first); null keeps the stored mappings
                    myUser.DepartmentIds = DepartmentIdsToSave();


                    // Acting user: the server-side session only
                    myUser.CreatedOn = System.DateTime.Now;
                    myUser.CreatedBy = ActingUserId();
                    myUser.UpdatedOn = System.DateTime.Now;
                    myUser.UpdatedBy = ActingUserId();

                    UserChangeResult result = myUserMgr.AddEditUser(myUser);

                    string closed = result.SuccessDetail(UserChangeReason.MappingsClosedPrefix);

                    if (result.Result == 1 && closed.Length > 0)
                        sMsg = "Saved. Their department mappings were closed today: " + HttpUtility.HtmlEncode(closed) + ".";
                    else if (result.Result == 1)
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

                MsgDisplay(sMsg, sMsg == "Successfully Saved" || sMsg.StartsWith("Saved.") ? MessageKind.Success
                               : sMsg == "Record Not Saved" ? MessageKind.Error : MessageKind.Warning);

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
                dv.RowFilter = " LoginName = '" + txtLoginName.Text.Trim().ToLower().Replace("'", "''") + "'";

                int PasswordMinLength = Convert.ToInt16(Common.GetAppSetting("PasswordMinLength"));
                if (txtPassword.Text.Trim().Length <= PasswordMinLength)
                {
                    MsgDisplay("Password length minimum of " + PasswordMinLength.ToString() + " characters in length");
                    ScriptManager.GetCurrent(this).SetFocus(txtPassword.ClientID);
                    return false;
                }
            }
            if (btnSave.Text == "Update")
                dv.RowFilter = " LoginName = '" + txtLoginName.Text.Trim().ToLower().Replace("'", "''") + "' and UserId <> " + hdnUserId.Value;


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

                    // Step UD1a: the departments managed; an inactive user's are shown but not changed
                    DataRow[] listed = ((DataTable)ViewState["dtUser"]).Select("UserId = " + UserId.ToString());
                    ViewState["EditedUserInactive"] = listed.Length > 0 && Convert.ToInt32(listed[0]["AccountStatus"]) != 1;
                    LoadUserDepartments(UserId);
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

                    string notRestored = result.SuccessDetail(UserChangeReason.NotRestoredPrefix);

                    if (result.Result == 1 && activate && notRestored.Length > 0)
                        // Activated, but not completely: a warning, so the department left out is noticed
                        MsgDisplay("Activated. Not restored (department inactive): " + HttpUtility.HtmlEncode(notRestored), MessageKind.Warning);
                    else if (result.Result == 1)
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

            // Step UD1a: the previous home department stays ticked (it is still managed until it is unticked)
            string previousHome = ViewState["HomeDepartment"] as string;
            ListItem previous = previousHome == null ? null : cblDepartments.Items.FindByValue(previousHome);
            if (previous != null && ManagerRoleSelected() && !EditedUserInactive())
                previous.Selected = true;
        }
        #endregion


        #region LoadMgrController
        private void LoadMgrController(int DepartmentId)
        {
            // Active Managers / Controllers, plus the edited user's current manager even if inactive.
            // Step UN3: the text is "Name (login)" (" (inactive)" added), sorted by name, then login; the value
            // stays UserId. The procedure's own ManagerText column (login only) is no longer shown.
            int currentManagerId = ViewState["CurrentManagerId"] == null ? 0 : (int)ViewState["CurrentManagerId"];
            DataTable dtMgrController = UserMgr.WithUserDisplayName(UserMgr.GetMgrControllerByDeptId(DepartmentId, currentManagerId));

            Common.LoadDropdownlist(ddlManager, dtMgrController, UserMgr.UserDisplayNameColumn, "UserId", true);
        }
        #endregion
        
    }
}
