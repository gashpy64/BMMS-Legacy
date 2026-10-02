using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region CommitteeBAL
    public class CommitteeBAL
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

    #region CommitteeBALList
    public class CommitteeBALList : List<CommitteeBAL>
    {
        #region public CommitteeBALList()
        public CommitteeBALList()
        {

        }
        #endregion
    }
    #endregion

    #region CommitteeMgr
    public class CommitteeMgr
    {

        #region GetCommitteeList
        public static DataTable GetCommitteeList(int StatusId)
        {
            return CommitteeDB.GetCommitteeList(StatusId);
        }
        #endregion

        #region GetNextCommitteeCode
        public static string GetNextCommitteeCode()
        {
            return CommitteeDB.GetNextCommitteeCode();
        }
        #endregion

        #region GetCommitteeByCommitteeId
        public static CommitteeBAL GetCommitteeByCommitteeId(int CommitteeId)
        {
            CommitteeDAL CommitteeDAL = new CommitteeDAL();
            CommitteeDAL = CommitteeDB.GetCommitteeByCommitteeId(CommitteeId);

            CommitteeBAL CommitteeBAL = new CommitteeBAL();
            CommitteeBAL.CommitteeId = CommitteeDAL.CommitteeId;
            CommitteeBAL.CommitteeCode = CommitteeDAL.CommitteeCode;
            CommitteeBAL.CommitteeName = CommitteeDAL.CommitteeName;
            CommitteeBAL.Board = CommitteeDAL.Board;
            CommitteeBAL.IncorporationDate = CommitteeDAL.IncorporationDate;
            CommitteeBAL.MeetingStartNo = CommitteeDAL.MeetingStartNo;
            CommitteeBAL.CommitteeColorCode = CommitteeDAL.CommitteeColorCode;
            CommitteeBAL.CessationDate = CommitteeDAL.CessationDate;
            CommitteeBAL.StatusId = CommitteeDAL.StatusId;
            CommitteeBAL.IsDelete = CommitteeDAL.IsDelete;

            return CommitteeBAL;
        }
        #endregion

        #region AddEditCommittee
        public int AddEditCommittee(CommitteeBAL CommitteeBAL)
        {
            CommitteeDAL CommitteeDAL = new CommitteeDAL();
            CommitteeDAL.Code = CommitteeBAL.Code;
            CommitteeDAL.CommitteeId = CommitteeBAL.CommitteeId;
            CommitteeDAL.CommitteeCode = CommitteeBAL.CommitteeCode;
            CommitteeDAL.CommitteeName = CommitteeBAL.CommitteeName;
            CommitteeDAL.Board = CommitteeBAL.Board;
            CommitteeDAL.IncorporationDate = CommitteeBAL.IncorporationDate;
            CommitteeDAL.MeetingStartNo = CommitteeBAL.MeetingStartNo;
            CommitteeDAL.CommitteeColorCode = CommitteeBAL.CommitteeColorCode;
            CommitteeDAL.CessationDate = CommitteeBAL.CessationDate;
            CommitteeDAL.StatusId = CommitteeBAL.StatusId;
            CommitteeDAL.CreatedOn = CommitteeBAL.CreatedOn;
            CommitteeDAL.CreatedBy = CommitteeBAL.CreatedBy;
            CommitteeDAL.UpdatedOn = CommitteeBAL.UpdatedOn;
            CommitteeDAL.UpdatedBy = CommitteeBAL.UpdatedBy;

            return CommitteeDB.AddEditCommittee(CommitteeDAL);
        }
        #endregion

        #region DeleteCommitteeByCommitteeId
        public static int DeleteCommitteeByCommitteeId(int CommitteeId)
        {
            return CommitteeDB.DeleteCommitteeByCommitteeId(CommitteeId);
        }
        #endregion

    }
    #endregion

}
