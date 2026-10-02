using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region RoleBAL
    public class RoleBAL
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

    #region RoleBALList
    public class RoleBALList : List<RoleBAL>
    {
        #region public RoleBALList()
        public RoleBALList()
        {

        }
        #endregion
    }
    #endregion

    #region RoleMgr
    public class RoleMgr
    {

        #region GetRoleList
        public static DataTable GetRoleList()
        {
            return RoleDB.GetRoleList();
        }
        #endregion

        #region GetNextRoleCode
        public static string GetNextRoleCode()
        {
            return RoleDB.GetNextRoleCode();
        }
        #endregion

        #region GetRoleByRoleId
        public static RoleBAL GetRoleByRoleId(int RoleId)
        {
            RoleDAL RoleDAL = new RoleDAL();
            RoleDAL = RoleDB.GetRoleByRoleId(RoleId);

            RoleBAL RoleBAL = new RoleBAL();
            RoleBAL.RoleId = RoleDAL.RoleId;
            RoleBAL.RoleCode = RoleDAL.RoleCode;
            RoleBAL.RoleName = RoleDAL.RoleName;
            RoleBAL.RoleDescription = RoleDAL.RoleDescription;
            RoleBAL.OrderNo = RoleDAL.OrderNo;
            RoleBAL.StatusId = RoleDAL.StatusId;

            return RoleBAL;
        }
        #endregion

        #region AddEditRole
        public int AddEditRole(RoleBAL RoleBAL)
        {
            RoleDAL RoleDAL = new RoleDAL();
            RoleDAL.Code = RoleBAL.Code;
            RoleDAL.RoleId = RoleBAL.RoleId;
            RoleDAL.RoleCode = RoleBAL.RoleCode;
            RoleDAL.RoleName = RoleBAL.RoleName;
            RoleDAL.RoleDescription = RoleBAL.RoleDescription;
            RoleDAL.OrderNo = RoleBAL.OrderNo;
            RoleDAL.StatusId = RoleBAL.StatusId;
            RoleDAL.CreatedOn = RoleBAL.CreatedOn;
            RoleDAL.CreatedBy = RoleBAL.CreatedBy;
            RoleDAL.UpdatedOn = RoleBAL.UpdatedOn;
            RoleDAL.UpdatedBy = RoleBAL.UpdatedBy;

            return RoleDB.AddEditRole(RoleDAL);
        }
        #endregion

        #region DeleteRoleByRoleId
        public static int DeleteRoleByRoleId(int RoleId)
        {
            return RoleDB.DeleteRoleByRoleId(RoleId);
        }
        #endregion
        
    }
    #endregion

}
