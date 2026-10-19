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
        private string _MemberScope;
        private int _DisplayOrder;
        private int _IsReserved;
        private int _CommitteeUseCount;
        private int _MeetingUseCount;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;
        private int _ActingUserId;

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
        /// <summary>C committee type, M meeting type (BMMS-Fix-MemberTypes-Step21.sql)</summary>
        public string MemberScope
        {
            get { return _MemberScope; }
            set { _MemberScope = value; }
        }
        public int DisplayOrder
        {
            get { return _DisplayOrder; }
            set { _DisplayOrder = value; }
        }
        /// <summary>1 = used by the application by id; cannot be edited or deleted</summary>
        public int IsReserved
        {
            get { return _IsReserved; }
            set { _IsReserved = value; }
        }
        public int CommitteeUseCount
        {
            get { return _CommitteeUseCount; }
            set { _CommitteeUseCount = value; }
        }
        public int MeetingUseCount
        {
            get { return _MeetingUseCount; }
            set { _MeetingUseCount = value; }
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
        public int ActingUserId
        {
            get { return _ActingUserId; }
            set { _ActingUserId = value; }
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

        #region GetMemberTypeForTagging
        /// <summary>
        /// Drop-down of a tagging page: the active types of the scope (C committee, M meeting),
        /// plus the edited row's current type when it is not one of them (BMMS-Fix-MemberTypes-Step21.sql).
        /// </summary>
        public static DataTable GetMemberTypeForTagging(string MemberScope, int CurrentMemberTypeId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MemberScope", MemberScope);
            parameter[1] = new SqlParameter("@CurrentMemberTypeId", CurrentMemberTypeId);

            return CommonDB.GetDataTable("spr_GetMemberTypeForTagging", parameter);
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
            memberTypeDAL.MemberTypeId = Convert.ToInt32(dt.Rows[0]["MemberTypeId"].ToString());
            memberTypeDAL.MemberTypeCode = dt.Rows[0]["MemberTypeCode"].ToString();
            memberTypeDAL.MemberTypeName = dt.Rows[0]["MemberTypeName"].ToString();
            memberTypeDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());
            memberTypeDAL.MemberScope = dt.Rows[0]["MemberScope"].ToString();
            memberTypeDAL.DisplayOrder = Convert.ToInt32(dt.Rows[0]["DisplayOrder"].ToString());
            memberTypeDAL.IsReserved = Convert.ToInt32(dt.Rows[0]["IsReserved"].ToString());
            memberTypeDAL.CommitteeUseCount = Convert.ToInt32(dt.Rows[0]["CommitteeUseCount"].ToString());
            memberTypeDAL.MeetingUseCount = Convert.ToInt32(dt.Rows[0]["MeetingUseCount"].ToString());

            return memberTypeDAL;
        }
        #endregion

        #region AddEditMemberType
        /// <summary>One row Result, Reason, ReasonDetail (BMMS-Fix-MemberTypes-Step21.sql)</summary>
        public static DataTable AddEditMemberType(MemberTypeDAL MemberTypeDAL)
        {
            SqlParameter[] parameter = new SqlParameter[12];
            parameter[0] = new SqlParameter("@Code", MemberTypeDAL.Code);
            parameter[1] = new SqlParameter("@MemberTypeId", MemberTypeDAL.MemberTypeId);
            parameter[2] = new SqlParameter("@MemberTypeCode", MemberTypeDAL.MemberTypeCode);
            parameter[3] = new SqlParameter("@MemberTypeName", MemberTypeDAL.MemberTypeName);
            parameter[4] = new SqlParameter("@StatusId", MemberTypeDAL.StatusId);
            parameter[5] = new SqlParameter("@CreatedOn", MemberTypeDAL.CreatedOn);
            parameter[6] = new SqlParameter("@CreatedBy", MemberTypeDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedOn", MemberTypeDAL.UpdatedOn);
            parameter[8] = new SqlParameter("@UpdatedBy", MemberTypeDAL.UpdatedBy);
            parameter[9] = new SqlParameter("@MemberScope", MemberTypeDAL.MemberScope);
            parameter[10] = new SqlParameter("@DisplayOrder", MemberTypeDAL.DisplayOrder);
            parameter[11] = new SqlParameter("@ActingUserId", MemberTypeDAL.ActingUserId);

            return CommonDB.GetDataTable("spr_AddEditMemberType", parameter);
        }
        #endregion

        #region DeleteMemberTypeByMemberTypeId
        /// <summary>One row Result, Reason, ReasonDetail (BMMS-Fix-MemberTypes-Step21.sql)</summary>
        public static DataTable DeleteMemberTypeByMemberTypeId(int MemberTypeId, int ActingUserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MemberTypeId", MemberTypeId);
            parameter[1] = new SqlParameter("@ActingUserId", ActingUserId);

            return CommonDB.GetDataTable("spr_DeleteMemberTypeByMemberTypeId", parameter);
        }
        #endregion
    }
    #endregion

}
