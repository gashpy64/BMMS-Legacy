using System;
using System.Data;
using System.Web;
using System.Web.UI;
using BMMSBAL;

namespace BMMS.Master
{
    /// <summary>
    /// Admin options kept in the database (App_Setting, BMMS-Fix-MeetingLocks-Step16.sql).
    /// Admin only (XML/PageAccess.xml); spr_SetAppSetting refuses anyone else as well.
    /// </summary>
    public partial class SystemSettings : System.Web.UI.Page
    {
        private string className = "SystemSettings";

        #region Page_Load
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                try
                {
                    MsgHide();
                    LoadSettings();
                }
                catch (Exception ex)
                {
                    Utilities.GoToErrPage(className, "Page_Load", ex);
                }
            }
        }
        #endregion

        #region LoadSettings
        private void LoadSettings()
        {
            DataTable dt = Utilities.GetAppSetting(Utilities.AgendaControllerBypass);

            // No row: the procedures treat the option as on
            chkAgendaControllerBypass.Checked = dt.Rows.Count == 0 || dt.Rows[0]["SettingValue"].ToString() == "1";

            litLastChanged.Text = string.Empty;
            if (dt.Rows.Count > 0 && dt.Rows[0]["LastChangedOn"] != DBNull.Value)
            {
                litLastChanged.Text = "Last changed by " + HttpUtility.HtmlEncode(dt.Rows[0]["LastChangedBy"].ToString())
                    + " on " + Convert.ToDateTime(dt.Rows[0]["LastChangedOn"]).ToString("dd-MMM-yyyy HH:mm") + ".";
            }
        }
        #endregion

        #region btnSave_Click
        protected void btnSave_Click(object sender, EventArgs e)
        {
            try
            {
                int ActingUserId = int.Parse(Session["UserId"].ToString());
                string value = chkAgendaControllerBypass.Checked ? "1" : "0";

                MeetingChangeResult result = Utilities.SetAppSetting(Utilities.AgendaControllerBypass, value, ActingUserId);

                if (result.Result == 1)
                    MsgDisplay("Successfully updated.");
                else if (result.Reason == MeetingChangeReason.ActingUserInvalid)
                    MsgDisplay(result.RefusalMessage());
                else if (result.Reason == MeetingChangeReason.NotFound)
                    MsgDisplay("Only an Admin can change system settings.");
                else
                    MsgDisplay("The value is not valid.");

                LoadSettings();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnSave_Click", ex);
            }
        }
        #endregion

        #region btnCancel_Click
        protected void btnCancel_Click(object sender, EventArgs e)
        {
            Response.Redirect("~/DashBoard/DashBoard.aspx");
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
