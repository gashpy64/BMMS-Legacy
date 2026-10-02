using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MinutesBAL
    public class MinutesBAL
    {
        #region Properties

        private string _Code;
        private int _MinutesId;
        private int _DecisionTypeId;
        private DateTime _DueDate = System.DateTime.Now;
        private string _Directions;
        private string _ActualResolution;
        private string _ShortText = string.Empty;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MinutesId
        {
            get { return _MinutesId; }
            set { _MinutesId = value; }
        }
        public int DecisionTypeId
        {
            get { return _DecisionTypeId; }
            set { _DecisionTypeId = value; }
        }
        public DateTime DueDate
        {
            get { return _DueDate; }
            set { _DueDate = value; }
        }
        public string Directions
        {
            get { return _Directions; }
            set { _Directions = value; }
        }
        public string ActualResolution
        {
            get { return _ActualResolution; }
            set { _ActualResolution = value; }
        }
        public string ShortText
        {
            get { return _ShortText; }
            set { _ShortText = value; }
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

    #region MinutesBALList
    public class MinutesBALList : List<MinutesBAL>
    {
        #region public MinutesBALList()
        public MinutesBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MinutesMgr
    public class MinutesMgr
    {

        #region GetMinutesByMeetingId
        public static DataTable GetMinutesByMeetingId(int MeetingId, int StatusId, int DepartmentId)
        {
            return MinutesDB.GetMinutesByMeetingId(MeetingId, StatusId, DepartmentId);
        }
        #endregion

        #region GetMinutesByMeetingNoFromTo
        public static DataTable GetMinutesByMeetingNoFromTo(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int StatusId, int DepartmentId)
        {
            return MinutesDB.GetMinutesByMeetingNoFromTo(CommitteeId, MeetingNoFrom, MeetingNoTo, StatusId, DepartmentId);
        }
        #endregion

        #region GetMinutesByMeetingIdAgendaId
        public static DataTable GetMinutesByMeetingIdAgendaId(int MeetingId, int AgendaId)
        {
            return MinutesDB.GetMinutesByMeetingIdAgendaId(MeetingId, AgendaId);
        }
        #endregion

        #region GetMinutesByMinutesId
        public static DataTable GetMinutesByMinutesId(int MinutesId)
        {
            return MinutesDB.GetMinutesByMinutesId(MinutesId);
        }
        #endregion

        #region UpdateMinutes
        public static int UpdateMinutes(MinutesBAL myMinutesBAL)
        {
            MinutesDAL myMinutesDAL = new MinutesDAL();

            myMinutesDAL.Code = myMinutesBAL.Code;
            myMinutesDAL.MinutesId = myMinutesBAL.MinutesId;
            myMinutesDAL.DecisionTypeId = myMinutesBAL.DecisionTypeId;
            //myMinutesDAL.DueDate = myMinutesBAL.DueDate;
            myMinutesDAL.Directions = myMinutesBAL.Directions;
            myMinutesDAL.ActualResolution = myMinutesBAL.ActualResolution;
            myMinutesDAL.ShortText = myMinutesBAL.ShortText;
            myMinutesDAL.CreatedBy = myMinutesBAL.CreatedBy;
            myMinutesDAL.UpdatedBy = myMinutesBAL.UpdatedBy;

            return MinutesDB.UpdateMinutes(myMinutesDAL);
        }
        #endregion

    }
    #endregion

}
