using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MeetingChangeResult
    /// <summary>
    /// Answer of the meeting-state procedures (BMMS-Fix-MeetingLocks.sql).
    /// Result 1 = done, 0 = refused. Reason says why (see MeetingChangeReason).
    /// ReasonDetail: the meeting's current status for reason 3.
    /// </summary>
    public class MeetingChangeResult
    {
        public int Result;
        public int Reason;
        public string ReasonDetail = string.Empty;

        public static MeetingChangeResult FromTable(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0 || !dt.Columns.Contains("Reason"))
                throw new InvalidOperationException("The meeting procedure returned no Reason. Run Database/BMMS-Fix-MeetingLocks.sql.");

            MeetingChangeResult r = new MeetingChangeResult();
            r.Result = Convert.ToInt32(dt.Rows[0]["Result"]);
            r.Reason = Convert.ToInt32(dt.Rows[0]["Reason"]);
            r.ReasonDetail = dt.Rows[0]["ReasonDetail"].ToString();
            return r;
        }

        /// <summary>Message for the page when Result = 0.</summary>
        public string RefusalMessage()
        {
            switch (Reason)
            {
                case MeetingChangeReason.MinutesFinalized:
                    return MeetingChangeReason.MinutesFinalizedMessage;
                case MeetingChangeReason.AttendanceRecorded:
                    return "This member's attendance is recorded for the meeting, so they cannot be removed.";
                case MeetingChangeReason.WrongState:
                    return "This step has already been done for this meeting (status: "
                         + System.Web.HttpUtility.HtmlEncode(ReasonDetail) + "). Reload the page to see the current state.";
                case MeetingChangeReason.NotFound:
                    return "The meeting or member no longer exists. Reload the page.";
                default:
                    return "Record Not Saved";
            }
        }
    }

    public static class MeetingChangeReason
    {
        public const int None = 0;
        public const int MinutesFinalized = 1;     // MinutesStatus 'F' or 'C'
        public const int AttendanceRecorded = 2;   // meeting member delete
        public const int WrongState = 3;           // agenda / minutes finalize, minutes confirm
        public const int NotFound = 4;

        public const string MinutesFinalizedMessage =
            "The minutes of this meeting are finalized. Members, attendance and chairman can no longer be changed.";
    }
    #endregion

    #region MeetingBAL
    public class MeetingBAL
    {
        #region Properties

        private string _Code;
        private int _MeetingId;
        private string _MeetingNo;
        private int _CommitteeId;
        private string _Place;
        private string _Venue;
        private DateTime _MeetingDate;
        private string _MeetingTime;
        private DateTime _AgendaSubmissionDate;
        private string _MeetingColorCode;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MeetingId
        {
            get { return _MeetingId; }
            set { _MeetingId = value; }
        }
        public string MeetingNo
        {
            get { return _MeetingNo; }
            set { _MeetingNo = value; }
        }
        public int CommitteeId
        {
            get { return _CommitteeId; }
            set { _CommitteeId = value; }
        }
        public string Place
        {
            get { return _Place; }
            set { _Place = value; }
        }
        public string Venue
        {
            get { return _Venue; }
            set { _Venue = value; }
        }

        public DateTime MeetingDate
        {
            get { return _MeetingDate; }
            set { _MeetingDate = value; }
        }
        public string MeetingTime
        {
            get { return _MeetingTime; }
            set { _MeetingTime = value; }
        }
        public DateTime AgendaSubmissionDate
        {
            get { return _AgendaSubmissionDate; }
            set { _AgendaSubmissionDate = value; }
        }
        public string MeetingColorCode
        {
            get { return _MeetingColorCode; }
            set { _MeetingColorCode = value; }
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

    #region MeetingBALList
    public class MeetingBALList : List<MeetingBAL>
    {
        #region public MeetingBALList()
        public MeetingBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MeetingMgr
    public class MeetingMgr
    {

        #region GetMeetingList
        public static DataTable GetMeetingList()
        {
            return MeetingDB.GetMeetingList();
        }
        #endregion

        #region GetScheduleMeet
        public static DataTable GetScheduleMeet(string Code)
        {
            return MeetingDB.GetScheduleMeet(Code);
        }
        #endregion

        #region GetMeetingByCommitteeId
        public static DataTable GetMeetingByCommitteeId(int CommitteeId)
        {
            return MeetingDB.GetMeetingByCommitteeId(CommitteeId);
        }
        #endregion

        #region GetMeetingForController
        public static DataTable GetMeetingForController(int CommitteeId)
        {
            return MeetingDB.GetMeetingForController(CommitteeId);
        }
        #endregion

        #region GetMeetingForUsers
        public static DataTable GetMeetingForUsers(int CommitteeId)
        {
            return MeetingDB.GetMeetingForUsers(CommitteeId);
        }
        #endregion

        #region GetNextMeetingByCommitteeId
        public static DataTable GetLastMeetingByCommitteeId(int CommitteeId, int MeetingId)
        {
            return MeetingDB.GetLastMeetingByCommitteeId(CommitteeId, MeetingId);
        }
        #endregion

        #region GetNextMeetingNo
        public static string GetNextMeetingNo(int CommitteeId)
        {
            return MeetingDB.GetNextMeetingNo(CommitteeId);
        }
        #endregion

        #region GetMeetingByMeetingId
        public static DataTable GetMeetingByMeetingId(int MeetingId)
        {
            return MeetingDB.GetMeetingByMeetingId(MeetingId);
        }
        #endregion

        #region GetMeetingByMeetingNoFromTo
        public static DataTable GetMeetingByMeetingNoFromTo(int CommitteeId, int MeetingIdFrom, int MeetingIdTo)
        {
            return MeetingDB.GetMeetingByMeetingNoFromTo(CommitteeId, MeetingIdFrom, MeetingIdTo);
        }
        #endregion

        #region GetMeetingByFromToDate
        public static DataTable GetMeetingByFromToDate(int CommitteeId, DateTime FromDate, DateTime ToDate)
        {
            return MeetingDB.GetMeetingByFromToDate(CommitteeId, FromDate, ToDate);
        }
        #endregion

        #region GetMeetingFullMember
        public static DataTable GetMeetingFullMember(int MeetingId, int CommitteeId)
        {
            return MeetingDB.GetMeetingFullMember(MeetingId, CommitteeId);
        }
        #endregion

        #region GetMeetingChairman
        public static DataTable GetMeetingChairman(int MeetingId)
        {
            return MeetingDB.GetMeetingChairman(MeetingId);
        }
        #endregion

        #region AddEditMeeting
        public static int AddEditMeeting(MeetingBAL MeetingBAL)
        {
            MeetingDAL MeetingDAL = new MeetingDAL();
            MeetingDAL.Code = MeetingBAL.Code;
            MeetingDAL.MeetingId = MeetingBAL.MeetingId;
            MeetingDAL.MeetingNo = MeetingBAL.MeetingNo;
            MeetingDAL.CommitteeId = MeetingBAL.CommitteeId;
            MeetingDAL.Place = MeetingBAL.Place;
            MeetingDAL.Venue = MeetingBAL.Venue;
            MeetingDAL.MeetingDate = MeetingBAL.MeetingDate;
            MeetingDAL.MeetingTime = MeetingBAL.MeetingTime;
            MeetingDAL.AgendaSubmissionDate = MeetingBAL.AgendaSubmissionDate;
            MeetingDAL.MeetingColorCode = MeetingBAL.MeetingColorCode;
            MeetingDAL.CreatedOn = MeetingBAL.CreatedOn;
            MeetingDAL.CreatedBy = MeetingBAL.CreatedBy;
            MeetingDAL.UpdatedOn = MeetingBAL.UpdatedOn;
            MeetingDAL.UpdatedBy = MeetingBAL.UpdatedBy;

            return MeetingDB.AddEditMeeting(MeetingDAL);
        }
        #endregion

        #region UpdateMeetingChairman
        public static MeetingChangeResult UpdateMeetingChairman(int MeetingId, int CommitteeId, int ChairmanNameId)
        {
            return MeetingChangeResult.FromTable(MeetingDB.UpdateMeetingChairman(MeetingId, CommitteeId, ChairmanNameId));
        }
        #endregion

        #region IsMinutesFinalized
        // True once the minutes are finalized ('F') or confirmed ('C'): members, attendance
        // and chairman can no longer change (BMMS-Fix-MeetingLocks.sql)
        public static bool IsMinutesFinalized(int MeetingId)
        {
            DataTable dt = MeetingDB.GetMeetingStatusByMeetingId(MeetingId);

            return dt.Rows.Count > 0 && Convert.ToInt32(dt.Rows[0]["IsMinutesFinalized"]) == 1;
        }
        #endregion

        #region DeleteMeetingByMeetingId
        public static int DeleteMeetingByMeetingId(int MeetingId)
        {
            return MeetingDB.DeleteMeetingByMeetingId(MeetingId);
        }
        #endregion

    }
    #endregion

}
