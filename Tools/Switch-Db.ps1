<#
.SYNOPSIS
    Step HK1: switch the BMMS site between the Local and the Azure database.

.DESCRIPTION
    -Target Local|Azure copies BMMS\connectionStrings.<Target>.config over
    BMMS\connectionStrings.config, then prints the server and the database of the copied file.
    -Show prints which file is in use (Local, Azure or unknown) and changes nothing.

    The folder BMMS is found from this script's own location (..\BMMS), so the script works from
    any current folder. It makes no network call: the connection string is only parsed, never
    opened. It never prints the user name, the password or the whole connection string.

    The two source files are made by hand from connectionStrings.config.example and
    connectionStrings.Azure.config.example; .gitignore keeps every connectionStrings*.config out
    of git.

    Refusals (nothing is changed, exit code 1):
    - the BMMS folder or the source file is missing;
    - the source file is not XML or has no <add name="ConnectionString"> element;
    - the current connectionStrings.config matches neither the Local nor the Azure file, so a
      copy could lose a hand edit (-Force copies anyway, after saving the current file as
      connectionStrings.Force-backup.config, which replaces an older backup; .gitignore keeps
      it out of git).
    Wrong use of the parameters: exit code 2.

    Runs on Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    powershell -File C:\repositories\bmms-legacy\Tools\Switch-Db.ps1 -Show
.EXAMPLE
    powershell -File C:\repositories\bmms-legacy\Tools\Switch-Db.ps1 -Target Azure
#>
[CmdletBinding()]
param(
    [ValidateSet('Local', 'Azure')]
    [string]$Target,
    [switch]$Show,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Line([string]$Text) { Write-Host $Text }

function Stop-Refused([string]$Text) {
    Write-Host ('REFUSED: ' + $Text)
    Write-Host 'Nothing was changed.'
    exit 1
}

# Reads server and database from a connection file. Returns an object with Ok, Problem,
# Server and Database. The connection string itself never leaves this function.
function Read-ConnectionFile([string]$Path) {
    $result = New-Object PSObject -Property @{ Ok = $false; Problem = ''; Server = ''; Database = '' }
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    try {
        $doc.Load($Path)
    }
    catch {
        $result.Problem = 'it is not a readable XML file'
        return $result
    }
    $node = $doc.SelectSingleNode("/connectionStrings/add[@name='ConnectionString']")
    if ($node -eq $null) {
        $result.Problem = 'it has no <add name="ConnectionString"> element under <connectionStrings>'
        return $result
    }
    $text = $node.GetAttribute('connectionString')
    if ([string]::IsNullOrEmpty($text)) {
        $result.Problem = 'its ConnectionString entry has no connectionString value'
        return $result
    }
    $builder = New-Object System.Data.Common.DbConnectionStringBuilder
    try {
        # set_ConnectionString, not "$builder.ConnectionString = ": PowerShell treats the builder
        # as a dictionary and would only add a key named ConnectionString.
        $builder.set_ConnectionString($text)
    }
    catch {
        $result.Problem = 'its connectionString value cannot be read as a connection string'
        return $result
    }
    foreach ($key in @('server', 'data source', 'address', 'addr', 'network address')) {
        if ($builder.ContainsKey($key)) { $result.Server = [string]$builder[$key]; break }
    }
    foreach ($key in @('database', 'initial catalog')) {
        if ($builder.ContainsKey($key)) { $result.Database = [string]$builder[$key]; break }
    }
    if ($result.Server -eq '') { $result.Server = '(not given)' }
    if ($result.Database -eq '') { $result.Database = '(not given)' }
    $result.Ok = $true
    return $result
}

function Get-Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

# --- Parameters ---------------------------------------------------------------------------
$usage = 'Use: Switch-Db.ps1 -Target Local|Azure [-Force]   or   Switch-Db.ps1 -Show'
if ($Show -and ($Target -or $Force)) {
    Write-Line ('-Show changes nothing and takes no -Target or -Force. ' + $usage)
    exit 2
}
if (-not $Show -and -not $Target) {
    Write-Line $usage
    exit 2
}

# --- Paths from the script's own location -------------------------------------------------
$site = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\BMMS'))
if (-not (Test-Path -LiteralPath $site -PathType Container)) {
    Stop-Refused ('the folder ' + $site + ' is missing (the script must stay in Tools\ of the repository).')
}
$current = Join-Path $site 'connectionStrings.config'
$localFile = Join-Path $site 'connectionStrings.Local.config'
$azureFile = Join-Path $site 'connectionStrings.Azure.config'
$backupName = 'connectionStrings.Force-backup.config'
$backup = Join-Path $site $backupName

$currentHash = Get-Hash $current
$localHash = Get-Hash $localFile
$azureHash = Get-Hash $azureFile

function Get-CurrentName {
    if ($currentHash -eq $null) { return 'none' }
    if ($localHash -ne $null -and $currentHash -eq $localHash) { return 'Local' }
    if ($azureHash -ne $null -and $currentHash -eq $azureHash) { return 'Azure' }
    return 'unknown (matches neither connectionStrings.Local.config nor connectionStrings.Azure.config)'
}

# --- -Show --------------------------------------------------------------------------------
if ($Show) {
    if ($currentHash -eq $null) {
        Write-Line ('There is no connectionStrings.config in ' + $site + '.')
        Write-Line 'Run Switch-Db.ps1 -Target Local or -Target Azure to make it.'
        exit 1
    }
    $info = Read-ConnectionFile $current
    Write-Line ('Target:   ' + (Get-CurrentName))
    if ($info.Ok) {
        Write-Line ('Server:   ' + $info.Server)
        Write-Line ('Database: ' + $info.Database)
    }
    else {
        Write-Line ('connectionStrings.config cannot be read: ' + $info.Problem + '.')
        Write-Line 'Nothing was changed. Correct the file by hand, or replace it with Switch-Db.ps1 -Target Local or -Target Azure (add -Force, because it matches neither source file).'
        exit 1
    }
    exit 0
}

# --- -Target ------------------------------------------------------------------------------
$sourceName = 'connectionStrings.' + $Target + '.config'
$source = Join-Path $site $sourceName
$exampleName = 'connectionStrings.config.example'
if ($Target -eq 'Azure') { $exampleName = 'connectionStrings.Azure.config.example' }

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    Stop-Refused ($sourceName + ' is missing in ' + $site + '. Make it once by copying ' + $exampleName + ' to ' + $sourceName + ' and putting in the real password.')
}

