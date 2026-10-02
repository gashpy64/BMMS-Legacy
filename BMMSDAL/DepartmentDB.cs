using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region DepartmentDAL
    public class DepartmentDAL
    {
        #region Properties

        private string _Code;
        private int _DepartmentId;
        private string _DepartmentCode;
        private string _DepartmentName;
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
        public int DepartmentId
        {
            get { return _DepartmentId; }
            set { _DepartmentId = value; }
        }
        public string DepartmentCode
        {
            get { return _DepartmentCode; }
            set { _DepartmentCode = value; }
        }
        public string DepartmentName
        {
            get { return _DepartmentName; }
            set { _DepartmentName = value; }
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

    #region DepartmentDALList
    public class DepartmentDALList : List<DepartmentDAL>
    {
        #region DepartmentDALList
        public DepartmentDALList()
        {

        }
        #endregion
    }
    #endregion

    #region DepartmentDB
    public class DepartmentDB
    {

        #region GetDepartmentList
        public static DataTable GetDepartmentList(int StatusId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetDepartment", parameter);;
        }
        #endregion

        #region GetNextDeptCode
        public static string GetNextDeptCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextDeptCode", null);

            return dt.Rows[0]["NextDeptCode"].ToString();
        }
        #endregion

        #region GetDepartmentByDeptId
        public static DepartmentDAL GetDepartmentByDeptId(int DeptId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DeptId", DeptId);

            dt = CommonDB.GetDataTable("spr_GetDepartmentByDeptId", parameter);

            DepartmentDAL deptDAL = new DepartmentDAL();
            deptDAL.DepartmentId = Convert.ToInt16(dt.Rows[0]["DepartmentId"].ToString());
            deptDAL.DepartmentCode = dt.Rows[0]["DepartmentCode"].ToString();
            deptDAL.DepartmentName = dt.Rows[0]["DepartmentName"].ToString();
            deptDAL.OrderNo = Convert.ToInt16(dt.Rows[0]["OrderNo"].ToString());
            deptDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return deptDAL;
        }
        #endregion

        #region AddEditDepartment
        public static int AddEditDepartment(DepartmentDAL deptDAL)
        {
            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@Code", deptDAL.Code);
            parameter[1] = new SqlParameter("@DepartmentId", deptDAL.DepartmentId);
            parameter[2] = new SqlParameter("@DepartmentCode", deptDAL.DepartmentCode);
            parameter[3] = new SqlParameter("@DepartmentName", deptDAL.DepartmentName);
            parameter[4] = new SqlParameter("@OrderNo", deptDAL.OrderNo);
            parameter[5] = new SqlParameter("@StatusId", deptDAL.StatusId);
            parameter[6] = new SqlParameter("@CreatedOn", deptDAL.CreatedOn);
            parameter[7] = new SqlParameter("@CreatedBy", deptDAL.CreatedBy);
            parameter[8] = new SqlParameter("@UpdatedOn", deptDAL.UpdatedOn);
            parameter[9] = new SqlParameter("@UpdatedBy", deptDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditDepartment", parameter);           
        }
        #endregion

        #region DeleteDepartmentByDeptId
        public static int DeleteDepartmentByDeptId(int DeptId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DeptId", DeptId);

            return CommonDB.ExecuteProcedure("spr_DeleteDepartmentByDeptId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
