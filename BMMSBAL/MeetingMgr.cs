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
                    // 'Open' comes only from Minutes Confirmation: the minutes are not finalized yet (step 23)
                    if (ReasonDetail == "Open")
                        return MeetingChangeReason.MinutesNotFinalizedForConfirmMessage;
                    return "This step has already been done for this meeting (status: "
                         + System.Web.HttpUtility.HtmlEncode(ReasonDetail) + "). Reload the page to see the current state.";
                case MeetingChangeReason.AgendaNotFinalized:
                    return MeetingChangeReason.AgendaNotFinalizedMessage;
                case MeetingChangeReason.AttendanceNotRecorded:
                    return MeetingChangeReason.AttendanceNotRecordedMessage;
                case MeetingChangeReason.MinutesNotUpdated:
                    return MeetingChangeReason.MinutesNotUpdatedMessage(ReasonDetail);
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
                case MeetingChangeReason.MemberTypeNotAllowed:
                    return MeetingChangeReason.MemberTypeNotAllowedMessage(ReasonDetail);
                case MeetingChangeReason.AgendaStepNotAllowed:
                    return MeetingChangeReason.AgendaStepNotAllowedMessage(ReasonDetail);
                case MeetingChangeReason.NoActiveController:
                    return MeetingChangeReason.NoActiveControllerMessage;
                case MeetingChangeReason.MeetingDateNotValid:
                    return MeetingChangeReason.MeetingDateNotValidMessage(ReasonDetail);
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
        public const int MemberTypeNotAllowed = 13;    // step 21: member type inactive, of the other scope or missing
        public const int AgendaStepNotAllowed = 14;    // step 20: approve / reject not allowed for you at this stage
        public const int NoActiveController = 15;      // step 20: the item would go to the Controllers and none is active
        public const int MeetingDateNotValid = 16;     // step 24: meeting / agenda submission date; ReasonDetail says which rule
        public const int AgendaNotFinalized = 17;      // step 23: attendance, minutes before the agenda is finalized
        public const int AttendanceNotRecorded = 18;   // step 23: minutes before the chairman and a member present are entered
        public const int MinutesNotUpdated = 19;       // step 23: finalize with a minute never updated; ReasonDetail 'not updated/total'

        public const string AgendaNotFinalizedMessage =
            "The agenda of this meeting is not finalized yet. Finalize the agenda (Agenda, Agenda Finalize) first.";

        public const string AttendanceNotRecordedMessage =
            "Attendance has not been entered for this meeting. Enter the attendance and the chairman (Master, Attendance) first.";

        public const string MinutesNotFinalizedForConfirmMessage =
            "The minutes of this meeting are not finalized yet. Finalize them (Minutes, Finalize Minutes) first.";

        /// <summary>Minutes finalize refused: ReasonDetail is 'not updated/total' (BMMS-Fix-WorkflowOrder-Step23.sql).</summary>
        public static string MinutesNotUpdatedMessage(string detail)
        {
            string[] parts = (detail ?? string.Empty).Split('/');
            int notUpdated, total;

            if (parts.Length == 2 && int.TryParse(parts[0], out notUpdated) && int.TryParse(parts[1], out total))
            {
                if (total == 0)
                    return "This meeting has no minutes to finalize (no agenda item was approved).";

                return notUpdated + " of the " + total + " minutes have not been updated yet. "
                     + "Update every item (Minutes, Update Minutes) before finalizing the minutes.";
            }

            return "Some minutes have not been updated yet. Update every item (Minutes, Update Minutes) before finalizing the minutes.";
        }

        // ReasonDetail of Reason 16 (BMMS-Fix-MeetingDates-Step24.sql)
        public const string DatesMissing = "Missing";
        public const string MeetingBeforeToday = "MeetingBeforeToday";
        public const string SubmissionBeforeToday = "SubmissionBeforeToday";
        public const string SubmissionAfterMeeting = "SubmissionAfterMeeting";

        /// <summary>A meeting date or agenda submission date the rules refuse (BMMS-Fix-MeetingDates-Step24.sql).</summary>
        public static string MeetingDateNotValidMessage(string detail)
        {
            switch (detail)
            {
                case MeetingBeforeToday:
                    return "The Meeting Date cannot be before today.";
                case SubmissionBeforeToday:
                    return "The Agenda Submission Date cannot be before today.";
                case SubmissionAfterMeeting:
                    return "The Agenda Submission Date must be on or before the Meeting Date.";
                default:
                    return "Meeting Date and Agenda Submission Date are required.";
            }
        }

        /// <summary>An approve or reject the acting user may not do at the item's stage (BMMS-Fix-AgendaRouting-Step20.sql).</summary>
        public static string AgendaStepNotAllowedMessage(string statusName)
        {
            return "You cannot approve or reject this agenda item at its current stage"
                 + (string.IsNullOrEmpty(statusName) ? "" : " (" + System.Web.HttpUtility.HtmlEncode(statusName) + ")")
                 + ". Reload the Dashboard to see its current state.";
        }

        public const string NoActiveControllerMessage =
            "No Controller is active, so this agenda item cannot be sent for approval. Ask the administrator to activate a Controller.";

        /// <summary>A committee or meeting member saved with a type the page does not offer (BMMS-Fix-MemberTypes-Step21.sql).</summary>
        public static string MemberTypeNotAllowedMessage(string typeName)
        {
            return "The member type " + System.Web.HttpUtility.HtmlEncode(typeName)
                 + " cannot be used here: it is inactive or belongs to the other tagging page. Reload the page and choose another type.";
        }

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

        // Minutes and Minutes Extract reports, page messages only: the report procedures read and return no Reason (BMMS-Fix-MinutesGating-Step22.sql)
        public const string MinutesNotFinalizedMessage =
            "The minutes of this meeting are not finalized yet. Finalize them (Minutes, Finalize Minutes) before viewing or generating the minutes or the minutes extract.";

        public const string NoMinutesFinalizedMessage =
            "No meeting of this committee has finalized minutes yet, so there are no minutes or minutes extracts to view or generate.";
    }
    #endregion

    #region MeetingWorkflowState
    /// <summary>
    /// A meeting's place in the workflow order (spr_GetMeetingWorkflowState, BMMS-Fix-WorkflowOrder-Step23.sql).
    /// The order applies only when IsNew (created after step 23 was installed).
    /// </summary>
    public class MeetingWorkflowState
    {
        public bool Exists;
        public bool IsNew;
        public bool AgendaFinalized;
        public bool AttendanceRecorded;   // chairman set and at least one member present
        public int MinutesTotal;
        public int MinutesUpdated;

        /// <summary>Attendance and chairman wait for Agenda Finalisation.</summary>
        public bool AttendanceBlocked
        {
            get { return IsNew && !AgendaFinalized; }
        }
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

        #region IsMeetingOpenForChange
        // Edit and Delete on Meeting Master: open for the whole of the meeting date, closed from the next day
        // (step M1; MeetingTime is not looked at). A meeting with no date stays open so that it can be corrected.
        public static bool IsMeetingOpenForChange(object MeetingDate, DateTime Today)
        {
            if (MeetingDate == null || MeetingDate == DBNull.Value)
                return true;

            return Convert.ToDateTime(MeetingDate).Date >= Today.Date;
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

        #region GetMeetingWorkflowState
        // The meeting's place in the workflow order (BMMS-Fix-WorkflowOrder-Step23.sql). IsNew: created after
        // step 23 was installed, so the order applies; for an older meeting the pages keep their earlier checks.
        public static MeetingWorkflowState GetMeetingWorkflowState(int MeetingId)
        {
            DataTable dt = MeetingDB.GetMeetingWorkflowState(MeetingId);
            MeetingWorkflowState state = new MeetingWorkflowState();

            if (dt.Rows.Count > 0)
            {
                state.Exists = true;
                state.IsNew = Convert.ToInt32(dt.Rows[0]["IsNew"]) == 1;
                state.AgendaFinalized = Convert.ToInt32(dt.Rows[0]["AgendaFinalized"]) == 1;
                state.AttendanceRecorded = Convert.ToInt32(dt.Rows[0]["AttendanceRecorded"]) == 1;
                state.MinutesTotal = Convert.ToInt32(dt.Rows[0]["MinutesTotal"]);
                state.MinutesUpdated = Convert.ToInt32(dt.Rows[0]["MinutesUpdated"]);
            }

            return state;
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

        #region GetMinutesReportMeetings
        // Meetings of the committee with finalized or confirmed minutes, by MeetingNo: the lists of the
        // Minutes and Minutes Extract reports (BMMS-Fix-MinutesGating-Step22.sql)
        public static DataTable GetMinutesReportMeetings(int CommitteeId)
        {
            return MinutesDB.GetMinutesReportMeetings(CommitteeId);
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
