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
    public partial class MemberType : System.Web.UI.Page
    {
        private string className = "MemberType";

        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadMemberType();
                LoadStatus();
            }
        }

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            btnSave.Attributes.Add("onclick", "return MemberTypeValidation()");
            txtMemberTypeCode.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtMemberTypeName.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtMemberTypeName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
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

        #region LoadMemberType
        private void LoadMemberType()
        {
            pnlViewMemberType.Visible = true;
            pnlEditMemberType.Visible = false;

            try
            {
                DataTable dtMemberType = new DataTable();
                dtMemberType = MemberTypeMgr.GetMemberTypeList(-1);

                ViewState["DataTable"] = dtMemberType;
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
            grvMemberType.DataSource = (DataTable)ViewState["DataTable"];
            grvMemberType.DataBind();
        }
        #endregion

        #region grvMemberType_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMemberType_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvMemberType_RowDataBound", ex);
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
            ClearText();
            hdnMemberTypeId.Value = "0";
            pnlViewMemberType.Visible = false;
            pnlEditMemberType.Visible = true;
            //txtMemberTypeCode.Text = MemberTypeMgr.GetNextMemberTypeCode();
            ScriptManager.GetCurrent(this).SetFocus(txtMemberTypeCode.ClientID);
            ddlStatus.Enabled = false;
            btnSave.Text = "Save";
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                MemberTypeMgr myMemberTypeMgr = new MemberTypeMgr();
                MemberTypeBAL myMemberType = new MemberTypeBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myMemberType.Code = "Save";
                    if (btnSave.Text == "Update")
                        myMemberType.Code = "Update";

                    myMemberType.MemberTypeId = Convert.ToInt16(hdnMemberTypeId.Value);
                    myMemberType.MemberTypeCode = txtMemberTypeCode.Text.Trim();
                    myMemberType.MemberTypeName = txtMemberTypeName.Text.Trim();
                    myMemberType.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myMemberType.CreatedOn = System.DateTime.Now;
                    myMemberType.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myMemberType.UpdatedOn = System.DateTime.Now;
                    myMemberType.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    int result = myMemberTypeMgr.AddEditMemberType(myMemberType);

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
                    myMemberTypeMgr = null;
                    myMemberType = null;
                }

                MsgDisplay(sMsg);

                pnlViewMemberType.Visible = true;
                pnlEditMemberType.Visible = false;
                LoadMemberType();
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
            pnlViewMemberType.Visible = true;
            pnlEditMemberType.Visible = false;
        }
        #endregion

        #region grvMemberType_RowCommand
        protected void grvMemberType_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                if (e.CommandName == "EditRec")
                {
                    int MemberTypeId = Convert.ToInt32(e.CommandArgument);

                    pnlViewMemberType.Visible = false;
                    pnlEditMemberType.Visible = true;
                    
                    MemberTypeBAL myMemberType = new MemberTypeBAL();
                    myMemberType = MemberTypeMgr.GetMemberTypeByMemberTypeId(MemberTypeId);

                    hdnMemberTypeId.Value = myMemberType.MemberTypeId.ToString();
                    txtMemberTypeCode.Text = myMemberType.MemberTypeCode;
                    txtMemberTypeName.Text = myMemberType.MemberTypeName;
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myMemberType.StatusId.ToString();
                    
                    ScriptManager.GetCurrent(this).SetFocus(txtMemberTypeCode.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int MemberTypeId = Convert.ToInt32(e.CommandArgument);
                    
                    try
                    {
                        MemberTypeMgr.DeleteMemberTypeByMemberTypeId(MemberTypeId);

                        MsgDisplay("Record Deleted Successfully");
                    }
                    catch (Exception ex)
                    {
                        string _ErrMsg = Common.GetAppSetting("delete_reference");
                        MsgDisplay(_ErrMsg);
                    }
                    LoadMemberType();
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
            txtMemberTypeCode.Text = string.Empty;
            txtMemberTypeName.Text = string.Empty;
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
