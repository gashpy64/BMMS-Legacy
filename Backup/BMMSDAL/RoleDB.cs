using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region RoleDAL
    public class RoleDAL
    {
        #region Properties

        private string _Code;
        private int _RoleId;
        private string _RoleCode;
        private string _RoleName;
        private string _RoleDescription;
        private int _OrderNo;
        private int _StatusId;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int RoleId
        {
            get { return _RoleId; }
            set { _RoleId = value; }
        }
        public string RoleCode
        {
            get { return _RoleCode; }
            set { _RoleCode = value; }
        }
        public string RoleName
        {
            get { return _RoleName; }
            set { _RoleName = value; }
        }
        public string RoleDescription
        {
            get { return _RoleDescription; }
            set { _RoleDescription = value; }
        }
        public int OrderNo
        {
            get { return _OrderNo; }
            set { _OrderNo = value; }
        }
        public int StatusId
        {
            get { return _StatusId; }
            set { _StatusId = value; }
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

    #region RoleDALList
    public class RoleDALList : List<RoleDAL>
    {
        #region RoleDALList
        public RoleDALList()
        {

        }
        #endregion
    }
    #endregion

    #region RoleDB
    public class RoleDB
    {

        #region GetRoleList
        public static DataTable GetRoleList()
        {
            return CommonDB.GetDataTable("spr_GetRole", null);;
        }
        #endregion

        #region GetNextRoleCode
        public static string GetNextRoleCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextRoleCode", null);

            return dt.Rows[0]["NextRoleCode"].ToString();
        }
        #endregion

        #region GetRoleByRoleId
        public static RoleDAL GetRoleByRoleId(int RoleId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@RoleId", RoleId);

            dt = CommonDB.GetDataTable("spr_GetRoleByRoleId", parameter);

            RoleDAL RoleDAL = new RoleDAL();
            RoleDAL.RoleId = Convert.ToInt16(dt.Rows[0]["RoleId"].ToString());
            RoleDAL.RoleCode = dt.Rows[0]["RoleCode"].ToString();
            RoleDAL.RoleName = dt.Rows[0]["RoleName"].ToString();
            RoleDAL.RoleDescription = dt.Rows[0]["RoleDescription"].ToString();
            RoleDAL.OrderNo = Convert.ToInt16(dt.Rows[0]["OrderNo"].ToString());
            RoleDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return RoleDAL;
        }
        #endregion

        #region AddEditRole
        public static int AddEditRole(RoleDAL RoleDAL)
        {
            SqlParameter[] parameter = new SqlParameter[11];
            parameter[0] = new SqlParameter("@Code", RoleDAL.Code);
            parameter[1] = new SqlParameter("@RoleId", RoleDAL.RoleId);
            parameter[2] = new SqlParameter("@RoleCode", RoleDAL.RoleCode);
            parameter[3] = new SqlParameter("@RoleName", RoleDAL.RoleName);
            parameter[4] = new SqlParameter("@RoleDescription", RoleDAL.RoleDescription);
            parameter[5] = new SqlParameter("@OrderNo", RoleDAL.OrderNo);
            parameter[6] = new SqlParameter("@StatusId", RoleDAL.StatusId);
            parameter[7] = new SqlParameter("@CreatedOn", RoleDAL.CreatedOn);
            parameter[8] = new SqlParameter("@CreatedBy", RoleDAL.CreatedBy);
            parameter[9] = new SqlParameter("@UpdatedOn", RoleDAL.UpdatedOn);
            parameter[10] = new SqlParameter("@UpdatedBy", RoleDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditRole", parameter);           
        }
        #endregion

        #region DeleteRoleByRoleId
        public static int DeleteRoleByRoleId(int RoleId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@RoleId", RoleId);

            return CommonDB.ExecuteProcedure("spr_DeleteRoleByRoleId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
