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
    public partial class Agenda : System.Web.UI.Page
    {
        private string className = "Agenda";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            Common.InitSetup(className);

            if (!IsPostBack)
            {
                MsgHide();
                InitCtrlAttributes();
                LoadDDLlist();
                LoadSubjectType();
                LoadCommittee();
            }
        }
        #endregion

        #region InitCtrlAttributes
        private void InitCtrlAttributes()
        {
            FileUploadAgendaText.Attributes.Add("onchange", "javascript:return UploadClick('" + btnAddAgentaText.ClientID + "')");
            fuAttachment.Attributes.Add("onchange", "javascript:return UploadClick('" + btnAddFile.ClientID + "')");

            btnSave.Attributes.Add("onclick", "return AgendaValidation()");
            ddlSubjectType.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtShortText.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");
            //txtShortText.Attributes.Add("onkeydown", "javascript:ClearErrMsg('" + divErrLogin.ClientID + "','" + txtShortText.ClientID + "');GoToNxtTxtBox(event,'" + btnSave.ClientID + "')");

        }
        #endregion

        #region LoadDDLlist
        private void LoadDDLlist()
        {
            try
            {
                DataTable dtDept = DepartmentMgr.GetDepartmentList(1);

                pnlDepartment.Visible = true;

                Common.LoadDropdownlist(ddlDepartment, dtDept, "DepartmentName", "DepartmentId", true);

                pnlDepartment.Visible = false;
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

        #region ddlCommittee_SelectedIndexChanged
        protected void ddlCommittee_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();
                int CommitteeId = int.Parse(ddlCommittee.SelectedValue.ToString());
                DataTable dtNextMeeting = new DataTable();

                switch (Session["RoleCode"].ToString())
                {
                    case "controller":
                        dtNextMeeting = MeetingMgr.GetMeetingForController(CommitteeId);
                        break;
                    default:
                        dtNextMeeting = MeetingMgr.GetMeetingForUsers(CommitteeId);
                        break;
                }


                Common.LoadDropdownlist(ddlMeeting, dtNextMeeting, "MeetingNo", "MeetingId", false);

                ddlMeeting_SelectedIndexChanged(this, e);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "ddlCommittee_SelectedIndexChanged", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region ddlMeeting_SelectedIndexChanged
        protected void ddlMeeting_SelectedIndexChanged(object sender, EventArgs e)
        {
            try
            {
                MsgHide();

                LoadAgenda();

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

        #region LoadSubjectType
        private void LoadSubjectType()
        {
            try
            {
                DataTable dtSubjectType = new DataTable();
                dtSubjectType = SubjectTypeMgr.GetSubjectTypeList();

                Common.LoadDropdownlist(ddlSubjectType, dtSubjectType, "SubjectTypeName", "SubjectTypeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadSubjectType", ex);
            }
            finally
            {

            }
        }
        #endregion

        #region LoadCommittee
        private void LoadCommittee()
        {
            pnlViewAgenda.Visible = true;
            pnlEditAgenda.Visible = false;

            try
            {
                DataTable dtCommittee = new DataTable();
                dtCommittee = CommitteeMgr.GetCommitteeList(1);

                Common.LoadDropdownlist(ddlCommittee, dtCommittee, "CommitteeName", "CommitteeId", true);
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "LoadMeeting", ex);
            }
            finally
            {

            }
        }
        #endregion


        #region LoadAgenda
        private void LoadAgenda()
        {
            int MeetingId = 0;
            if (ddlMeeting.Items.Count > 0)
                MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue);

            int UserId = int.Parse(Session["UserId"].ToString());

            DataTable dtAgenda = new DataTable();

            switch (Session["RoleCode"].ToString())
            {
                case "controller":
                    dtAgenda = AgendaMgr.GetAgendaByMeetingId(MeetingId);
                    break;
                default:
                    dtAgenda = AgendaMgr.GetAgendaByMeetingIdDeptId(MeetingId, UserId);
                    break;
            }

            ViewState["dtAgenda"] = dtAgenda;
        }
        #endregion

        #region BindGridView
        private void BindGridView()
        {
            grvAgenda.DataSource = (DataTable)ViewState["dtAgenda"];
            grvAgenda.DataBind();
        }
        #endregion


        #region grvAgenda_RowDataBound(object sender, GridViewRowEventArgs e)
        protected void grvAgenda_RowDataBound(object sender, GridViewRowEventArgs e)
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
                Utilities.GoToErrPage(className, "grvAgenda_RowDataBound", ex);
            }
        }
        #endregion

        #region grvAgenda_RowCommand
        protected void grvAgenda_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            try
            {
                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                DataTable dtAgenda = new DataTable();
                dtAgenda = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId);

                if (dtAgenda.Rows.Count <= 0 && Session["RoleCode"].ToString() != "controller")
                {
                    MsgDisplay("Agenda is Finalised for this Committee/Meeting");
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                }
                else
                {
                    if (e.CommandName == "EditRec")
                    {

                        int AgendaId = Convert.ToInt32(e.CommandArgument);

                        DataTable dtAgendaEdit = new DataTable();
                        dtAgendaEdit = AgendaMgr.GetAgendaByAgendaId(AgendaId);


                        if ((Session["RoleCode"].ToString() == "user" || Session["RoleCode"].ToString() == "manager") &&
                            (dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() == "Approved" ||
                            dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() == "Rejected"))
                        {
                            if (dtAgendaEdit.Rows[0]["MgrApprovedStatus"].ToString() == "Rejected")
                            {
                                MsgDisplay("This Agenda was " + dtAgendaEdit.Rows[0]["MgrApprovedStatus"].ToString() + " by Manager");
                                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                            }
                            else
                            {
                                MsgDisplay("This Agenda was " + dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() + " by Controller");
                                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                            }
                        }
                        else if (Session["RoleCode"].ToString() == "user" &&
                                (dtAgendaEdit.Rows[0]["MgrApprovedStatus"].ToString() == "Approved" ||
                                dtAgendaEdit.Rows[0]["MgrApprovedStatus"].ToString() == "Rejected"))
                        {
                            MsgDisplay("This Agenda was " + dtAgendaEdit.Rows[0]["MgrApprovedStatus"].ToString() + " by Manager");
                            ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                        }
                        else
                        {
                            pnlViewAgenda.Visible = false;
                            pnlEditAgenda.Visible = true;

                            txtAgendaNo.Text = dtAgendaEdit.Rows[0]["AgendaNo"].ToString();
                            txtSubjectNo.Text = dtAgendaEdit.Rows[0]["SubjectNo"].ToString();
                            hdnAgendaId.Value = dtAgendaEdit.Rows[0]["AgendaId"].ToString();
                            txtCommittee.Text = dtAgendaEdit.Rows[0]["CommitteeName"].ToString();
                            hdnCommitteeId.Value = dtAgendaEdit.Rows[0]["CommitteeId"].ToString();
                            txtMeetingNo.Text = dtAgendaEdit.Rows[0]["MeetingNo"].ToString();
                            hdnMeetingId.Value = dtAgendaEdit.Rows[0]["MeetingId"].ToString();
                            txtDateOfMeeting.Text = Convert.ToDateTime(dtAgendaEdit.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");


                            if (Session["RoleCode"].ToString() == "controller")
                            {
                                pnlDepartment.Visible = true;
                                txtDepartment.Visible = false;
                                ddlDepartment.Text = dtAgendaEdit.Rows[0]["DepartmentId"].ToString();
                            }
                            else
                            {
                                pnlDepartment.Visible = false;
                                txtDepartment.Visible = true;
                                txtDepartment.Text = dtAgendaEdit.Rows[0]["DepartmentName"].ToString();
                            }

                            hdnDepartmentId.Value = dtAgendaEdit.Rows[0]["DepartmentId"].ToString();
                            ddlSubjectType.Text = dtAgendaEdit.Rows[0]["SubjectTypeId"].ToString();
                            txtShortText.Text = dtAgendaEdit.Rows[0]["ShortText"].ToString();
                            rdoAgendaType.Text = dtAgendaEdit.Rows[0]["AgendaType"].ToString();

                            if (dtAgendaEdit.Rows[0]["AgendaType"].ToString() == "Entry")
                            {
                                ftxtAgendaText.Visible = true;
                                aAgendaText.Visible = false;
                                pnlUploadAgendaText.Visible = false;
                            }
                            else
                            {
                                ftxtAgendaText.Visible = false;
                                aAgendaText.Visible = true;
                                pnlUploadAgendaText.Visible = true;
                                aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString());
                            }

                            ftxtAgendaText.Text = dtAgendaEdit.Rows[0]["AgendaText"].ToString();
                            txtAgendaTextPath.Text = dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString();
                            ftxtProposedResolution.Text = dtAgendaEdit.Rows[0]["ProposedResolution"].ToString();

                            string[] attFiles = dtAgendaEdit.Rows[0]["FilePath"].ToString().Split(',');
                            DataTable dtAttFiles = new DataTable();
                            dtAttFiles.Columns.Add("FilePathOrg");
                            dtAttFiles.Columns.Add("FilePath");
                            dtAttFiles.Columns.Add("DisplayName");

                            for (int i = 0; i < attFiles.Length; i++)
                            {
                                if (attFiles[i].ToString() != string.Empty)
                                {
                                    DataRow dr = dtAttFiles.NewRow();
                                    dr["FilePathOrg"] = attFiles[i].ToString();
                                    dr["FilePath"] = "../Files/AgendaAttach/" + attFiles[i].ToString();
                                    dr["DisplayName"] = attFiles[i].ToString();
                                    dtAttFiles.Rows.Add(dr);
                                }
                            }

                            ViewState["dtAttFiles"] = dtAttFiles;

                            grvAttachedFiles.DataSource = dtAttFiles;
                            grvAttachedFiles.DataBind();

                            if (Session["RoleCode"].ToString() == "user")
                            {
                                pnlManagerComments.Visible = false;
                                pnlControllerComments.Visible = false;
                                txtSubjectNo.ReadOnly = true;
                            }

                            if (Session["RoleCode"].ToString() == "manager")
                            {
                                pnlManagerComments.Visible = true;
                                pnlControllerComments.Visible = false;
                                txtSubjectNo.ReadOnly = true;
                                ftxtManagerComments.Text = dtAgendaEdit.Rows[0]["MgrComments"].ToString();
                            }

                            if (Session["RoleCode"].ToString() == "controller")
                            {
                                pnlManagerComments.Visible = true;
                                pnlControllerComments.Visible = true;
                                
                                if (txtSubjectNo.Text.Trim() != string.Empty)
                                    txtSubjectNo.ReadOnly = false;
                                else
                                    txtSubjectNo.ReadOnly = true;

                                ftxtManagerComments.Text = dtAgendaEdit.Rows[0]["MgrComments"].ToString();
                                ftxtControllerComments.Text = dtAgendaEdit.Rows[0]["ControllerComments"].ToString();
                            }




                            ScriptManager.GetCurrent(this).SetFocus(txtShortText.ClientID);
                            btnSave.Text = "Update";
                            MsgHide();
                        }

                    }
                    if (e.CommandName == "DeleteRec")
                    {
                        int AgendaId = Convert.ToInt32(e.CommandArgument);

                        try
                        {
                            AgendaMgr.DeleteAgendaByAgendaId(AgendaId);


                            /// Subject no auto regeneration based on Department

                            //DataTable dt = AgendaMgr.GetAgendaApprovedByMeetingId(MeetingId, -1);

                            //for (int i = 0; i < dt.Rows.Count; i++)
                            //{
                            //    int AgendaIdTemp = int.Parse(dt.Rows[i]["AgendaId"].ToString());
                            //    int SubjectNo = i + 1;
                            //    AgendaMgr.UpdateSubjectNoByAgendaId(AgendaIdTemp, SubjectNo);
                            //}

                            MsgDisplay("Record Deleted Successfully");
                        }
                        catch (Exception ex)
                        {
                            Utilities.WriteErrorLog(className, "grvAgenda_RowCommand", ex.ToString());
                            string _ErrMsg = Common.GetAppSetting("delete_reference");
                            MsgDisplay(_ErrMsg);
                        }

                        LoadAgenda();
                        BindGridView();
                    }
                }
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "grvBranchDetails_RowCommand", ex);
            }
        }
        #endregion

        #region grvRecord_Sorting
        protected void grvRecord_Sorting(object sender, GridViewSortEventArgs e)
        {
            try
            {
                ViewState["dtAgenda"] = Utilities.GridViewDataTableSorting(sender, e, (DataTable)ViewState["dtAgenda"]);

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
            if (ddlCommittee.Text == "0")
            {
                MsgDisplay("Please Select Committee Name");
                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
            }
            else if (ddlMeeting.Items.Count <= 0)
            {
                MsgDisplay("No new meeting available for this Committee");
                ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
            }
            else
            {
                int CommitteeId = int.Parse(ddlCommittee.SelectedValue);
                int MeetingId = int.Parse(ddlMeeting.SelectedValue.ToString());

                DataTable dtAgenda = new DataTable();
                dtAgenda = AgendaMgr.CheckAgendaFinalizeByMeetingId(MeetingId);

                if (dtAgenda.Rows.Count <= 0 && Session["RoleCode"].ToString() != "controller")
                {
                    MsgDisplay("Agenda is Finalised for this Committee/Meeting");
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                }
                else
                {
                    ClearText();

                    pnlViewAgenda.Visible = false;
                    pnlEditAgenda.Visible = true;

                    string nextAgendaNo = AgendaMgr.GetNextAgendaNo(CommitteeId, MeetingId);

                    DataTable dtMeeting = new DataTable();
                    dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

                    txtAgendaNo.Text = nextAgendaNo;
                    txtSubjectNo.Text = string.Empty;
                    txtCommittee.Text = ddlCommittee.SelectedItem.Text.ToString();
                    hdnCommitteeId.Value = ddlCommittee.SelectedValue;
                    txtMeetingNo.Text = ddlMeeting.SelectedValue.ToString();
                    hdnMeetingId.Value = ddlMeeting.SelectedItem.Text.ToString();
                    txtDateOfMeeting.Text = Convert.ToDateTime(dtMeeting.Rows[0]["MeetingDate"].ToString()).ToString("dd-MMM-yyyy");

                    UserBAL userBal = new UserBAL();
                    userBal = UserMgr.GetUserByUserId(int.Parse(Session["UserId"].ToString()));

                    if (Session["RoleCode"].ToString() == "controller")
                    {
                        pnlDepartment.Visible = true;
                        txtDepartment.Visible = false;
                        hdnDepartmentId.Value = string.Empty;
                        ddlDepartment.SelectedIndex = 0;
                        txtSubjectNo.ReadOnly = false;
                        pnlManagerComments.Visible = false;
                        pnlControllerComments.Visible = true;
                    }
                    if (Session["RoleCode"].ToString() == "manager")
                    {
                        pnlDepartment.Visible = false;
                        txtDepartment.Visible = true;
                        txtDepartment.Text = userBal.DepartmentName.ToString();
                        hdnDepartmentId.Value = userBal.DepartmentId.ToString();
                        txtSubjectNo.ReadOnly = true;
                        pnlControllerComments.Visible = false;
                        pnlManagerComments.Visible = true;
                    }
                    if (Session["RoleCode"].ToString() == "user")
                    {
                        pnlManagerComments.Visible = false;
                        pnlControllerComments.Visible = false;
                        pnlDepartment.Visible = false;
                        txtDepartment.Visible = true;
                        txtDepartment.Text = userBal.DepartmentName.ToString();
                        hdnDepartmentId.Value = userBal.DepartmentId.ToString();
                        txtSubjectNo.ReadOnly = true;
                    }

                    txtShortText.Text = string.Empty;
                    rdoAgendaType.Text = "Entry";
                    aAgendaText.Visible = false;
                    pnlUploadAgendaText.Visible = false;
                    ftxtAgendaText.Text = string.Empty;
                    ftxtProposedResolution.Text = string.Empty;
                    ftxtControllerComments.Text = string.Empty;
                    ftxtManagerComments.Text = string.Empty;

                    ViewState["dtAttFiles"] = null;

                    DataTable dtAttFiles = new DataTable();
                    dtAttFiles.Columns.Add("FilePathOrg");
                    dtAttFiles.Columns.Add("FilePath");
                    dtAttFiles.Columns.Add("DisplayName");

                    grvAttachedFiles.DataSource = dtAttFiles;
                    grvAttachedFiles.DataBind();

                    hdnAgendaId.Value = "0";
                    ScriptManager.GetCurrent(this).SetFocus(ddlSubjectType.ClientID);
                    btnSave.Text = "Save";
                }
            }

        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (PageValidation())
            {
                AgendaMgr myAgendaMgr = new AgendaMgr();
                AgendaBAL myAgenda = new AgendaBAL();
                string sMsg = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myAgenda.Code = "Save";
                    if (btnSave.Text == "Update")
                        myAgenda.Code = "Update";

                    myAgenda.AgendaId = Convert.ToInt16(hdnAgendaId.Value);
                    myAgenda.AgendaNo = txtAgendaNo.Text.Trim();

                    myAgenda.SubjectNo = txtSubjectNo.Text.Trim();

                    myAgenda.CommitteeId = Convert.ToInt16(hdnCommitteeId.Value);
                    myAgenda.MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue.ToString());

                    if (Session["RoleCode"].ToString() == "controller")
                        myAgenda.DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString());
                    else
                        myAgenda.DepartmentId = int.Parse(hdnDepartmentId.Value.ToString());

                    myAgenda.SubjectTypeId = Convert.ToInt16(ddlSubjectType.SelectedValue);
                    myAgenda.ShortText = txtShortText.Text.Trim();

                    myAgenda.AgendaType = rdoAgendaType.SelectedValue.ToString();

                    string strAgendaText = ftxtAgendaText.Text.Trim();
                    myAgenda.AgendaText = strAgendaText;

                    myAgenda.AgendaTextPath = txtAgendaTextPath.Text.Trim();

                    myAgenda.ProposedResolution = HTML_Report.ReplaceRichTextFont(ftxtProposedResolution.Text.Trim());

                    myAgenda.FilePath = GetFilePathList();

                    myAgenda.MgrComments = ftxtManagerComments.Text.Trim();
                    myAgenda.ControllerComments = ftxtControllerComments.Text.Trim();

                    myAgenda.CurrentStatus = "New";
                    myAgenda.CreatedOn = System.DateTime.Now;
                    myAgenda.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myAgenda.UpdatedOn = System.DateTime.Now;
                    myAgenda.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    string strResult = "Success";

                    if (btnSave.Text == "Save")
                        strResult = GenerateMail();

                    if (strResult == "Success")
                    {
                        switch (Session["RoleCode"].ToString())
                        {
                            case "controller":

                                myAgenda.ControllerComments = ftxtControllerComments.Text.Trim();

                                myAgendaMgr.AddEditAgendaByController(myAgenda);

                                break;

                            case "manager":

                                myAgenda.MgrComments = ftxtManagerComments.Text.Trim();

                                myAgendaMgr.AddEditAgendaByManager(myAgenda);

                                break;

                            default:
                                myAgendaMgr.AddEditAgenda(myAgenda);
                                break;
                        }

                        sMsg = "Successfully Saved";
                    }
                    else
                    {
                        sMsg = strResult;
                    }

                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "btnSave_Click", ex);
                }
                finally
                {
                    myAgendaMgr = null;
                    myAgenda = null;
                }

                MsgDisplay(sMsg);

                pnlViewAgenda.Visible = true;
                pnlEditAgenda.Visible = false;

                LoadAgenda();
                BindGridView();
            }
        }
        #endregion

        #region GetFilePathList()
        private string GetFilePathList()
        {
            string strFilePath = string.Empty;

            foreach (GridViewRow gr in grvAttachedFiles.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    HiddenField hdnFilePath = (HiddenField)gr.FindControl("hdnFilePath");
                    CheckBox cbAttach = (CheckBox)gr.FindControl("cbAttach");

                    if (cbAttach.Checked == true)
                    {
                        strFilePath += hdnFilePath.Value.ToString() + ",";
                    }
                }
            }

            return strFilePath;
        }
        #endregion


        #region PageValidation
        private bool PageValidation()
        {

            if (pnlDepartment.Visible == true)
            {
                if (ddlDepartment.Text == "0")
                {
                    MsgDisplay("Department name is required field.");
                    ScriptManager.GetCurrent(this).SetFocus(ddlDepartment.ClientID);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0); document.getElementById('divProgress').style.visibility = 'hidden'", true);
                    return false;
                }
            }


            return true;
        }
        #endregion

        #region GenerateMail
        private string GenerateMail()
        {
            string ToMailId = string.Empty;
            string Bcc = string.Empty;

            int mgrUserId = 0;

            DataTable dtUser = UserMgr.GetUserList();
            if (dtUser.Rows.Count > 0)
            {
                for (int i = 0; i <= dtUser.Rows.Count - 1; i++)
                {
                    if (dtUser.Rows[i]["UserId"].ToString() == Session["UserId"].ToString())
                    {
                        ToMailId = dtUser.Rows[i]["EmailId"].ToString();
                        mgrUserId = Convert.ToInt16(dtUser.Rows[i]["ManagerId"].ToString());
                        break;
                    }
                }
            }
            if (dtUser.Rows.Count > 0)
            {
                for (int i = 0; i <= dtUser.Rows.Count - 1; i++)
                {
                    if (dtUser.Rows[i]["UserId"].ToString() == mgrUserId.ToString())
                    {
                        Bcc += dtUser.Rows[i]["EmailId"].ToString();
                        break;
                    }
                }
            }


            string Subject = "Agenda (" + txtAgendaNo.Text.Trim() + ") has been Created";
            string BodyText = string.Empty;
            BodyText += "<table>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Agenda No <br /><br />";
            BodyText += "Committee Name <br /><br />";
            BodyText += "Meeting No <br /><br />";
            BodyText += "Meeting Date <br /><br />";
            BodyText += "Department <br /><br />";
            BodyText += "Subject Type <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + txtAgendaNo.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtCommittee.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtMeetingNo.Text.Trim() + "<br /><br />";
            BodyText += ": " + txtDateOfMeeting.Text.Trim() + "<br /><br />";

            if (Session["RoleCode"].ToString() == "controller")
                BodyText += ": " + ddlDepartment.SelectedItem.Text.ToString().Trim() + "<br /><br />";
            else
                BodyText += ": " + txtDepartment.Text.Trim() + "<br /><br />";

            BodyText += ": " + ddlSubjectType.SelectedItem.Text.Trim() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "<tr>";
            BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
            BodyText += "Short Text <br /><br />";
            //BodyText += " <br /><br />";
            BodyText += "</td>";

            BodyText += "<td style='text-align:left; font-weight:normal;'>";
            BodyText += ": " + txtShortText.Text.Trim() + "<br /><br />";
            //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
            BodyText += "</td>";

            BodyText += "</tr>";

            BodyText += "</table>";

            string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);

            

            return result;

        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            MsgHide();
            pnlViewAgenda.Visible = true;
            pnlEditAgenda.Visible = false;
        }
        #endregion

        #region ClearText
        private void ClearText()
        {
            txtAgendaNo.Text = string.Empty;
            txtSubjectNo.Text = string.Empty;
            txtCommittee.Text = string.Empty;
            txtMeetingNo.Text = string.Empty;
            txtDateOfMeeting.Text = string.Empty;
            txtDepartment.Text = string.Empty;
            hdnDepartmentId.Value = string.Empty;
            ddlSubjectType.Text = "0";
            txtShortText.Text = string.Empty;
            ftxtAgendaText.Text = string.Empty;
            ftxtProposedResolution.Text = string.Empty;
        }
        #endregion

        #region rdoAgendaType_SelectedIndexChanged
        protected void rdoAgendaType_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (rdoAgendaType.Text == "Entry")
            {
                ftxtAgendaText.Visible = true;
                ftxtAgendaText.Text = string.Empty;
                aAgendaText.Visible = false;
                pnlUploadAgendaText.Visible = false;
            }
            if (rdoAgendaType.Text == "Upload")
            {
                ftxtAgendaText.Visible = false;
                aAgendaText.Visible = false;
                pnlUploadAgendaText.Visible = true;
            }
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

        #region btnAddFile_Click
        protected void btnAddFile_Click(object sender, EventArgs e)
        {
            if (fuAttachment.HasFile)
            {

                string fName = string.Empty;
                string fNameWithPath = string.Empty;

                fName = "Attach-" + txtAgendaNo.Text + "-" + fuAttachment.FileName;
                fNameWithPath = MapPath("~/Files/AgendaAttach/" + fName);

                string strExt = System.IO.Path.GetExtension(fNameWithPath).ToLower();

                if (strExt.Equals(".pdf"))
                {

                    DataTable dtAttFiles = new DataTable();

                    if (ViewState["dtAttFiles"] == null)
                    {
                        dtAttFiles = new DataTable();
                        dtAttFiles.Columns.Add("FilePathOrg");
                        dtAttFiles.Columns.Add("FilePath");
                        dtAttFiles.Columns.Add("DisplayName");
                    }
                    else
                    {
                        dtAttFiles = (DataTable)ViewState["dtAttFiles"];
                    }

                    fuAttachment.SaveAs(fNameWithPath);

                    DataRow dr = dtAttFiles.NewRow();
                    dr["FilePathOrg"] = fName;
                    dr["FilePath"] = "../Files/AgendaAttach/" + fName;
                    dr["DisplayName"] = fName;
                    dtAttFiles.Rows.Add(dr);

                    ViewState["dtAttFiles"] = dtAttFiles;

                    grvAttachedFiles.DataSource = dtAttFiles;
                    grvAttachedFiles.DataBind();
                }
                else
                {
                    MsgDisplay("Attachment upload suppport pdf files only.");
                    ScriptManager.GetCurrent(this).SetFocus(fuAttachment.ClientID);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0); document.getElementById('divProgress').style.visibility = 'hidden'", true);
                }
            }

        }
        #endregion

        #region btnAddAgentaText_Click
        protected void btnAddAgentaText_Click(object sender, EventArgs e)
        {
            MsgHide();

            if (FileUploadAgendaText.HasFile)
            {

                string fName = string.Empty;
                string fPath = string.Empty;
                string fNameWithPath = string.Empty;

                fName = txtAgendaNo.Text + "-" + FileUploadAgendaText.FileName;
                fPath = MapPath("~/Files/AgendaText/");
                fNameWithPath = fPath + fName;

                //string[] strSep = fName.Split('.');
                //int arrLength = strSep.Length - 1;
                string strExt = System.IO.Path.GetExtension(fNameWithPath).ToLower(); // strSep[arrLength].ToString().ToUpper();

                if (strExt.Equals(".pdf"))
                {
                    FileUploadAgendaText.SaveAs(fNameWithPath);

                    //string strPathToConvert = fName + ".htm";
                    aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + fName);
                    txtAgendaTextPath.Text = fName; // strPathToConvert;

                    aAgendaText.Visible = true;

                    ftxtAgendaText.Visible = false;
                    //ftxtAgendaText.Text = DocToString.ConvertDocToString(fName, fPath);
                }
                else
                {
                    aAgendaText.Visible = false;

                    ftxtAgendaText.Visible = false;

                    MsgDisplay("Agenda text upload suppport pdf files only.");
                    ScriptManager.GetCurrent(this).SetFocus(FileUploadAgendaText.ClientID);
                    ScriptManager.RegisterStartupScript(this, this.GetType(), "scroll", "window.scrollTo(0,0); document.getElementById('divProgress').style.visibility = 'hidden'", true);
                }

            }

        }
        #endregion
    }
}
