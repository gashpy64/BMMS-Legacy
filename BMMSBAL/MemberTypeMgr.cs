using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using BMMSDAL;

namespace BMMSBAL
{
    #region MemberTypeBAL
    public class MemberTypeBAL
    {
        #region Properties

        private string _Code;
        private int _MemberTypeId;
        private string _MemberTypeCode;
        private string _MemberTypeName;
        private int _StatusId;
        private string _MemberScope;
        private int _DisplayOrder;
        private int _IsReserved;
        private int _CommitteeUseCount;
        private int _MeetingUseCount;
        private DateTime _CreatedOn;
        private int _CreatedBy;
        private DateTime _UpdatedOn;
        private int _UpdatedBy;
        private int _ActingUserId;

        public string Code
        {
            get { return _Code; }
            set { _Code = value; }
        }
        public int MemberTypeId
        {
            get { return _MemberTypeId; }
            set { _MemberTypeId = value; }
        }
        public string MemberTypeCode
        {
            get { return _MemberTypeCode; }
            set { _MemberTypeCode = value; }
        }
        public string MemberTypeName
        {
            get { return _MemberTypeName; }
            set { _MemberTypeName = value; }
        }
        public int StatusId
        {
            get { return _StatusId; }
            set { _StatusId = value; }
        }
        /// <summary>C committee type, M meeting type (BMMS-Fix-MemberTypes-Step21.sql)</summary>
        public string MemberScope
        {
            get { return _MemberScope; }
            set { _MemberScope = value; }
        }
        public int DisplayOrder
        {
            get { return _DisplayOrder; }
            set { _DisplayOrder = value; }
        }
        /// <summary>1 = used by the application by id; cannot be edited or deleted</summary>
        public int IsReserved
        {
            get { return _IsReserved; }
            set { _IsReserved = value; }
        }
        public int CommitteeUseCount
        {
            get { return _CommitteeUseCount; }
            set { _CommitteeUseCount = value; }
        }
        public int MeetingUseCount
        {
            get { return _MeetingUseCount; }
            set { _MeetingUseCount = value; }
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
        public int ActingUserId
        {
            get { return _ActingUserId; }
            set { _ActingUserId = value; }
        }

        #endregion
    }
    #endregion

    #region MemberTypeBALList
    public class MemberTypeBALList : List<MemberTypeBAL>
    {
        #region public MemberTypeBALList()
        public MemberTypeBALList()
        {

        }
        #endregion
    }
    #endregion

    #region MemberTypeMgr
    public class MemberTypeMgr
    {
        public const string CommitteeScope = "C";
        public const string MeetingScope = "M";

        #region GetMemberTypeList
        public static DataTable GetMemberTypeList(int StatusId)
        {
            return MemberTypeDB.GetMemberTypeList(StatusId);
        }
        #endregion

        #region GetMemberTypeForTagging
        /// <summary>
        /// Drop-down of Committee Member (scope C) or Meeting Member (scope M): the active types of
        /// the scope in display order, plus CurrentMemberTypeId marked "(inactive)" or with its
        /// scope when it is not one of them (0 = none). Columns MemberTypeId, MemberTypeName, DisplayName.
        /// </summary>
        public static DataTable GetMemberTypeForTagging(string MemberScope, int CurrentMemberTypeId)
        {
            return MemberTypeDB.GetMemberTypeForTagging(MemberScope, CurrentMemberTypeId);
        }
        #endregion

        #region GetNextMemberTypeCode
        public static string GetNextMemberTypeCode()
        {
            return MemberTypeDB.GetNextMemberTypeCode();
        }
        #endregion

        #region GetMemberTypeByMemberTypeId
        public static MemberTypeBAL GetMemberTypeByMemberTypeId(int MemberTypeId)
        {
            MemberTypeDAL MemberTypeDAL = new MemberTypeDAL();
            MemberTypeDAL = MemberTypeDB.GetMemberTypeByMemberTypeId(MemberTypeId);

            MemberTypeBAL MemberTypeBAL = new MemberTypeBAL();
            MemberTypeBAL.MemberTypeId = MemberTypeDAL.MemberTypeId;
            MemberTypeBAL.MemberTypeCode = MemberTypeDAL.MemberTypeCode;
            MemberTypeBAL.MemberTypeName = MemberTypeDAL.MemberTypeName;
            MemberTypeBAL.StatusId = MemberTypeDAL.StatusId;
            MemberTypeBAL.MemberScope = MemberTypeDAL.MemberScope;
            MemberTypeBAL.DisplayOrder = MemberTypeDAL.DisplayOrder;
            MemberTypeBAL.IsReserved = MemberTypeDAL.IsReserved;
            MemberTypeBAL.CommitteeUseCount = MemberTypeDAL.CommitteeUseCount;
            MemberTypeBAL.MeetingUseCount = MemberTypeDAL.MeetingUseCount;

            return MemberTypeBAL;
        }
        #endregion

