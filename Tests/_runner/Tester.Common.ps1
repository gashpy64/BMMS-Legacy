#Requires -Version 7
<#
  Tester.Common.ps1 - shared code of the BMMS tester (step WF3a1). Dot-sourced by Run-Tests.ps1,
  Setup-Quality.ps1 and Update-Baseline.ps1; it is not run on its own.

  Safety rules built in here
  - The database is BMMS_Quality. The name is a constant in this file: not a parameter, not read
    from a file or from the environment. Every sqlcmd call goes through Invoke-QaSqlcmd, which
    accepts only BMMS_Quality (or master, for the one RESTORE statement, which names
    [BMMS_Quality] in fixed text). BMMS and BMMS_Test are never named anywhere in the tester.
  - The site under test is the copy in Tests\_site on port 18573. Only an IIS Express process
    whose command line names that folder and that port is ever stopped.
  - Secrets (test account passwords, the bmms_tester password, the connection string) are never
    written to the console or to a results file.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Variable -Name QaDatabase     -Value 'BMMS_Quality'              -Option Constant
New-Variable -Name QaServer       -Value '.'                         -Option Constant
New-Variable -Name QaTesterLogin  -Value 'bmms_tester'               -Option Constant
New-Variable -Name QaAppLogin     -Value 'bmms_app'                  -Option Constant
New-Variable -Name QaSiteLogin    -Value 'bmms_site'                 -Option Constant
New-Variable -Name QaPort         -Value 18573                       -Option Constant
New-Variable -Name QaBaseUrl      -Value 'http://localhost:18573'    -Option Constant
New-Variable -Name QaBaselineFile -Value 'BMMS_Quality_baseline.bak' -Option Constant
# Step UN6b (owner, 2026-11-12): below this much available memory the preflight warns (the run still goes on)
New-Variable -Name QaMemoryWarnMB -Value 1500                        -Option Constant

$QaRepo        = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$QaTests       = Join-Path $QaRepo 'Tests'
$QaSiteDir     = Join-Path $QaTests '_site'
$QaBuildDir    = Join-Path $QaTests '_build'
$QaLocalDir    = Join-Path $QaTests 'local'
$QaResultsRoot = Join-Path $QaTests '_results'
$QaFixtureDir  = Join-Path $QaTests 'fixture'
$QaCredFile    = Join-Path $QaLocalDir 'credentials.json'
$QaBaselineInfo = Join-Path $QaLocalDir 'baseline.json'
$QaCheckScript = Join-Path $QaRepo 'Database\BMMS-Check-InstalledSteps.sql'
$QaFixtureScript      = Join-Path $QaFixtureDir 'BMMS-Quality-Fixture.sql'
$QaFixtureCheckScript = Join-Path $QaFixtureDir 'BMMS-Quality-Fixture-Check.sql'
$QaFixtureDatesScript = Join-Path $QaFixtureDir 'BMMS-Quality-Fixture-Dates.sql'
$QaIisExpress  = 'C:\Program Files (x86)\IIS Express\iisexpress.exe'

# The test accounts of the fixture: key (used by the packs) = login name in BMMS_Quality.
$QaAccounts = [ordered]@{
    admin      = 'qa_admin'
    controller = 'qa_ctrl'
    manager    = 'qa_manager'
    manager2   = 'qa_manager2'
    user       = 'qa_user'
    user2      = 'qa_user2'
    mgmt       = 'qa_mgmt'
    mdsec      = 'qa_mdsec'
    inactive   = 'qa_inactive'
}

class QaRefusal : System.Exception { QaRefusal([string]$m) : base($m) {} }
# Step WF3a2: the run broke off in a way that makes it not count (the standing proof's put-back failed).
class QaVoid : System.Exception { QaVoid([string]$m) : base($m) {} }
function Stop-Qa([string]$Message) { throw [QaRefusal]::new($Message) }
function Write-QaStep([string]$Text) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Text) }

