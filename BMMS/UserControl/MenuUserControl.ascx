<%@ Control Language="C#" AutoEventWireup="true" Codebehind="MenuUserControl.ascx.cs"
    Inherits="BMMS.UserControl.MenuUserControl" %>
<div id="ddtopmenubar" class="mattblackmenu">
    <ul>
        <%if (Session["RoleCode"].ToString() != "admin" && Session["RoleCode"].ToString() != "md_sect")
          { %>
        <li><a href="../DashBoard/DashBoard.aspx">Home</a></li>
        <%
            } %>
        <%if (Session["RoleCode"].ToString() == "admin" || Session["RoleCode"].ToString() == "controller")
          { %>
        <li><a href="#" rel="ddsubmenu1">Master</a></li>
        <%
            } %>
        <%if (Session["RoleCode"].ToString() == "controller")
          { %>
        <li><a href="#" rel="ddsubmenu4">Agenda</a></li>
        <%
            } %>
        <%if (Session["RoleCode"].ToString() == "user" || Session["RoleCode"].ToString() == "manager")
          { %>
        <li><a href="../Master/Agenda.aspx">Agenda Entry</a></li>
        <%
            } %>
        <%if (Session["RoleCode"].ToString() == "controller" || Session["RoleCode"].ToString() == "md_sect")
          { %>
        <li><a href="#" rel="ddsubmenu3">Minutes</a></li>
        <%
            } %>
        <%if (Session["RoleCode"].ToString() == "admin" || Session["RoleCode"].ToString() == "controller")
          { %>
        <li><a href="#" rel="ddsubmenu2">Admin</a></li>
        <%
            } %>
        <%--<li><a href="../Master/ChangePassword.aspx">Change Password</a></li>--%>
        <%if (Session["RoleCode"].ToString() == "manager" || Session["RoleCode"].ToString() == "controller" || Session["RoleCode"].ToString() == "mgmt")
          { %>
        <li><a href="#" rel="ddSubmenuReports">Reports</a></li>
        <%
            } %>
    </ul>
</div>

<script type="text/javascript">
	ddlevelsmenu.setup("ddtopmenubar", "topbar") //ddlevelsmenu.setup("mainmenuid", "topbar|sidebar")
</script>

<!--HTML for the Drop Down Menus associated with Top Menu Bar-->
<!--They should be inserted OUTSIDE any element other than the BODY tag itself-->
<!--A good location would be the end of the page (right above "</BODY>")-->
<!--Top Drop Down Menu 1 HTML-->
<ul id="ddsubmenu1" class="ddsubmenustyle">
    <li><a href="../Master/Department.aspx">Department Master</a></li>
    <li><a href="../Master/Designation.aspx">Designation Master</a></li>
    <%if (Session["RoleCode"].ToString() == "admin")
      { %>
    <li><a href="../Master/MemberType.aspx">Member Type</a></li>
    <%
        } %>
    <li><a href="../Master/SubjectType.aspx">Subject Type</a></li>
    <li><a href="../Master/DecisionType.aspx">Decision Type</a></li>
    <li><a href="../Master/User.aspx">User Master</a></li>
    <li><a href="../Master/Member.aspx">Member Master</a></li>
    <li><a href="../Master/Committee.aspx">Committee Master</a></li>
    <li><a href="../Master/CommitteeMember.aspx">Committee Member Tag / UnTag</a></li>
    <li><a href="../Master/Meeting.aspx">Meeting Master</a></li>
    <li><a href="../Master/MeetingMember.aspx">Meeting - Member Tag / UnTag</a></li>
    <li><a href="../Master/Attendance.aspx">Attendance</a></li>
