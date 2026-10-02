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
    public partial class Designation : System.Web.UI.Page
    {
        private string className = "Designation";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDesignation();
                LoadStatus();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return DesignationValidation()");
            txtDesignationCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtDesignationName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtDesignationName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
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

        #region LoadDesignation
        private void LoadDesignation()
        {
            pnlViewDesignation.Visible = true;
            pnlEditDesignation.Visible = false;

            try
            {
                DataTable dtDesignation = new DataTable();
                dtDesignation = DesignationMgr.GetDesignationList(-1);

                ViewState["dtDesignation"] = dtDesignation;
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
            grvDesignation.DataSource = (DataTable)ViewState["dtDesignation"];
            grvDesignation.DataBind();
        }
        #endregion

        #region grvDesignation_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvDesignation_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvDesignation_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtDesignation"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtDesignation"]);

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
            hdnDesignationId.Value = "0";
            pnlViewDesignation.Visible = false;
            pnlEditDesignation.Visible = true;
            txtDesignationCode.Text = DesignationMgr.GetNextDesignationCode();
            ScriptManager.GetCurrent(this).SetFocus(txtDesignationName.ClientID);
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                DesignationMgr myDesignationMgr = new DesignationMgr();
                DesignationBAL myDesignation = new DesignationBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myDesignation.Code = "Save";
                    if (btnSave.Text == "Update")
                        myDesignation.Code = "Update";

                    myDesignation.DesignationId = Convert.ToInt16(hdnDesignationId.Value);
                    myDesignation.DesignationCode = txtDesignationCode.Text.Trim();
                    myDesignation.DesignationName = txtDesignationName.Text.Trim();
                    myDesignation.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myDesignation.CreatedOn = System.DateTime.Now;
                    myDesignation.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myDesignation.UpdatedOn = System.DateTime.Now;
                    myDesignation.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myDesignationMgr.AddEditDesignation(myDesignation);

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
                    myDesignationMgr = null;
                    myDesignation = null;
                }

                MsgDisplay(sMsg);

                pnlViewDesignation.Visible = true;
                pnlEditDesignation.Visible = false;
                LoadDesignation();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtDesignation = (DataTable)ViewState["dtDesignation"];

            DataView dv = new DataView(dtDesignation);

            dtDesignation.CaseSensitive = false;

            if (btnSave.Text == "Save")
                dv.RowFilter = " DesignationName = '" + txtDesignationName.Text.Trim().ToLower() + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " DesignationName = '" + txtDesignationName.Text.Trim().ToLower() + "' and DesignationId <> " + hdnDesignationId.Value;

            
            DataTable dtFilter = dv.ToTable("dtDesignation");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Designation not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtDesignationName.ClientID);
                return false;
            }


            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewDesignation.Visible = true;
            pnlEditDesignation.Visible = false;
        }
        #endregion

        #region grvDesignation_RowCommand
        protected void grvDesignation_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int DesignationId = Convert.ToInt32(e.CommandArgument);

                    pnlViewDesignation.Visible = false;
                    pnlEditDesignation.Visible = true;
                    
                    DesignationBAL myDesignation = new DesignationBAL();
                    myDesignation = DesignationMgr.GetDesignationByDesignationId(DesignationId);

                    hdnDesignationId.Value = myDesignation.DesignationId.ToString();
                    txtDesignationCode.Text = myDesignation.DesignationCode;
                    txtDesignationName.Text = myDesignation.DesignationName;
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myDesignation.StatusId.ToString();
                    
                    ScriptManager.GetCurrent(this).SetFocus(txtDesignationName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int DesignationId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        DesignationMgr.DeleteDesignationByDesignationId(DesignationId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }

                    LoadDesignation();
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
            txtDesignationCode.Text = string.Empty;
            txtDesignationName.Text = string.Empty;
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
