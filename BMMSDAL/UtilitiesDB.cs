using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;

namespace BMMSDAL
{
    #region UtilitiesDB
    public class UtilitiesDB
    {

        #region ResetDatabase
        public static int ResetDatabase()
        {
            return CommonDB.ExecuteProcedure("spr_sys_ResetDatabase", null); ;
        }
        #endregion

        #region GetSMTPMaster
        public static DataTable GetSMTPMaster()
        {
            return CommonDB.GetDataTable("spr_GetSMTPMaster", null); ;
        }
        #endregion

        #region GetStateMaster
        public static DataTable GetStateMaster()
        {
            return CommonDB.GetDataTable("spr_GetStateMaster", null); ;
        }
        #endregion

        #region UpdateSMTPMaster
        public static DataTable UpdateSMTPMaster(string SMTPServer, string SMTPServerPort,
            string UserName, string Password, string FromMailId, string Bcc)
        {
            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@SMTPServer", SMTPServer);
            parameter[1] = new SqlParameter("@SMTPServerPort", SMTPServerPort);
            parameter[2] = new SqlParameter("@UserName", UserName);
            parameter[3] = new SqlParameter("@Password", Password);
            parameter[4] = new SqlParameter("@FromMailId", FromMailId);
            parameter[5] = new SqlParameter("@Bcc", Bcc);

            return CommonDB.GetDataTable("spr_UpdateSMTPMaster", parameter); ;
        }
        #endregion

        #region AddEditAuditTrialLogin
        public static int AddEditAuditTrialLogin(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_AddEditAuditTrialLogin", parameter); ;
        }
        #endregion

        #region GetAppSetting
        // SettingCode, SettingValue, Description, LastChangedOn, LastChangedBy; no row if the
        // setting is not stored (BMMS-Fix-MeetingLocks-Step16.sql)
        public static DataTable GetAppSetting(string SettingCode)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@SettingCode", SettingCode);

            return CommonDB.GetDataTable("spr_GetAppSetting", parameter);
        }
        #endregion

        #region SetAppSetting
        // One row: Result, Reason, ReasonDetail; only an active Admin may change a setting
        public static DataTable SetAppSetting(string SettingCode, string SettingValue, int ActingUserId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@SettingCode", SettingCode);
            parameter[1] = new SqlParameter("@SettingValue", SettingValue);
            parameter[2] = new SqlParameter("@ActingUserId", ActingUserId);

            return CommonDB.GetDataTable("spr_SetAppSetting", parameter);
        }
        #endregion

        #region GetOrganisationSettings
        // Seq, SettingCode, SettingValue, LastChangedOn, LastChangedBy; always the 12 rows in a fixed
        // order, '' for a setting that is not stored (BMMS-Fix-OrganisationSettings-Step19.sql)
        public static DataTable GetOrganisationSettings()
        {
            return CommonDB.GetDataTable("spr_GetOrganisationSettings", null);
        }
        #endregion

        #region SetOrganisationSettings
        // One row: Result, Reason, ReasonDetail; all 12 saved or none; only an active Admin.
        // Values holds the 12 settings in the order of spr_GetOrganisationSettings.
        public static DataTable SetOrganisationSettings(string[] Values, int ActingUserId)
        {
            string[] names = { "@OrganisationName", "@OrganisationShortName", "@OrganisationTerm", "@CertificateSignOff",
                               "@RegisteredOfficeLabel", "@RegisteredOfficeLine1", "@RegisteredOfficeLine2", "@RegisteredOfficeCity",
                               "@RegisteredOfficePinCode", "@OrganisationPhone", "@OrganisationFax", "@OrganisationEmail" };

            SqlParameter[] parameter = new SqlParameter[13];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            for (int i = 0; i < names.Length; i++)
            {
                parameter[i + 1] = new SqlParameter(names[i], SqlDbType.NVarChar, 400);
                parameter[i + 1].Value = Values[i] ?? string.Empty;
            }

            return CommonDB.GetDataTable("spr_SetOrganisationSettings", parameter);
        }
        #endregion

        #region RecordOrganisationLogo
        // One row: Result, Reason, ReasonDetail; Action 'Upload' or 'Remove'; only an active Admin
        public static DataTable RecordOrganisationLogo(string Action, string FileDetail, int ActingUserId)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@ActingUserId", ActingUserId);
            parameter[1] = new SqlParameter("@Action", Action);
            parameter[2] = new SqlParameter("@FileDetail", FileDetail);

            return CommonDB.GetDataTable("spr_RecordOrganisationLogo", parameter);
        }
        #endregion

    }
    #endregion
    
}
