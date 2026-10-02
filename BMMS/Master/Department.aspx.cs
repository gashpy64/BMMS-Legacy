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
    public partial class Department : System.Web.UI.Page
    {
        private string className = "Department";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDepartment();
                LoadStatus();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return DeptValidation()");
            txtDeptCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtDeptName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtDeptName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtOrderNo.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtOrderNo.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlStatus.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + btnSave.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

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

        #region LoadDepartment
        private void LoadDepartment()
        {
            pnlViewDept.Visible = true;
            pnlEditDept.Visible = false;

            try
            {
                DataTable dtDept = new DataTable();
                dtDept = DepartmentMgr.GetDepartmentList(-1);

                ViewState["dtDepartment"] = dtDept;
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
            grvDepartment.DataSource = (DataTable)ViewState["dtDepartment"];
            grvDepartment.DataBind();
        }
        #endregion

        #region grvDepartment_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvDepartment_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvDepartment_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtDepartment"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtDepartment"]);

                BindGridView();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvRecord_Sorting", ex);
            }
        }
        #endregion

        #region OnPaging
        protected void OnPaging(object sender, GridViewPageEventArgs e)
        {
            DataTable dtDepartment = (DataTable)ViewState["dtDepartment"];
            grvDepartment.DataSource = dtDepartment;
            grvDepartment.PageIndex = e.NewPageIndex;
            grvDepartment.DataBind();
        }
        #endregion

        #region btnAdd_Click
        protected void btnAdd_Click(object sender, EventArgs e)
        {
            MsgHide();
            ClearText();
            hdnDeptId.Value = "0";
            pnlViewDept.Visible = false;
            pnlEditDept.Visible = true;
            txtDeptCode.Text = DepartmentMgr.GetNextDeptCode();
            ScriptManager.GetCurrent(this).SetFocus(txtDeptName.ClientID);
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                DepartmentMgr myDeptMgr = new DepartmentMgr();
                DepartmentBAL myDept = new DepartmentBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myDept.Code = "Save";
                    if (btnSave.Text == "Update")
                        myDept.Code = "Update";

                    myDept.DepartmentId = Convert.ToInt16(hdnDeptId.Value);
                    myDept.DepartmentCode = txtDeptCode.Text.Trim();
                    myDept.DepartmentName = txtDeptName.Text.Trim();
                    if (txtOrderNo.Text.Trim() == string.Empty)
                        myDept.OrderNo = 0;
                    else
                        myDept.OrderNo = Convert.ToInt16(txtOrderNo.Text.Trim());
                    myDept.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myDept.CreatedOn = System.DateTime.Now;
                    myDept.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myDept.UpdatedOn = System.DateTime.Now;
                    myDept.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myDeptMgr.AddEditDepartment(myDept);

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
                    myDeptMgr = null;
                    myDept = null;
                }

                MsgDisplay(sMsg);

                pnlViewDept.Visible = true;
                pnlEditDept.Visible = false;
                LoadDepartment();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtDepartment = (DataTable)ViewState["dtDepartment"];

            DataView dv = new DataView(dtDepartment);

            dtDepartment.CaseSensitive = false;

            if (btnSave.Text == "Save")
                dv.RowFilter = " DepartmentName = '" + txtDeptName.Text.Trim().ToLower() + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " DepartmentName = '" + txtDeptName.Text.Trim().ToLower() + "' and DepartmentId <> " + hdnDeptId.Value;


            DataTable dtFilter = dv.ToTable("dtDepartment");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Department not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtDeptName.ClientID);
                return false;
            }


            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewDept.Visible = true;
            pnlEditDept.Visible = false;
        }
        #endregion

        #region grvDepartment_RowCommand
        protected void grvDepartment_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int DeptId = Convert.ToInt32(e.CommandArgument);

                    pnlViewDept.Visible = false;
                    pnlEditDept.Visible = true;

                    DepartmentBAL myDept = new DepartmentBAL();
                    myDept = DepartmentMgr.GetDepartmentByDeptId(DeptId);

                    hdnDeptId.Value = myDept.DepartmentId.ToString();
                    txtDeptCode.Text = myDept.DepartmentCode;
                    txtDeptName.Text = myDept.DepartmentName;
                    txtOrderNo.Text = myDept.OrderNo.ToString();
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myDept.StatusId.ToString();

                    ScriptManager.GetCurrent(this).SetFocus(txtDeptName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int DeptId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        DepartmentMgr.DeleteDepartmentByDeptId(DeptId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }
                    
                    LoadDepartment();
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
            txtDeptCode.Text = string.Empty;
            txtDeptName.Text = string.Empty;
            txtOrderNo.Text = string.Empty;
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