$sourceInfo = Read-ConnectionFile $source
if (-not $sourceInfo.Ok) {
    Stop-Refused ($sourceName + ' cannot be used: ' + $sourceInfo.Problem + '.')
}

$sourceHash = Get-Hash $source
if ($currentHash -ne $null -and $currentHash -ne $sourceHash) {
    $known = ($localHash -ne $null -and $currentHash -eq $localHash) -or ($azureHash -ne $null -and $currentHash -eq $azureHash)
    if (-not $known) {
        if (-not $Force) {
            Stop-Refused ('connectionStrings.config matches neither connectionStrings.Local.config nor connectionStrings.Azure.config, so a copy over it could lose a hand edit. Run Switch-Db.ps1 -Show to see the server and database it points at. To keep it as a source, copy connectionStrings.config to connectionStrings.Local.config or connectionStrings.Azure.config first; to replace it, run again with -Force (the current file is then saved as ' + $backupName + ', replacing an older backup).')
        }
        Copy-Item -LiteralPath $current -Destination $backup -Force
        if ((Get-Hash $backup) -ne $currentHash) {
            Stop-Refused ('the backup ' + $backupName + ' could not be written, so connectionStrings.config was not overwritten.')
        }
        Write-Line ('connectionStrings.config matched neither source file; saved as ' + $backupName + ' (an older backup is replaced), then overwritten because -Force was given.')
    }
}

if ($currentHash -eq $sourceHash) {
    Write-Line ('connectionStrings.config is already the ' + $Target + ' file; nothing copied.')
}
else {
    Copy-Item -LiteralPath $source -Destination $current -Force
    if ((Get-Hash $current) -ne $sourceHash) {
        Write-Line ('ERROR: connectionStrings.config is not the same as ' + $sourceName + ' after the copy.')
        exit 1
    }
    Write-Line ('Copied ' + $sourceName + ' to connectionStrings.config.')
    Write-Line 'A running site restarts by itself on this change; signed-in users must sign in again.'
}

$info = Read-ConnectionFile $current
Write-Line ('Target:   ' + $Target + ' (' + $sourceName + ')')
Write-Line ('Server:   ' + $info.Server)
Write-Line ('Database: ' + $info.Database)
exit 0
