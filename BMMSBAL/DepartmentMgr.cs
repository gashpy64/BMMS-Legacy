using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region DepartmentBAL
    public class DepartmentBAL
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

    #region DepartmentBALList
    public class DepartmentBALList : List<DepartmentBAL>
    {
        #region public DepartmentBALList()
        public DepartmentBALList()
        {

        }
        #endregion
    }
    #endregion

    #region DepartmentMgr
    public class DepartmentMgr
    {

        #region GetDepartmentList
        public static DataTable GetDepartmentList(int StatusId)
        {
            return DepartmentDB.GetDepartmentList(StatusId);
        }
        #endregion

        #region GetNextDeptCode
        public static string GetNextDeptCode()
        {
            return DepartmentDB.GetNextDeptCode();
        }
        #endregion

        #region GetDepartmentByDeptId
        public static DepartmentBAL GetDepartmentByDeptId(int DeptId)
        {
            DepartmentDAL deptDAL = new DepartmentDAL();
            deptDAL = DepartmentDB.GetDepartmentByDeptId(DeptId);

            DepartmentBAL deptBAL = new DepartmentBAL();
            deptBAL.DepartmentId = deptDAL.DepartmentId;
            deptBAL.DepartmentCode = deptDAL.DepartmentCode;
            deptBAL.DepartmentName = deptDAL.DepartmentName;
            deptBAL.OrderNo = deptDAL.OrderNo;
            deptBAL.StatusId = deptDAL.StatusId;

            return deptBAL;
        }
        #endregion

        #region AddEditDepartment
        public int AddEditDepartment(DepartmentBAL deptBAL)
        {
            DepartmentDAL deptDAL = new DepartmentDAL();
            deptDAL.Code = deptBAL.Code;
            deptDAL.DepartmentId = deptBAL.DepartmentId;
            deptDAL.DepartmentCode = deptBAL.DepartmentCode;
            deptDAL.DepartmentName = deptBAL.DepartmentName;
            deptDAL.OrderNo = deptBAL.OrderNo;
            deptDAL.StatusId = deptBAL.StatusId;
            deptDAL.CreatedOn = deptBAL.CreatedOn;
            deptDAL.CreatedBy = deptBAL.CreatedBy;
            deptDAL.UpdatedOn = deptBAL.UpdatedOn;
            deptDAL.UpdatedBy = deptBAL.UpdatedBy;

            return DepartmentDB.AddEditDepartment(deptDAL);
        }
        #endregion

        #region DeleteDepartmentByDeptId
        public static int DeleteDepartmentByDeptId(int DeptId)
        {
            return DepartmentDB.DeleteDepartmentByDeptId(DeptId);
        }
        #endregion
        
    }
    #endregion

}