function Get-QaFileHash([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }

# ---------------------------------------------------------------------------------------------
# Local folder and credentials
# ---------------------------------------------------------------------------------------------
function Get-QaCurrentAccount { [Security.Principal.WindowsIdentity]::GetCurrent().Name }

# Step UN6b: the machine's available memory (Task Manager's "Available": free plus standby cache) and its total,
# in MB. The counter is read through CIM (its name is the same in every Windows language), else through
# Get-Counter. $null when neither can be read; the reading never stops a run.
function Get-QaMemory {
    $available = $null
    try { $available = [int](Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop).AvailableMBytes } catch { }
    if ($null -eq $available) {
        try { $available = [int](Get-Counter -Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples[0].CookedValue } catch { }
    }
    if ($null -eq $available) { return $null }
    $total = $null
    try { $total = [int]([math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1MB)) } catch { }
    [pscustomobject]@{ AvailableMB = $available; TotalMB = $total; Low = ($available -lt $QaMemoryWarnMB) }
}

function Format-QaMemory([object]$Memory) {
    if ($null -eq $Memory) { return 'could not be read' }
    "$($Memory.AvailableMB) MB available" + $(if ($Memory.TotalMB) { " of $($Memory.TotalMB) MB" } else { '' })
}

# Tests\local is readable by the owner's Windows account only (no inherited permissions).
function Protect-QaLocalDir {
    if (-not (Test-Path -LiteralPath $QaLocalDir)) { New-Item -ItemType Directory -Path $QaLocalDir | Out-Null }
    $me = Get-QaCurrentAccount
    $out = & icacls $QaLocalDir /inheritance:r /grant:r "${me}:(OI)(CI)F" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "icacls failed on Tests\local: $out" }
    $out = & icacls (Join-Path $QaLocalDir '*') /reset /T /Q 2>&1   # files already there take the folder's rule
    if (-not (Test-QaLocalDirAcl)) { throw 'Tests\local is still readable by another account after icacls.' }
}

function Test-QaLocalDirAcl {
    if (-not (Test-Path -LiteralPath $QaLocalDir)) { return $false }
    $me = Get-QaCurrentAccount
    foreach ($item in @(Get-Item -LiteralPath $QaLocalDir) + @(Get-ChildItem -LiteralPath $QaLocalDir -Force)) {
        $acl = Get-Acl -LiteralPath $item.FullName
        foreach ($rule in $acl.Access) {
            if ($rule.IdentityReference.Value -ine $me) { return $false }
        }
    }
    return $true
}

# One file: no inherited permissions, and every entry is the owner's Windows account (step WF3a2).
function Test-QaOnlyMine([string]$Path) {
    $me = Get-QaCurrentAccount
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { return $false }
    $rules = @($acl.Access)
    if ($rules.Count -eq 0) { return $false }
    foreach ($rule in $rules) { if ($rule.IsInherited -or $rule.IdentityReference.Value -ine $me) { return $false } }
    return $true
}

$script:QaCredCache = $null
function Get-QaCredentials {
    if ($null -ne $script:QaCredCache) { return $script:QaCredCache }
    if (-not (Test-Path -LiteralPath $QaCredFile)) { Stop-Qa 'Tests\local\credentials.json is missing. Run Tests\_runner\Setup-Quality.ps1 first (see Tests\README.md).' }
    if (-not (Test-QaLocalDirAcl)) { Stop-Qa 'Tests\local can be read by an account other than yours. Restrict it as Tests\README.md says ("Credentials"), then run again.' }
    $c = Get-Content -LiteralPath $QaCredFile -Raw | ConvertFrom-Json
    if (-not $c.sqlLogin -or $c.sqlLogin.name -cne $QaTesterLogin -or -not $c.sqlLogin.password) { Stop-Qa 'Tests\local\credentials.json has no bmms_tester entry. Run Tests\_runner\Setup-Quality.ps1 again.' }
    if (-not $c.PSObject.Properties['siteLogin'] -or $c.siteLogin.name -cne $QaSiteLogin -or -not $c.siteLogin.password) { Stop-Qa 'Tests\local\credentials.json has no bmms_site entry. Run Tests\_runner\Setup-Quality.ps1 again.' }
    foreach ($key in $QaAccounts.Keys) {
        $a = $c.accounts.$key
        if (-not $a -or $a.login -cne $QaAccounts[$key] -or -not $a.password) { Stop-Qa "Tests\local\credentials.json has no entry for the '$key' test account." }
    }
    $script:QaCredCache = $c
    return $c
}

function New-QaPassword([int]$Length = 24) {
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; $lower = 'abcdefghijkmnopqrstuvwxyz'; $digit = '23456789'
    $all = $upper + $lower + $digit
    do {
        $chars = for ($i = 0; $i -lt $Length; $i++) { $all[[Security.Cryptography.RandomNumberGenerator]::GetInt32($all.Length)] }
        $p = -join $chars
    } until ($p -cmatch '[A-Z]' -and $p -cmatch '[a-z]' -and $p -match '[0-9]')
    return $p
}

# ---------------------------------------------------------------------------------------------
# SQL: every call names BMMS_Quality (or master for RESTORE); nothing else is possible here
# ---------------------------------------------------------------------------------------------
function Invoke-QaSqlcmd {
    param(
        [Parameter(Mandatory)][ValidateSet('Windows', 'Tester', 'Site')][string]$As,
        [ValidateSet('BMMS_Quality', 'master')][string]$Database = 'BMMS_Quality',
        [string]$InputFile,
        [string]$Query,
        [switch]$NoHeader,
        [switch]$NoThrow
    )
    if ([bool]$InputFile -eq [bool]$Query) { throw 'Invoke-QaSqlcmd: give either -InputFile or -Query.' }
    $a = @('-S', $QaServer, '-C', '-b', '-I', '-W', '-s', '|', '-d', $Database)
    if ($NoHeader) { $a += @('-h', '-1') }
    if ($InputFile) { $a += @('-i', $InputFile) } else { $a += @('-Q', $Query) }
    $code = 1; $lines = @()
    try {
        if ($As -eq 'Windows') { $a += '-E' }
        elseif ($As -eq 'Site') { $a += @('-U', $QaSiteLogin); $env:SQLCMDPASSWORD = (Get-QaCredentials).siteLogin.password }
        else { $a += @('-U', $QaTesterLogin); $env:SQLCMDPASSWORD = (Get-QaCredentials).sqlLogin.password }
        $lines = @(& sqlcmd @a 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally {
        Remove-Item Env:SQLCMDPASSWORD -ErrorAction SilentlyContinue
    }
    if ($code -ne 0 -and -not $NoThrow) {
        throw ("sqlcmd failed (exit $code) on $Database as $As" + ': ' + (($lines | Where-Object { $_.Trim() } | Select-Object -Last 6) -join ' / '))
    }
    return [pscustomobject]@{ ExitCode = $code; Lines = $lines }
}

# The connection really is on BMMS_Quality (exact name, case included).
function Assert-QaDatabase([ValidateSet('Windows', 'Tester')][string]$As) {
    $r = Invoke-QaSqlcmd -As $As -NoHeader -Query 'SET NOCOUNT ON; SELECT DB_NAME();'
    $name = ($r.Lines | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ("$name".Trim() -cne $QaDatabase) { Stop-Qa "The connection is on '$name', not on $QaDatabase. Nothing was done." }
}

# The two SQL logins of the tester - bmms_tester (restores and checks) and bmms_site (the site copy's
# connection) - can open BMMS_Quality and the three system databases every login can open, and no
# other database. This is the wall between the tester and BMMS / BMMS_Test, so it is proved, not
# assumed: asked of the server as each login itself, before every run. Refused when the login
#   - is not the one expected, or can open any other database (the list it sees);
#   - can open BMMS or BMMS_Test (asked by name, so a hidden list cannot hide them);
#   - is a member of any fixed server role;
#   - holds CONTROL SERVER or IMPERSONATE ANY LOGIN, or any IMPERSONATE grant on another login;
#   - (step WF3a2, an allow-list) holds any server permission in effect other than CONNECT SQL and
#     VIEW ANY DATABASE (what every login has through public), however it was given: directly, to
#     public or through a role (fn_my_permissions); or has any permission granted to the login
#     itself other than CONNECT SQL on the server (sys.server_permissions);
#   - bmms_site only: is in BMMS_Quality anything but a member of exactly db_backupoperator,
#     db_datareader and db_datawriter (the roles of the application login bmms_app).
# Every answer line must be there with the expected value: a missing line refuses too.
New-Variable -Name QaAllowedServerPermissions -Value @('CONNECT SQL', 'VIEW ANY DATABASE') -Option Constant
function Assert-QaLoginReach([ValidateSet('Tester', 'Site')][string]$As) {
    $login = $(if ($As -eq 'Site') { $QaSiteLogin } else { $QaTesterLogin })
    $q = "SET NOCOUNT ON; " +
         "SELECT 'self|' + SUSER_SNAME(); " +
         "SELECT 'db|' + name FROM sys.databases WHERE HAS_DBACCESS(name) = 1 AND name NOT IN (N'BMMS_Quality', N'master', N'tempdb', N'msdb'); " +
         "SELECT 'named|' + CAST(ISNULL(HAS_DBACCESS(N'BMMS'), 0) + ISNULL(HAS_DBACCESS(N'BMMS_Test'), 0) AS varchar(5)); " +
         "SELECT 'role|' + CAST(IS_SRVROLEMEMBER('sysadmin') + IS_SRVROLEMEMBER('securityadmin') + IS_SRVROLEMEMBER('serveradmin') + IS_SRVROLEMEMBER('setupadmin') + IS_SRVROLEMEMBER('processadmin') + IS_SRVROLEMEMBER('diskadmin') + IS_SRVROLEMEMBER('dbcreator') + IS_SRVROLEMEMBER('bulkadmin') + (SELECT COUNT(*) FROM sys.server_role_members m WHERE m.member_principal_id = SUSER_ID()) AS varchar(5)); " +
         "SELECT 'perm|' + CAST((SELECT COUNT(*) FROM fn_my_permissions(NULL, 'SERVER') WHERE permission_name IN ('CONTROL SERVER', 'IMPERSONATE ANY LOGIN')) + (SELECT COUNT(*) FROM sys.server_permissions WHERE grantee_principal_id = SUSER_ID() AND permission_name LIKE 'IMPERSONATE%') AS varchar(5)); " +
         "SELECT 'eff|' + permission_name FROM fn_my_permissions(NULL, 'SERVER'); " +
         "SELECT 'own|' + class_desc + ':' + permission_name + ':' + state_desc FROM sys.server_permissions WHERE grantee_principal_id = SUSER_ID(); " +
         "SELECT 'dbuser|' + USER_NAME(); " +
         "SELECT 'dbrole|' + r.name FROM sys.database_role_members m JOIN sys.database_principals r ON r.principal_id = m.role_principal_id WHERE m.member_principal_id = DATABASE_PRINCIPAL_ID() ORDER BY r.name;"
    $r = Invoke-QaSqlcmd -As $As -NoHeader -Query $q -NoThrow
    if ($r.ExitCode -ne 0) { Stop-Qa "$login could not sign in to $QaDatabase or could not be checked. Nothing was done; run Setup-Quality.ps1 again or tell Claude." }
    function One([string]$key) { @($r.Lines | Where-Object { $_ -match "^$key\|" } | ForEach-Object { ($_ -split '\|', 2)[1].Trim() }) }
    $self = @(One 'self'); $others = @(One 'db'); $named = @(One 'named'); $roles = @(One 'role'); $perm = @(One 'perm'); $dbuser = @(One 'dbuser'); $dbroles = @(One 'dbrole') -join ','
    if ($self.Count -ne 1 -or $self[0] -cne $login) { Stop-Qa "The SQL connection is not signed in as $login. Nothing was done." }
    if ($others.Count -gt 0) { Stop-Qa "$login can open another database ($($others -join ', ')). It must reach $QaDatabase only. Nothing was done; tell Claude." }
    if ($named.Count -ne 1 -or $named[0] -cne '0') { Stop-Qa "$login can open BMMS or BMMS_Test. It must reach $QaDatabase only. Nothing was done; tell Claude." }
    if ($roles.Count -ne 1 -or $roles[0] -cne '0') { Stop-Qa "$login is a member of a server role. It must have none. Nothing was done; tell Claude." }
    if ($perm.Count -ne 1 -or $perm[0] -cne '0') { Stop-Qa "$login holds CONTROL SERVER or an IMPERSONATE right. It must have neither. Nothing was done; tell Claude." }
    # Step WF3a2: the allow-list. The answer must name CONNECT SQL (a login that can sign in has it), so an
    # empty answer cannot pass.
    $effective = @(One 'eff' | Sort-Object -Unique); $own = @(One 'own')
    $extra = @($effective | Where-Object { $_ -cnotin $QaAllowedServerPermissions })
    if ($effective -cnotcontains 'CONNECT SQL' -or $extra.Count -gt 0) { Stop-Qa "$login holds the server permission(s) '$($extra -join ', ')' besides CONNECT SQL and VIEW ANY DATABASE. It must hold no other. Nothing was done; tell Claude." }
    $ownExtra = @($own | Where-Object { $_ -cne 'SERVER:CONNECT SQL:GRANT' })
    if ($ownExtra.Count -gt 0) { Stop-Qa "$login was given '$($ownExtra -join ', ')' on the server besides CONNECT SQL. It must have nothing else. Nothing was done; tell Claude." }
    if ($As -eq 'Site') {
        if ($dbuser.Count -ne 1 -or $dbuser[0] -cne $QaSiteLogin) { Stop-Qa "$login is not the plain user $QaSiteLogin in $QaDatabase. Nothing was done; tell Claude." }
        if ($dbroles -cne 'db_backupoperator,db_datareader,db_datawriter') { Stop-Qa "$login has the roles '$dbroles' in $QaDatabase, not exactly db_backupoperator, db_datareader, db_datawriter. Nothing was done; tell Claude." }
    }
    elseif ($dbuser.Count -ne 1 -or $dbuser[0] -cne 'dbo') { Stop-Qa "$login is not the owner of $QaDatabase. Nothing was done; run Setup-Quality.ps1 again or tell Claude." }
}
function Assert-QaLoginsReach { Assert-QaLoginReach -As Tester; Assert-QaLoginReach -As Site }

# The repository's Check script on BMMS_Quality: one object per step row.
function Get-QaInstalledSteps([ValidateSet('Windows', 'Tester')][string]$As) {
    $r = Invoke-QaSqlcmd -As $As -InputFile $QaCheckScript
    $rows = foreach ($l in $r.Lines) {
        if ($l -match '^\s*(\d+)\|([^|]*)\|([A-Za-z]+)\|(.*)$') {
            [pscustomobject]@{ Step = [int]$Matches[1]; Script = $Matches[2].Trim(); Status = $Matches[3].Trim(); Detail = $Matches[4].Trim() }
        }
    }
    $db = $null
    for ($i = 0; $i -lt $r.Lines.Count; $i++) { if ($r.Lines[$i].Trim() -eq 'CurrentDatabase' -and $i + 2 -lt $r.Lines.Count) { $db = $r.Lines[$i + 2].Trim() } }
    $history = ($r.Lines | Where-Object { $_ -match 'history rows|step 39 not installed' } | Select-Object -First 1)
    return [pscustomobject]@{ Rows = @($rows); Database = $db; History = "$history".Trim() }
}

# All rows of the Check script must read Installed. A step added to the repository after the
# baseline was taken reads Missing here: the baseline is out of date.
function Assert-QaStepsInstalled([ValidateSet('Windows', 'Tester')][string]$As, [string]$What) {
    $s = Get-QaInstalledSteps -As $As
    if ($s.Database -cne $QaDatabase) { Stop-Qa "The Check script ran on '$($s.Database)', not on $QaDatabase." }
    if ($s.Rows.Count -eq 0) { Stop-Qa 'The Check script returned no step rows.' }
    $bad = @($s.Rows | Where-Object { $_.Status -cne 'Installed' })
    if ($bad.Count -gt 0) {
        $list = ($bad | ForEach-Object { "step $($_.Step) ($($_.Script)): $($_.Status)" }) -join '; '
        Stop-Qa "$What is out of date: $list. Bring it up to date with Tests\_runner\Update-Baseline.ps1 (see Tests\README.md)."
    }
    return $s
}

function Get-QaBaselineInfo {
    if (-not (Test-Path -LiteralPath $QaBaselineInfo)) { Stop-Qa 'Tests\local\baseline.json is missing: no baseline has been taken. Run Tests\_runner\Setup-Quality.ps1 first.' }
    $b = Get-Content -LiteralPath $QaBaselineInfo -Raw | ConvertFrom-Json
    if ((Split-Path -Leaf $b.backupPath) -cne $QaBaselineFile -or $b.backupPath -match "['`"\r\n]") { Stop-Qa 'Tests\local\baseline.json names an unexpected backup file.' }
    return $b
}

# The three fixture scripts are the ones the baseline was built and checked with.
function Assert-QaFixtureUnchanged([object]$Baseline) {
    $now = [ordered]@{ fixtureSha256 = $QaFixtureScript; fixtureCheckSha256 = $QaFixtureCheckScript; fixtureDatesSha256 = $QaFixtureDatesScript }
    foreach ($key in $now.Keys) {
        $recorded = $(if ($Baseline.PSObject.Properties[$key]) { [string]$Baseline.PSObject.Properties[$key].Value } else { '' })
        if (-not $recorded -or (Get-QaFileHash $now[$key]) -ne $recorded) {
            Stop-Qa "Tests\fixture\$(Split-Path -Leaf $now[$key]) has changed since the baseline was taken (or the baseline record is older than this check). Build the baseline again with Setup-Quality.ps1 (see Tests\README.md)."
        }
    }
}

# Restores BMMS_Quality from its baseline backup. The statement text is fixed; only the folder of
# the backup file comes from baseline.json (its file name is checked above).
function Restore-QaBaseline([ValidateSet('Windows', 'Tester')][string]$As) {
    $b = Get-QaBaselineInfo
    $restore = "SET NOCOUNT ON; IF DB_ID(N'BMMS_Quality') IS NULL BEGIN RAISERROR('BMMS_Quality does not exist on this server.', 16, 1); RETURN; END; " +
               "ALTER DATABASE [BMMS_Quality] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; " +
               "RESTORE DATABASE [BMMS_Quality] FROM DISK = N'$($b.backupPath)' WITH REPLACE, RECOVERY;"
    $multi = "SET NOCOUNT ON; IF DB_ID(N'BMMS_Quality') IS NOT NULL AND CAST(DATABASEPROPERTYEX(N'BMMS_Quality', 'UserAccess') AS varchar(20)) <> 'MULTI_USER' ALTER DATABASE [BMMS_Quality] SET MULTI_USER;"
    $last = $null
    for ($try = 1; $try -le 3; $try++) {
        $r = Invoke-QaSqlcmd -As $As -Database master -Query $restore -NoThrow
        $null = Invoke-QaSqlcmd -As $As -Database master -Query $multi -NoThrow
        if ($r.ExitCode -eq 0) { Assert-QaDatabase -As $As; return }
        $last = ($r.Lines | Where-Object { $_.Trim() } | Select-Object -Last 4) -join ' / '
        Start-Sleep -Seconds 2
    }
    throw "The baseline could not be restored over $QaDatabase after 3 tries: $last"
}

# ---------------------------------------------------------------------------------------------
# The site copy: build, sync, connection string, start, stop
# ---------------------------------------------------------------------------------------------
function Get-QaMsBuild {
    $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $found = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null | Select-Object -First 1
        if ($found -and (Test-Path -LiteralPath $found)) { return $found }
    }
    $fixed = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe'
    if (Test-Path -LiteralPath $fixed) { return $fixed }
    Stop-Qa 'MSBuild.exe was not found (Visual Studio with MSBuild is needed to build the site copy).'
}

# Builds the three projects from the working tree into Tests\_build. The projects' own bin and obj
# folders are not written (OutDir and IntermediateOutputPath point into Tests\_build).
function Invoke-QaBuild {
    $out = Join-Path $QaBuildDir 'out'; $obj = Join-Path $QaBuildDir 'obj'
    New-Item -ItemType Directory -Force -Path $out, $obj | Out-Null
    $rsp = Join-Path $QaBuildDir 'build.rsp'
    @('/nologo', '/v:m', '/t:Build', '/p:Configuration=Debug',
      "/p:OutDir=`"$out\\`"", "/p:IntermediateOutputPath=`"$obj\\`"",
      "/p:ReferencePath=`"$QaRepo\BMMSBAL\bin\Debug;$QaRepo\BMMS\bin`"",
      '/p:UseSharedCompilation=false') | Set-Content -LiteralPath $rsp -Encoding utf8
    $log = @(& (Get-QaMsBuild) (Join-Path $QaRepo 'BMMS\BMMS.csproj') "@$rsp" 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        $errors = ($log | Where-Object { $_ -match ': error ' } | Select-Object -First 5) -join "`n"
        Stop-Qa "The build of the working tree failed; no test was run.`n$errors"
    }
    foreach ($dll in 'BMMS.dll', 'BMMSBAL.dll', 'BMMSDAL.dll') {
        if (-not (Test-Path -LiteralPath (Join-Path $out $dll))) { Stop-Qa "The build did not produce $dll." }
    }
}

function Get-QaSyncArgs {
    $src = Join-Path $QaRepo 'BMMS'
    return @($src, $QaSiteDir, '/MIR',
        '/XD', (Join-Path $src 'bin'), (Join-Path $src 'obj'), (Join-Path $src 'Log'), (Join-Path $src 'Files'), (Join-Path $src 'Properties'),
               (Join-Path $QaSiteDir 'bin'), (Join-Path $QaSiteDir 'Log'), (Join-Path $QaSiteDir 'Files'),
        '/XF', '*.cs', '*.csproj', '*.user', '*.resx', '*.pdb', 'connectionStrings.config', 'connectionStrings.config.example', 'PageAccessLog.txt',
        '/R:1', '/W:1', '/NJH', '/NJS', '/NDL', '/NP', '/NS', '/NC')
}

# Rebuilds and re-syncs Tests\_site from the working tree, then proves the copy is current.
# A change made inside Tests\_site (for example by a proof that edits PageAccess.xml there) is
# undone here: /MIR copies the working tree's file back.
function Sync-QaSite {
    Invoke-QaBuild
    New-Item -ItemType Directory -Force -Path $QaSiteDir | Out-Null
    $a = Get-QaSyncArgs
    $null = & robocopy @a
    if ($LASTEXITCODE -ge 8) { Stop-Qa "Copying the pages to Tests\_site failed (robocopy $LASTEXITCODE)." }
    $null = & robocopy (Join-Path $QaBuildDir 'out') (Join-Path $QaSiteDir 'bin') /MIR /XD (Join-Path $QaBuildDir 'out\_PublishedWebsites') /XF *.xml /R:1 /W:1 /NJH /NJS /NDL /NP /NS /NC /NFL
    if ($LASTEXITCODE -ge 8) { Stop-Qa "Copying the build to Tests\_site\bin failed (robocopy $LASTEXITCODE)." }
    # The upload folders exist but are empty; the branding folder (organisation logo) is copied.
    $null = & robocopy (Join-Path $QaRepo 'BMMS\Files') (Join-Path $QaSiteDir 'Files') /E /XF * /R:1 /W:1 /NJH /NJS /NDL /NP /NS /NC /NFL
    if (Test-Path -LiteralPath (Join-Path $QaRepo 'BMMS\Files\Branding')) {
        $null = & robocopy (Join-Path $QaRepo 'BMMS\Files\Branding') (Join-Path $QaSiteDir 'Files\Branding') /MIR /R:1 /W:1 /NJH /NJS /NDL /NP /NS /NC /NFL
    }
    foreach ($d in 'Log', 'App_Data', 'Files\Temp', 'Files\PDF') { New-Item -ItemType Directory -Force -Path (Join-Path $QaSiteDir $d) | Out-Null }
    $global:LASTEXITCODE = 0

    # Proof 1 of "current": a second pass in list-only mode must find nothing left to copy or remove.
    $left = @(& robocopy @a /L | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($left.Count -gt 0) { Stop-Qa ("Tests\_site is not the same as the working tree after the sync (" + $left.Count + " file(s), first: " + $left[0] + ").") }
    # Proof 2: no code file is newer than the build.
    $out = Join-Path $QaBuildDir 'out'
    $built = (Get-Item (Join-Path $out 'BMMS.dll'), (Join-Path $out 'BMMSBAL.dll'), (Join-Path $out 'BMMSDAL.dll') | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
    $newest = Get-ChildItem -LiteralPath (Join-Path $QaRepo 'BMMS'), (Join-Path $QaRepo 'BMMSBAL'), (Join-Path $QaRepo 'BMMSDAL') -Recurse -File -Include *.cs, *.csproj |
        Where-Object { $_.FullName -notmatch '\\(obj|bin)\\' } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($newest -and $newest.LastWriteTimeUtc -gt $built) { Stop-Qa "A source file is newer than the build of the site copy: $($newest.FullName). No test was run." }
    foreach ($dll in 'BMMS.dll', 'BMMSBAL.dll', 'BMMSDAL.dll') {
        if ((Get-QaFileHash (Join-Path $out $dll)) -ne (Get-QaFileHash (Join-Path $QaSiteDir "bin\$dll"))) { Stop-Qa "Tests\_site\bin\$dll is not the file that was just built." }
    }
    Write-QaSiteConnection
}

# The site copy's own connectionStrings.config, written from fixed parts: this machine's SQL
# Server, BMMS_Quality, and the login bmms_site, which can open no other database. The owner's
# BMMS\connectionStrings.config (the application login bmms_app) is not read and not used. The
# file is made readable by the owner's account only before the password is written into it.
# The text is never shown.
function Write-QaSiteConnection {
    $password = [string](Get-QaCredentials).siteLogin.password
    if ($password -notmatch '^[A-Za-z0-9]+$') { Stop-Qa 'The bmms_site password in Tests\local\credentials.json is not in the form Setup-Quality.ps1 writes. Run Setup-Quality.ps1 again.' }
    $target = Join-Path $QaSiteDir 'connectionStrings.config'
    Set-Content -LiteralPath $target -Value '' -Encoding ascii
    $me = Get-QaCurrentAccount
    $null = & icacls $target /inheritance:r /grant:r "${me}:F" 2>&1
    if ($LASTEXITCODE -ne 0) { Stop-Qa 'The permissions of Tests\_site\connectionStrings.config could not be restricted.' }
    # Step WF3a2: read the permissions back before the password goes in. /grant:r replaces only the
    # entries of this account, so an explicit entry of another account would stay: refuse then.
    if (-not (Test-QaOnlyMine $target)) {
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        Stop-Qa 'Tests\_site\connectionStrings.config can still be read by an account other than yours after icacls (an explicit entry of another account, or inherited permissions). The password was not written. Tell Claude.'
    }
    @('<connectionStrings>',
      "`t<add name=`"ConnectionString`"",
      "`t`t connectionString=`"server=$QaServer;database=$QaDatabase;uid=$QaSiteLogin;password=$password;TrustServerCertificate=True`"/>",
      '</connectionStrings>') | Set-Content -LiteralPath $target -Encoding ascii
    Assert-QaSiteConnection
}

# The connection string points at this machine's SQL Server, nowhere else.
function Assert-QaLocalServer([string]$ConnectionString) {
    $servers = @([regex]::Matches($ConnectionString, '(?i)(?<=^|;)\s*(server|data source|address|addr|network address)\s*=\s*([^;]*)') | ForEach-Object { $_.Groups[2].Value.Trim() })
    if ($servers.Count -ne 1 -or $servers[0] -notin '.', '(local)', 'localhost') { Stop-Qa "The connection string must name the local SQL Server ('.', '(local)' or 'localhost') exactly once. No test was run." }
}

# Proof before any sign-in: the file the site under test reads names exactly BMMS_Quality.
function Assert-QaSiteConnection {
    $target = Join-Path $QaSiteDir 'connectionStrings.config'
    if (-not (Test-Path -LiteralPath $target)) { Stop-Qa 'Tests\_site\connectionStrings.config is missing.' }
    [xml]$x = Get-Content -LiteralPath $target -Raw
    $nodes = @($x.connectionStrings.add)
    if ($nodes.Count -ne 1) { Stop-Qa 'Tests\_site\connectionStrings.config must hold exactly one connection string.' }
    $names = @([regex]::Matches([string]$nodes[0].connectionString, '(?i)(?<=^|;)\s*(database|initial catalog)\s*=\s*([^;]*)') | ForEach-Object { $_.Groups[2].Value.Trim() })
    if ($names.Count -ne 1 -or $names[0] -cne $QaDatabase) { Stop-Qa "The site copy's connection string does not name $QaDatabase (and only it). No test was run." }
    Assert-QaLocalServer ([string]$nodes[0].connectionString)
    $users = @([regex]::Matches([string]$nodes[0].connectionString, '(?i)(?<=^|;)\s*(uid|user id|user)\s*=\s*([^;]*)') | ForEach-Object { $_.Groups[2].Value.Trim() })
    if ($users.Count -ne 1 -or $users[0] -cne $QaSiteLogin) { Stop-Qa "The site copy's connection string does not sign in as $QaSiteLogin (and only as it). No test was run." }
    if ([string]$nodes[0].connectionString -match '(?i)(?<=^|;)\s*(integrated security|trusted_connection)\s*=') { Stop-Qa "The site copy's connection string must not use Windows sign-in. No test was run." }
    if (([xml](Get-Content -LiteralPath (Join-Path $QaSiteDir 'Web.config') -Raw)).configuration.connectionStrings.configSource -ne 'connectionStrings.config') {
        Stop-Qa "The site copy's Web.config does not read connectionStrings.config. No test was run."
    }
}

function Get-QaBuildMarker {
    $dll = Get-Item -LiteralPath (Join-Path $QaSiteDir 'bin\BMMS.dll')
    $head = (& git -C $QaRepo rev-parse --short HEAD 2>$null)
    $dirty = @(& git -C $QaRepo status --short 2>$null | Where-Object { $_ -and $_ -notmatch '^\?\? ' }).Count
    return [ordered]@{
        builtOn      = $dll.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        bmmsDllSha256 = (Get-QaFileHash $dll.FullName)
        productVersion = $dll.VersionInfo.ProductVersion
        gitCommit    = "$head"
        modifiedFiles = $dirty
    }
}

# Step WF3a2: the site copy runs from the runner's own IIS Express configuration (Tests\_build\iisexpress),
# made from IIS Express's template: one site, Tests\_site on http://localhost:18573, and the IP restriction
# module set to let in only callers on this machine (127.0.0.1 and ::1). IIS Express listens through http.sys
# on every address of the machine and answers a request that says "Host: localhost" on any of them (seen
# 2026-11-11), so the host-name binding alone keeps no other machine out. BMMS\Web.config is not touched.
New-Variable -Name QaIisSiteName -Value 'BMMSTester' -Option Constant
$QaIisConfig = Join-Path $QaBuildDir 'iisexpress\applicationhost.config'

function New-QaIisConfig {
    $template = Join-Path (Split-Path -Parent $QaIisExpress) 'AppServer\applicationhost.config'
    if (-not (Test-Path -LiteralPath $template)) { Stop-Qa "The IIS Express configuration template was not found ($template)." }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $QaIisConfig) | Out-Null
    $x = [xml]::new(); $x.PreserveWhitespace = $true; $x.Load($template)
    $sites = $x.SelectSingleNode('/configuration/system.applicationHost/sites')
    foreach ($s in @($sites.SelectNodes('site'))) { $null = $sites.RemoveChild($s) }
    $site = $x.CreateElement('site'); $site.SetAttribute('name', $QaIisSiteName); $site.SetAttribute('id', '1'); $site.SetAttribute('serverAutoStart', 'true')
    $app = $x.CreateElement('application'); $app.SetAttribute('path', '/'); $app.SetAttribute('applicationPool', 'Clr4IntegratedAppPool')
    $vd = $x.CreateElement('virtualDirectory'); $vd.SetAttribute('path', '/'); $vd.SetAttribute('physicalPath', $QaSiteDir)
    $null = $app.AppendChild($vd); $null = $site.AppendChild($app)
    $bindings = $x.CreateElement('bindings'); $b = $x.CreateElement('binding'); $b.SetAttribute('protocol', 'http'); $b.SetAttribute('bindingInformation', ":${QaPort}:localhost")
    $null = $bindings.AppendChild($b); $null = $site.AppendChild($bindings)
    $null = $sites.PrependChild($site)
    $ip = $x.SelectSingleNode('/configuration/system.webServer/security/ipSecurity')
    if (-not $ip) { Stop-Qa 'The IIS Express template has no ipSecurity section; the site copy cannot be kept to this machine.' }
    $ip.RemoveAll(); $ip.SetAttribute('allowUnlisted', 'false')
    foreach ($a in '127.0.0.1', '::1') { $e = $x.CreateElement('add'); $e.SetAttribute('ipAddress', $a); $e.SetAttribute('allowed', 'true'); $null = $ip.AppendChild($e) }
    $x.Save($QaIisConfig)
}

function Get-QaSiteProcesses {
    # The runner's own configuration (since WF3a2), or an older /path start of the site copy (WF3a1).
    @(Get-CimInstance Win32_Process -Filter "Name='iisexpress.exe'" | Where-Object {
        $_.CommandLine -and (
            ($_.CommandLine -like "*$QaIisConfig*" -and $_.CommandLine -like "*/site:$QaIisSiteName*") -or
            ($_.CommandLine -like "*/port:$QaPort*" -and $_.CommandLine -like "*$QaSiteDir*")) })
}

function Stop-QaSite {
    foreach ($p in Get-QaSiteProcesses) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    for ($i = 0; $i -lt 20 -and @(Get-QaSiteProcesses).Count -gt 0; $i++) { Start-Sleep -Milliseconds 250 }
}

function Start-QaSite {
    Stop-QaSite
    # A listening entry owned by process 0 is a socket of a process that has already ended (seen after the
    # address probes below); it does not keep IIS Express from starting, so only a live owner refuses.
    if (@(Get-NetTCPConnection -LocalPort $QaPort -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -gt 0 }).Count -gt 0) { Stop-Qa "Port $QaPort is already in use by another program. No test was run." }
    if (-not (Test-Path -LiteralPath $QaIisExpress)) { Stop-Qa 'IIS Express was not found.' }
    Assert-QaSiteConnection
    # Started without redirecting its output, so it inherits none of the runner's pipes: a site copy
    # left running (-LeaveSiteRunning) then never keeps the caller of the runner waiting.
    New-QaIisConfig
    $p = Start-Process -FilePath $QaIisExpress -ArgumentList "/config:`"$QaIisConfig`"", "/site:$QaIisSiteName", '/systray:false' `
        -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds(180); $ok = $false
    while ((Get-Date) -lt $deadline -and -not $p.HasExited) {
        try {
            $r = Invoke-WebRequest -Uri "$QaBaseUrl/Default.aspx" -UseBasicParsing -TimeoutSec 60 -SkipHttpErrorCheck
            if ($r.StatusCode -eq 200) { $ok = $true; break }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ok) { Stop-QaSite; Stop-Qa "The site copy did not start or did not answer on $QaBaseUrl within 3 minutes. No test was run. To see IIS Express's own message, tell Claude." }
    # The process that answers is ours and serves Tests\_site.
    $mine = @(Get-QaSiteProcesses | Where-Object { $_.ProcessId -eq $p.Id })
    if ($mine.Count -ne 1) { Stop-QaSite; Stop-Qa 'The IIS Express process on the test port is not the one the runner started.' }
    Assert-QaLocalhostOnly
    return $p
}

# Step WF3a2: the site copy serves only callers on this machine. Asked through each of this machine's own network
# addresses (what another machine would use), twice: with the address as host name (HTTP 400: the localhost
# binding) and with "Host: localhost" (HTTP 403: the IP restriction of New-QaIisConfig). Anything but no
# connection, 400 or 403 stops the run; so does a probe that gets no answer in time. Local traffic does not pass
# the firewall, so this tests the binding and the IP restriction, not the firewall (Get-QaFirewallOpenings).
function Get-QaLocalAddresses {
    @(Get-NetIPAddress -ErrorAction SilentlyContinue | Where-Object {
        $_.AddressState -eq 'Preferred' -and $_.IPAddress -notmatch '^(127\.|169\.254\.|::1$|fe80:)' } |
        ForEach-Object { $_.IPAddress } | Sort-Object -Unique)
}

function Assert-QaLocalhostOnly {
    $answered = @()
    foreach ($ip in Get-QaLocalAddresses) {
        $hostPart = $(if ($ip -match ':') { "[$ip]" } else { $ip })
        # Twice per address: with the address as host name (what a browser elsewhere sends) and with
        # "Host: localhost" (what a caller elsewhere could send). Only a refusal passes: no connection,
        # HTTP 400 (host name not served) or HTTP 403 (the IP restriction: not a caller on this machine).
        foreach ($hostHeader in @($null, "localhost:$QaPort")) {
            try {
                $a = @{ Uri = "http://${hostPart}:$QaPort/Default.aspx"; UseBasicParsing = $true; TimeoutSec = 10; SkipHttpErrorCheck = $true; MaximumRedirection = 0; DisableKeepAlive = $true; NoProxy = $true }
                if ($hostHeader) { $a.Headers = @{ Host = $hostHeader } }
                $r = Invoke-WebRequest @a
                if ($r.StatusCode -notin 400, 403) { $answered += "$ip$(if ($hostHeader) { ' (Host: localhost)' }) (HTTP $($r.StatusCode))" }
            } catch {
                # Refused or reset: as wanted. No answer in time: not shown to be refused, so it stops the run.
                if ($_.Exception -is [System.Threading.Tasks.TaskCanceledException] -or $_.Exception -is [System.TimeoutException] -or "$($_.Exception.Message)" -match '(?i)time(d)? ?out') {
                    $answered += "$ip$(if ($hostHeader) { ' (Host: localhost)' }) (no answer within 10 seconds)"
                }
            }
        }
    }
    if ($answered.Count -gt 0) {
        Stop-QaSite
        Stop-Qa "The site copy answers on a network address of this machine, not only to localhost: $($answered -join ', '). It was stopped; no test was run. Tell Claude."
    }
}

# Step WF3a2: what in the firewall could let another machine reach the site copy: a profile that is off or that
# lets inbound traffic in by default, and every enabled inbound allow rule (TCP or any protocol) for IIS Express,
# for System (http.sys receives the traffic) or for any program, that covers port 18573 (the number, a range,
# "*" or no port given). Rules of other programs and app-container rules (LocalUserOwner set) are not counted.
# Read through the firewall's COM interface, which needs no administrator rights; if it fails, the runner fails.
# Owner decision (2026-11-11): each finding is an object { Refuse; Text }. Only a profile that lets inbound
# traffic in by default refuses -LeaveSiteRunning; a rule or a profile that is off is a warning, because the IP
# restriction is probed on every address with both host names on every run (Assert-QaLocalhostOnly). The
# runner changes no Windows rule.
function Get-QaFirewallOpenings {
    $out = @()
    $fw = New-Object -ComObject HNetCfg.FwPolicy2
    foreach ($profile in @(@{ n = 'Domain'; v = 1 }, @{ n = 'Private'; v = 2 }, @{ n = 'Public'; v = 4 })) {
        if (-not $fw.FirewallEnabled($profile.v)) { $out += [pscustomobject]@{ Refuse = $false; Text = "the Windows Firewall is off for the $($profile.n) profile" } }
        elseif ($fw.DefaultInboundAction($profile.v) -eq 1) { $out += [pscustomobject]@{ Refuse = $true; Text = "the $($profile.n) profile lets inbound traffic in by default (no rule needed)" } }
    }
    # The traffic of the site copy is received by System (http.sys) on behalf of IIS Express. A rule counts when
    # it is for IIS Express, for System or for any program, and covers port 18573 (the number, a range, or every
    # port). Rules of an app container (LocalUserOwner set: a Store app's own rule) and of other programs do not
    # reach System and are not counted.
    foreach ($rule in $fw.Rules) {
        if ($rule.Direction -ne 1 -or -not $rule.Enabled -or $rule.Action -ne 1 -or $rule.Protocol -notin 6, 256) { continue }
        $owner = ''; try { $owner = "$($rule.LocalUserOwner)" } catch { }
        if ($owner) { continue }
        $app = "$($rule.ApplicationName)"
        if ($app -and $app -notmatch '(?i)(^|\\)iisexpress\.exe$|^System$') { continue }
        $ports = "$($rule.LocalPorts)".Trim()
        $covers = (-not $ports -or $ports -eq '*')
        foreach ($part in ($ports -split ',')) {
            $x = $part.Trim()
            if ($x -match '^(\d+)-(\d+)$') { if ($QaPort -ge [int]$Matches[1] -and $QaPort -le [int]$Matches[2]) { $covers = $true } }
            elseif ($x -match '^\d+$' -and [int]$x -eq $QaPort) { $covers = $true }
        }
        if ($covers) { $out += [pscustomobject]@{ Refuse = $false; Text = "rule '$($rule.Name)' (" + $(if ($app) { $app } else { 'any program' }) + ", port " + $(if ($ports -and $ports -ne '*') { $ports } else { 'any' }) + ") lets inbound traffic in" } }
    }
    return @($out)
}
