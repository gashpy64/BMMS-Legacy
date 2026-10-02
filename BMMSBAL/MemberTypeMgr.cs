using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MemberTypeBAL
    public class MemberTypeBAL
    {
        #region Properties

        private string _Code;
        private int _MemberTypeId;
        private string _MemberTypeCode;
        private string _MemberTypeName;
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
        public int MemberTypeId
        {
            get { return _MemberTypeId; }
            set { _MemberTypeId = value; }
        }
        public string MemberTypeCode
        {
            get { return _MemberTypeCode; }
            set { _MemberTypeCode = value; }
        }
        public string MemberTypeName
        {
            get { return _MemberTypeName; }
            set { _MemberTypeName = value; }
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

    #region MemberTypeBALList
    public class MemberTypeBALList : List<MemberTypeBAL>
    {
        #region public MemberTypeBALList()
        public MemberTypeBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MemberTypeMgr
    public class MemberTypeMgr
    {

        #region GetMemberTypeList
        public static DataTable GetMemberTypeList(int StatusId)
        {
            return MemberTypeDB.GetMemberTypeList(StatusId);
        }
        #endregion

        #region GetNextMemberTypeCode
        public static string GetNextMemberTypeCode()
        {
            return MemberTypeDB.GetNextMemberTypeCode();
        }
        #endregion

        #region GetMemberTypeByMemberTypeId
        public static MemberTypeBAL GetMemberTypeByMemberTypeId(int MemberTypeId)
        {
            MemberTypeDAL MemberTypeDAL = new MemberTypeDAL();
            MemberTypeDAL = MemberTypeDB.GetMemberTypeByMemberTypeId(MemberTypeId);

            MemberTypeBAL MemberTypeBAL = new MemberTypeBAL();
            MemberTypeBAL.MemberTypeId = MemberTypeDAL.MemberTypeId;
            MemberTypeBAL.MemberTypeCode = MemberTypeDAL.MemberTypeCode;
            MemberTypeBAL.MemberTypeName = MemberTypeDAL.MemberTypeName;
            MemberTypeBAL.StatusId = MemberTypeDAL.StatusId;

            return MemberTypeBAL;
        }
        #endregion

        #region AddEditMemberType
        public int AddEditMemberType(MemberTypeBAL MemberTypeBAL)
        {
            MemberTypeDAL MemberTypeDAL = new MemberTypeDAL();
            MemberTypeDAL.Code = MemberTypeBAL.Code;
            MemberTypeDAL.MemberTypeId = MemberTypeBAL.MemberTypeId;
            MemberTypeDAL.MemberTypeCode = MemberTypeBAL.MemberTypeCode;
            MemberTypeDAL.MemberTypeName = MemberTypeBAL.MemberTypeName;
            MemberTypeDAL.StatusId = MemberTypeBAL.StatusId;
            MemberTypeDAL.CreatedOn = MemberTypeBAL.CreatedOn;
            MemberTypeDAL.CreatedBy = MemberTypeBAL.CreatedBy;
            MemberTypeDAL.UpdatedOn = MemberTypeBAL.UpdatedOn;
            MemberTypeDAL.UpdatedBy = MemberTypeBAL.UpdatedBy;

            return MemberTypeDB.AddEditMemberType(MemberTypeDAL);
        }
        #endregion

        #region DeleteMemberTypeByMemberTypeId
        public static int DeleteMemberTypeByMemberTypeId(int MemberTypeId)
        {
            return MemberTypeDB.DeleteMemberTypeByMemberTypeId(MemberTypeId);
        }
        #endregion
        
    }
    #endregion

}
