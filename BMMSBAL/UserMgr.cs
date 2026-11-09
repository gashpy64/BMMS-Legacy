using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region UserChangeResult
    /// <summary>
    /// Answer of the protected user procedures (BMMS-Fix-UserProtection-Stage1.sql).
    /// Result 1 = done, 0 = refused. Reason says why (see UserChangeReason).
    /// ReasonDetail: user names (5), history groups (6), or the SQL Server
    /// message (9, for the error log only - never shown on a page).
    /// </summary>
    public class UserChangeResult
    {
        public int Result;
        public int Reason;
        public string ReasonDetail = string.Empty;

        public static UserChangeResult FromTable(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0 || !dt.Columns.Contains("Reason"))
                throw new InvalidOperationException("The user procedure returned no Reason. Run Database/BMMS-Fix-UserProtection-Stage1.sql.");

            UserChangeResult r = new UserChangeResult();
            r.Result = Convert.ToInt32(dt.Rows[0]["Result"]);
            r.Reason = Convert.ToInt32(dt.Rows[0]["Reason"]);
            r.ReasonDetail = dt.Rows[0]["ReasonDetail"].ToString();
            return r;
        }

        /// <summary>
        /// Message for the page when Result = 0. ActionText completes "You are not
        /// allowed to ...", e.g. "delete this user". Reason 9 detail goes to the
        /// error log, never to the page.
        /// </summary>
        public string RefusalMessage(string ActionText, string ClassName)
        {
            switch (Reason)
            {
                case UserChangeReason.OwnAccount:
                    return "You cannot delete, deactivate or change the role of your own account.";
                case UserChangeReason.LastAdmin:
                    return "This is the last active Admin. It cannot be deleted, deactivated or given another role.";
                case UserChangeReason.LastController:
                    return "This is the last active Controller. It cannot be deleted, deactivated or given another role.";
                case UserChangeReason.NotAllowedForRole:
                    return "You are not allowed to " + ActionText + ". A Controller cannot change Admin or Controller accounts, "
                         + "or give anyone the Admin or Controller role.";
                case UserChangeReason.ReferencedByUsers:
                    return "This user cannot be deleted: these users have them as reporting person, or were created or last updated by them: "
                         + System.Web.HttpUtility.HtmlEncode(ReasonDetail) + ".";
                case UserChangeReason.HasHistory:
                    return "This user cannot be deleted because they have history: " + System.Web.HttpUtility.HtmlEncode(ReasonDetail) + ".";
                case UserChangeReason.SystemAccount:
                    // BMMS-Fix-SystemAccount-Stage3.sql
                    return UserChangeReason.SystemAccountMessage;
                case UserChangeReason.ActingUserMissing:
                    // missing or inactive acting user (BMMS-Fix-UserStatus-Stage2a.sql)
                    return "Your session is no longer valid. Please log in again.";
                case UserChangeReason.DepartmentsNotValid:
                    // BMMS-Fix-UserHistory-Step39.sql (step UD1a)
                    return DepartmentsMessage(ReasonDetail);
                case UserChangeReason.LastManager:
                    // BMMS-Fix-UserHistory-Step39.sql (step UD1a, rule 12)
                    return "Not saved: this Manager is still needed: " + System.Web.HttpUtility.HtmlEncode(ReasonDetail) + ". "
                         + "Approve or reject those items first, or give the department another active Manager. Nothing was changed.";
                case UserChangeReason.Other:
                    Utilities.WriteErrorLog(ClassName, "UserChange", "Refused by the database: " + ReasonDetail);
                    return "This user cannot be deleted because other data still refers to them. The details were written to the error log.";
                default:
                    return Common.GetAppSetting("delete_reference");
            }
        }

        // Reason 23 (step UD1a): ReasonDetail is a code, for an inactive home department followed by its name
        private static string DepartmentsMessage(string Detail)
        {
            const string homeInactive = "HomeDepartmentInactive:";

            if (Detail != null && Detail.StartsWith(homeInactive, StringComparison.Ordinal))
                return "Not activated: " + System.Web.HttpUtility.HtmlEncode(Detail.Substring(homeInactive.Length))
                     + " is inactive. Reactivate it or change the user's department first.";

            switch (Detail)
            {
                case "HomeNotTicked":
                    return "Not saved: the home department must be one of the departments managed. Nothing was changed.";
                case "OneDepartmentOnly":
                    return "Not saved: only a Manager can have more than one department. Nothing was changed.";
                case "DepartmentInactive":
                    return "Not saved: a department you ticked is no longer active. Reload the page and try again. Nothing was changed.";
                case "DepartmentNotFound":
                    return "Not saved: a department you ticked no longer exists. Reload the page and try again. Nothing was changed.";
                default:
                    return "Not saved: the departments sent were not valid. Reload the page and try again. Nothing was changed.";
            }
        }

        /// <summary>
        /// Step UD1a: the text after Prefix in ReasonDetail of a successful save ("MappingsClosed:" after a role change
        /// away from Manager, "NotRestored:" after an activation); empty when it is not there. Plain text: encode it.
        /// </summary>
        public string SuccessDetail(string Prefix)
        {
            if (Result == 1 && ReasonDetail != null && ReasonDetail.StartsWith(Prefix, StringComparison.Ordinal))
                return ReasonDetail.Substring(Prefix.Length);

            return string.Empty;
        }
    }

    public static class UserChangeReason
    {
        public const int None = 0;
        public const int OwnAccount = 1;
        public const int LastAdmin = 2;
        public const int LastController = 3;
        public const int NotAllowedForRole = 4;
        public const int ReferencedByUsers = 5;
        public const int HasHistory = 6;
        public const int SystemAccount = 7;       // the protected system account (stage 3)
        public const int ActingUserMissing = 8;   // missing or inactive (stage 2a)
        public const int Other = 9;
        public const int DepartmentsNotValid = 23; // the departments, or an inactive home department on Activate (step 39)
        public const int LastManager = 24;         // last active Manager / items routed to him (step 39, rule 12)

        public const string MappingsClosedPrefix = "MappingsClosed:";
        public const string NotRestoredPrefix = "NotRestored:";

        public const string SystemAccountMessage =
            "This is the protected system account. It cannot be edited, deactivated, deleted, or have its role or Login ID changed, "
          + "and only the account itself can change its password (Change Password).";
    }
    #endregion

    #region UserBAL
    public class UserBAL
    {
        #region Properties

        private string _Code;
        private int _UserId;
        private string _UserName;
        private int _DepartmentId;
        private string _DepartmentName;
        private int _DesignationId;
        private int _ManagerId;
        private int _RoleId;
        private string _DOB;
        private string _EmailId;
        private string _LoginName;
        private string _Password;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int UserId
        {
            get { return _UserId; }
            set { _UserId = value; }
        }
        public string UserName
        {
            get { return _UserName; }
            set { _UserName = value; }
        }
        public int DepartmentId
        {
            get { return _DepartmentId; }
            set { _DepartmentId = value; }
        }
        public string DepartmentName
        {
            get { return _DepartmentName; }
            set { _DepartmentName = value; }
        }
        public int DesignationId
        {
            get { return _DesignationId; }
            set { _DesignationId = value; }
        }
        public int ManagerId
        {
            get { return _ManagerId; }
            set { _ManagerId = value; }
        }
        public int RoleId
        {
            get { return _RoleId; }
            set { _RoleId = value; }
        }
        public string DOB
        {
            get { return _DOB; }
            set { _DOB = value; }
        }
        public string EmailId
        {
            get { return _EmailId; }
            set { _EmailId = value; }
        }
        public string LoginName
        {
            get { return _LoginName; }
            set { _LoginName = value; }
        }
        public string Password
        {
            get { return _Password; }
            set { _Password = value; }
        }
        public DateTime CreatedOn
        {
            get { return _CreatedOn; }
            set { _CreatedOn = value; }
        }
        public int CreatedBy
        {
            get { return _CreatedBy; }
            set { _CreatedBy = value; }
        }
        public DateTime UpdatedOn
        {
            get { return _UpdatedOn; }
            set { _UpdatedOn = value; }
        }
        public int UpdatedBy
        {
            get { return _UpdatedBy; }
            set { _UpdatedBy = value; }
        }

        // Step UD1a: the departments as a comma list of ids (home department included); null = not passed
        public string DepartmentIds { get; set; }

        #endregion
    }
    #endregion

    #region UserBALList
    public class UserBALList : List<UserBAL>
    {
        #region public UserBALList()
        public UserBALList()
        {

        }
        #endregion
    }
    #endregion

    #region UserMgr
    public class UserMgr
    {
        #region GetUserByLoginName
        public static DataTable GetUserByLoginName(string LoginName, string Password, string User_IP_Address, string Server_Url)
        {
            DataTable dt = UserDB.GetUserByLoginName(LoginName, Password, User_IP_Address, Server_Url);
            return dt;
        }
        #endregion

        #region RecordLogin
        public static void RecordLogin(int UserId, string User_IP_Address, string Server_Url)
        {
            UserDB.RecordLogin(UserId, User_IP_Address, Server_Url);
        }
        #endregion

        #region GetUserList
        public static DataTable GetUserList()
        {
            return UserDB.GetUserList();
        }
        #endregion

        #region UserDisplayName columns (step UN3)
        /// <summary>Column with "Name (login)" (Common.UserDisplayName); plain text, encoded by the page.</summary>
        public const string UserDisplayNameColumn = "UserDisplayName";

        /// <summary>Sort key of the pick lists: the name, or the login when the name is blank.</summary>
        public const string UserSortNameColumn = "UserSortName";

        /// <summary>Text of an audit row whose user no longer exists (the same as the Entered by column, step 33).</summary>
        public const string UnknownUserText = "(unknown user)";

        /// <summary>
        /// Step UN3: a pick list of users (rows with UserName, LoginName and AccountStatus, as spr_GetUser and
        /// spr_GetMgrControllerByDeptId return them). Returns a copy with the columns UserDisplayName and
        /// UserSortName, sorted by name, then login (case ignored). The value of the list stays UserId.
        /// </summary>
        public static DataTable WithUserDisplayName(DataTable Users)
        {
            DataTable dt = Users.Copy();

            if (!dt.Columns.Contains(UserDisplayNameColumn))
                dt.Columns.Add(UserDisplayNameColumn, typeof(string));
            if (!dt.Columns.Contains(UserSortNameColumn))
                dt.Columns.Add(UserSortNameColumn, typeof(string));

            foreach (DataRow row in dt.Rows)
            {
                string name = Convert.ToString(row["UserName"]).Trim();
                string login = Convert.ToString(row["LoginName"]).Trim();

                row[UserDisplayNameColumn] = Common.UserDisplayName(name, login, IsActiveRow(row));
                row[UserSortNameColumn] = name.Length > 0 ? name : login;
            }

            DataView view = new DataView(dt);
            view.Sort = UserSortNameColumn + " ASC, LoginName ASC";
            return view.ToTable();
        }

        /// <summary>
        /// Step UN3: adds the column UserDisplayName to rows that carry only a user's id (an audit table:
        /// Audit_Trail_Master.Update_By, Audit_Trail_SqlBackup.User_Id). The names come from spr_GetUser,
        /// read once; a row whose user does not exist (or has no id) gets "(unknown user)".
        /// </summary>
        public static void AddUserDisplayColumn(DataTable Rows, string UserIdColumn)
        {
            Dictionary<int, string> displayById = new Dictionary<int, string>();
            foreach (DataRow user in GetUserList().Rows)
            {
                int userId;
                if (int.TryParse(Convert.ToString(user["UserId"]), out userId))
                    displayById[userId] = Common.UserDisplayName(Convert.ToString(user["UserName"]),
                        Convert.ToString(user["LoginName"]), IsActiveRow(user));
            }

            if (!Rows.Columns.Contains(UserDisplayNameColumn))
                Rows.Columns.Add(UserDisplayNameColumn, typeof(string));

            foreach (DataRow row in Rows.Rows)
            {
                int userId;
                string display;
                if (int.TryParse(Convert.ToString(row[UserIdColumn]), out userId) && displayById.TryGetValue(userId, out display))
                    row[UserDisplayNameColumn] = display;
                else
                    row[UserDisplayNameColumn] = UnknownUserText;
            }
        }

        // AccountStatus 1 = active (UserStatus-Stage2a); a row without the column counts as active
        private static bool IsActiveRow(DataRow Row)
        {
            if (!Row.Table.Columns.Contains("AccountStatus") || Row["AccountStatus"] == DBNull.Value)
                return true;

            return Convert.ToInt32(Row["AccountStatus"]) == 1;
        }
        #endregion

        #region GetActiveUserList
        public static DataTable GetActiveUserList()
        {
            return UserDB.GetActiveUserList();
        }
        #endregion

        #region GetMgrController
        public static DataTable GetMgrControllerByDeptId(int DepartmentId)
        {
            return UserDB.GetMgrControllerByDeptId(DepartmentId);
        }

        public static DataTable GetMgrControllerByDeptId(int DepartmentId, int IncludeUserId)
        {
            return UserDB.GetMgrControllerByDeptId(DepartmentId, IncludeUserId);
        }
        #endregion

        #region GetUserStatusByUserId
        public static int GetUserStatusByUserId(int UserId)
        {
            return UserDB.GetUserStatusByUserId(UserId);
        }
        #endregion

        #region SetUserStatusByUserId
        public static UserChangeResult SetUserStatusByUserId(int UserId, int AccountStatus, int ActingUserId)
        {
            return UserChangeResult.FromTable(UserDB.SetUserStatusByUserId(UserId, AccountStatus, ActingUserId));
        }
        #endregion

        #region GetUserByUserId
        public static UserBAL GetUserByUserId(int UserId)
        {
            UserDAL UserDAL = new UserDAL();
            UserDAL = UserDB.GetUserByUserId(UserId);

            UserBAL UserBAL = new UserBAL();
            UserBAL.UserId = UserDAL.UserId;
            UserBAL.UserName = UserDAL.UserName;
            UserBAL.DepartmentId = UserDAL.DepartmentId;
            UserBAL.DepartmentName = UserDAL.DepartmentName;
            UserBAL.DesignationId = UserDAL.DesignationId;
            UserBAL.ManagerId = UserDAL.ManagerId;
            UserBAL.RoleId = UserDAL.RoleId;
            UserBAL.EmailId = UserDAL.EmailId;
            UserBAL.LoginName = UserDAL.LoginName;
            UserBAL.Password = UserDAL.Password;

            return UserBAL;
        }
        #endregion

        #region GetUserDataTableByUserId
        public static DataTable GetUserDataTableByUserId(int UserId)
        {
            return UserDB.GetUserDataTableByUserId(UserId);
        }
        #endregion

        #region GetCompanySecretary
        public static DataTable GetCompanySecretary(int MeetingId)
        {
            return UserDB.GetCompanySecretary(MeetingId);
        }
        #endregion

        #region AddEditUser
        public UserChangeResult AddEditUser(UserBAL UserBAL)
        {
            UserDAL UserDAL = new UserDAL();
            UserDAL.Code = UserBAL.Code;
            UserDAL.UserId = UserBAL.UserId;
            UserDAL.UserName = UserBAL.UserName;
            UserDAL.DepartmentId = UserBAL.DepartmentId;
            UserDAL.DesignationId = UserBAL.DesignationId;
            UserDAL.ManagerId = UserBAL.ManagerId;
            UserDAL.RoleId = UserBAL.RoleId;
            UserDAL.EmailId = UserBAL.EmailId;
            UserDAL.LoginName = UserBAL.LoginName;
            UserDAL.Password = UserBAL.Password;
            UserDAL.CreatedOn = UserBAL.CreatedOn;
            UserDAL.CreatedBy = UserBAL.CreatedBy;
            UserDAL.UpdatedOn = UserBAL.UpdatedOn;
            UserDAL.UpdatedBy = UserBAL.UpdatedBy;
            UserDAL.DepartmentIds = UserBAL.DepartmentIds;

            return UserChangeResult.FromTable(UserDB.AddEditUser(UserDAL));
        }
        #endregion

        #region Departments of a user (step UD1a, BMMS-Fix-UserHistory-Step39.sql)
        /// <summary>True when step 39 is installed; without it User Master keeps one department per user, as before.</summary>
        public static bool HasUserHistory()
        {
            return UserDB.HasUserHistory();
        }

        /// <summary>The open mappings (UserId, DepartmentId, DepartmentName, IsHome, DepartmentActive); UserId 0 = every user.</summary>
        public static DataTable GetUserDepartmentMap(int UserId)
        {
            return UserDB.GetUserDepartmentMap(UserId);
        }
        #endregion

        #region DeleteUserByUserId
        public static UserChangeResult DeleteUserByUserId(int UserId, int ActingUserId)
        {
            return UserChangeResult.FromTable(UserDB.DeleteUserByUserId(UserId, ActingUserId));
        }
        #endregion

        #region CheckUserChange
        public static UserChangeResult CheckUserChange(int ActingUserId, int TargetUserId, string Action, int NewRoleId)
        {
            return UserChangeResult.FromTable(UserDB.CheckUserChange(ActingUserId, TargetUserId, Action, NewRoleId));
        }
        #endregion

        #region GetUserListForUserPage
        // Step PW1: without the Password column. spr_GetUserListForUserPage returns View_Users v.*, which includes
        // each user's password hash, and User Master keeps this list in ViewState (sorting, the duplicate login
        // check). ASP.NET encrypts that ViewState today because the grid has DataKeyNames, so the hash was never
        // readable in the browser; removing it here is defence in depth in case the page ever stops encrypting.
        // No caller needs the hash: the grid, the row buttons, the sort and the duplicate check use other columns.
        // The procedure keeps its columns, so the test scripts of steps 13, 14 and 18 that fill a table from it
        // are unchanged.
        public static DataTable GetUserListForUserPage(int ActingUserId)
        {
            DataTable dt = UserDB.GetUserListForUserPage(ActingUserId);

            if (dt.Columns.Contains("Password"))
                dt.Columns.Remove("Password");

            return dt;
        }
        #endregion

        #region ResetPasswordByUserId
        public static int ResetPasswordByUserId(int UserId, string Password, int UpdatedBy)
        {
            return UserDB.ResetPasswordByUserId(UserId, Password, UpdatedBy);
        }
        #endregion

        #region LockUserByUserId
        public static int LockUserByUserId(int UserId)
        {
            return UserDB.LockUserByUserId(UserId);
        }
        #endregion
        
    }
    #endregion

}
