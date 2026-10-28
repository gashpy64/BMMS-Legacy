using System;
using System.Data;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using BMMSBAL;

namespace BMMS.Master
{
    /// <summary>
    /// Admin options kept in the database (App_Setting, BMMS-Fix-MeetingLocks-Step16.sql), the
    /// organisation details and logo printed on the output (BMMS-Fix-OrganisationSettings-Step19.sql).
    /// Admin only (XML/PageAccess.xml); the procedures refuse anyone else as well.
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
                    LoadOrganisation();
                    LoadLogo();
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

        #region Organisation details
        // The text boxes in the order of OrganisationDetails.SettingCodes
        private TextBox[] OrganisationBoxes()
        {
            return new TextBox[] { txtOrganisationName, txtOrganisationShortName, txtOrganisationTerm, txtCertificateSignOff,
                                   txtRegisteredOfficeLabel, txtRegisteredOfficeLine1, txtRegisteredOfficeLine2, txtRegisteredOfficeCity,
                                   txtRegisteredOfficePinCode, txtOrganisationPhone, txtOrganisationFax, txtOrganisationEmail };
        }

        private void LoadOrganisation()
        {
            DataTable dt = OrganisationDetails.GetSettings();
            TextBox[] boxes = OrganisationBoxes();

            DateTime lastOn = DateTime.MinValue;
            string lastBy = string.Empty;

            foreach (DataRow row in dt.Rows)
            {
                int index = Array.IndexOf(OrganisationDetails.SettingCodes, row["SettingCode"].ToString());
                if (index >= 0)
                    boxes[index].Text = row["SettingValue"].ToString();

                if (row["LastChangedOn"] != DBNull.Value && Convert.ToDateTime(row["LastChangedOn"]) > lastOn)
                {
                    lastOn = Convert.ToDateTime(row["LastChangedOn"]);
                    lastBy = row["LastChangedBy"].ToString();
                }
            }

            divOrgNotSet.Visible = txtOrganisationName.Text.Trim() == string.Empty;

            litOrgLastChanged.Text = string.Empty;
            if (lastOn > DateTime.MinValue)
                litOrgLastChanged.Text = "Last changed by " + HttpUtility.HtmlEncode(lastBy) + " on " + lastOn.ToString("dd-MMM-yyyy HH:mm") + ".";
        }

        private void LoadLogo()
        {
            bool hasLogo = OrganisationDetails.HasLogo;

            imgLogo.Visible = hasLogo;
            litNoLogo.Visible = !hasLogo;
            btnRemoveLogo.Enabled = hasLogo;

            // The file name is fixed: the query string makes the browser fetch a new upload
            if (hasLogo)
                imgLogo.ImageUrl = OrganisationDetails.LogoVirtualPath + "?v="
                    + System.IO.File.GetLastWriteTimeUtc(OrganisationDetails.LogoFilePath).Ticks;
        }

        private static string FieldLabel(string SettingCode)
        {
            switch (SettingCode)
            {
                case "OrganisationName": return "Organisation name (at most 150 characters)";
                case "OrganisationShortName": return "Short name (at most 100 characters)";
                case "OrganisationTerm": return "Organisation term (letters and spaces, at most 30)";
                case "CertificateSignOff": return "Certificate sign-off (at most 150 characters)";
                case "RegisteredOfficeLabel": return "Office label (at most 60 characters)";
                case "RegisteredOfficeLine1": return "Office address line 1 (at most 100 characters)";
                case "RegisteredOfficeLine2": return "Office address line 2 (at most 100 characters)";
                case "RegisteredOfficeCity": return "City (at most 60 characters)";
                case "RegisteredOfficePinCode": return "PIN code (digits, spaces and hyphens, at most 12)";
                case "OrganisationPhone": return "Phone (digits, spaces and + - ( ) / , at most 60)";
                case "OrganisationFax": return "Fax (digits, spaces and + - ( ) / , at most 60)";
                case "OrganisationEmail": return "E-mail (one address, at most 100 characters)";
                default: return SettingCode;
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
                    MsgDisplay("Successfully updated.", MessageKind.Success);
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

        #region btnSaveOrganisation_Click
        protected void btnSaveOrganisation_Click(object sender, EventArgs e)
        {
            try
            {
                int ActingUserId = int.Parse(Session["UserId"].ToString());

                TextBox[] boxes = OrganisationBoxes();
                string[] values = new string[boxes.Length];
                for (int i = 0; i < boxes.Length; i++)
                    values[i] = boxes[i].Text.Trim();

                MeetingChangeResult result = OrganisationDetails.Save(values, ActingUserId);

                if (result.Result == 1)
                {
                    MsgDisplay("Organisation details saved.", MessageKind.Success);
                    LoadOrganisation();
                }
                else if (result.Reason == MeetingChangeReason.ActingUserInvalid)
                    MsgDisplay(result.RefusalMessage());
                else if (result.Reason == MeetingChangeReason.NotFound)
                    MsgDisplay("Only an Admin can change system settings.");
                else
                    // Nothing was saved; the typed values stay in the boxes for correction
                    MsgDisplay("Not saved: " + HttpUtility.HtmlEncode(FieldLabel(result.ReasonDetail))
                        + " is not valid. Line breaks and characters outside Windows-1252 are not allowed.");
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnSaveOrganisation_Click", ex);
            }
        }
        #endregion

        #region btnUploadLogo_Click
        protected void btnUploadLogo_Click(object sender, EventArgs e)
        {
            try
            {
                int ActingUserId = int.Parse(Session["UserId"].ToString());

                if (!fuLogo.HasFile)
                {
                    MsgDisplay("Choose an image file first.");
                    return;
                }

                // Only the bytes are used: the file name and the type the browser sends are ignored
                bool saved;
                string message = OrganisationDetails.UploadLogo(fuLogo.FileBytes, ActingUserId, out saved);
                MsgDisplay(HttpUtility.HtmlEncode(message), saved ? MessageKind.Success : MessageKind.Warning);

                LoadLogo();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnUploadLogo_Click", ex);
            }
        }
        #endregion

        #region btnRemoveLogo_Click
        protected void btnRemoveLogo_Click(object sender, EventArgs e)
        {
            try
            {
                int ActingUserId = int.Parse(Session["UserId"].ToString());

                bool removed;
                string message = OrganisationDetails.RemoveLogo(ActingUserId, out removed);
                MsgDisplay(HttpUtility.HtmlEncode(message), removed ? MessageKind.Success : MessageKind.Warning);

                LoadLogo();
            }
            catch (Exception ex)
            {
                Utilities.GoToErrPage(className, "btnRemoveLogo_Click", ex);
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
    }
}
