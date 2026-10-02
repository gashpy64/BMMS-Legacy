using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region MemberTypeDAL
    public class MemberTypeDAL
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

    #region MemberTypeDALList
    public class MemberTypeDALList : List<MemberTypeDAL>
    {
        #region MemberTypeDALList
        public MemberTypeDALList()
        {

        }
        #endregion
    }
    #endregion

    #region MemberTypeDB
    public class MemberTypeDB
    {

        #region GetMemberTypeList
        public static DataTable GetMemberTypeList(int StatusId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetMemberType", parameter);
        }
        #endregion

        #region GetNextMemberTypeCode
        public static string GetNextMemberTypeCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextMemberTypeCode", null);

            return dt.Rows[0]["NextMemberTypeCode"].ToString();
        }
        #endregion

        #region GetMemberTypeByMemberTypeId
        public static MemberTypeDAL GetMemberTypeByMemberTypeId(int MemberTypeId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MemberTypeId", MemberTypeId);

            dt = CommonDB.GetDataTable("spr_GetMemberTypeByMemberTypeId", parameter);

            MemberTypeDAL memberTypeDAL = new MemberTypeDAL();
            memberTypeDAL.MemberTypeId = Convert.ToInt16(dt.Rows[0]["MemberTypeId"].ToString());
            memberTypeDAL.MemberTypeCode = dt.Rows[0]["MemberTypeCode"].ToString();
            memberTypeDAL.MemberTypeName = dt.Rows[0]["MemberTypeName"].ToString();
            memberTypeDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return memberTypeDAL;
        }
        #endregion

        #region AddEditMemberType
        public static int AddEditMemberType(MemberTypeDAL MemberTypeDAL)
        {
            SqlParameter[] parameter = new SqlParameter[9];
            parameter[0] = new SqlParameter("@Code", MemberTypeDAL.Code);
            parameter[1] = new SqlParameter("@MemberTypeId", MemberTypeDAL.MemberTypeId);
            parameter[2] = new SqlParameter("@MemberTypeCode", MemberTypeDAL.MemberTypeCode);
            parameter[3] = new SqlParameter("@MemberTypeName", MemberTypeDAL.MemberTypeName);
            parameter[4] = new SqlParameter("@StatusId", MemberTypeDAL.StatusId);
            parameter[5] = new SqlParameter("@CreatedOn", MemberTypeDAL.CreatedOn);
            parameter[6] = new SqlParameter("@CreatedBy", MemberTypeDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedOn", MemberTypeDAL.UpdatedOn);
            parameter[8] = new SqlParameter("@UpdatedBy", MemberTypeDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditMemberType", parameter);           
        }
        #endregion

        #region DeleteMemberTypeByMemberTypeId
        public static int DeleteMemberTypeByMemberTypeId(int MemberTypeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@MemberTypeId", MemberTypeId);

            return CommonDB.ExecuteProcedure("spr_DeleteMemberTypeByMemberTypeId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
