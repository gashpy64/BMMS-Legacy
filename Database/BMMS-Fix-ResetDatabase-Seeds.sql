USE [BMMS];
GO

/* ============================================================================
   BMMS - seed users in the new password-hash format
   ----------------------------------------------------------------------------
   spr_sys_ResetDatabase used to re-create the four default users (admin,
   secuser, credmanager, creduser) with the legacy password "123". With the
   legacy login branch removed, those accounts could not log in after a reset.

   This version is IDENTICAL to the original procedure except that the four
   seeded passwords are now PBKDF2 hashes (a different random salt for each)
   of the application's built-in default password: lvb@123
   Logging in with lvb@123 sends the user straight to ChangePasswordFirst, so
   every seeded account must choose a new password at first login.

   This script only replaces the procedure. It does NOT run it and changes no
   data. Remember that executing the procedure wipes the whole database.
   ============================================================================ */

CREATE OR ALTER PROCEDURE [dbo].[spr_sys_ResetDatabase]
AS
BEGIN

TRUNCATE TABLE ActionItem_User_Map;
TRUNCATE TABLE Alert_User_Map;
TRUNCATE TABLE Meeting_Member;
TRUNCATE TABLE Committee_Member;
TRUNCATE TABLE Attendance;

DELETE FROM SysCodeSetting;
DELETE FROM Audit_Trail_Master;
DELETE FROM Audit_Trail_SqlBackup;
DELETE FROM Audit_Trial_Login;

DELETE FROM Audit_Trail_Master;
DBCC CHECKIDENT (Audit_Trail_Master, RESEED, 0);

DELETE FROM Audit_Trail_SqlBackup;
DBCC CHECKIDENT (Audit_Trail_SqlBackup, RESEED, 0);

DELETE FROM Audit_Trial_Login;
DBCC CHECKIDENT (Audit_Trial_Login, RESEED, 0);

DELETE FROM Action_Item;
DBCC CHECKIDENT (Action_Item, RESEED, 0);

DELETE FROM Alert_Master;
DBCC CHECKIDENT (Alert_Master, RESEED, 0);

DELETE FROM Minutes;
DBCC CHECKIDENT (Minutes, RESEED, 0);

DELETE FROM Agenda;
DBCC CHECKIDENT (Agenda, RESEED, 0);

DELETE FROM Agenda_Status;

DELETE FROM Meeting;
DBCC CHECKIDENT (Meeting, RESEED, 0);

DELETE FROM Committee;
DBCC CHECKIDENT (Committee, RESEED, 0);

DELETE FROM Member;
DBCC CHECKIDENT (Member, RESEED, 0);

DELETE FROM Member_Type;
DBCC CHECKIDENT (Member_Type, RESEED, 0);

DELETE FROM Alert_Type;

DELETE FROM Decision_Type;
DBCC CHECKIDENT (Decision_Type, RESEED, 0);

DELETE FROM Users;
DBCC CHECKIDENT (Users, RESEED, 0);

DELETE FROM Department;
DBCC CHECKIDENT (Department, RESEED, 0);

DELETE FROM Designation;
DBCC CHECKIDENT (Designation, RESEED, 0);

DELETE FROM Subject_Type;
DBCC CHECKIDENT (Subject_Type, RESEED, 0);


DELETE FROM Roles;
DBCC CHECKIDENT (Roles, RESEED, 0);

INSERT INTO [SysCodeSetting]
([SysCodeId], [MainCode],[SubCode],[DisplayName],[Remarks],[DisplayOrder],[IsActive])
SELECT 1, 'Status', '1', 'Active', 'Status', 1, 1
UNION ALL
SELECT 2, 'Status', '0', 'InActive', 'Status', 2, 1
UNION ALL
SELECT 3, 'Sex', '1', 'Male', 'Sex', 1, 1
UNION ALL
SELECT 4, 'Sex', '0', 'Female', 'Sex', 2, 1;

INSERT INTO [Agenda_Status]
([AgendaStatusCode],[AgendaStatusName])
SELECT 'AC', 'Agenda Creation'
UNION ALL
SELECT 'AMA', 'Manager Approved'
UNION ALL
SELECT 'ACA', 'Controller Approved'
UNION ALL
SELECT 'AMR', 'Manager Rejected'
UNION ALL
SELECT 'ACR', 'Controller Rejected'
UNION ALL
SELECT 'AF', 'Finalized';


