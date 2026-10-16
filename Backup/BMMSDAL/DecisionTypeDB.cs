using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region DecisionTypeDAL
    public class DecisionTypeDAL
    {
        #region Properties

        private string _Code;
        private int _DecisionTypeId;
        private string _DecisionTypeCode;
        private string _DecisionTypeName;
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
        public int DecisionTypeId
        {
            get { return _DecisionTypeId; }
            set { _DecisionTypeId = value; }
        }
        public string DecisionTypeCode
        {
            get { return _DecisionTypeCode; }
            set { _DecisionTypeCode = value; }
        }
        public string DecisionTypeName
        {
            get { return _DecisionTypeName; }
            set { _DecisionTypeName = value; }
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

    #region DecisionTypeDALList
    public class DecisionTypeDALList : List<DecisionTypeDAL>
    {
        #region DecisionTypeDALList
        public DecisionTypeDALList()
        {

        }
        #endregion
    }
    #endregion

    #region DecisionTypeDB
    public class DecisionTypeDB
    {

        #region GetDecisionTypeList
        public static DataTable GetDecisionTypeList(int StatusId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetDecisionType", parameter); ;
        }
        #endregion

        #region GetNextDecisionTypeCode
        public static string GetNextDecisionTypeCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextDecisionTypeCode", null);

            return dt.Rows[0]["NextDecisionTypeCode"].ToString();
        }
        #endregion

        #region GetDecisionTypeByDecisionTypeId
        public static DecisionTypeDAL GetDecisionTypeByDecisionTypeId(int DecisionTypeId)
        {
            DataTable dt = new DataTable();
            
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DecisionTypeId", DecisionTypeId);

            dt = CommonDB.GetDataTable("spr_GetDecisionTypeByDecisionTypeId", parameter);

            DecisionTypeDAL DecisionTypeDAL = new DecisionTypeDAL();
            DecisionTypeDAL.DecisionTypeId = Convert.ToInt16(dt.Rows[0]["DecisionTypeId"].ToString());
            DecisionTypeDAL.DecisionTypeCode = dt.Rows[0]["DecisionTypeCode"].ToString();
            DecisionTypeDAL.DecisionTypeName = dt.Rows[0]["DecisionTypeName"].ToString();
            DecisionTypeDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());

            return DecisionTypeDAL;
        }
        #endregion

        #region AddEditDecisionType
        public static int AddEditDecisionType(DecisionTypeDAL DecisionTypeDAL)
        {
            SqlParameter[] parameter = new SqlParameter[9];
            parameter[0] = new SqlParameter("@Code", DecisionTypeDAL.Code);
            parameter[1] = new SqlParameter("@DecisionTypeId", DecisionTypeDAL.DecisionTypeId);
            parameter[2] = new SqlParameter("@DecisionTypeCode", DecisionTypeDAL.DecisionTypeCode);
            parameter[3] = new SqlParameter("@DecisionTypeName", DecisionTypeDAL.DecisionTypeName);
            parameter[4] = new SqlParameter("@StatusId", DecisionTypeDAL.StatusId);
            parameter[5] = new SqlParameter("@CreatedOn", DecisionTypeDAL.CreatedOn);
            parameter[6] = new SqlParameter("@CreatedBy", DecisionTypeDAL.CreatedBy);
            parameter[7] = new SqlParameter("@UpdatedOn", DecisionTypeDAL.UpdatedOn);
            parameter[8] = new SqlParameter("@UpdatedBy", DecisionTypeDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditDecisionType", parameter);           
        }
        #endregion

        #region DeleteDecisionTypeByDecisionTypeId
        public static int DeleteDecisionTypeByDecisionTypeId(int DecisionTypeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@DecisionTypeId", DecisionTypeId);

            return CommonDB.ExecuteProcedure("spr_DeleteDecisionTypeByDecisionTypeId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
