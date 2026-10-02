using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region DecisionTypeBAL
    public class DecisionTypeBAL
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

    #region DecisionTypeBALList
    public class DecisionTypeBALList : List<DecisionTypeBAL>
    {
        #region public DecisionTypeBALList()
        public DecisionTypeBALList()
        {

        }
        #endregion
    }
    #endregion

    #region DecisionTypeMgr
    public class DecisionTypeMgr
    {

        #region GetDecisionTypeList
        public static DataTable GetDecisionTypeList(int StatusId)
        {
            return DecisionTypeDB.GetDecisionTypeList(StatusId);
        }
        #endregion

        #region GetNextDecisionTypeCode
        public static string GetNextDecisionTypeCode()
        {
            return DecisionTypeDB.GetNextDecisionTypeCode();
        }
        #endregion

        #region GetDecisionTypeByDecisionTypeId
        public static DecisionTypeBAL GetDecisionTypeByDecisionTypeId(int DecisionTypeId)
        {
            DecisionTypeDAL DecisionTypeDAL = new DecisionTypeDAL();
            DecisionTypeDAL = DecisionTypeDB.GetDecisionTypeByDecisionTypeId(DecisionTypeId);

            DecisionTypeBAL DecisionTypeBAL = new DecisionTypeBAL();
            DecisionTypeBAL.DecisionTypeId = DecisionTypeDAL.DecisionTypeId;
            DecisionTypeBAL.DecisionTypeCode = DecisionTypeDAL.DecisionTypeCode;
            DecisionTypeBAL.DecisionTypeName = DecisionTypeDAL.DecisionTypeName;
            DecisionTypeBAL.StatusId = DecisionTypeDAL.StatusId;

            return DecisionTypeBAL;
        }
        #endregion

        #region AddEditDecisionType
        public int AddEditDecisionType(DecisionTypeBAL DecisionTypeBAL)
        {
            DecisionTypeDAL DecisionTypeDAL = new DecisionTypeDAL();
            DecisionTypeDAL.Code = DecisionTypeBAL.Code;
            DecisionTypeDAL.DecisionTypeId = DecisionTypeBAL.DecisionTypeId;
            DecisionTypeDAL.DecisionTypeCode = DecisionTypeBAL.DecisionTypeCode;
            DecisionTypeDAL.DecisionTypeName = DecisionTypeBAL.DecisionTypeName;
            DecisionTypeDAL.StatusId = DecisionTypeBAL.StatusId;
            DecisionTypeDAL.CreatedOn = DecisionTypeBAL.CreatedOn;
            DecisionTypeDAL.CreatedBy = DecisionTypeBAL.CreatedBy;
            DecisionTypeDAL.UpdatedOn = DecisionTypeBAL.UpdatedOn;
            DecisionTypeDAL.UpdatedBy = DecisionTypeBAL.UpdatedBy;

            return DecisionTypeDB.AddEditDecisionType(DecisionTypeDAL);
        }
        #endregion

        #region DeleteDecisionTypeByDecisionTypeId
        public static int DeleteDecisionTypeByDecisionTypeId(int DecisionTypeId)
        {
            return DecisionTypeDB.DeleteDecisionTypeByDecisionTypeId(DecisionTypeId);
        }
        #endregion
        
    }
    #endregion

}
