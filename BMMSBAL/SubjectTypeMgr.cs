using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region SubjectTypeBAL
    public class SubjectTypeBAL
    {
        #region Properties

        private string _Code;
        private int _SubjectTypeId;
        private string _SubjectTypeCode;
        private string _SubjectTypeName;
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
        public int SubjectTypeId
        {
            get { return _SubjectTypeId; }
            set { _SubjectTypeId = value; }
        }
        public string SubjectTypeCode
        {
            get { return _SubjectTypeCode; }
            set { _SubjectTypeCode = value; }
        }
        public string SubjectTypeName
        {
            get { return _SubjectTypeName; }
            set { _SubjectTypeName = value; }
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

    #region SubjectTypeBALList
    public class SubjectTypeBALList : List<SubjectTypeBAL>
    {
        #region public SubjectTypeBALList()
        public SubjectTypeBALList()
        {

        }
        #endregion
    }
    #endregion

    #region SubjectTypeMgr
    public class SubjectTypeMgr
    {

        #region GetSubjectTypeList
        public static DataTable GetSubjectTypeList()
        {
            return SubjectTypeDB.GetSubjectTypeList();
        }
        #endregion

        #region GetNextSubjectTypeCode
        public static string GetNextSubjectTypeCode()
        {
            return SubjectTypeDB.GetNextSubjectTypeCode();
        }
        #endregion

        #region GetSubjectTypeBySubjectTypeId
        public static SubjectTypeBAL GetSubjectTypeBySubjectTypeId(int SubjectTypeId)
        {
            SubjectTypeDAL SubjectTypeDAL = new SubjectTypeDAL();
            SubjectTypeDAL = SubjectTypeDB.GetSubjectTypeBySubjectTypeId(SubjectTypeId);

            SubjectTypeBAL SubjectTypeBAL = new SubjectTypeBAL();
            SubjectTypeBAL.SubjectTypeId = SubjectTypeDAL.SubjectTypeId;
            SubjectTypeBAL.SubjectTypeCode = SubjectTypeDAL.SubjectTypeCode;
            SubjectTypeBAL.SubjectTypeName = SubjectTypeDAL.SubjectTypeName;
            SubjectTypeBAL.OrderNo = SubjectTypeDAL.OrderNo;
            SubjectTypeBAL.StatusId = SubjectTypeDAL.StatusId;

            return SubjectTypeBAL;
        }
        #endregion

        #region AddEditSubjectType
        public int AddEditSubjectType(SubjectTypeBAL SubjectTypeBAL)
        {
            SubjectTypeDAL SubjectTypeDAL = new SubjectTypeDAL();
            SubjectTypeDAL.Code = SubjectTypeBAL.Code;
            SubjectTypeDAL.SubjectTypeId = SubjectTypeBAL.SubjectTypeId;
            SubjectTypeDAL.SubjectTypeCode = SubjectTypeBAL.SubjectTypeCode;
            SubjectTypeDAL.SubjectTypeName = SubjectTypeBAL.SubjectTypeName;
            SubjectTypeDAL.OrderNo = SubjectTypeBAL.OrderNo;
            SubjectTypeDAL.StatusId = SubjectTypeBAL.StatusId;
            SubjectTypeDAL.CreatedOn = SubjectTypeBAL.CreatedOn;
            SubjectTypeDAL.CreatedBy = SubjectTypeBAL.CreatedBy;
            SubjectTypeDAL.UpdatedOn = SubjectTypeBAL.UpdatedOn;
            SubjectTypeDAL.UpdatedBy = SubjectTypeBAL.UpdatedBy;

            return SubjectTypeDB.AddEditSubjectType(SubjectTypeDAL);
        }
        #endregion

        #region DeleteSubjectTypeBySubjectTypeId
        public static int DeleteSubjectTypeBySubjectTypeId(int SubjectTypeId)
        {
            return SubjectTypeDB.DeleteSubjectTypeBySubjectTypeId(SubjectTypeId);
        }
        #endregion
        
    }
    #endregion

}
