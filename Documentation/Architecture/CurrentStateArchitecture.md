# BMMS Current State Architecture

## Board Minutes and Management Software (BMMS)

Version: Legacy Recovery Baseline
Date: 2026-10-02

## Repository Information

Repository Name: BMMS-Legacy

GitHub Repository:
https://github.com/<your-account>/BMMS-Legacy

Development Branch:
modernization

Baseline Tag:
BMMS-Recovered-Baseline

## Runtime Environment

Source Location:

C:\BMMS\BMMS\Source

Purpose:

- Stable recovered application
- Functional validation
- User acceptance testing
- Regression testing

Status:

✅ Operational

## Development Environment

Repository Location:

C:\Repository\BMMS-Legacy

Purpose:

- Modernization
- Git source control
- Refactoring
- Dependency replacement
- API development
- Cloud migration

Status:

✅ Active Development Repository

## Current Architecture Status

Recovery Stage:
Completed

Modernization Stage:
Sprint 1 – Stabilization & Inventory

Application Status:
Operational

Database Status:
Operational

Authentication Status:
Operational

Current Login:

admin / 123

Database:

BMMS

Platform:

SQL Server 2025 Developer Edition

Framework:

ASP.NET Web Forms
.NET Framework 4.8

IDE:

Visual Studio Community

--------------------------------------------------------------------------------

# High Level Architecture

Users
    │
    ▼
ASP.NET Web Forms (BMMS)
    │
    ▼
BMMSBAL (Business Layer)
    │
    ▼
BMMSDAL (Data Access Layer)
    │
    ▼
SQL Server (BMMS)

--------------------------------------------------------------------------------

# Functional Coverage

- Committee Management
- Committee Member Tagging
- Member Management
- Meeting Management
- Attendance
- Agenda Workflow
- Minutes Workflow
- Action Items
- Alerts
- Reports
- Audit Trail
- SMTP Configuration
- Administration

--------------------------------------------------------------------------------

# User Roles

1. Admin
2. Controller
3. Manager
4. User
5. Management

--------------------------------------------------------------------------------

# Governance Workflow

Agenda Entry
    ↓
Manager Approval
    ↓
Controller Approval
    ↓
Agenda Finalization
    ↓
Attendance
    ↓
Minutes Update
    ↓
Minutes Finalization
    ↓
Minutes Confirmation
    ↓
Meeting Closure

--------------------------------------------------------------------------------

# Major Database Entities

Users
Roles

Department
Designation
Member
Member_Type

Committee
Committee_Member

Meeting
Meeting_Member
Attendance

Agenda
Minutes
Action_Item

Subject_Type
Decision_Type

Alert_Master
Alert_User_Map

--------------------------------------------------------------------------------

# Known Legacy Dependencies

High Priority

- FreeTextBox
- AjaxControlToolkit
- Microsoft.SqlServer.Replication
- Microsoft.SqlServer.BatchParser
- Office Interop

Medium Priority

- Legacy Web.config
- ADO.NET DataTables
- Stored Procedure Tight Coupling

--------------------------------------------------------------------------------

# Modernization Boundary

The following business processes must remain unchanged:

- Committee Workflow
- Agenda Approval Workflow
- Minutes Workflow
- Action Item Workflow
- Audit Trail Workflow
- Reporting Workflow

Only the technology stack will be modernized.

--------------------------------------------------------------------------------

# Modernization Roadmap

Sprint 1
- Inventory
- Dependency Assessment
- Stabilization

Sprint 2
- Legacy Dependency Removal

Sprint 3
- ASP.NET Core API Layer

Sprint 4
- React UI

Sprint 5
- Authentication Modernization

Sprint 6
- Azure Migration

--------------------------------------------------------------------------------

# Recovery Validation

Recovery Completed:

✅ SQL Server Installed

✅ Database Restored

✅ Source Recovered

✅ Solution Builds

✅ Login Page Displays

✅ Authentication Works

✅ Dashboard Accessible

✅ Application Operational

--------------------------------------------------------------------