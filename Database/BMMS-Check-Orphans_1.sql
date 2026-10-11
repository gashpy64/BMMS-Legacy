/* ============================================================================
   BMMS - Critical fix #5, step 1: READ-ONLY orphan check
   ----------------------------------------------------------------------------
   Nothing in this script changes data. For each relationship that has no
   foreign key today, it counts the rows that would BREAK the key if it were
   added (child rows pointing at a parent that does not exist).
   Written to run at any database compatibility level.

   How to read the first result grid (12 rows, one per relationship):
     OrphanRows         0  -> the key can be added as-is.
                        >0 -> those rows must be cleaned up first.
     RowsWithValueZero     rows where the column holds 0. In this schema 0 is
                           often used to mean "none" (e.g. Users.ManagerId).
                           If OrphanRows is mostly or entirely these zero rows,
                           they would need converting to NULL before the key
                           can be added, and any application code that tests
                           for 0 would need checking.
     SampleChildIds        up to 5 child primary keys to look at.

   Send both result grids back before any constraint is added.
   ============================================================================ */

USE [BMMS];
GO

SET NOCOUNT ON;

SELECT 'FK_Agenda_CommitteeId' AS ProposedFK,
       'Agenda.CommitteeId -> Committee.CommitteeId' AS Relationship,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[CommitteeId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AgendaId] AS VARCHAR(12)) FROM [Agenda] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId]) ORDER BY c.[AgendaId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
UNION ALL
SELECT 'FK_Agenda_MgrApprovedBy' AS ProposedFK,
       'Agenda.MgrApprovedBy -> Users.UserId' AS Relationship,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[MgrApprovedBy] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[MgrApprovedBy])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[MgrApprovedBy] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AgendaId] AS VARCHAR(12)) FROM [Agenda] c WHERE c.[MgrApprovedBy] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[MgrApprovedBy]) ORDER BY c.[AgendaId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 may mean not yet approved' AS Note
UNION ALL
SELECT 'FK_Agenda_ControllerApprovedBy' AS ProposedFK,
       'Agenda.ControllerApprovedBy -> Users.UserId' AS Relationship,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[ControllerApprovedBy] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[ControllerApprovedBy])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Agenda] c WHERE c.[ControllerApprovedBy] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AgendaId] AS VARCHAR(12)) FROM [Agenda] c WHERE c.[ControllerApprovedBy] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[ControllerApprovedBy]) ORDER BY c.[AgendaId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 may mean not yet approved' AS Note
UNION ALL
SELECT 'FK_Users_ManagerId' AS ProposedFK,
       'Users.ManagerId -> Users.UserId' AS Relationship,
       (SELECT COUNT(*) FROM [Users] c WHERE c.[ManagerId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[ManagerId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Users] c WHERE c.[ManagerId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[UserId] AS VARCHAR(12)) FROM [Users] c WHERE c.[ManagerId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[ManagerId]) ORDER BY c.[UserId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 is used as no manager' AS Note
UNION ALL
SELECT 'FK_Member_State_Id' AS ProposedFK,
       'Member.State_Id -> State_Master.State_Id' AS Relationship,
       (SELECT COUNT(*) FROM [Member] c WHERE c.[State_Id] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [State_Master] p WHERE p.[State_Id] = c.[State_Id])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Member] c WHERE c.[State_Id] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[MemberId] AS VARCHAR(12)) FROM [Member] c WHERE c.[State_Id] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [State_Master] p WHERE p.[State_Id] = c.[State_Id]) ORDER BY c.[MemberId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
UNION ALL
SELECT 'FK_Meeting_ChairmanNameId' AS ProposedFK,
       'Meeting.ChairmanNameId -> Member.MemberId' AS Relationship,
       (SELECT COUNT(*) FROM [Meeting] c WHERE c.[ChairmanNameId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Member] p WHERE p.[MemberId] = c.[ChairmanNameId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Meeting] c WHERE c.[ChairmanNameId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[MeetingId] AS VARCHAR(12)) FROM [Meeting] c WHERE c.[ChairmanNameId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Member] p WHERE p.[MemberId] = c.[ChairmanNameId]) ORDER BY c.[MeetingId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 may mean chairman not chosen' AS Note
UNION ALL
SELECT 'FK_Action_Item_MinutesId' AS ProposedFK,
       'Action_Item.MinutesId -> Minutes.MinutesId' AS Relationship,
       (SELECT COUNT(*) FROM [Action_Item] c WHERE c.[MinutesId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Minutes] p WHERE p.[MinutesId] = c.[MinutesId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Action_Item] c WHERE c.[MinutesId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[ActionItemId] AS VARCHAR(12)) FROM [Action_Item] c WHERE c.[MinutesId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Minutes] p WHERE p.[MinutesId] = c.[MinutesId]) ORDER BY c.[ActionItemId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
UNION ALL
SELECT 'FK_Alert_User_Map_UserId' AS ProposedFK,
       'Alert_User_Map.UserId -> Users.UserId' AS Relationship,
       (SELECT COUNT(*) FROM [Alert_User_Map] c WHERE c.[UserId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[UserId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Alert_User_Map] c WHERE c.[UserId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AlertUserId] AS VARCHAR(12)) FROM [Alert_User_Map] c WHERE c.[UserId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[UserId]) ORDER BY c.[AlertUserId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
UNION ALL
SELECT 'FK_ActionItem_User_Map_UserId' AS ProposedFK,
       'ActionItem_User_Map.UserId -> Users.UserId' AS Relationship,
       (SELECT COUNT(*) FROM [ActionItem_User_Map] c WHERE c.[UserId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[UserId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [ActionItem_User_Map] c WHERE c.[UserId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[ActionItemUserMapId] AS VARCHAR(12)) FROM [ActionItem_User_Map] c WHERE c.[UserId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Users] p WHERE p.[UserId] = c.[UserId]) ORDER BY c.[ActionItemUserMapId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
UNION ALL
SELECT 'FK_Alert_Master_CommitteeId' AS ProposedFK,
       'Alert_Master.CommitteeId -> Committee.CommitteeId' AS Relationship,
       (SELECT COUNT(*) FROM [Alert_Master] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Alert_Master] c WHERE c.[CommitteeId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AlertId] AS VARCHAR(12)) FROM [Alert_Master] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId]) ORDER BY c.[AlertId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 may mean not committee-specific' AS Note
UNION ALL
SELECT 'FK_Alert_Master_DepartmentId' AS ProposedFK,
       'Alert_Master.DepartmentId -> Department.DepartmentId' AS Relationship,
       (SELECT COUNT(*) FROM [Alert_Master] c WHERE c.[DepartmentId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Department] p WHERE p.[DepartmentId] = c.[DepartmentId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Alert_Master] c WHERE c.[DepartmentId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AlertId] AS VARCHAR(12)) FROM [Alert_Master] c WHERE c.[DepartmentId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Department] p WHERE p.[DepartmentId] = c.[DepartmentId]) ORDER BY c.[AlertId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '0 may mean no department' AS Note
UNION ALL
SELECT 'FK_Attendance_CommitteeId' AS ProposedFK,
       'Attendance.CommitteeId -> Committee.CommitteeId' AS Relationship,
       (SELECT COUNT(*) FROM [Attendance] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId])) AS OrphanRows,
       (SELECT COUNT(*) FROM [Attendance] c WHERE c.[CommitteeId] = 0) AS RowsWithValueZero,
       STUFF((SELECT TOP 5 ', ' + CAST(c.[AttendanceId] AS VARCHAR(12)) FROM [Attendance] c WHERE c.[CommitteeId] IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [Committee] p WHERE p.[CommitteeId] = c.[CommitteeId]) ORDER BY c.[AttendanceId] FOR XML PATH('')), 1, 2, '') AS SampleChildIds,
       '' AS Note
ORDER BY ProposedFK;

/* Informational only - Member.SexId cannot take a normal foreign key because
   SysCodeSetting is keyed on SysCodeId, while Sex values are matched through
   MainCode / SubCode. This shows what is actually stored versus what exists. */
SELECT m.SexId AS StoredSexId, COUNT(*) AS Members,
       STUFF((SELECT ', ' + ISNULL(s.SubCode, '') + '=' + ISNULL(s.DisplayName, '')
              FROM SysCodeSetting s WHERE s.MainCode = 'Sex' ORDER BY s.SubCode
              FOR XML PATH('')), 1, 2, '') AS DefinedSexCodes
FROM Member m
GROUP BY m.SexId
ORDER BY m.SexId;