        #region AddEditMemberType
        public MeetingChangeResult AddEditMemberType(MemberTypeBAL MemberTypeBAL)
        {
            MemberTypeDAL MemberTypeDAL = new MemberTypeDAL();
            MemberTypeDAL.Code = MemberTypeBAL.Code;
            MemberTypeDAL.MemberTypeId = MemberTypeBAL.MemberTypeId;
            MemberTypeDAL.MemberTypeCode = MemberTypeBAL.MemberTypeCode;
            MemberTypeDAL.MemberTypeName = MemberTypeBAL.MemberTypeName;
            MemberTypeDAL.StatusId = MemberTypeBAL.StatusId;
            MemberTypeDAL.MemberScope = MemberTypeBAL.MemberScope;
            MemberTypeDAL.DisplayOrder = MemberTypeBAL.DisplayOrder;
            MemberTypeDAL.CreatedOn = MemberTypeBAL.CreatedOn;
            MemberTypeDAL.CreatedBy = MemberTypeBAL.CreatedBy;
            MemberTypeDAL.UpdatedOn = MemberTypeBAL.UpdatedOn;
            MemberTypeDAL.UpdatedBy = MemberTypeBAL.UpdatedBy;
            MemberTypeDAL.ActingUserId = MemberTypeBAL.ActingUserId;

            return ToResult(MemberTypeDB.AddEditMemberType(MemberTypeDAL), "spr_AddEditMemberType");
        }
        #endregion

        #region DeleteMemberTypeByMemberTypeId
        public static MeetingChangeResult DeleteMemberTypeByMemberTypeId(int MemberTypeId, int ActingUserId)
        {
            return ToResult(MemberTypeDB.DeleteMemberTypeByMemberTypeId(MemberTypeId, ActingUserId), "spr_DeleteMemberTypeByMemberTypeId");
        }
        #endregion

        #region RefusalMessage
        /// <summary>
        /// Message for the Member Type Master when Result = 0 (BMMS-Fix-MemberTypes-Step21.sql).
        /// IsDelete chooses the wording of Reason 5 (in use).
        /// </summary>
        public static string RefusalMessage(MeetingChangeResult Result, bool IsDelete)
        {
            switch (Result.Reason)
            {
                case 3:
                    switch (Result.ReasonDetail)
                    {
                        case "MemberTypeCode":
                            return "Member Type Code must be 1 to 50 characters, without line breaks, tabs or characters the database cannot store.";
                        case "MemberTypeName":
                            return "Member Type Name must be 1 to 50 characters, without line breaks, tabs or characters the database cannot store.";
                        case "MemberScope":
                            return "Choose where the member type is used: Committee or Meeting.";
                        case "DisplayOrder":
                            return "Display Order must be a number from 0 to 9999.";
                        case "StatusId":
                            return "Choose a status.";
                        case "DuplicateCode":
                            return "Another member type already has this code.";
                        case "DuplicateName":
                            return "Another member type already has this name.";
                        case "NotFound":
                            return "This member type no longer exists. Reload the page.";
                        default:
                            return "Record Not Saved";
                    }
                case 4:
                    return "Only an Admin or a Controller can change member types.";
                case 5:
                    if (IsDelete)
                        return "This member type is in use (" + System.Web.HttpUtility.HtmlEncode(Result.ReasonDetail)
                             + " member rows), so it cannot be deleted. You can make it inactive instead.";
                    return "This member type is in use (" + System.Web.HttpUtility.HtmlEncode(Result.ReasonDetail)
                         + " member rows), so it cannot be moved to the other tagging page.";
                case 7:
                    return ReservedMessage;
                case MeetingChangeReason.ActingUserInvalid:
                    return "Your session is no longer valid. Please log in again.";
                default:
                    return "Record Not Saved";
            }
        }

        public const string ReservedMessage =
            "This member type is reserved: the application uses it for the minutes, the notices and their signer, so it cannot be changed or deleted.";
        #endregion

        #region ToResult
        private static MeetingChangeResult ToResult(DataTable dt, string ProcedureName)
        {
            if (dt == null || !dt.Columns.Contains("Reason"))
                throw new InvalidOperationException(ProcedureName + " returned no Reason. Run Database/BMMS-Fix-MemberTypes-Step21.sql.");

            return MeetingChangeResult.FromTable(dt);
        }
        #endregion

    }
    #endregion

}
