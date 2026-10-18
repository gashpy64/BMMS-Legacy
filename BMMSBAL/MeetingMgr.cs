using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MeetingChangeResult
    /// <summary>
    /// Answer of the meeting-state procedures (BMMS-Fix-MeetingLocks.sql and
    /// BMMS-Fix-MeetingLocks-Step16.sql). Result 1 = done, 0 = refused.
    /// Reason says why (see MeetingChangeReason). ReasonDetail: the meeting's
    /// current status for reason 3, Finalized / BypassOff for reason 5, the
    /// locked fields for reason 6, the member name for reason 9.
    /// </summary>
    public class MeetingChangeResult
    {
        public int Result;
        public int Reason;
        public string ReasonDetail = string.Empty;

        public static MeetingChangeResult FromTable(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0 || !dt.Columns.Contains("Reason"))
                throw new InvalidOperationException("The meeting procedure returned no Reason. Run Database/BMMS-Fix-MeetingLocks.sql and BMMS-Fix-MeetingLocks-Step16.sql.");

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
                case MeetingChangeReason.AgendaFinalized:
                    return ReasonDetail == "BypassOff"
                         ? MeetingChangeReason.AgendaFinalizedMessage + " Controller changes after finalization are switched off in System Settings."
                         : MeetingChangeReason.AgendaFinalizedMessage;
                case MeetingChangeReason.AttendanceLocksMeeting:
                    return MeetingChangeReason.AttendanceLocksMeetingMessage;
                case MeetingChangeReason.MinutesConfirmed:
                    return MeetingChangeReason.MinutesConfirmedMessage;
                case MeetingChangeReason.ActingUserInvalid:
                    return "Your session is no longer valid. Please log in again.";
                case MeetingChangeReason.NotOnCommittee:
                    return System.Web.HttpUtility.HtmlEncode(ReasonDetail) + " is not a member of this committee on the meeting date.";
                case MeetingChangeReason.AgendaLocksCommittee:
                    return "Agenda items are recorded for this meeting, so its committee cannot be changed.";
                case MeetingChangeReason.ManagerInactive:
                    return MeetingChangeReason.ManagerInactiveMessage(ReasonDetail);
                case MeetingChangeReason.SystemAccount:
                    return MeetingChangeReason.SystemAccountMessage;
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
        public const int AgendaFinalized = 5;          // step 16: agenda add / edit / delete / approve
        public const int AttendanceLocksMeeting = 6;   // step 16: meeting date / committee
        public const int MinutesConfirmed = 7;         // step 16: minutes update
        public const int ActingUserInvalid = 8;        // step 16: acting user missing or inactive
        public const int NotOnCommittee = 9;           // step 16: chairman
        public const int AgendaLocksCommittee = 10;    // step 16: meeting committee
        public const int ManagerInactive = 11;         // step 17: the user's manager is inactive (new agenda item)
        public const int SystemAccount = 12;           // step 18: the protected system account cannot approve or reject

        public const string SystemAccountMessage =
            "The system account takes no part in the agenda workflow and cannot approve or reject agenda items.";

        /// <summary>A user's new agenda item waits for their manager, who is inactive (BMMS-Fix-UserStatus-Stage2b.sql).</summary>
        public static string ManagerInactiveMessage(string managerName)
        {
            string who = string.IsNullOrEmpty(managerName) ? "Your manager" : "Your manager (" + System.Web.HttpUtility.HtmlEncode(managerName) + ")";
            return who + " is inactive, so this agenda item cannot be sent for approval. Ask the administrator to assign you an active manager.";
        }

        public const string MinutesFinalizedMessage =
            "The minutes of this meeting are finalized. Members, attendance and chairman can no longer be changed.";

        public const string AgendaFinalizedMessage =
            "The agenda for this meeting is finalized, so agenda items can no longer be added, changed or deleted.";

        public const string AttendanceLocksMeetingMessage =
            "Attendance is recorded for this meeting, so its date and committee cannot be changed. Venue, time and the other details can still be changed.";

        public const string MinutesConfirmedMessage =
            "The minutes of this meeting are confirmed and can no longer be changed.";
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
        // Refused (Reason 6) when attendance is recorded and the date or committee changes,
        // and (Reason 10) when agenda items exist and the committee changes (BMMS-Fix-MeetingLocks-Step16.sql)
        public static MeetingChangeResult AddEditMeeting(MeetingBAL MeetingBAL)
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

            return MeetingChangeResult.FromTable(MeetingDB.AddEditMeeting(MeetingDAL));
        }
        #endregion

        #region IsMeetingHeld
        // True when the meeting is dated today or earlier (database server date)
        public static bool IsMeetingHeld(int MeetingId)
        {
            DataTable dt = MeetingDB.GetMeetingStatusByMeetingId(MeetingId);

            return dt.Rows.Count > 0 && Convert.ToInt32(dt.Rows[0]["IsHeld"]) == 1;
        }
        #endregion

        #region IsAgendaOpen
        // True while the agenda is not finalized (NULL AgendaStatus counts as 'Open')
        public static bool IsAgendaOpen(int MeetingId)
        {
            DataTable dt = MeetingDB.GetMeetingStatusByMeetingId(MeetingId);

            return dt.Rows.Count > 0 && dt.Rows[0]["AgendaStatus"].ToString() == "Open";
        }
        #endregion

        #region HasAttendance
        // True when attendance is recorded for the meeting: its date and committee are then locked
        public static bool HasAttendance(int MeetingId)
        {
            DataTable dt = MeetingDB.GetMeetingEditLockByMeetingId(MeetingId);

            return dt.Rows.Count > 0 && Convert.ToInt32(dt.Rows[0]["HasAttendance"]) == 1;
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
