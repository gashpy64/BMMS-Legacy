using System;
using System.Collections.Generic;
using System.Text;
using System.Data.SqlClient;
using System.Data;


namespace BMMSDAL
{
    #region ActionItemDAL
    public class ActionItemDAL
    {
        #region Properties

        #endregion
    }
    #endregion

    #region ActionItemDALList
    public class ActionItemDALList : List<ActionItemDAL>
    {
        #region ActionItemDALList
        public ActionItemDALList()
        {

        }
        #endregion
    }
    #endregion

    #region ActionItemDB
    public class ActionItemDB
    {

        #region GetFollowup
        public static DataTable GetFollowup(string SQL_Query_Text)
        {
            return CommonDB.GetDataTableFromQuery(SQL_Query_Text);
        }
        #endregion

        #region GetActionItemByUserId
        public static DataTable GetActionItemByUserId(int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetActionItemByUserId", parameter); ;
        }
        #endregion

        #region GetActionItemByMeetingId
        public static DataTable GetActionItemByMeetingId(int MeetingId, int IsConfirmed)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@MeetingId", MeetingId);
            parameter[1] = new SqlParameter("@IsConfirmed", IsConfirmed);

            return CommonDB.GetDataTable("spr_GetActionItemByMeetingId", parameter); ;
        }
        #endregion

        #region GetActionItemByMeetingIdDeptId
        public static DataTable GetActionItemByMeetingIdDeptId(int CommitteeId, int MeetingNoFrom, int MeetingNoTo, int DepartmentId)
        {
            SqlParameter[] parameter = new SqlParameter[4];
            parameter[0] = new SqlParameter("@CommitteeId", CommitteeId);
            parameter[1] = new SqlParameter("@MeetingNoFrom", MeetingNoFrom);
            parameter[2] = new SqlParameter("@MeetingNoTo", MeetingNoTo);
            parameter[3] = new SqlParameter("@DepartmentId", DepartmentId);

            return CommonDB.GetDataTable("spr_GetActionItemByMeetingIdDeptId", parameter); ;
        }
        #endregion

        #region GetActionItemByActionItemIdUserId
        public static DataTable GetActionItemByActionItemIdUserId(int ActionItemId, int UserId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[1] = new SqlParameter("@UserId", UserId);

            return CommonDB.GetDataTable("spr_GetActionItemByActionItemIdUserId", parameter); ;
        }
        #endregion

        #region GetActionItemByActionItemId
        public static DataTable GetActionItemByActionItemId(int ActionItemId)
        {
            SqlParameter[] parameter = new SqlParameter[1];
            parameter[0] = new SqlParameter("@ActionItemId", ActionItemId);

            return CommonDB.GetDataTable("spr_GetActionItemByActionItemId", parameter); ;
        }
        #endregion

        #region UpdateActionItem
        public static void UpdateActionItem(string Code, int ActionItemId, string ActualResolution, string ActionText, int IsComplied, int IsConfirmed)
        {
            SqlParameter[] parameter = new SqlParameter[6];
            parameter[0] = new SqlParameter("@Code", Code);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);
            parameter[2] = new SqlParameter("@ActualResolution", ActualResolution);
            parameter[3] = new SqlParameter("@ActionText", ActionText);
            parameter[4] = new SqlParameter("@IsComplied", IsComplied);
            parameter[5] = new SqlParameter("@IsConfirmed", IsConfirmed);

            CommonDB.ExecuteProcedure("spr_UpdateActionItem", parameter); ;
        }
        #endregion

        #region UpdateActionItemByUserId
        public static void UpdateActionItemByUserId(int UserId, int ActionItemId)
        {
            SqlParameter[] parameter = new SqlParameter[2];
            parameter[0] = new SqlParameter("@UserId", UserId);
            parameter[1] = new SqlParameter("@ActionItemId", ActionItemId);

            CommonDB.ExecuteProcedure("spr_UpdateActionItemByUserId", parameter); ;
        }
        #endregion
    }
    #endregion
    
}
