using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region UserDAL
    public class UserDAL
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

    #region UserDALList
    public class UserDALList : List<UserDAL>
    {
        #region UserDALList
        public UserDALList()
        {

        }
        #endregion
    }
    #endregion

    #region UserDB
    public class UserDB
    {

        #region GetUserByLoginName
        public static DataTable GetUserByLoginName(string LoginName, string Password, string User_IP_Address, string Server_Url)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@LoginName", LoginName);
            parameter[1] = new SqlParameter("@Password", Password);
            parameter[2] = new SqlParameter("@User_IP_Address", User_IP_Address);
            parameter[3] = new SqlParameter("@Server_Url", Server_Url);

            dt = CommonDB.GetDataTable("spr_GetUserByLoginName", parameter);
            return dt;
        }
        #endregion

        #region GetUserList
        public static DataTable GetUserList()
        {
            return CommonDB.GetDataTable("spr_GetUser", null); ;
        }
        #endregion

        #region GetMgrControllerByDeptId
        public static DataTable GetMgrControllerByDeptId(int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetMgrControllerByDeptId", parameter); ;
        }
        #endregion

        #region GetUserByUserId
        public static UserDAL GetUserByUserId(int UserId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            dt = CommonDB.GetDataTable("spr_GetUserByUserId", parameter);

            UserDAL UserDAL = new UserDAL();
            UserDAL.UserId = Convert.ToInt16(dt.Rows[0]["UserId"].ToString());
            UserDAL.UserName = dt.Rows[0]["UserName"].ToString();
            UserDAL.DepartmentId = Convert.ToInt16(dt.Rows[0]["DepartmentId"].ToString());
            UserDAL.DepartmentName = dt.Rows[0]["DepartmentName"].ToString();
            UserDAL.DesignationId = Convert.ToInt16(dt.Rows[0]["DesignationId"].ToString());
            UserDAL.ManagerId = Convert.ToInt16(dt.Rows[0]["ManagerId"].ToString());
            UserDAL.RoleId = Convert.ToInt16(dt.Rows[0]["RoleId"].ToString());
            UserDAL.EmailId = dt.Rows[0]["EmailId"].ToString();
            UserDAL.LoginName = dt.Rows[0]["LoginName"].ToString();
            UserDAL.Password = dt.Rows[0]["Password"].ToString();

            return UserDAL;
        }
        #endregion

        #region GetUserDataTableByUserId
        public static DataTable GetUserDataTableByUserId(int UserId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            dt = CommonDB.GetDataTable("spr_GetUserByUserId", parameter);

            return dt;
        }
        #endregion

        #region GetCompanySecretary
        public static DataTable GetCompanySecretary(int MeetingId)
        {
            string CompanySecretary = string.Empty;

            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);

            return CommonDB.GetDataTable("spr_GetCompanySecretary", parameter);
        }
        #endregion

        #region AddEditUser
        public static int AddEditUser(UserDAL UserDAL)
        {
            SqlParameter[] parameter = new SqlParameter[14];
            parameter[0] = new SqlParameter("@Code", UserDAL.Code);
            parameter[1] = new SqlParameter("@UserId", UserDAL.UserId);
            parameter[2] = new SqlParameter("@UserName", UserDAL.UserName);
            parameter[3] = new SqlParameter("@DepartmentId", UserDAL.DepartmentId);
            parameter[4] = new SqlParameter("@DesignationId", UserDAL.DesignationId);
            parameter[5] = new SqlParameter("@ManagerId", UserDAL.ManagerId);
            parameter[6] = new SqlParameter("@RoleId", UserDAL.RoleId);
            parameter[7] = new SqlParameter("@EmailId", UserDAL.EmailId);
            parameter[8] = new SqlParameter("@LoginName", UserDAL.LoginName);
            parameter[9] = new SqlParameter("@Password", UserDAL.Password);
            parameter[10] = new SqlParameter("@CreatedOn", UserDAL.CreatedOn);
            parameter[11] = new SqlParameter("@CreatedBy", UserDAL.CreatedBy);
            parameter[12] = new SqlParameter("@UpdatedOn", UserDAL.UpdatedOn);
            parameter[13] = new SqlParameter("@UpdatedBy", UserDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditUser", parameter);
        }
        #endregion

        #region DeleteUserByUserId
        public static int DeleteUserByUserId(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_DeleteUserByUserId", parameter); ;
        }
        #endregion

        #region ResetPasswordByUserId
        public static int ResetPasswordByUserId(int UserId, string Password, int UpdatedBy)
        {
            SqlParameter[] parameter = new SqlParameter[3];
            parameter[0] = new SqlParameter("@UserId", UserId);
            parameter[1] = new SqlParameter("@Password", Password);
            parameter[2] = new SqlParameter("@UpdatedBy", UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_ResetPasswordByUserId", parameter); ;
        }
        #endregion

        #region LockUserByUserId
        public static int LockUserByUserId(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.ExecuteProcedure("spr_LockUserByUserId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
