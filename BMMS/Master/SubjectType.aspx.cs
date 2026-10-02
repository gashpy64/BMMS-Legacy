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
    public partial class SubjectType : System.Web.UI.Page
    {
        private string className = "SubjectType";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadSubjectType();
                LoadStatus();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return SubjectTypeValidation()");
            txtSubjectTypeCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtSubjectTypeName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtSubjectTypeName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtOrderNo.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtOrderNo.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
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

        #region LoadSubjectType
        private void LoadSubjectType()
        {
            pnlViewSubjectType.Visible = true;
            pnlEditSubjectType.Visible = false;

            try
            {
                DataTable dtSubjectType = new DataTable();
                dtSubjectType = SubjectTypeMgr.GetSubjectTypeList();

                ViewState["dtSubjectType"] = dtSubjectType;
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
            grvSubjectType.DataSource = (DataTable)ViewState["dtSubjectType"];
            grvSubjectType.DataBind();
        }
        #endregion

        #region grvSubjectType_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvSubjectType_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvSubjectType_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtSubjectType"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtSubjectType"]);

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
            hdnSubjectTypeId.Value = "0";
            pnlViewSubjectType.Visible = false;
            pnlEditSubjectType.Visible = true;
            txtSubjectTypeCode.Text = SubjectTypeMgr.GetNextSubjectTypeCode();
            ScriptManager.GetCurrent(this).SetFocus(txtSubjectTypeName.ClientID);
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                SubjectTypeMgr mySubjectTypeMgr = new SubjectTypeMgr();
                SubjectTypeBAL mySubjectType = new SubjectTypeBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        mySubjectType.Code = "Save";
                    if (btnSave.Text == "Update")
                        mySubjectType.Code = "Update";

                    mySubjectType.SubjectTypeId = Convert.ToInt16(hdnSubjectTypeId.Value);
                    mySubjectType.SubjectTypeCode = txtSubjectTypeCode.Text.Trim();
                    mySubjectType.SubjectTypeName = txtSubjectTypeName.Text.Trim();
                    if (txtOrderNo.Text.Trim() == string.Empty)
                        mySubjectType.OrderNo = 0;
                    else
                        mySubjectType.OrderNo = Convert.ToInt16(txtOrderNo.Text.Trim());
                    mySubjectType.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    mySubjectType.CreatedOn = System.DateTime.Now;
                    mySubjectType.CreatedBy = int.Parse(Session["UserId"].ToString());
                    mySubjectType.UpdatedOn = System.DateTime.Now;
                    mySubjectType.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = mySubjectTypeMgr.AddEditSubjectType(mySubjectType);

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
                    mySubjectTypeMgr = null;
                    mySubjectType = null;
                }

                MsgDisplay(sMsg);

                pnlViewSubjectType.Visible = true;
                pnlEditSubjectType.Visible = false;
                LoadSubjectType();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtSubjectType = (DataTable)ViewState["dtSubjectType"];

            DataView dv = new DataView(dtSubjectType);

            dtSubjectType.CaseSensitive = false;

            if (btnSave.Text == "Save")
                dv.RowFilter = " SubjectTypeName = '" + txtSubjectTypeName.Text.Trim().ToLower() + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " SubjectTypeName = '" + txtSubjectTypeName.Text.Trim().ToLower() + "' and SubjectTypeId <> " + hdnSubjectTypeId.Value;


            DataTable dtFilter = dv.ToTable("dtSubjectType");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Subject Type not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtSubjectTypeName.ClientID);
                return false;
            }


            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewSubjectType.Visible = true;
            pnlEditSubjectType.Visible = false;
        }
        #endregion

        #region grvSubjectType_RowCommand
        protected void grvSubjectType_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int SubjectTypeId = Convert.ToInt32(e.CommandArgument);

                    pnlViewSubjectType.Visible = false;
                    pnlEditSubjectType.Visible = true;
                    
                    SubjectTypeBAL mySubjectType = new SubjectTypeBAL();
                    mySubjectType = SubjectTypeMgr.GetSubjectTypeBySubjectTypeId(SubjectTypeId);

                    hdnSubjectTypeId.Value = mySubjectType.SubjectTypeId.ToString();
                    txtSubjectTypeCode.Text = mySubjectType.SubjectTypeCode;
                    txtSubjectTypeName.Text = mySubjectType.SubjectTypeName;
                    txtOrderNo.Text = mySubjectType.OrderNo.ToString();
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = mySubjectType.StatusId.ToString();
                    
                    ScriptManager.GetCurrent(this).SetFocus(txtSubjectTypeName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int SubjectTypeId = Convert.ToInt32(e.CommandArgument);
                    
                    try
                    {
                        SubjectTypeMgr.DeleteSubjectTypeBySubjectTypeId(SubjectTypeId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }
                    LoadSubjectType();
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
            txtSubjectTypeCode.Text = string.Empty;
            txtSubjectTypeName.Text = string.Empty;
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
