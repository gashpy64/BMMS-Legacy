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
using BMMS.Controls;
using BMMSBAL;

namespace BMMS.Master
{
    public partial class Agenda : System.Web.UI.Page
    {
        private string className = "Agenda";

        // A new item only up to the whole meeting date (step M4, the rule of step M1)
        private const string MeetingDatePassedMessage = "The meeting date has passed, so agenda items can no longer be added to this meeting.";

        // Edit, Update and Delete of an item only up to the whole meeting date, for every role (step M5)
        private const string ItemMeetingDatePassedMessage = "The meeting date has passed, so agenda items can no longer be edited or deleted.";

        // The item is saved before the mail goes out (step M2); the mail error itself is in the error log
        // Step N2: a saved attachment or agenda text name that is not a plain file name
        private const string FileNameNotValidMessage = "An attached file name is not valid. Remove the file and attach it again.";

        // Step N2: the agenda text file name the server set (Edit or upload), not the posted text box
        private const string AgendaTextPathKey = "AgendaTextPath";

        private const string MailNotSentMessage ="The agenda item was saved, but the mail could not be sent. The error is in the error log.";

        // Step ML1: the update mail failed (or step 37 is not installed); the Update itself is saved
        private const string UpdateMailNotSentMessage = "The agenda item was updated, but the mail could not be sent. The error is in the error log.";

        // Step C2: Edit and Update by the rule of the list (BMMS-Fix-ManagerDepartment-Step33.sql); Delete for the
        // Controller only. Nothing is opened, saved or deleted on a refusal.
        private const string ItemNotOwnMessage = "You can open only the agenda items you entered.";
        private const string ItemNotInDepartmentMessage = "You can open only the agenda items of your department and the items you entered.";
        private const string DeleteControllerOnlyMessage = "Only the Controller can delete agenda items. Nothing was deleted.";

        // Step C2: a new item of a User or Manager takes the department from the user master, read at Save
        private const string DepartmentMismatchMessage = "The department does not match your department. Nothing was saved.";

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
                int ActingUserId = int.Parse(Session["UserId"].ToString());

                // Finalized agenda: only the Controller, with the System Settings option on, until the
                // minutes are finalized (BMMS-Fix-MeetingLocks-Step16.sql)
                MeetingChangeResult agendaLock = AgendaMgr.GetAgendaLock(MeetingId, ActingUserId);

