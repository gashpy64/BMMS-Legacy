using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
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

        #region GetUserList
        public static DataTable GetUserList()
        {
            return UserDB.GetUserList();
        }
        #endregion

        #region GetMgrController
        public static DataTable GetMgrControllerByDeptId(int DepartmentId)
        {
            return UserDB.GetMgrControllerByDeptId(DepartmentId);
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
        public int AddEditUser(UserBAL UserBAL)
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

            return UserDB.AddEditUser(UserDAL);
        }
        #endregion

        #region DeleteUserByUserId
        public static int DeleteUserByUserId(int UserId)
        {
            return UserDB.DeleteUserByUserId(UserId);
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
