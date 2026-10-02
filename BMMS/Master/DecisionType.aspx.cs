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
    public partial class DecisionType : System.Web.UI.Page
    {
        private string className = "DecisionType";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDecisionType();
                LoadStatus();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return DecisionTypeValidation()");
            txtDecisionTypeCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtDecisionTypeName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtDecisionTypeName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
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

        #region LoadDecisionType
        private void LoadDecisionType()
        {
            pnlViewDecisionType.Visible = true;
            pnlEditDecisionType.Visible = false;

            try
            {
                DataTable dtDecisionType = new DataTable();
                dtDecisionType = DecisionTypeMgr.GetDecisionTypeList(-1);

                ViewState["dtDecisionType"] = dtDecisionType;
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
            grvDecisionType.DataSource = (DataTable)ViewState["dtDecisionType"];
            grvDecisionType.DataBind();
        }
        #endregion

        #region grvDecisionType_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvDecisionType_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    //e.Row.Attributes.Add("onmouseover", "MouseEvents(this, event)");
                    //e.Row.Attributes.Add("onmouseout", "MouseEvents(this, event)");

                    if (Session["RoleCode"].ToString() != "admin")
                    {
                        Button btnEdit = (Button)e.Row.FindControl("btnEdit");
                        btnEdit.Enabled = false;

                        Button btnDelete = (Button)e.Row.FindControl("btnDelete");
                        btnDelete.Enabled = false;
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvDecisionType_RowDataBound", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtDecisionType"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtDecisionType"]);

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
            hdnDecisionTypeId.Value = "0";
            pnlViewDecisionType.Visible = false;
            pnlEditDecisionType.Visible = true;
            txtDecisionTypeCode.Text = DecisionTypeMgr.GetNextDecisionTypeCode();
            ScriptManager.GetCurrent(this).SetFocus(txtDecisionTypeName.ClientID);
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                DecisionTypeMgr myDecisionTypeMgr = new DecisionTypeMgr();
                DecisionTypeBAL myDecisionType = new DecisionTypeBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myDecisionType.Code = "Save";
                    if (btnSave.Text == "Update")
                        myDecisionType.Code = "Update";

                    myDecisionType.DecisionTypeId = Convert.ToInt16(hdnDecisionTypeId.Value);
                    myDecisionType.DecisionTypeCode = txtDecisionTypeCode.Text.Trim();
                    myDecisionType.DecisionTypeName = txtDecisionTypeName.Text.Trim();
                    myDecisionType.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myDecisionType.CreatedOn = System.DateTime.Now;
                    myDecisionType.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myDecisionType.UpdatedOn = System.DateTime.Now;
                    myDecisionType.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myDecisionTypeMgr.AddEditDecisionType(myDecisionType);

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
                    myDecisionTypeMgr = null;
                    myDecisionType = null;
                }

                MsgDisplay(sMsg);

                pnlViewDecisionType.Visible = true;
                pnlEditDecisionType.Visible = false;
                LoadDecisionType();
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {

            DataTable dtDecisionType = (DataTable)ViewState["dtDecisionType"];

            DataView dv = new DataView(dtDecisionType);

            dtDecisionType.CaseSensitive = false;

            if (btnSave.Text == "Save")
                dv.RowFilter = " DecisionTypeName = '" + txtDecisionTypeName.Text.Trim().ToLower() + "'";
            if (btnSave.Text == "Update")
                dv.RowFilter = " DecisionTypeName = '" + txtDecisionTypeName.Text.Trim().ToLower() + "' and DecisionTypeId <> " + hdnDecisionTypeId.Value;


            DataTable dtFilter = dv.ToTable("dtDecisionType");

            if (dtFilter.Rows.Count > 0)
            {
                MsgDisplay("Duplicate Decision Type not allowed");
                ScriptManager.GetCurrent(this).SetFocus(txtDecisionTypeName.ClientID);
                return false;
            }


            return true;
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewDecisionType.Visible = true;
            pnlEditDecisionType.Visible = false;
        }
        #endregion

        #region grvDecisionType_RowCommand
        protected void grvDecisionType_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int DecisionTypeId = Convert.ToInt32(e.CommandArgument);

                    pnlViewDecisionType.Visible = false;
                    pnlEditDecisionType.Visible = true;
                    
                    DecisionTypeBAL myDecisionType = new DecisionTypeBAL();
                    myDecisionType = DecisionTypeMgr.GetDecisionTypeByDecisionTypeId(DecisionTypeId);

                    hdnDecisionTypeId.Value = myDecisionType.DecisionTypeId.ToString();
                    txtDecisionTypeCode.Text = myDecisionType.DecisionTypeCode;
                    txtDecisionTypeName.Text = myDecisionType.DecisionTypeName;
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myDecisionType.StatusId.ToString();
                    
                    ScriptManager.GetCurrent(this).SetFocus(txtDecisionTypeName.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int DecisionTypeId = Convert.ToInt32(e.CommandArgument);

                    try
                    {
                        DecisionTypeMgr.DeleteDecisionTypeByDecisionTypeId(DecisionTypeId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }

                    LoadDecisionType();
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
            txtDecisionTypeCode.Text = string.Empty;
            txtDecisionTypeName.Text = string.Empty;
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