                if (agendaLock.Result != 1)
                {
                    MsgDisplay(agendaLock.RefusalMessage());
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                }
                else
                {
                    if (e.CommandName == "EditRec")
                    {

                        int AgendaId = Convert.ToInt32(e.CommandArgument);

                        DataTable dtAgendaEdit = new DataTable();
                        dtAgendaEdit = AgendaMgr.GetAgendaByAgendaId(AgendaId);


                        string accessMsg = dtAgendaEdit.Rows.Count > 0 ? CheckItemAccess(dtAgendaEdit.Rows[0]) : "Success";

                        if (accessMsg != "Success")
                        {
                            // Step C2: not an item of this user's list; the form is not opened
                            MsgDisplay(accessMsg);
                            ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                        }
                        else if (dtAgendaEdit.Rows.Count > 0 && !MeetingMgr.IsMeetingOpenForChange(dtAgendaEdit.Rows[0]["MeetingDate"], DateTime.Today))
                        {
                            // Every role; Update checks again (step M5)
                            MsgDisplay(ItemMeetingDatePassedMessage);
                            ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                        }
                        else if ((Session["RoleCode"].ToString() == "user" || Session["RoleCode"].ToString() == "manager") &&
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
                            txtDateOfMeeting.Text = FormatDate(dtAgendaEdit.Rows[0]["MeetingDate"]);   // a meeting with no date is open (step M5)


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
                                aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + Uri.EscapeDataString(dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString()));
                            }

                            ftxtAgendaText.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["AgendaText"].ToString());
                            txtAgendaTextPath.Text = dtAgendaEdit.Rows[0]["AgendaTextPath"].ToString();
                            ViewState[AgendaTextPathKey] = txtAgendaTextPath.Text;
                            ftxtProposedResolution.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["ProposedResolution"].ToString());

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
                                    dr["FilePath"] = "../Files/AgendaAttach/" + Uri.EscapeDataString(attFiles[i].ToString());
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
                                ftxtManagerComments.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["MgrComments"].ToString());
                            }

                            if (Session["RoleCode"].ToString() == "controller")
                            {
                                pnlManagerComments.Visible = true;
                                pnlControllerComments.Visible = true;
                                
                                // Step N5: the number of a Controller-approved item cannot be changed
                                if (dtAgendaEdit.Rows[0]["ControllerApprovedStatus"].ToString() == "Approved")
                                    txtSubjectNo.ReadOnly = true;
                                else if (txtSubjectNo.Text.Trim() != string.Empty)
                                    txtSubjectNo.ReadOnly = false;
                                else
                                    txtSubjectNo.ReadOnly = true;

                                ftxtManagerComments.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["MgrComments"].ToString());
                                ftxtControllerComments.Text = HtmlCleaner.Clean(dtAgendaEdit.Rows[0]["ControllerComments"].ToString());
                            }

                            ApplyCommentRoles();   // step C1
                            ShowCommentCaptions(dtAgendaEdit.Rows[0]);   // step UN4



                            ScriptManager.GetCurrent(this).SetFocus(txtShortText.ClientID);
                            btnSave.Text = "Update";
                            MsgHide();
                        }

                    }
                    if (e.CommandName == "DeleteRec")
                    {
                        int AgendaId = Convert.ToInt32(e.CommandArgument);

                        if (Session["RoleCode"].ToString() != "controller")
                        {
                            // Step C2: the button is shown to the Controller only; a forged post is refused here
                            MsgDisplay(DeleteControllerOnlyMessage);
                        }
                        else if (!IsItemMeetingOpen(AgendaId))
                        {
                            // Every role; nothing is deleted (step M5)
                            MsgDisplay(ItemMeetingDatePassedMessage);
                        }
                        else
                        {
                            try
                            {
                                MeetingChangeResult deleteResult = AgendaMgr.DeleteAgendaByAgendaId(AgendaId, ActingUserId);


                                /// Subject no auto regeneration based on Department

                                //DataTable dt = AgendaMgr.GetAgendaApprovedByMeetingId(MeetingId, -1);

                                //for (int i = 0; i < dt.Rows.Count; i++)
                                //{
                                //    int AgendaIdTemp = int.Parse(dt.Rows[i]["AgendaId"].ToString());
                                //    int SubjectNo = i + 1;
                                //    AgendaMgr.UpdateSubjectNoByAgendaId(AgendaIdTemp, SubjectNo);
                                //}

                                MsgDisplay(deleteResult.Result == 1 ? "Record Deleted Successfully" : deleteResult.RefusalMessage(), deleteResult.Result == 1 ? MessageKind.Success : MessageKind.Warning);
                            }
                            catch (Exception ex)
                            {
                                Utilities.WriteErrorLog(className, "grvAgenda_RowCommand", ex.ToString());
                                string _ErrMsg = Common.GetAppSetting("delete_reference");
                                MsgDisplay(_ErrMsg);
                            }
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

                // Same rule as the agenda procedures (BMMS-Fix-MeetingLocks-Step16.sql)
                MeetingChangeResult agendaLock = AgendaMgr.GetAgendaLock(MeetingId, int.Parse(Session["UserId"].ToString()));

                DataTable dtMeeting = new DataTable();
                dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);

                if (agendaLock.Result != 1)
                {
                    MsgDisplay(agendaLock.RefusalMessage());
                    ScriptManager.GetCurrent(this).SetFocus(ddlCommittee.ClientID);
                }
                else if (!MeetingMgr.IsMeetingOpenForChange(dtMeeting.Rows[0]["MeetingDate"], DateTime.Today))
                {
                    // The Agenda Submission Date blocks nothing; Save checks the meeting date again (step M4)
                    MsgDisplay(MeetingDatePassedMessage);
                    ScriptManager.GetCurrent(this).SetFocus(ddlMeeting.ClientID);
                }
                else
                {
                    ClearText();

                    pnlViewAgenda.Visible = false;
                    pnlEditAgenda.Visible = true;

                    string nextAgendaNo = AgendaMgr.GetNextAgendaNo(CommitteeId, MeetingId);

                    txtAgendaNo.Text = nextAgendaNo;
                    txtSubjectNo.Text = string.Empty;
                    txtCommittee.Text = ddlCommittee.SelectedItem.Text.ToString();
                    hdnCommitteeId.Value = ddlCommittee.SelectedValue;
                    txtMeetingNo.Text  = ddlMeeting.SelectedItem.Text;
                    hdnMeetingId.Value = ddlMeeting.SelectedValue;
                    txtDateOfMeeting.Text = FormatDate(dtMeeting.Rows[0]["MeetingDate"]);   // a meeting with no date is open (step M4)

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
                    ApplyCommentRoles();   // step C1
                    ShowCommentCaptions(null);   // step UN4: a new item has no who and when

                    ViewState["dtAttFiles"] = null;

                    // Step N2: a new item starts without an agenda text file (before, the name of an item opened
                    // earlier stayed in the hidden box)
                    ViewState[AgendaTextPathKey] = string.Empty;
                    txtAgendaTextPath.Text = string.Empty;

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
            // Step A2a: rich text over the limit (Web.config): nothing is saved
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            if (PageValidation())
            {
                AgendaMgr myAgendaMgr = new AgendaMgr();
                AgendaBAL myAgenda = new AgendaBAL();
                string sMsg = string.Empty;
                bool saved = false;
                bool mailFailed = false;
                string submissionNotice = string.Empty;

                try
                {
                    if (btnSave.Text == "Save")
                        myAgenda.Code = "Save";
                    if (btnSave.Text == "Update")
                        myAgenda.Code = "Update";

                    myAgenda.AgendaId = Convert.ToInt16(hdnAgendaId.Value);
                    myAgenda.AgendaNo = txtAgendaNo.Text.Trim();

                    myAgenda.SubjectNo = txtSubjectNo.Text.Trim();

                    // Step C1: the comments as saved now (empty on a new item); the column of another role is
                    // written back unchanged
                    string savedMgrComments = string.Empty;
                    string savedControllerComments = string.Empty;

                    // Step N5, Update, every role: a Controller-approved item always keeps its saved Subject No,
                    // whatever was posted (also when it was approved after this form was opened). For other
                    // items an empty box keeps the saved value (NULL stays NULL, an old 0 stays 0); a typed number is used.
                    if (btnSave.Text == "Update")
                    {
                        DataTable dtSaved = AgendaMgr.GetAgendaByAgendaId(myAgenda.AgendaId);
                        if (dtSaved.Rows.Count > 0 &&
                            (dtSaved.Rows[0]["ControllerApprovedStatus"].ToString() == "Approved" || myAgenda.SubjectNo == string.Empty))
                            myAgenda.SubjectNo = dtSaved.Rows[0]["SubjectNo"].ToString().Trim();

                        if (dtSaved.Rows.Count > 0)
                        {
                            savedMgrComments = dtSaved.Rows[0]["MgrComments"].ToString();
                            savedControllerComments = dtSaved.Rows[0]["ControllerComments"].ToString();
                        }
                    }

                    myAgenda.CommitteeId = Convert.ToInt16(hdnCommitteeId.Value);
                    myAgenda.MeetingId = Convert.ToInt16(ddlMeeting.SelectedValue.ToString());

                    // Step C2: the Controller chooses the department. For every other role a new item (Save) takes the
                    // department of the user master, read now (as the Edit check does), never the posted hidden field
                    // hdnDepartmentId; a posted value that differs is refused (departmentRefusal) and nothing is saved.
                    // An Update of a User or Manager does not write the department (spr_AddEditAgenda and
                    // spr_AddEditAgendaByManager leave Agenda.DepartmentId unchanged), so the posted value is passed
                    // as before, read without an error for a value that is not a number.
                    string departmentRefusal = "Success";

                    if (Session["RoleCode"].ToString() == "controller")
                        myAgenda.DepartmentId = int.Parse(ddlDepartment.SelectedValue.ToString());
                    else
                    {
                        int postedDepartmentId;
                        bool postedDepartmentValid = int.TryParse(hdnDepartmentId.Value, out postedDepartmentId);

                        if (btnSave.Text == "Save")
                        {
                            UserBAL actingUserForDepartment = UserMgr.GetUserByUserId(int.Parse(Session["UserId"].ToString()));
                            myAgenda.DepartmentId = actingUserForDepartment.DepartmentId;

                            if (!postedDepartmentValid || postedDepartmentId != actingUserForDepartment.DepartmentId)
                                departmentRefusal = DepartmentMismatchMessage;
                        }
                        else
                            myAgenda.DepartmentId = postedDepartmentValid ? postedDepartmentId : 0;
                    }

                    myAgenda.SubjectTypeId = Convert.ToInt16(ddlSubjectType.SelectedValue);
                    myAgenda.ShortText = txtShortText.Text.Trim();

                    myAgenda.AgendaType = rdoAgendaType.SelectedValue.ToString();

                    string strAgendaText = ftxtAgendaText.Text.Trim();
                    myAgenda.AgendaText = strAgendaText;

                    // Step N2: the file names the server set, never the posted hidden fields
                    myAgenda.AgendaTextPath = ViewState[AgendaTextPathKey] == null ? string.Empty : ViewState[AgendaTextPathKey].ToString();

                    myAgenda.ProposedResolution = HTML_Report.ReplaceRichTextFont(ftxtProposedResolution.Text.Trim());

                    myAgenda.FilePath = GetFilePathList();

                    bool fileNamesValid = myAgenda.FilePath != null &&
                        (myAgenda.AgendaTextPath == string.Empty || SafeFileName.IsPlainName(myAgenda.AgendaTextPath));

                    // Step C1: each comment only from the editor of the role that writes it (Manager Comments by the
                    // Manager, Controller Comments by the Controller); every other role, the User included, keeps
                    // the saved text. Before, a Manager's Update blanked the Controller comment, a User's both.
                    string roleCode = Session["RoleCode"].ToString();
                    myAgenda.MgrComments = roleCode == "manager" ? ftxtManagerComments.Text.Trim() : savedMgrComments;
                    myAgenda.ControllerComments = roleCode == "controller" ? ftxtControllerComments.Text.Trim() : savedControllerComments;

                    myAgenda.CurrentStatus = "New";
                    myAgenda.CreatedOn = System.DateTime.Now;
                    myAgenda.CreatedBy = int.Parse(Session["UserId"].ToString());
                    myAgenda.UpdatedOn = System.DateTime.Now;
                    myAgenda.UpdatedBy = int.Parse(Session["UserId"].ToString());

                    string strResult = "Success";

                    // Another tab may have finalized the agenda since the form opened: check before
                    // saving. The procedure checks again (BMMS-Fix-MeetingLocks-Step16.sql).
                    int ActingUserId = int.Parse(Session["UserId"].ToString());
                    MeetingChangeResult agendaLock = AgendaMgr.GetAgendaLock(myAgenda.MeetingId, ActingUserId);

                    // Step C2: Update only of an item of this user's list (Save is a new item)
                    string updateAccess = btnSave.Text == "Update" ? CheckItemAccessById(myAgenda.AgendaId) : "Success";

                    if (!fileNamesValid)
                        strResult = FileNameNotValidMessage;   // nothing is saved (step N2)
                    else if (agendaLock.Result != 1)
                        strResult = agendaLock.RefusalMessage();
                    else if (departmentRefusal != "Success")
                        strResult = departmentRefusal;   // step C2: before the date and route checks and the mail
                    else if (btnSave.Text == "Save")
                    {
                        strResult = CheckNewItemMeetingDate(myAgenda.MeetingId, out submissionNotice);

                        if (strResult == "Success")
                            strResult = CheckNewItemRoute();
                    }
                    else if (updateAccess != "Success")
                    {
                        // Step C2: the id comes from the hidden field hdnAgendaId, so the item is checked again by
                        // its saved creator and department; nothing is saved
                        strResult = updateAccess;
                    }
                    else if (btnSave.Text == "Update" && !IsItemMeetingOpen(myAgenda.AgendaId))
                    {
                        // The item's own saved meeting date, not the dropdown or the form (step M5); nothing is saved
                        strResult = ItemMeetingDatePassedMessage;
                    }

                    if (strResult == "Success")
                    {
                        MeetingChangeResult result;

                        switch (Session["RoleCode"].ToString())
                        {
                            case "controller":

                                result = myAgendaMgr.AddEditAgendaByController(myAgenda, ActingUserId);

                                break;

                            case "manager":

                                result = myAgendaMgr.AddEditAgendaByManager(myAgenda, ActingUserId);

                                break;

                            default:
                                result = myAgendaMgr.AddEditAgenda(myAgenda, ActingUserId);
                                break;
                        }

                        saved = result.Result == 1;

                        // Save first; the "Agenda Created" mail goes out only when the database accepted the new
                        // item, and the item stays saved when the mail fails (step M2)
                        if (!saved)
                            sMsg = result.RefusalMessage();
                        else if (btnSave.Text == "Save" && GenerateMail() != "Success")
                        {
                            mailFailed = true;
                            sMsg = MailNotSentMessage + submissionNotice;
                        }
                        else if (btnSave.Text == "Update" && GenerateUpdateMail(myAgenda.AgendaId, ActingUserId, result.ChangedFields) != "Success")
                        {
                            // Step ML1: the Update is saved; the page says the mail did not go out
                            mailFailed = true;
                            sMsg = UpdateMailNotSentMessage;
                        }
                        else
                            sMsg = submissionNotice == string.Empty ? "Successfully Saved" : "Successfully Saved." + submissionNotice;
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

                MsgDisplay(sMsg, saved && !mailFailed ? MessageKind.Success : sMsg.StartsWith("Error: ") ? MessageKind.Error : MessageKind.Warning);

                pnlViewAgenda.Visible = true;
                pnlEditAgenda.Visible = false;

                LoadAgenda();
                BindGridView();
            }
        }
        #endregion

        #region CheckNewItemMeetingDate
        // A new item: the meeting date is read again at Save, so a form left open past the meeting date cannot
        // add (step M4); checked before the mail goes out. Returns "Success" or the refusal. The Agenda Submission
        // Date blocks nothing: after it, Notice holds the sentence added to the saved message; otherwise it is empty.
        private string CheckNewItemMeetingDate(int MeetingId, out string Notice)
        {
            Notice = string.Empty;

            DataTable dtMeeting = MeetingMgr.GetMeetingByMeetingId(MeetingId);
            if (dtMeeting.Rows.Count == 0)
                return "Success";   // an unknown meeting is refused by the procedure

            if (!MeetingMgr.IsMeetingOpenForChange(dtMeeting.Rows[0]["MeetingDate"], DateTime.Today))
                return MeetingDatePassedMessage;

            if (MeetingMgr.IsAfterAgendaSubmissionDate(dtMeeting.Rows[0]["AgendaSubmissionDate"], DateTime.Today))
                Notice = " This item was added after the Agenda Submission Date (" + FormatDate(dtMeeting.Rows[0]["AgendaSubmissionDate"]) + ").";

            return "Success";
        }
        #endregion

        #region IsItemMeetingOpen
        // Delete and Update (step M5): the rule of step M1 on the meeting date of the item as saved, read by the
        // item's id. An item that no longer exists is left to the procedure.
        private bool IsItemMeetingOpen(int AgendaId)
        {
            DataTable dtItem = AgendaMgr.GetAgendaByAgendaId(AgendaId);
            if (dtItem.Rows.Count == 0)
                return true;

            return MeetingMgr.IsMeetingOpenForChange(dtItem.Rows[0]["MeetingDate"], DateTime.Today);
        }
        #endregion

        #region CheckItemAccess
        // Step C2: may the acting user open and update this item? The rule of the list
        // (spr_GetAgendaByMeetingIdDeptId, BMMS-Fix-ManagerDepartment-Step33.sql): the Controller every item; a
        // Manager the items of their department (the item's Agenda.DepartmentId) and the items they entered; every
        // other role only the items it entered. The Manager's department is read from the database, not from the
        // session or the form. Returns "Success" or the refusal.
        private string CheckItemAccess(DataRow item)
        {
            string roleCode = Session["RoleCode"].ToString();
            if (roleCode == "controller")
                return "Success";

            int userId = int.Parse(Session["UserId"].ToString());

            int createdBy;
            if (int.TryParse(item["CreatedBy"].ToString(), out createdBy) && createdBy == userId)
                return "Success";

            if (roleCode == "manager")
            {
                int itemDepartmentId;
                UserBAL actingUser = UserMgr.GetUserByUserId(userId);

                if (int.TryParse(item["DepartmentId"].ToString(), out itemDepartmentId)
                    && actingUser != null && itemDepartmentId == actingUser.DepartmentId)
                    return "Success";

                return ItemNotInDepartmentMessage;
            }

            return ItemNotOwnMessage;
        }

        // The same, by the item's id as saved; an item that no longer exists is left to the procedure, as in
        // IsItemMeetingOpen
        private string CheckItemAccessById(int AgendaId)
        {
            DataTable dtItem = AgendaMgr.GetAgendaByAgendaId(AgendaId);
            if (dtItem.Rows.Count == 0)
                return "Success";

            return CheckItemAccess(dtItem.Rows[0]);
        }
        #endregion

        #region EnteredBy
        // Step C2: the "Entered by" column; empty when the list procedure has no EnteredByName column (step 33 not
        // installed, or rolled back), so the grid still shows
        protected string EnteredBy(object dataItem)
        {
            DataRowView row = dataItem as DataRowView;
            if (row == null || !row.Row.Table.Columns.Contains("EnteredByName"))
                return string.Empty;

            return row["EnteredByName"].ToString();
        }
        #endregion

        #region FormatDate
        // dd-MMM-yyyy, or empty when there is no date
        private static string FormatDate(object value)
        {
            return value == null || value == DBNull.Value ? string.Empty : Convert.ToDateTime(value).ToString("dd-MMM-yyyy");
        }
        #endregion

        #region GetFilePathList()
        // Step N2: the names come from the server's own list (ViewState["dtAttFiles"], filled on Edit from the
        // database and on each upload; the grid is always bound from it, row for row), not from the posted hidden
        // field hdnFilePath. Returns null when a ticked name is not a plain file name.
        private string GetFilePathList()
        {
            string strFilePath = string.Empty;
            DataTable dtAttFiles = ViewState["dtAttFiles"] as DataTable;

            foreach (GridViewRow gr in grvAttachedFiles.Rows)
            {
                if (gr.RowType == DataControlRowType.DataRow)
                {
                    CheckBox cbAttach = (CheckBox)gr.FindControl("cbAttach");

                    if (cbAttach.Checked == true && dtAttFiles != null && gr.RowIndex < dtAttFiles.Rows.Count)
                    {
                        string name = dtAttFiles.Rows[gr.RowIndex]["FilePathOrg"].ToString();

                        if (!SafeFileName.IsPlainName(name))
                            return null;

                        strFilePath += name + ",";
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

        #region CheckNewItemRoute
        // A user's new item, before it is saved: refused while the manager is inactive (BMMS-Fix-UserStatus-Stage2b.sql)
        // or when it would go to the Controllers and none is active (BMMS-Fix-AgendaRouting-Step20.sql). Returns
        // "Success" or the refusal; nothing is saved and no mail goes out on a refusal. The procedure checks again.
        private string CheckNewItemRoute()
        {
            string roleCode = Session["RoleCode"].ToString();
            if (roleCode == "controller" || roleCode == "manager")
                return "Success";

            DataTable dtRoute = AgendaMgr.GetAgendaCreationMailId(int.Parse(Session["UserId"].ToString()));
            string route = dtRoute.Rows[0]["Route"].ToString();

            if (route == "I")
                return MeetingChangeReason.ManagerInactiveMessage(dtRoute.Rows[0]["ManagerName"].ToString());

            if (route == "C" && Convert.ToInt32(dtRoute.Rows[0]["ActiveControllers"]) == 0)
                return MeetingChangeReason.NoActiveControllerMessage;

            return "Success";
        }
        #endregion

        #region GenerateMail
        private string GenerateMail()
        {
            try
            {
                string ToMailId = string.Empty;
                string Bcc = string.Empty;

                int mgrUserId = 0;

                DataTable dtUser = UserMgr.GetActiveUserList();   // active users only (stage 2a)
                if (dtUser.Rows.Count > 0)
                {
                    for (int i = 0; i <= dtUser.Rows.Count - 1; i++)
                    {
                        if (dtUser.Rows[i]["UserId"].ToString() == Session["UserId"].ToString())
                        {
                            ToMailId = dtUser.Rows[i]["EmailId"].ToString();
                            // ManagerId is NULL when the user has no manager
                            if (!int.TryParse(dtUser.Rows[i]["ManagerId"].ToString(), out mgrUserId))
                                mgrUserId = 0;
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

                // A user's new item follows the route of BMMS-Fix-AgendaRouting-Step20.sql: it waits for an active
                // Manager (Bcc the manager), or goes straight to the Controllers (Bcc the active Controllers). The
                // refusals of the route are checked before saving (CheckNewItemRoute).
                string roleCode = Session["RoleCode"].ToString();
                if (roleCode != "controller" && roleCode != "manager")
                {
                    DataTable dtRoute = AgendaMgr.GetAgendaCreationMailId(int.Parse(Session["UserId"].ToString()));

                    Bcc = string.Empty;
                    for (int i = 0; i <= dtRoute.Rows.Count - 1; i++)
                    {
                        string emailId = dtRoute.Rows[i]["EmailId"].ToString().Trim();
                        if (emailId != string.Empty)
                            Bcc += (Bcc == string.Empty ? "" : ", ") + emailId;
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
                BodyText += ": " + HttpUtility.HtmlEncode(txtAgendaNo.Text.Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(txtCommittee.Text.Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(txtMeetingNo.Text.Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(txtDateOfMeeting.Text.Trim()) + "<br /><br />";
                if (Session["RoleCode"].ToString() == "controller")
                    BodyText += ": " + HttpUtility.HtmlEncode(ddlDepartment.SelectedItem.Text.ToString().Trim()) + "<br /><br />";
                else
                    BodyText += ": " + HttpUtility.HtmlEncode(txtDepartment.Text.Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(ddlSubjectType.SelectedItem.Text.Trim()) + "<br /><br />";
                //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "<tr>";
                BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
                BodyText += "Short Text <br /><br />";
                //BodyText += " <br /><br />";
                BodyText += "</td>";

                BodyText += "<td style='text-align:left; font-weight:normal;'>";
                BodyText += ": " + HttpUtility.HtmlEncode(txtShortText.Text.Trim()) + "<br /><br />";
                //BodyText += ": " + txt.Text.Trim() + "<br /><br />";
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "</table>";

                string result = Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);



                return result;
            }
            catch (Exception ex)
            {
                // The item is already saved: log, and let the page say the mail was not sent
                Utilities.WriteErrorLog(className, "GenerateMail", ex.ToString());
                return "Error";
            }
        }
        #endregion

        #region GenerateUpdateMail
        // Step ML1: the mail after an Update the database accepted. ChangedFields comes from the procedure
        // (BMMS-Fix-UpdateMail-Step37.sql): "" = nothing changed, no mail; null = step 37 is not installed (logged;
        // the page says the mail was not sent). It goes to the users the refreshed alert is shown to (Bcc;
        // spr_GetAgendaUpdateMailId), To the person who saved; nobody in Bcc with an address = no mail.
        // The body has the details of the "has been Created" mail as saved now, then one line per changed field,
        // never the text of a field (Agenda Text and Proposed Resolution can be rich text or files).
        // Returns "Success" or an error.
        private string GenerateUpdateMail(int AgendaId, int ActingUserId, string ChangedFields)
        {
            try
            {
                if (ChangedFields == null)
                {
                    Utilities.WriteErrorLog(className, "GenerateUpdateMail", "The procedure returned no list of changed fields: step 37 (BMMS-Fix-UpdateMail-Step37.sql) is not installed. Agenda " + AgendaId + " was saved; no mail was sent.");
                    return "Error";
                }
                if (ChangedFields == string.Empty)
                    return "Success";

                string Bcc = AgendaMgr.GetAgendaUpdateMailId(AgendaId, ActingUserId);
                if (Bcc == string.Empty)
                    return "Success";

                DataTable dtItem = AgendaMgr.GetAgendaByAgendaId(AgendaId);
                if (dtItem.Rows.Count == 0)
                {
                    Utilities.WriteErrorLog(className, "GenerateUpdateMail", "Agenda " + AgendaId + " could not be read; no mail was sent.");
                    return "Error";
                }
                DataRow item = dtItem.Rows[0];

                // To: the person who saved, as in the "has been Created" and the approve / reject mails
                UserBAL actingUser = UserMgr.GetUserByUserId(ActingUserId);
                string ToMailId = actingUser.EmailId == null ? string.Empty : actingUser.EmailId.Trim();

                string Subject = "Agenda (" + item["AgendaNo"].ToString().Trim() + ") has been Updated";
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
                BodyText += "</td>";

                BodyText += "<td style='text-align:left; font-weight:normal;'>";
                BodyText += ": " + HttpUtility.HtmlEncode(item["AgendaNo"].ToString().Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(item["CommitteeName"].ToString().Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(item["MeetingNo"].ToString().Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(FormatDate(item["MeetingDate"])) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(item["DepartmentName"].ToString().Trim()) + "<br /><br />";
                BodyText += ": " + HttpUtility.HtmlEncode(item["SubjectTypeName"].ToString().Trim()) + "<br /><br />";
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "<tr>";
                BodyText += "<td style='text-align:left; font-weight:bold; width:150px;'>";
                BodyText += "Short Text <br /><br />";
                BodyText += "</td>";

                BodyText += "<td style='text-align:left; font-weight:normal;'>";
                BodyText += ": " + HttpUtility.HtmlEncode(item["ShortText"].ToString().Trim()) + "<br /><br />";
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "<tr>";
                BodyText += "<td style='text-align:left; font-weight:bold; width:150px; vertical-align:top;'>";
                BodyText += "Changes";
                BodyText += "</td>";

                BodyText += "<td style='text-align:left; font-weight:normal;'>";
                foreach (string code in ChangedFields.Split(','))
                {
                    if (code.Trim() != string.Empty)
                        BodyText += ": " + HttpUtility.HtmlEncode(ChangeLine(code.Trim(), item)) + "<br />";
                }
                BodyText += "</td>";

                BodyText += "</tr>";

                BodyText += "</table>";

                return Mail_Mgr.SendWebEmail(ToMailId, Subject, BodyText, null, Bcc);
            }
            catch (Exception ex)
            {
                // The Update is already saved: log, and let the page say the mail was not sent
                Utilities.WriteErrorLog(className, "GenerateUpdateMail", ex.ToString());
                return "Error";
            }
        }

        // Step ML1: one line of the update mail for a code of @ChangedFields, from the item as saved now; plain text
        // (the caller encodes it); no text of a field, no file name
        private static string ChangeLine(string Code, DataRow Item)
        {
            switch (Code)
            {
                case "SubjectType":
                    return "Subject Type - Updated";
                case "ShortText":
                    return "Short Text - Updated";
                case "AgendaType":
                    return "Agenda Type - Updated";
                case "AgendaText":
                    return "Agenda Text - Updated";
                case "AgendaTextFile:Attached":
                    return "Agenda Text file - Attached";
                case "AgendaTextFile:Removed":
                    return "Agenda Text file - Removed";
                case "AgendaTextFile:Replaced":
                    return "Agenda Text file - Replaced";
                case "ProposedResolution":
                    return "Proposed Resolution - Updated";
                case "Attachments":
                    int files = 0;
                    foreach (string name in Item["FilePath"].ToString().Split(','))
                    {
                        if (name.Trim() != string.Empty)
                            files++;
                    }
                    return files == 0 ? "Attachments - Removed" : "Attachments - Updated (" + files + (files == 1 ? " file now)" : " files now)");
                case "MgrComments":
                    return CommentLine("Manager's Comments", Item["MgrComments"], Item["MgrApprovedBy"], Item["MgrApprovedDate"]);
                case "ControllerComments":
                    return CommentLine("Controller's Comments", Item["ControllerComments"], Item["ControllerApprovedBy"], Item["ControllerApprovedDate"]);
                case "Department":
                    return "Department - Updated";
                case "SubjectNo":
                    string subjectNo = Item["SubjectNo"].ToString().Trim();
                    return subjectNo == string.Empty ? "Subject No - Removed" : "Subject No - " + subjectNo;
                default:
                    return Code + " - Updated";
            }
        }

        // Step ML1: "Manager's Comments - Updated (Venkat, 11-Oct-2026 16:49)": who and when of step 35, never the text
        private static string CommentLine(string Label, object Comment, object ById, object On)
        {
            string author = AgendaMgr.CommentAuthor(ById, On);
            string line = Label + (Comment == DBNull.Value || Comment.ToString().Trim() == string.Empty ? " - Removed" : " - Updated");
            return author == string.Empty ? line : line + " (" + author + ")";
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

        #region ApplyCommentRoles
        // Step C1: each comment editor is editable only by the role that writes it; for every other role it is
        // read-only (no toolbar, its text kept in view state, a posted value ignored). Which panels show is unchanged.
        private void ApplyCommentRoles()
        {
            string roleCode = Session["RoleCode"].ToString();
            ftxtManagerComments.ReadOnly = roleCode != "manager";
            ftxtControllerComments.ReadOnly = roleCode != "controller";
        }
        #endregion

        #region ShowCommentCaptions
        // Step UN4: who wrote each comment and when, after its caption ("Manager's comment: MohanKumar, 11-Oct-2026 16:49";
        // the label alone for a new item and for a comment saved before step 35). The name is HTML-encoded here.
        // The editor's accessible name is the same text. Item = the saved row, or null for a new item.
        private void ShowCommentCaptions(DataRow Item)
        {
            string mgrBy = Item == null ? string.Empty : AgendaMgr.CommentAuthor(Item["MgrApprovedBy"], Item["MgrApprovedDate"]);
            string ctlBy = Item == null ? string.Empty : AgendaMgr.CommentAuthor(Item["ControllerApprovedBy"], Item["ControllerApprovedDate"]);

            lblManagerCommentBy.Text = mgrBy.Length == 0 ? string.Empty : ": " + HttpUtility.HtmlEncode(mgrBy);
            lblManagerCommentBy.Visible = mgrBy.Length > 0;
            ftxtManagerComments.Label = AgendaMgr.CommentCaption(AgendaMgr.ManagerCommentLabel, mgrBy);

            lblControllerCommentBy.Text = ctlBy.Length == 0 ? string.Empty : ": " + HttpUtility.HtmlEncode(ctlBy);
            lblControllerCommentBy.Visible = ctlBy.Length > 0;
            ftxtControllerComments.Label = AgendaMgr.CommentCaption(AgendaMgr.ControllerCommentLabel, ctlBy);
        }
        #endregion

        #region rdoAgendaType_SelectedIndexChanged
        protected void rdoAgendaType_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (rdoAgendaType.Text == "Entry")
            {
                ftxtAgendaText.Visible = true;
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

        #region btnAddFile_Click
        protected void btnAddFile_Click(object sender, EventArgs e)
        {
            // Step A2a: rich text over the limit (Web.config): the whole post is refused, no file is kept
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            if (fuAttachment.HasFile)
            {

                string fName = string.Empty;
                string fNameWithPath = string.Empty;

                // Safe name, not yet used in the folder (step N1)
                fName = SafeFileName.MakeUnique(MapPath("~/Files/AgendaAttach/"),
                    "Attach-" + txtAgendaNo.Text + "-" + SafeFileName.Clean(fuAttachment.FileName));
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
                    dr["FilePath"] = "../Files/AgendaAttach/" + Uri.EscapeDataString(fName);
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
            // Step A2a: rich text over the limit (Web.config): the whole post is refused, no file is kept
            if (RichTextEditor.IsTooLong(this)) { MsgDisplay(RichTextLimits.TooLongMessage); return; }

            MsgHide();

            if (FileUploadAgendaText.HasFile)
            {

                string fName = string.Empty;
                string fPath = string.Empty;
                string fNameWithPath = string.Empty;

                fPath = MapPath("~/Files/AgendaText/");
                // Safe name, not yet used in the folder (step N1)
                fName = SafeFileName.MakeUnique(fPath, txtAgendaNo.Text + "-" + SafeFileName.Clean(FileUploadAgendaText.FileName));
                fNameWithPath = fPath + fName;

                //string[] strSep = fName.Split('.');
                //int arrLength = strSep.Length - 1;
                string strExt = System.IO.Path.GetExtension(fNameWithPath).ToLower(); // strSep[arrLength].ToString().ToUpper();

                if (strExt.Equals(".pdf"))
                {
                    FileUploadAgendaText.SaveAs(fNameWithPath);

                    //string strPathToConvert = fName + ".htm";
                    aAgendaText.Attributes.Add("href", "../Files/AgendaText/" + Uri.EscapeDataString(fName));
                    txtAgendaTextPath.Text = fName; // strPathToConvert;
                    ViewState[AgendaTextPathKey] = fName;   // step N2: this is what Save and Update store

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
