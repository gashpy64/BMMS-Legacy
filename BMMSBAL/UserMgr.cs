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
                case UserChangeReason.ActingUserMissing:
                    // missing or inactive acting user (BMMS-Fix-UserStatus-Stage2a.sql)
                    return "Your session is no longer valid. Please log in again.";
                case UserChangeReason.Other:
                    Utilities.WriteErrorLog(ClassName, "UserChange", "Refused by the database: " + ReasonDetail);
                    return "This user cannot be deleted because other data still refers to them. The details were written to the error log.";
                default:
                    return Common.GetAppSetting("delete_reference");
            }
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
        public const int SystemAccount = 7;
        public const int ActingUserMissing = 8;   // missing or inactive (stage 2a)
        public const int Other = 9;
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

            return UserChangeResult.FromTable(UserDB.AddEditUser(UserDAL));
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
        public static DataTable GetUserListForUserPage(int ActingUserId)
        {
            return UserDB.GetUserListForUserPage(ActingUserId);
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
