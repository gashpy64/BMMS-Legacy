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
            txtMemberTypeName.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlMemberScope.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            ddlMemberScope.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtDisplayOrder.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            txtDisplayOrder.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + ddlStatus.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
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

        #region ActingUserId
        private int ActingUserId()
        {
            int userId;
            return (Session["UserId"] != null && int.TryParse(Session["UserId"].ToString(), out userId)) ? userId : 0;
        }
        #endregion

        #region grvMemberType_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvMemberType_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            try
            {
                if (e.Row.RowType == DataControlRowType.DataRow)
                {
                    // Visual only: the procedures refuse these anyway (BMMS-Fix-MemberTypes-Step21.sql)
                    DataRowView drv = (DataRowView)e.Row.DataItem;
                    Button btnEdit = (Button)e.Row.FindControl("btnEdit");
                    Button btnDelete = (Button)e.Row.FindControl("btnDelete");

                    if (Convert.ToInt32(drv["IsReserved"]) == 1)
                    {
                        ((Label)e.Row.FindControl("lblReserved")).Visible = true;

                        btnEdit.Enabled = false;
                        btnEdit.ToolTip = "Reserved member type: it cannot be changed";
                        btnDelete.Enabled = false;
                        btnDelete.ToolTip = "Reserved member type: it cannot be deleted";
                    }
                    else if (Convert.ToInt32(drv["CanDelete"]) != 1)
                    {
                        btnDelete.Enabled = false;
                        btnDelete.ToolTip = "In use on " + drv["CommitteeUseCount"].ToString() + " committee and "
                                          + drv["MeetingUseCount"].ToString() + " meeting member rows: it cannot be deleted";
                    }

                    if (Convert.ToInt32(drv["StatusId"]) != 1)
                        e.Row.CssClass = (e.Row.CssClass + " wb-row-inactive").Trim();
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
                MeetingChangeResult result = null;

                try
                {
                    if (btnSave.Text == "Save")
                        myMemberType.Code = "Save";
                    if (btnSave.Text == "Update")
                        myMemberType.Code = "Update";

                    myMemberType.MemberTypeId = Convert.ToInt32(hdnMemberTypeId.Value);
                    myMemberType.MemberTypeCode = txtMemberTypeCode.Text.Trim();
                    myMemberType.MemberTypeName = txtMemberTypeName.Text.Trim();
                    myMemberType.MemberScope = ddlMemberScope.SelectedValue;
                    myMemberType.DisplayOrder = txtDisplayOrder.Text.Trim() == string.Empty ? 0 : Convert.ToInt32(txtDisplayOrder.Text.Trim());
                    myMemberType.StatusId = Convert.ToInt16(ddlStatus.SelectedValue);
                    myMemberType.CreatedOn = System.DateTime.Now;
                    myMemberType.CreatedBy = ActingUserId();
                    myMemberType.UpdatedOn = System.DateTime.Now;
                    myMemberType.UpdatedBy = ActingUserId();
                    myMemberType.ActingUserId = ActingUserId();

                    // Refused for a reserved type, a duplicate or a bad value (BMMS-Fix-MemberTypes-Step21.sql)
                    result = myMemberTypeMgr.AddEditMemberType(myMemberType);
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

                if (result == null)
                    return;

                if (result.Result == 1)
                {
                    MsgDisplay("Successfully Saved");
                    LoadMemberType();
                }
                else
                {
                    MsgDisplay(MemberTypeMgr.RefusalMessage(result, false));

                    // A value the user can correct: keep the form open
                    if ((result.Reason == 3 && result.ReasonDetail != "NotFound") || result.Reason == 5)
                        return;

                    LoadMemberType();
                }
            }
        }
        #endregion

        #region PageValidation
        private bool PageValidation()
        {
            int displayOrder;

            if (ddlMemberScope.SelectedValue != MemberTypeMgr.CommitteeScope && ddlMemberScope.SelectedValue != MemberTypeMgr.MeetingScope)
            {
                MsgDisplay("Used On is required field");
                return false;
            }

            if (txtDisplayOrder.Text.Trim() != string.Empty
                && (!int.TryParse(txtDisplayOrder.Text.Trim(), out displayOrder) || displayOrder < 0 || displayOrder > 9999))
            {
                MsgDisplay("Display Order must be a number from 0 to 9999.");
                return false;
            }

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

                    MemberTypeBAL myMemberType = new MemberTypeBAL();
                    myMemberType = MemberTypeMgr.GetMemberTypeByMemberTypeId(MemberTypeId);

                    if (myMemberType.IsReserved == 1)
                    {
                        MsgDisplay(MemberTypeMgr.ReservedMessage);
                        return;
                    }

                    pnlViewMemberType.Visible = false;
                    pnlEditMemberType.Visible = true;

                    hdnMemberTypeId.Value = myMemberType.MemberTypeId.ToString();
                    txtMemberTypeCode.Text = myMemberType.MemberTypeCode;
                    txtMemberTypeName.Text = myMemberType.MemberTypeName;
                    ddlMemberScope.SelectedValue = myMemberType.MemberScope;
                    txtDisplayOrder.Text = myMemberType.DisplayOrder.ToString();
                    ddlStatus.Enabled = true;
                    ddlStatus.Text = myMemberType.StatusId.ToString();

                    // A type in use keeps its scope: its rows would be on the wrong page
                    int inUse = myMemberType.CommitteeUseCount + myMemberType.MeetingUseCount;
                    ddlMemberScope.Enabled = (inUse == 0);
                    lblScopeNote.Visible = (inUse > 0);
                    lblScopeNote.Text = "In use on " + myMemberType.CommitteeUseCount + " committee and "
                                      + myMemberType.MeetingUseCount + " meeting member rows, so it stays on this page.";

                    ScriptManager.GetCurrent(this).SetFocus(txtMemberTypeCode.ClientID);
                    btnSave.Text = "Update";
                    MsgHide();
                }
                if (e.CommandName == "DeleteRec")
                {
                    int MemberTypeId = Convert.ToInt32(e.CommandArgument);

                    // Refused for a reserved type or a type in use (BMMS-Fix-MemberTypes-Step21.sql)
                    MeetingChangeResult Result = MemberTypeMgr.DeleteMemberTypeByMemberTypeId(MemberTypeId, ActingUserId());

                    if (Result.Result == 1)
                        MsgDisplay("Record Deleted Successfully");
                    else
                        MsgDisplay(MemberTypeMgr.RefusalMessage(Result, true));

                    LoadMemberType();
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvMemberType_RowCommand", ex);
            }
        }
        #endregion

        #region ClearText
        private void ClearText()
        {
            txtMemberTypeCode.Text = string.Empty;
            txtMemberTypeName.Text = string.Empty;
            ddlMemberScope.SelectedValue = "0";
            ddlMemberScope.Enabled = true;
            lblScopeNote.Visible = false;
            txtDisplayOrder.Text = string.Empty;
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
