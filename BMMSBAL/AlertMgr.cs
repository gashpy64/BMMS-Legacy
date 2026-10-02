using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region AlertBAL
    public class AlertBAL
    {
        #region Properties

        #endregion
    }
    #endregion

    #region AlertBALList
    public class AlertBALList : List<AlertBAL>
    {
        #region public AlertBALList()
        public AlertBALList()
        {

        }
        #endregion
    }
    #endregion

    #region AlertMgr
    public class AlertMgr
    {

        #region GetAlertByUserId
        public static DataTable GetAlertByUserId(string RoleName, int UserId)
        {
            return AlertDB.GetAlertByUserId(RoleName, UserId);
        }
        #endregion

        #region GetAlertMailId
        public static string GetAlertMailId(string Code, int UserId, int AgendaId)
        {
            return AlertDB.GetAlertMailId(Code, UserId, AgendaId);
        }
        #endregion

        #region UpdateAlertByUserId
        public static void UpdateAlertByUserId(int UserId, int AlertId)
        {
            AlertDB.UpdateAlertByUserId(UserId, AlertId);
        }
        #endregion

        #region UpdateAlertByAlertUserId
        public static void UpdateAlertByAlertUserId(int AlertUserId)
        {
            AlertDB.UpdateAlertByAlertUserId(AlertUserId);
        }
        #endregion

        #region UpdateAlertByMeetingId
        public static void UpdateAlertByMeetingId(int MeetingId)
        {
            AlertDB.UpdateAlertByMeetingId(MeetingId);
        }
        #endregion        
    }
    #endregion

}
