using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region CommitteeDAL
    public class CommitteeDAL
    {
        #region Properties

        private string _Code;
        private int _CommitteeId;
        private string _CommitteeCode;
        private string _CommitteeName;
        private int _Board;
        private DateTime _IncorporationDate;
        private string _CommitteeColorCode;
        private int _MeetingStartNo;
        private string _CessationDate;
        private int _StatusId;
        private int _IsDelete;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int CommitteeId
        {
            get { return _CommitteeId; }
            set { _CommitteeId = value; }
        }
        public string CommitteeCode
        {
            get { return _CommitteeCode; }
            set { _CommitteeCode = value; }
        }
        public string CommitteeName
        {
            get { return _CommitteeName; }
            set { _CommitteeName = value; }
        }
        public int Board
        {
            get { return _Board; }
            set { _Board = value; }
        }
        public DateTime IncorporationDate
        {
            get { return _IncorporationDate; }
            set { _IncorporationDate = value; }
        }
        public int MeetingStartNo
        {
            get { return _MeetingStartNo; }
            set { _MeetingStartNo = value; }
        }
        public string CommitteeColorCode
        {
            get { return _CommitteeColorCode; }
            set { _CommitteeColorCode = value; }
        }
        public string CessationDate
        {
            get { return _CessationDate; }
            set { _CessationDate = value; }
        }
        public int StatusId
        {
            get { return _StatusId; }
            set { _StatusId = value; }
        }
        public int IsDelete
        {
            get { return _IsDelete; }
            set { _IsDelete = value; }
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

    #region CommitteeDALList
    public class CommitteeDALList : List<CommitteeDAL>
    {
        #region CommitteeDALList
        public CommitteeDALList()
        {

        }
        #endregion
    }
    #endregion

    #region CommitteeDB
    public class CommitteeDB
    {

        #region GetCommitteeList
        public static DataTable GetCommitteeList(int StatusId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@StatusId", StatusId);

            return CommonDB.GetDataTable("spr_GetCommittee", parameter); ;
        }
        #endregion

        #region GetNextCommitteeCode
        public static string GetNextCommitteeCode()
        {
            DataTable dt = new DataTable();
            dt = CommonDB.GetDataTable("spr_GetNextCommitteeCode", null);

            return dt.Rows[0]["NextCommitteeCode"].ToString();
        }
        #endregion

        #region GetCommitteeByCommitteeId
        public static CommitteeDAL GetCommitteeByCommitteeId(int CommitteeId)
        {
            DataTable dt = new DataTable();

            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            dt = CommonDB.GetDataTable("spr_GetCommitteeByCommitteeId", parameter);

            CommitteeDAL CommitteeDAL = new CommitteeDAL();
            CommitteeDAL.CommitteeId = Convert.ToInt16(dt.Rows[0]["CommitteeId"].ToString());
            CommitteeDAL.CommitteeCode = dt.Rows[0]["CommitteeCode"].ToString();
            CommitteeDAL.CommitteeName = dt.Rows[0]["CommitteeName"].ToString();
            CommitteeDAL.Board = Convert.ToInt16(dt.Rows[0]["Board"].ToString());
            CommitteeDAL.IncorporationDate = Convert.ToDateTime(dt.Rows[0]["IncorporationDate"].ToString());
            CommitteeDAL.MeetingStartNo = int.Parse(dt.Rows[0]["MeetingStartNo"].ToString());
            CommitteeDAL.CommitteeColorCode = dt.Rows[0]["CommitteeColorCode"].ToString();
            CommitteeDAL.CessationDate = dt.Rows[0]["CessationDate"].ToString();
            CommitteeDAL.StatusId = Convert.ToInt16(dt.Rows[0]["StatusId"].ToString());
            CommitteeDAL.IsDelete = Convert.ToInt16(dt.Rows[0]["IsDelete"].ToString());

            return CommitteeDAL;
        }
        #endregion

        #region AddEditCommittee
        public static int AddEditCommittee(CommitteeDAL CommitteeDAL)
        {
            SqlParameter[] parameter = new SqlParameter[14];
            parameter[0] = new SqlParameter("@Code", CommitteeDAL.Code);
            parameter[1] = new SqlParameter("@CommitteeId", CommitteeDAL.CommitteeId);
            parameter[2] = new SqlParameter("@CommitteeCode", CommitteeDAL.CommitteeCode);
            parameter[3] = new SqlParameter("@CommitteeName", CommitteeDAL.CommitteeName);
            parameter[4] = new SqlParameter("@Board", CommitteeDAL.Board);
            parameter[5] = new SqlParameter("@IncorporationDate", CommitteeDAL.IncorporationDate);
            parameter[6] = new SqlParameter("@MeetingStartNo", CommitteeDAL.MeetingStartNo);
            parameter[7] = new SqlParameter("@CommitteeColorCode", CommitteeDAL.CommitteeColorCode);
            parameter[8] = new SqlParameter("@CessationDate", CommitteeDAL.CessationDate);
            parameter[9] = new SqlParameter("@StatusId", CommitteeDAL.StatusId);
            parameter[10] = new SqlParameter("@CreatedOn", CommitteeDAL.CreatedOn);
            parameter[11] = new SqlParameter("@CreatedBy", CommitteeDAL.CreatedBy);
            parameter[12] = new SqlParameter("@UpdatedOn", CommitteeDAL.UpdatedOn);
            parameter[13] = new SqlParameter("@UpdatedBy", CommitteeDAL.UpdatedBy);

            return CommonDB.ExecuteProcedure("spr_AddEditCommittee", parameter);
        }
        #endregion

        #region DeleteCommitteeByCommitteeId
        public static int DeleteCommitteeByCommitteeId(int CommitteeId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);

            return CommonDB.ExecuteProcedure("spr_DeleteCommitteeByCommitteeId", parameter); ;
        }
        #endregion
    }
    #endregion

}
