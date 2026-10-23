# BMMS

BMMS (Board Minutes and Meeting Software) is a board-meeting product for any company: committees and members, meetings and attendance, agenda items with Manager and Controller approval, minutes, action items, alerts and mail, sitting-fee and meeting reports. Owner: Gashpy Software. Consultant: Ganesh Shankar C S.

## Projects

The solution `BMMS.sln` has three projects, all .NET Framework 4.8:

- `BMMS` - the ASP.NET Web Forms application (pages, master pages, CSS, scripts, reports).
- `BMMSBAL` - business layer (the `*Mgr` classes, mail, PDF and Word output).
- `BMMSDAL` - data layer (the `*DB` classes; SQL Server, almost entirely through stored procedures).

## Build

1. Open `BMMS.sln` in Visual Studio (with the .NET Framework 4.8 developer pack).
2. Copy `BMMS/connectionStrings.config.example` to `BMMS/connectionStrings.config` and set the connection string. `connectionStrings.config` is not tracked.
3. Build, Rebuild Solution. The third-party DLLs under `BMMS/bin` and `BMMSBAL/bin/Debug` are tracked on purpose: the projects find them there.

## Branding

The product name is "Board Minutes and Meeting Software" (short: BMMS), owned by Gashpy Software, the same everywhere: the login page, the page header and footer, the browser title (`BMMS/XML/AppSettings.xml`), the mail footer (`BMMSBAL/Mail_Mgr.cs`) and the assembly details. The application ships no organisation or vendor image: the brand is text. Printed reports carry only the customer's own logo, uploaded on System Settings, or else the organisation name.

## Database

The database scripts, their run order, the tests and the release notes for each step are in [Database/README.md](Database/README.md). Always run a change on a test copy first.

## Working in this repository

Stage files by explicit path (`git add <path>`); never `git add .` or `git add -A`. Rebuilt binaries under `bin/` and `obj/` stay out of commits.
