using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region DesignationBAL
    public class DesignationBAL
    {
        #region Properties

        private string _Code;
        private int _DesignationId;
        private string _DesignationCode;
        private string _DesignationName;
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
        public int DesignationId
        {
            get { return _DesignationId; }
            set { _DesignationId = value; }
        }
        public string DesignationCode
        {
            get { return _DesignationCode; }
            set { _DesignationCode = value; }
        }
        public string DesignationName
        {
            get { return _DesignationName; }
            set { _DesignationName = value; }
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

    #region DesignationBALList
    public class DesignationBALList : List<DesignationBAL>
    {
        #region public DesignationBALList()
        public DesignationBALList()
        {

        }
        #endregion
    }
    #endregion

    #region DesignationMgr
    public class DesignationMgr
    {

        #region GetDesignationList
        public static DataTable GetDesignationList(int StatusId)
        {
            return DesignationDB.GetDesignationList(StatusId);
        }
        #endregion

        #region GetNextDesignationCode
        public static string GetNextDesignationCode()
        {
            return DesignationDB.GetNextDesignationCode();
        }
        #endregion

        #region GetDesignationByDesignationId
        public static DesignationBAL GetDesignationByDesignationId(int DesignationId)
        {
            DesignationDAL DesignationDAL = new DesignationDAL();
            DesignationDAL = DesignationDB.GetDesignationByDesignationId(DesignationId);

            DesignationBAL DesignationBAL = new DesignationBAL();
            DesignationBAL.DesignationId = DesignationDAL.DesignationId;
            DesignationBAL.DesignationCode = DesignationDAL.DesignationCode;
            DesignationBAL.DesignationName = DesignationDAL.DesignationName;
            DesignationBAL.StatusId = DesignationDAL.StatusId;

            return DesignationBAL;
        }
        #endregion

        #region AddEditDesignation
        public int AddEditDesignation(DesignationBAL DesignationBAL)
        {
            DesignationDAL DesignationDAL = new DesignationDAL();
            DesignationDAL.Code = DesignationBAL.Code;
            DesignationDAL.DesignationId = DesignationBAL.DesignationId;
            DesignationDAL.DesignationCode = DesignationBAL.DesignationCode;
            DesignationDAL.DesignationName = DesignationBAL.DesignationName;
            DesignationDAL.StatusId = DesignationBAL.StatusId;
            DesignationDAL.CreatedOn = DesignationBAL.CreatedOn;
            DesignationDAL.CreatedBy = DesignationBAL.CreatedBy;
            DesignationDAL.UpdatedOn = DesignationBAL.UpdatedOn;
            DesignationDAL.UpdatedBy = DesignationBAL.UpdatedBy;

            return DesignationDB.AddEditDesignation(DesignationDAL);
        }
        #endregion

        #region DeleteDesignationByDesignationId
        public static int DeleteDesignationByDesignationId(int DesignationId)
        {
            return DesignationDB.DeleteDesignationByDesignationId(DesignationId);
        }
        #endregion
        
    }
    #endregion

}
