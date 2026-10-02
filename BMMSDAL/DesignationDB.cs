using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region DesignationDAL
    public class DesignationDAL
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

    #region DesignationDALList
    public class DesignationDALList : List<DesignationDAL>
    {
        #region DesignationDALList
        public DesignationDALList()
        {

        }
        #endregion
    }
    #endregion

    #region DesignationDB
    public class DesignationDB
    {

        #region GetDesignationList
        public static DataTable GetDesignationList(int StatusId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetDesignation", parameter); ;
        }
        #endregion

        #region GetNextDesignationCode
        public static string GetNextDesignationCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextDesignationCode", null);

            return dt.Rows[0]["NextDesignationCode"].ToString();
        }
        #endregion

        #region GetDesignationByDesignationId
        public static DesignationDAL GetDesignationByDesignationId(int DesignationId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DesignationId", DesignationId);

            dt = CommonDB.GetDataTable("spr_GetDesignationByDesignationId", parameter);

            DesignationDAL DesignationDAL = new DesignationDAL();
            DesignationDAL.DesignationId = Convert.ToInt16(dt.Rows[0]["DesignationId"].ToString());
            DesignationDAL.DesignationCode = dt.Rows[0]["DesignationCode"].ToString();
            DesignationDAL.DesignationName = dt.Rows[0]["DesignationName"].ToString();
            DesignationDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return DesignationDAL;
        }
        #endregion

        #region AddEditDesignation
        public static int AddEditDesignation(DesignationDAL DesignationDAL)
        {
            SqlParameter[] parameter = new SqlParameter[9];
            parameter[0] = new SqlParameter("@Code", DesignationDAL.Code);
            parameter[1] = new SqlParameter("@DesignationId", DesignationDAL.DesignationId);
            parameter[2] = new SqlParameter("@DesignationCode", DesignationDAL.DesignationCode);
            parameter[3] = new SqlParameter("@DesignationName", DesignationDAL.DesignationName);
            parameter[4] = new SqlParameter("@StatusId", DesignationDAL.StatusId);
            parameter[5] = new SqlParameter("@CreatedOn", DesignationDAL.CreatedOn);
            parameter[6] = new SqlParameter("@CreatedBy", DesignationDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedOn", DesignationDAL.UpdatedOn);
            parameter[8] = new SqlParameter("@UpdatedBy", DesignationDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditDesignation", parameter);           
        }
        #endregion

        #region DeleteDesignationByDesignationId
        public static int DeleteDesignationByDesignationId(int DesignationId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DesignationId", DesignationId);

            return CommonDB.ExecuteProcedure("spr_DeleteDesignationByDesignationId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