</ul>
<!--Top Drop Down Menu 2 HTML-->
<ul id="ddsubmenu2" class="ddsubmenustyle">
    <%if (Session["RoleCode"].ToString() == "admin")
      { %>
    <li><a href="../Master/ResetPassword.aspx">Reset Password</a></li>
    <li><a href="../Master/BackupDatabase.aspx">Backup Database</a></li>
    <li><a href="../Master/SMTPServerConfig.aspx">SMTP Configuration</a></li>
    <li><a href="../Master/ResetDatabase.aspx">Reset Database</a></li>
    <%
        } %>
    <%if (Session["RoleCode"].ToString() == "controller")
      { %>
    <li><a href="../Master/ResetPassword.aspx">Reset Password</a></li>
    <li><a href="../Master/BackupDatabase.aspx">Backup Database</a></li>
    <%
        } %>
</ul>
<ul id="ddSubmenuReports" class="ddsubmenustyle">
    <%if (Session["RoleCode"].ToString() == "controller")
      { %>
    <li><a href="../Report/SendMail.aspx">Send Mail</a></li>
    <li><a href="../Report/CommitteeMaster.aspx">Committee Master</a></li>
    <li><a href="../Report/MeetingMaster.aspx">Meeting Master</a></li>
    <li><a href="../Report/CommitteeMember.aspx">Committee Member</a></li>
    <li><a href="../Report/MeetingCalendar.aspx">Meeting Calendar</a></li>
    <li><a href="../Report/SittingFeesApplicable.aspx">Sitting Fees Applicable</a></li>
    <li><a href="../Report/SittingFees.aspx">Sitting Fees</a></li>
    <li><a href="../Report/AttendanceDetails.aspx">Attendance Details</a></li>
    <li><a href="../Report/AgendaApproval.aspx">Agenda Approval</a></li>
    <li><a href="../Report/Notice.aspx">Notice</a></li>
    <li><a href="../Report/Reports.aspx?rc=agenda_summary">Agenda Summary</a></li>
    <li><a href="../Report/Reports.aspx?rc=agenda_details">Agenda Details</a></li>
    <li><a href="../Report/Reports.aspx?rc=minutes">Minutes</a></li>
    <li><a href="../Report/Reports.aspx?rc=minutes_extract">Minutes Extract</a></li>
    <li><a href="../Report/Followup.aspx?fc=followup">Followup</a></li>
    <li><a href="../Report/Followup.aspx?fc=summary">Followup Summary</a></li>
    <li><a href="../Report/AuditTrail.aspx">Audit Trail</a></li>
    <%
        } %>
    <%if (Session["RoleCode"].ToString() == "manager")
      { %>
    <li><a href="../Report/Reports.aspx?rc=agenda_summary">Agenda Summary</a></li>
    <li><a href="../Report/Reports.aspx?rc=agenda_details">Agenda Details</a></li>
    <li><a href="../Report/Reports.aspx?rc=minutes">Minutes</a></li>
    <li><a href="../Report/Reports.aspx?rc=minutes_extract">Minutes Extract</a></li>
    <%
        } %>
</ul>
<ul id="ddsubmenu3" class="ddsubmenustyle">
    <%if (Session["RoleCode"].ToString() == "controller")
      { %>
    <li><a href="../Master/MinutesUpdate.aspx">Update Minutes</a></li>
    <li><a href="../Master/MinutesFinalization.aspx">Finalize Minutes</a></li>
    <li><a href="../Master/MinutesConfirmation.aspx">Minutes Confirmation</a></li>
    <li><a href="../Master/Followup.aspx">Followup</a></li>
    <%
        } %>
    <%if (Session["RoleCode"].ToString() == "md_sect")
      { %>
    <li><a href="../Master/Followup.aspx">Followup</a></li>
    <%
        } %>
</ul>
<ul id="ddsubmenu4" class="ddsubmenustyle">
    <%if (Session["RoleCode"].ToString() == "controller")
      { %>
    <li><a href="../Master/Agenda.aspx">Agenda Entry</a></li>
    <li><a href="../Master/AgendaFinalization.aspx">Agenda Finalize</a></li>
    <%
        } %>
</ul>
<!--Multi-Level Navigation Menu End-->
