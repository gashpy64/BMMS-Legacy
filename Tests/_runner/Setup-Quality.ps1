#Requires -Version 7
<#
  Setup-Quality.ps1 - one-time setup of the tester's database BMMS_Quality (step WF3a1).

  Run by the owner (or by the main Claude session on the owner's approval) with the owner's
  Windows login, which is sysadmin on the local SQL Server. The tester agent cannot run it.

      pwsh -NoProfile -File Tests\_runner\Setup-Quality.ps1 -ConfirmDatabase BMMS_Quality

  It works on BMMS_Quality only. The name is fixed in Tester.Common.ps1; -ConfirmDatabase must
  repeat it (as the application's Reset Database page asks for the name) or nothing happens.

  What it does, in this order, and stops at the first thing that is not as expected:
    1. BMMS_Quality exists and every row of Database\BMMS-Check-InstalledSteps.sql reads
       Installed on it (the repository's own list of steps is the yardstick).
    2. The application login bmms_app is linked to its user in BMMS_Quality and has the three
       roles db_backupoperator, db_datareader, db_datawriter. Read only; nothing is changed.
    3. Builds the working tree into Tests\_build (needed for the application's hash function).
    4. CLEARS BMMS_Quality with the application's own spr_sys_ResetDatabase.
    5. The Check script again; the mail settings must be the safe default (localhost:25).
    6. Creates the SQL login bmms_tester (or gives it a new password) and makes it the owner of
       BMMS_Quality. Creates the SQL login bmms_site (or gives it a new password) and its user
       in BMMS_Quality, with what the application login bmms_app has there: db_datareader,
       db_datawriter, db_backupoperator and EXECUTE on the dbo schema. Neither login gets a
       server role or access to any other database; step 10 asks the server to confirm it.
       A login keeps its identity (SID) when only its password is changed, so the user stored in
       the baseline stays linked to it through every restore.
    7. Generates a random password per test account, hashes each with Common.HashPassword of
       the built BMMSBAL.dll, runs the fixture with the hashes, then the fixture check.
    8. Writes Tests\local\credentials.json (readable by the owner's Windows account only).
    9. Takes the baseline backup BMMS_Quality_baseline.bak in the server's backup folder and
       writes Tests\local\baseline.json.
   10. Proves the tester's own path: restores the baseline as bmms_tester and checks again.
  At the end it lists exactly what it changed on the server.
#>
param(
    [Parameter(Mandatory)][string]$ConfirmDatabase
)
. (Join-Path $PSScriptRoot 'Tester.Common.ps1')

$changes = [System.Collections.Generic.List[string]]::new()
$tempFiles = [System.Collections.Generic.List[string]]::new()
$exitCode = 0
try {
    if ($ConfirmDatabase -cne $QaDatabase) { Stop-Qa "-ConfirmDatabase must be exactly $QaDatabase. Nothing was done." }

    Write-QaStep "1. Steps installed on $QaDatabase"
    Assert-QaDatabase -As Windows
    $steps = Assert-QaStepsInstalled -As Windows -What $QaDatabase
    Write-Host "     $($steps.Rows.Count) step rows, all Installed. $($steps.History)"

    Write-QaStep "2. The application login $QaAppLogin (read only)"
    $r = Invoke-QaSqlcmd -As Windows -NoHeader -Query @"
SET NOCOUNT ON;
SELECT 'linked', CASE WHEN SUSER_SNAME(dp.sid) = '$QaAppLogin' THEN 'yes' ELSE 'no' END FROM sys.database_principals dp WHERE dp.name = '$QaAppLogin';
SELECT 'role', r.name FROM sys.database_role_members m JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
WHERE m.member_principal_id = DATABASE_PRINCIPAL_ID('$QaAppLogin') ORDER BY r.name;
"@
    $linked = @($r.Lines | Where-Object { $_ -match '^linked\|yes\s*$' }).Count -eq 1
    $roles = @($r.Lines | Where-Object { $_ -match '^role\|' } | ForEach-Object { ($_ -split '\|')[1].Trim() }) -join ','
    if (-not $linked) { Stop-Qa "$QaAppLogin is not linked to its user in $QaDatabase. Nothing was changed." }
    if ($roles -cne 'db_backupoperator,db_datareader,db_datawriter') { Stop-Qa "$QaAppLogin has the roles '$roles' in $QaDatabase, not the three expected. Nothing was changed." }
    Write-Host "     linked; roles: $roles"

    Write-QaStep '3. Build of the working tree into Tests\_build'
    Stop-QaSite
    Invoke-QaBuild

    Write-QaStep "4. Clearing $QaDatabase with spr_sys_ResetDatabase"
    $r = Invoke-QaSqlcmd -As Windows -NoHeader -Query @"
SET NOCOUNT ON;
IF (DB_NAME() COLLATE Latin1_General_BIN <> N'BMMS_Quality') BEGIN RAISERROR('Not on BMMS_Quality.', 16, 1); RETURN; END
DECLARE @Admin INT, @Result INT, @Reason INT;
SET @Admin = (SELECT TOP 1 u.UserId FROM Users u JOIN Roles r ON r.RoleId = u.RoleId WHERE r.RoleCode = 'admin' AND u.AccountStatus = 1 ORDER BY u.IsSystem DESC, u.UserId);
IF (@Admin IS NULL) BEGIN RAISERROR('No active Admin in BMMS_Quality to act for Reset Database.', 16, 1); RETURN; END
EXEC spr_sys_ResetDatabase @ActingUserId = @Admin, @ConfirmDatabaseName = N'BMMS_Quality', @Result = @Result OUTPUT, @Reason = @Reason OUTPUT;
IF (ISNULL(@Result, 0) <> 1) BEGIN RAISERROR('Reset Database was refused (Reason %d).', 16, 1, @Reason); RETURN; END
PRINT 'RESET: DONE';
"@
    if (-not ($r.Lines -match 'RESET: DONE')) { throw 'Reset Database did not report success.' }
    $changes.Add("Database $QaDatabase cleared with spr_sys_ResetDatabase (all data replaced by the seed rows; mail settings set to the safe default).")

    Write-QaStep '5. Steps and mail settings after the clearing'
    $steps = Assert-QaStepsInstalled -As Windows -What $QaDatabase
    $r = Invoke-QaSqlcmd -As Windows -NoHeader -Query "SET NOCOUNT ON; SELECT CAST(COUNT(*) AS varchar(5)) + ';' + ISNULL(MAX(CAST(SMTPServer AS varchar(100)) + ':' + CAST(SMTPServerPort AS varchar(10))), '') FROM SMTP_Master;"
    $smtp = ($r.Lines | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
    if ($smtp -cne '1;localhost:25') { Stop-Qa "The mail settings of $QaDatabase are '$smtp', not the safe default. Stopped after the clearing." }
    Write-Host "     $($steps.Rows.Count) step rows Installed; $($steps.History); mail: localhost:25"

    Write-QaStep "6. SQL logins: $QaTesterLogin (owner of $QaDatabase) and $QaSiteLogin (the site copy's login)"
    Protect-QaLocalDir
    $sqlPassword = New-QaPassword 32
    $sitePassword = New-QaPassword 32
    $loginFile = Join-Path $QaLocalDir ('login-' + [guid]::NewGuid().ToString('N') + '.sql'); $tempFiles.Add($loginFile)
    @"
SET NOCOUNT ON;
IF (DB_NAME() COLLATE Latin1_General_BIN <> N'BMMS_Quality') BEGIN RAISERROR('Not on BMMS_Quality.', 16, 1); RETURN; END
IF SUSER_ID(N'bmms_tester') IS NULL
BEGIN
    CREATE LOGIN [bmms_tester] WITH PASSWORD = N'$sqlPassword', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [BMMS_Quality];
    PRINT 'LOGIN: CREATED';
END
ELSE
BEGIN
    ALTER LOGIN [bmms_tester] WITH PASSWORD = N'$sqlPassword', DEFAULT_DATABASE = [BMMS_Quality];
    PRINT 'LOGIN: PASSWORD CHANGED';
END
IF EXISTS (SELECT 1 FROM sys.server_role_members m WHERE m.member_principal_id = SUSER_ID(N'bmms_tester'))
BEGIN RAISERROR('bmms_tester is a member of a server role; that is not expected.', 16, 1); RETURN; END
IF EXISTS (SELECT 1 FROM sys.server_permissions p WHERE p.grantee_principal_id = SUSER_ID(N'bmms_tester') AND NOT (p.permission_name = 'CONNECT SQL' AND p.state_desc = 'GRANT'))
BEGIN RAISERROR('bmms_tester has a server permission other than CONNECT SQL; that is not expected.', 16, 1); RETURN; END
IF (ISNULL(SUSER_SNAME((SELECT owner_sid FROM sys.databases WHERE name = N'BMMS_Quality')), N'') <> N'bmms_tester')
BEGIN
    ALTER AUTHORIZATION ON DATABASE::[BMMS_Quality] TO [bmms_tester];
    PRINT 'OWNER: CHANGED';
END
PRINT 'OWNER: SET';

-- The login of the site copy. It gets what the application login bmms_app has in this database
-- (the three roles and EXECUTE on the dbo schema) and nothing anywhere else. Its user is created
-- here, before the baseline is taken, so the baseline holds it.
IF SUSER_ID(N'bmms_site') IS NULL
BEGIN
    CREATE LOGIN [bmms_site] WITH PASSWORD = N'$sitePassword', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [BMMS_Quality];
    PRINT 'SITE LOGIN: CREATED';
END
ELSE
BEGIN
    ALTER LOGIN [bmms_site] WITH PASSWORD = N'$sitePassword', DEFAULT_DATABASE = [BMMS_Quality];
    PRINT 'SITE LOGIN: PASSWORD CHANGED';
END
IF EXISTS (SELECT 1 FROM sys.server_role_members m WHERE m.member_principal_id = SUSER_ID(N'bmms_site'))
BEGIN RAISERROR('bmms_site is a member of a server role; that is not expected.', 16, 1); RETURN; END
IF EXISTS (SELECT 1 FROM sys.server_permissions p WHERE p.grantee_principal_id = SUSER_ID(N'bmms_site') AND NOT (p.permission_name = 'CONNECT SQL' AND p.state_desc = 'GRANT'))
BEGIN RAISERROR('bmms_site has a server permission other than CONNECT SQL; that is not expected.', 16, 1); RETURN; END
IF DATABASE_PRINCIPAL_ID(N'bmms_site') IS NULL
BEGIN
    CREATE USER [bmms_site] FOR LOGIN [bmms_site];
    PRINT 'SITE USER: CREATED';
END
ELSE IF (ISNULL(SUSER_SNAME((SELECT sid FROM sys.database_principals WHERE name = N'bmms_site')), N'') <> N'bmms_site')
BEGIN
    ALTER USER [bmms_site] WITH LOGIN = [bmms_site];
    PRINT 'SITE USER: LINKED AGAIN';
END
IF EXISTS (SELECT 1 FROM sys.database_role_members m JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
           WHERE m.member_principal_id = DATABASE_PRINCIPAL_ID(N'bmms_site') AND r.name NOT IN (N'db_backupoperator', N'db_datareader', N'db_datawriter'))
BEGIN RAISERROR('bmms_site is in a database role other than the three expected.', 16, 1); RETURN; END
IF (IS_ROLEMEMBER(N'db_datareader', N'bmms_site') = 0) EXEC sp_addrolemember N'db_datareader', N'bmms_site';
IF (IS_ROLEMEMBER(N'db_datawriter', N'bmms_site') = 0) EXEC sp_addrolemember N'db_datawriter', N'bmms_site';
IF (IS_ROLEMEMBER(N'db_backupoperator', N'bmms_site') = 0) EXEC sp_addrolemember N'db_backupoperator', N'bmms_site';
GRANT EXECUTE ON SCHEMA::[dbo] TO [bmms_site];
PRINT 'SITE USER: SET';
"@ | Set-Content -LiteralPath $loginFile -Encoding utf8
    $r = Invoke-QaSqlcmd -As Windows -InputFile $loginFile
    Remove-Item -LiteralPath $loginFile -Force
    if (-not ($r.Lines -match 'OWNER: SET') -or -not ($r.Lines -match 'SITE USER: SET')) { throw 'The login step did not report success.' }
    if ($r.Lines -match '^LOGIN: CREATED') { $changes.Add("SQL login $QaTesterLogin created (no server role, default database $QaDatabase).") }
    else { $changes.Add("SQL login $QaTesterLogin already existed: its password was changed.") }
    if ($r.Lines -match 'OWNER: CHANGED') { $changes.Add("Owner of $QaDatabase set to $QaTesterLogin.") }
    if ($r.Lines -match 'SITE LOGIN: CREATED') { $changes.Add("SQL login $QaSiteLogin created (no server role, only CONNECT SQL, default database $QaDatabase).") }
    else { $changes.Add("SQL login $QaSiteLogin already existed: its password was changed.") }
    if ($r.Lines -match 'SITE USER: CREATED') { $changes.Add("Database user $QaSiteLogin created in $QaDatabase for that login: member of db_datareader, db_datawriter and db_backupoperator, with EXECUTE on the dbo schema (what $QaAppLogin has there). No user in any other database.") }
    elseif ($r.Lines -match 'SITE USER: LINKED AGAIN') { $changes.Add("Database user $QaSiteLogin in $QaDatabase linked to its login again.") }

    Write-QaStep '7. Test accounts: passwords, hashes by the application, fixture'
    # The sign-in page takes at most 12 characters in each box (LoginIdMaxLength, PasswordMaxLength in the application settings file AppSettings.xml).
    foreach ($key in $QaAccounts.Keys) { if ($QaAccounts[$key].Length -gt 12) { throw "The login name '$($QaAccounts[$key])' is longer than the 12 characters the sign-in page takes." } }
    $passwords = [ordered]@{}
    foreach ($key in $QaAccounts.Keys) { $passwords[$key] = New-QaPassword 12 }
    # Hashes: Windows PowerShell 5.1 (.NET Framework) loads a temporary copy of the built BMMSBAL.dll and
    # calls Common.HashPassword. The passwords go in on standard input, never on a command line.
    $hashDir = Join-Path $QaBuildDir ('hash-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $hashDir | Out-Null
    $hashes = @{}
    try {
        Copy-Item -Path (Join-Path $QaBuildDir 'out\*.dll') -Destination $hashDir
        $helper = Join-Path $hashDir 'hash.ps1'
        @'
$ErrorActionPreference = 'Stop'
$a = [Reflection.Assembly]::LoadFrom($args[0]); $t = $a.GetType('BMMSBAL.Common', $true)
$hash = $t.GetMethod('HashPassword'); $verify = $t.GetMethod('VerifyPassword'); $default = $t.GetField('DefaultPassword').GetValue($null)
while ($null -ne ($line = [Console]::In.ReadLine())) {
    if ($line -eq '') { continue }
    $i = $line.IndexOf("`t"); $name = $line.Substring(0, $i); $p = $line.Substring($i + 1)
    if ($p -eq $default) { throw 'a generated password equals the default password' }
    $h = $hash.Invoke($null, @($p))
    if (-not $verify.Invoke($null, @($p, $h))) { throw 'VerifyPassword refused a fresh hash' }
    [Console]::Out.WriteLine($name + "`t" + $h)
}
'@ | Set-Content -LiteralPath $helper -Encoding ascii
        $lines = @($passwords.Keys | ForEach-Object { "$_`t$($passwords[$_])" }) |
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper (Join-Path $hashDir 'BMMSBAL.dll')
        if ($LASTEXITCODE -ne 0) { throw 'The hash helper failed.' }
        foreach ($l in @($lines)) { $parts = "$l" -split "`t", 2; if ($parts.Count -eq 2) { $hashes[$parts[0]] = $parts[1].Trim() } }
    } finally {
        Remove-Item -LiteralPath $hashDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($key in $QaAccounts.Keys) {
        if (-not $hashes.ContainsKey($key) -or $hashes[$key] -notmatch '^100000\.[A-Za-z0-9+/=]+\.[A-Za-z0-9+/=]+$') { throw "No hash was made for the '$key' test account." }
    }
    $fixtureFile = Join-Path $QaLocalDir ('fixture-' + [guid]::NewGuid().ToString('N') + '.sql'); $tempFiles.Add($fixtureFile)
    $vars = foreach ($key in $QaAccounts.Keys) { ":setvar H_$key `"$($hashes[$key])`"" }
    (@($vars) + @(":r `"$QaFixtureScript`"")) | Set-Content -LiteralPath $fixtureFile -Encoding ascii
    $r = Invoke-QaSqlcmd -As Windows -InputFile $fixtureFile
    Remove-Item -LiteralPath $fixtureFile -Force
    if (-not ($r.Lines -match 'FIXTURE: DONE')) { throw 'The fixture did not report success.' }
    $r = Invoke-QaSqlcmd -As Windows -InputFile $QaFixtureCheckScript
    $pass = ($r.Lines | Where-Object { $_ -match '^FIXTURE CHECK: PASS' } | Select-Object -First 1)
    if (-not $pass) { throw 'The fixture check did not pass.' }
    Write-Host "     $pass"
    $changes.Add("Fixture data added to ${QaDatabase}: nine qa_ accounts, committee QA1 with two members, six meetings, thirteen agenda items and their minutes.")

    Write-QaStep '8. Tests\local\credentials.json'
    $cred = [ordered]@{
        note      = 'Local test secrets of the BMMS tester. Never commit, never copy elsewhere. Valid for BMMS_Quality only.'
        createdOn = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        sqlLogin  = [ordered]@{ name = $QaTesterLogin; password = $sqlPassword }
        siteLogin = [ordered]@{ name = $QaSiteLogin; password = $sitePassword }
        accounts  = [ordered]@{}
    }
    foreach ($key in $QaAccounts.Keys) { $cred.accounts[$key] = [ordered]@{ login = $QaAccounts[$key]; password = $passwords[$key] } }
    $cred | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $QaCredFile -Encoding utf8
    Protect-QaLocalDir
    $script:QaCredCache = $null
    $null = Get-QaCredentials

    Write-QaStep '9. Baseline backup'
    $r = Invoke-QaSqlcmd -As Windows -NoHeader -Query "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(400));"
    $backupDir = ($r.Lines | Where-Object { $_.Trim() } | Select-Object -First 1).Trim().TrimEnd('\')
    if (-not $backupDir -or $backupDir -match "['`"]") { throw 'The server backup folder could not be read.' }
    $backupPath = "$backupDir\$QaBaselineFile"
    $null = Invoke-QaSqlcmd -As Windows -Query "SET NOCOUNT ON; IF (DB_NAME() COLLATE Latin1_General_BIN <> N'BMMS_Quality') BEGIN RAISERROR('Not on BMMS_Quality.', 16, 1); RETURN; END; BACKUP DATABASE [BMMS_Quality] TO DISK = N'$backupPath' WITH INIT, CHECKSUM, NAME = N'BMMS_Quality tester baseline';"
    [ordered]@{
        takenOn            = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        backupPath         = $backupPath
        stepRows           = $steps.Rows.Count
        lastStep           = ($steps.Rows | Where-Object { $_.Step -lt 100 } | Sort-Object Step | Select-Object -Last 1).Step
        fixtureSha256      = (Get-QaFileHash $QaFixtureScript)
        fixtureCheckSha256 = (Get-QaFileHash $QaFixtureCheckScript)
        fixtureDatesSha256 = (Get-QaFileHash $QaFixtureDatesScript)
        gitCommit          = "$(& git -C $QaRepo rev-parse --short HEAD 2>$null)"
    } | ConvertTo-Json | Set-Content -LiteralPath $QaBaselineInfo -Encoding utf8
    Protect-QaLocalDir
    $changes.Add("Baseline backup written: $backupPath (an earlier file of that name is replaced).")

    Write-QaStep "10. Proof: $QaTesterLogin and $QaSiteLogin reach $QaDatabase only; restore of the baseline as $QaTesterLogin"
    Assert-QaLoginsReach
    Restore-QaBaseline -As Tester
    $null = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureDatesScript
    $null = Assert-QaStepsInstalled -As Tester -What 'The baseline'
    $r = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureCheckScript
    if (-not ($r.Lines -match '^FIXTURE CHECK: PASS')) { throw 'The fixture check did not pass after the restore.' }
    $changes.Add("$QaDatabase restored once from the baseline by $QaTesterLogin (the proof that a tester run can do it). Open connections to $QaDatabase were closed.")

    Write-Host ''
    Write-Host 'SETUP DONE. Changed on the SQL Server:'
    $n = 0; foreach ($c in $changes) { $n++; Write-Host "  $n. $c" }
    Write-Host 'Not touched: every other database, the login bmms_app and its roles, the product code.'
    Write-Host 'Local files written: Tests\local\credentials.json, Tests\local\baseline.json, Tests\_build.'
}
catch {
    Write-Host ''
    if ($_.Exception.GetType().Name -eq 'QaRefusal') { Write-Host "REFUSED: $($_.Exception.Message)"; $exitCode = 2 }
    else { Write-Host "SETUP FAILED: $($_.Exception.Message)"; $exitCode = 1 }
}
finally {
    foreach ($f in $tempFiles) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    if ($exitCode -ne 0 -and $changes.Count -gt 0) {
        Write-Host 'Already changed on the SQL Server before it stopped:'
        $n = 0; foreach ($c in $changes) { $n++; Write-Host "  $n. $c" }
    }
}
exit $exitCode
