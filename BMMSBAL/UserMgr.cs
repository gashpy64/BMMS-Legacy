using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region UserAccessState
    /// <summary>
    /// Step RA1d (BMMS-Fix-SessionCheck-Step51.sql): what a signed-in session is compared with on every request.
    /// Read at sign-in (Default.aspx) and by PageAccessModule on every checked request.
    /// DepartmentSet is Users.DepartmentId, "|", the open User_Department rows by DepartmentId, the home row
    /// marked "h" (for example "4|4h,5"): any change of the home department or of an open row gives another text.
    /// </summary>
    public class UserAccessState
    {
        public int UserId;
        public string RoleCode = string.Empty;
        public string RoleName = string.Empty;
        public bool IsActive;
        public bool IsSystem;
        public string DepartmentSet = string.Empty;

        /// <summary>null when the procedure returned no row (the user is not in View_Users).</summary>
        public static UserAccessState FromTable(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0)
                return null;
            if (!dt.Columns.Contains("RoleCode") || !dt.Columns.Contains("AccountStatus") || !dt.Columns.Contains("DepartmentSet"))
                throw new InvalidOperationException("spr_GetUserAccessState returned other columns. Run Database/BMMS-Fix-SessionCheck-Step51.sql.");

            DataRow row = dt.Rows[0];
            UserAccessState s = new UserAccessState();
            s.UserId = Convert.ToInt32(row["UserId"]);
            s.RoleCode = Convert.ToString(row["RoleCode"]).Trim();
            s.RoleName = Convert.ToString(row["RoleName"]).Trim();
            s.IsActive = Convert.ToString(row["AccountStatus"]) == "1";
            s.IsSystem = Convert.ToString(row["IsSystem"]) == "1";
            s.DepartmentSet = Convert.ToString(row["DepartmentSet"]);
            return s;
        }
    }
    #endregion

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
                    // Step RA1a (step 40): only an Admin changes other users' accounts
                    return "You are not allowed to " + ActionText + ". Only an Admin can change other users' accounts.";
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
                    // BMMS-Fix-UserHistory-Step39.sql (step UD1a, rule 12); the parts since step MR1 (step 52)
                    return LastManagerMessage(ReasonDetail);
                case UserChangeReason.Other:
                    Utilities.WriteErrorLog(ClassName, "UserChange", "Refused by the database: " + ReasonDetail);
                    return "This user cannot be deleted because other data still refers to them. The details were written to the error log.";
                default:
                    return Common.GetAppSetting("delete_reference");
            }
        }

        // Reason 24 (step MR1, BMMS-Fix-ManagerRelease-Step52.sql): ReasonDetail is 'open:<n>|past:<n>|<department part>',
        // the department part as step 39 wrote it ('last active Manager of <names with counts>', or empty; its counts are
        // said as the department's, DepartmentCounts). One line per
        // part that applies, in screen terms; the items routed to the person never suggest another department Manager.
        // A detail in the step 39 form (the database without step 52) gets the step 39 message.
        private static string LastManagerMessage(string Detail)
        {
            string detail = Detail ?? string.Empty;
            System.Text.RegularExpressions.Match m = System.Text.RegularExpressions.Regex.Match(detail, @"^open:(\d{1,9})\|past:(\d{1,9})\|(.*)$",
                System.Text.RegularExpressions.RegexOptions.Singleline);
            if (!m.Success)
                return "Not saved: this Manager is still needed: " + System.Web.HttpUtility.HtmlEncode(detail) + ". "
                     + "Approve or reject those items first, or give the department another active Manager. Nothing was changed.";

            int open = int.Parse(m.Groups[1].Value);
            int past = int.Parse(m.Groups[2].Value);
            string departments = m.Groups[3].Value.Trim();

            List<string> parts = new List<string>();
            if (open > 0)
                parts.Add(Items(open) + " routed to them " + (open == 1 ? "is" : "are")
                          + " still open for approval: approve or reject " + (open == 1 ? "it" : "them") + " first.");
            if (past > 0)
                parts.Add(Items(past) + " routed to them " + (past == 1 ? "belongs" : "belong")
                          + " to meetings whose date has passed and whose agenda was never finalized: the Controller should finalize "
                          + "the agenda of those meetings first (finalizing rejects the items not yet approved).");
            if (departments.Length > 0)
                parts.Add(Capitalise(System.Web.HttpUtility.HtmlEncode(DepartmentCounts(departments))) + ": give the department another active Manager first.");

            return "Not saved: this Manager is still needed.<br />" + string.Join("<br />", parts.ToArray())
                 + (parts.Count > 0 ? "<br />" : string.Empty) + "Nothing was changed.";
        }

        // Step MR1 (owner 2026-11-19): in the department part the count is the department's, not the person's:
        // "(2 items waiting)" as the database writes it becomes "(2 items of the department waiting)"
        private static string DepartmentCounts(string departments)
        {
            return System.Text.RegularExpressions.Regex.Replace(departments, @"\((\d{1,9}) items? waiting\)",
                m => "(" + Items(int.Parse(m.Groups[1].Value)) + " of the department waiting)");
        }

        private static string Items(int n)
        {
            return n.ToString() + (n == 1 ? " item" : " items");
        }

        private static string Capitalise(string text)
        {
            return text.Length == 0 ? text : char.ToUpperInvariant(text[0]) + text.Substring(1);
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
            string detail = SuccessDetailWithoutReleased();
            if (Result == 1 && detail.StartsWith(Prefix, StringComparison.Ordinal))
                return detail.Substring(Prefix.Length);

            return string.Empty;
        }

        // Step UD1b (BMMS-Fix-DepartmentApprovers-Step53.sql): a successful detail may end with
        // '|Released:<n>:<department names>'; the part before it is the detail of step UD1a
        private string SuccessDetailWithoutReleased()
        {
            string detail = ReasonDetail ?? string.Empty;
            int at = detail.LastIndexOf(UserChangeReason.ReleasedMarker, StringComparison.Ordinal);
            return at >= 0 ? detail.Substring(0, at) : detail;
        }

        /// <summary>
        /// Step UD1b: after a successful save or deactivation of a Manager, the sentence about his waiting approval alerts
        /// that were closed for him ("" when none were). The other Managers of the department still have them.
        /// Encoded for the page.
        /// </summary>
        public string ReleasedMessage()
        {
            if (Result != 1 || ReasonDetail == null)
                return string.Empty;

            int at = ReasonDetail.LastIndexOf(UserChangeReason.ReleasedMarker, StringComparison.Ordinal);
            if (at < 0)
                return string.Empty;

            System.Text.RegularExpressions.Match m = System.Text.RegularExpressions.Regex.Match(
                ReasonDetail.Substring(at + UserChangeReason.ReleasedMarker.Length), @"^(\d{1,9}):(.*)$",
                System.Text.RegularExpressions.RegexOptions.Singleline);
            if (!m.Success)
                return string.Empty;

            int n = int.Parse(m.Groups[1].Value);
            string departments = m.Groups[2].Value.Trim();
            return n.ToString() + " waiting approval alert" + (n == 1 ? "" : "s")
                 + (departments.Length > 0 ? " of " + System.Web.HttpUtility.HtmlEncode(departments) : "")
                 + (n == 1 ? " was" : " were") + " closed; the other Managers of the department still have "
                 + (n == 1 ? "it" : "them") + ".";
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
        public const string ReleasedMarker = "|Released:";   // step UD1b: at the end of a successful detail

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

        #region GetUserAccessState
        // Step RA1d: the role, status, system flag and department set of one user, read from the database
        // (spr_GetUserAccessState, step 51); null when the user is not in View_Users. A database error is thrown.
        public static UserAccessState GetUserAccessState(int UserId)
        {
            return UserAccessState.FromTable(UserDB.GetUserAccessState(UserId));
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
