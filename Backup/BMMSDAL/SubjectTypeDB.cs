using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region SubjectTypeDAL
    public class SubjectTypeDAL
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

    #region SubjectTypeDALList
    public class SubjectTypeDALList : List<SubjectTypeDAL>
    {
        #region SubjectTypeDALList
        public SubjectTypeDALList()
        {

        }
        #endregion
    }
    #endregion

    #region SubjectTypeDB
    public class SubjectTypeDB
    {

        #region GetSubjectTypeList
        public static DataTable GetSubjectTypeList()
        {
            return CommonDB.GetDataTable("spr_GetSubjectType", null);;
        }
        #endregion

        #region GetNextSubjectTypeCode
        public static string GetNextSubjectTypeCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextSubjectTypeCode", null);

            return dt.Rows[0]["NextSubjectTypeCode"].ToString();
        }
        #endregion

        #region GetSubjectTypeBySubjectTypeId
        public static SubjectTypeDAL GetSubjectTypeBySubjectTypeId(int SubjectTypeId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@SubjectTypeId", SubjectTypeId);

            dt = CommonDB.GetDataTable("spr_GetSubjectTypeBySubjectTypeId", parameter);

            SubjectTypeDAL SubjectTypeDAL = new SubjectTypeDAL();
            SubjectTypeDAL.SubjectTypeId = Convert.ToInt16(dt.Rows[0]["SubjectTypeId"].ToString());
            SubjectTypeDAL.SubjectTypeCode = dt.Rows[0]["SubjectTypeCode"].ToString();
            SubjectTypeDAL.SubjectTypeName = dt.Rows[0]["SubjectTypeName"].ToString();
            SubjectTypeDAL.OrderNo = Convert.ToInt16(dt.Rows[0]["OrderNo"].ToString());
            SubjectTypeDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return SubjectTypeDAL;
        }
        #endregion

        #region AddEditSubjectType
        public static int AddEditSubjectType(SubjectTypeDAL SubjectTypeDAL)
        {
            SqlParameter[] parameter = new SqlParameter[10];
            parameter[0] = new SqlParameter("@Code", SubjectTypeDAL.Code);
            parameter[1] = new SqlParameter("@SubjectTypeId", SubjectTypeDAL.SubjectTypeId);
            parameter[2] = new SqlParameter("@SubjectTypeCode", SubjectTypeDAL.SubjectTypeCode);
            parameter[3] = new SqlParameter("@SubjectTypeName", SubjectTypeDAL.SubjectTypeName);
            parameter[4] = new SqlParameter("@OrderNo", SubjectTypeDAL.OrderNo);
            parameter[5] = new SqlParameter("@StatusId", SubjectTypeDAL.StatusId);
            parameter[6] = new SqlParameter("@CreatedOn", SubjectTypeDAL.CreatedOn);
            parameter[7] = new SqlParameter("@CreatedBy", SubjectTypeDAL.CreatedBy);
            parameter[8] = new SqlParameter("@UpdatedOn", SubjectTypeDAL.UpdatedOn);
            parameter[9] = new SqlParameter("@UpdatedBy", SubjectTypeDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditSubjectType", parameter);           
        }
        #endregion

        #region DeleteSubjectTypeBySubjectTypeId
        public static int DeleteSubjectTypeBySubjectTypeId(int SubjectTypeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@SubjectTypeId", SubjectTypeId);

            return CommonDB.ExecuteProcedure("spr_DeleteSubjectTypeBySubjectTypeId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