INSERT INTO [Alert_Type]
([AlertTypeCode],[AlertTypeName],[AlertTypeDescription],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'CC', 'Creation', 'Committee Creation', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MC', 'Creation', 'Meeting Creation', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AC', 'Creation', 'Agenda Creation', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMA', 'Manager Approved', 'Agenda Manager Approved', 4, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACA', 'Controller Approved', 'Agenda Controller Approved', 5, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AMR', 'Manager Rejected', 'Agenda Manager Rejected', 6, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ACR', 'Controller Rejected', 'Agenda Controller Rejected', 7, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'AF', 'Finalized', 'Agenda Finalized', 8, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MF', 'Finalized', 'Minutes Finalized', 9, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MU', 'Updated', 'Meeting Updated', 10, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'CU', 'Updated', 'Committee Updated', 11, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Member_Type]
([MemberTypeCode],[MemberTypeName],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'Member', 'Member', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Invitee', 'Invitee', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'InAttendance', 'In Attendance', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Chairman', 'Chairman', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'MD', 'Managing Director', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Special Invitee', 'Special Invitee', 1, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Decision_Type]
([DecisionTypeCode],[DecisionTypeName],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DT001', 'Followup', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT002', 'Pending', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DT003', 'Sanctioned', 1, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Subject_Type]
([SubjectTypeCode],[SubjectTypeName],[OrderNo],[StatusId],[IsDelete],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'ST001', 'Ratification', 1, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST002', 'Information', 2, 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'ST003', 'Sanction', 3, 1, 1, GETDATE(), 1, GETDATE(), 1;


INSERT INTO [Department]
([DepartmentCode],[DepartmentName],[OrderNo],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'D001', 'Admin', 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D002', 'Secretarial', 2, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D003', 'HRD', 3, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'D004', 'Credit', 4, 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Designation]
([DesignationCode],[DesignationName],[StatusId],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'DESIGN001', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN002', 'Company Secretary', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN003', 'Chairman', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN004', 'Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN005', 'Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN006', 'Assistant Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN007', 'General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN008', 'Assistant General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN009', 'Deputy General Manager', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN010', 'Managing Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN011', 'Executive Director', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'DESIGN012', 'Chief Operating Officer', 1, GETDATE(), 1, GETDATE(), 1;

INSERT INTO [Roles]
([RoleCode],[RoleName],[RoleDescription],[OrderNo],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'admin', 'Admin', 'Administrator', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'controller', 'Controller', 'Controller', 2, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'manager', 'Manager', 'Manager', 3, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'user', 'User', 'User', 4, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'mgmt', 'Management', 'Management', 5, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'md_sect', 'MD Secretariat', 'MD Secretariat', 6, GETDATE(), 1, GETDATE(), 1;


INSERT INTO [Users]
([UserName],[DepartmentId],[DesignationId],[ManagerId],[RoleId],[EmailId],[LoginName],[Password]
           ,[AccountStatus],[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'admin', 1, 1, 0, 1, '', 'admin', '100000.WADOkeW3PD8T+KGnhd13NA==.ykPBZLhjry5KbA3hGEQsf8hdO3yY8C23RTHKeAOfXWU=', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Controller', 2, 3, 0, 2, 'con@lvb.com', 'secuser', '100000.M/UxC7LnMnNnEZFfpnw6mg==.BjFpjTZvVXXXGN0NOfAyBgtqgpaTbE4rH41LJyBONSc=', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'Manager', 4, 4, 0, 3, 'mgr@lvb.com', 'credmanager', '100000.PsM4vZJAAQ9wtc5TyVtBcg==.g2/yOexqH1W/RQ33t0LmQ0eZYFQl6gPN7buM+M1bbqY=', 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'User', 4, 5, 3, 4, 'usr@lvb.com', 'creduser', '100000.VqhtwYgekpXELBK53d/DLg==.haI/Qxp3EbSWTlfeUjLiqWbR30WATDUW5pazcR8k7tA=', 1, GETDATE(), 1, GETDATE(), 1;


INSERT INTO [Committee]
([CommitteeCode],[CommitteeName],[Board],[IncorporationDate],[StatusId],[IsDelete],
	[CreatedOn],[CreatedBy],[UpdatedOn],[UpdatedBy])
SELECT 'C01', 'Board of Directors',1, GETDATE(), 1, 1, GETDATE(), 1, GETDATE(), 1
UNION ALL
SELECT 'C02', 'Audit Committee',0, GETDATE(), 1, 0, GETDATE(), 1, GETDATE(), 1;


END
GO
