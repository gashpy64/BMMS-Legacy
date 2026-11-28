#Requires -Version 7.3
<#
  Check-UserManuals.ps1 - the internal-material check of the BMMS user manuals.

  Searches every Markdown file under Documents/User-Manuals/ (or only the files given with
  -Files) for material that must not reach a shipped manual: procedure and function names, step
  numbers, step codes and tag names, Reason codes, table names that are not plain words, file paths,
  internal words, open [[CONFIRM: ...]] points and secret-like text.

  The rules run on the Markdown source and again on pandoc's rendering of it, so escapes and
  entity codes cannot hide a hit; entity codes such as #95; (which Mermaid decodes when it
  draws a diagram) are a hit themselves. pandoc is required: without it the check fails.

  Prints one line per hit (file:line [rule] text) and a total. Exit code 0 when there are no
  hits, 1 when there are hits or pandoc is missing. Reads files only; writes nothing.

  Usage (from the repository root):
    pwsh -File Documents/_build/Check-UserManuals.ps1
    pwsh -File Documents/_build/Check-UserManuals.ps1 -Files Documents/User-Manuals/01-User.md
#>
[CmdletBinding()]
param(
    [string[]]$Files,
    [string]$Pandoc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Native programs get their arguments quoted the standard way (each argument stays one argument).
$PSNativeCommandArgumentPassing = 'Standard'

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$manualDir = Join-Path $repo 'Documents\User-Manuals'

if ($Files) {
    $targets = foreach ($f in $Files) {
        $p = (Resolve-Path -LiteralPath (Join-Path $repo $f) -ErrorAction SilentlyContinue)
        if (-not $p) { $p = Resolve-Path -LiteralPath $f }
        Get-Item -LiteralPath $p.Path
    }
} else {
    $targets = Get-ChildItem -LiteralPath $manualDir -Recurse -File -Force -Filter '*.md'
}

# Table names that are not plain English words. Plain-word tables (Agenda, Attendance, Committee,
# Department, Designation, Meeting, Member, Minutes, Roles, Users) may appear in their everyday
# sense and are not searched. Fixed list from the BMMS_Test catalog (2026-11-09), plus every
# name with an underscore or an inner capital found in a CREATE TABLE in Database/*.sql.
$tables = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
@('Action_Item', 'ActionItem_User_Map', 'Agenda_Status', 'Alert_Master', 'Alert_Type',
  'Alert_User_Map', 'App_Setting', 'Audit_Trail_Master', 'Audit_Trail_SendMail',
  'Audit_Trail_SqlBackup', 'Audit_Trial_Login', 'Committee_Member', 'Decision_Type',
  'Meeting_Member', 'Member_Type', 'SMTP_Master', 'Source_Type', 'State_Master', 'Subject_Type',
  'SysCodeSetting', 'sysdiagrams', 'User_Department', 'User_Role') | ForEach-Object { [void]$tables.Add($_) }
$dbDir = Join-Path $repo 'Database'
if (Test-Path -LiteralPath $dbDir) {
    foreach ($sql in Get-ChildItem -LiteralPath $dbDir -Filter '*.sql' -File -Force) {
        $text = Get-Content -Raw -LiteralPath $sql.FullName
        foreach ($m in [regex]::Matches($text, '(?i)CREATE\s+TABLE\s+(?:\[?dbo\]?\.)?\[?([A-Za-z_][A-Za-z0-9_]*)')) {
            $n = $m.Groups[1].Value
            if ($n.StartsWith('#')) { continue }
            if ($n -cmatch '_' -or $n -cmatch '[a-z][A-Z]') { [void]$tables.Add($n) }
        }
    }
}
$tablePattern = '\b(' + (($tables | Sort-Object -Descending { $_.Length } | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'

# The project's git tag names (for example user-ud1a, reset-safe-29), read with git.
$tagNames = @(& git -C $repo tag 2>$null | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' })
$tagPattern = if ($tagNames.Count -gt 0) { '\b(' + (($tagNames | Sort-Object -Descending { $_.Length } | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b' } else { '(?!x)x' }

# Each rule: name, pattern, case-sensitive.
$rules = @(
    @{ Name = 'procedure or function'; Pattern = '\b(spr_|fn_|sp_|xp_)\w*|\bdbo\.'; Case = $false },
    @{ Name = 'step number';           Pattern = '\b[Ss]tep \d';                     Case = $true  },
    @{ Name = 'step code';             Pattern = '\b[A-Z]{1,3}\d{1,2}[a-z]?\d?\b';   Case = $false },
    @{ Name = 'tag name';              Pattern = $tagPattern;                         Case = $false },
    @{ Name = 'Reason';                Pattern = '\bReason\b|\b[Rr]eason (code|\d)'; Case = $true  },
    @{ Name = 'table name';            Pattern = $tablePattern;                       Case = $true  },
    @{ Name = 'file path';             Pattern = '\.(aspx|ascx|asmx|ashx|cs|sql|xml|config|dll|ps1|py)\b|[A-Za-z]:\\|\bApp_Data\b|\bBMMS/|\bBMMSBAL\b|\bBMMSDAL\b|\bDocuments/|\bDatabase/'; Case = $false },
    @{ Name = 'internal word';         Pattern = '\bTo confirm\b|\breviewer|\bbacklog\b|\bKnown items\b|\bcommit(s|ted)?\b|\bBMMS_Test\b'; Case = $false },
    @{ Name = 'open point';            Pattern = '\[\[CONFIRM';                       Case = $false },
    @{ Name = 'entity code';           Pattern = '&?#[A-Za-z0-9]+;';                  Case = $false },
    @{ Name = 'secret-like';           Pattern = 'password\s*=|pwd\s*=|Data Source\s*=|Initial Catalog|Integrated Security|\b\d{1,3}(\.\d{1,3}){3}\b'; Case = $false },
    @{ Name = 'mail address';          Pattern = '[A-Za-z0-9._%+-]+@(?![A-Za-z0-9-]+\.example\b|example\.(com|org|net)\b)[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+'; Case = $false }
)

# The rules run twice: on the Markdown source, and on the text as pandoc renders it (escapes
# such as spr\_ and &#95; decoded, wrapped lines joined), so that nothing written differently in
# the source reaches an export unseen. The second pass needs pandoc; without it, the check fails.
. (Join-Path $PSScriptRoot 'DocTools.ps1')
$pandocPath = Find-DocPandoc -Hint $Pandoc
$PSNativeCommandArgumentPassing = 'Standard'
if (-not $pandocPath) {
    Write-Output 'FAIL: pandoc not found (pass -Pandoc <path to pandoc.exe>); the rendered-text pass is required.'
    exit 1
}

function Test-Lines([string]$Rel, [string[]]$Lines, [string]$Where) {
    $n = 0
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        foreach ($r in $rules) {
            $opt = if ($r.Case) { [System.Text.RegularExpressions.RegexOptions]::None } else { [System.Text.RegularExpressions.RegexOptions]::IgnoreCase }
            $m = [regex]::Match($line, $r.Pattern, $opt)
            if ($m.Success) {
                $n++
                Write-Output ("{0}:{1}{2} [{3}] '{4}' in: {5}" -f $Rel, ($i + 1), $Where, $r.Name, $m.Value, $line.Trim())
            }
        }
    }
    $script:hits += $n
}

$hits = 0
foreach ($file in $targets) {
    $rel = [System.IO.Path]::GetRelativePath($repo, $file.FullName).Replace('\', '/')
    $sourceHits = $hits
    Test-Lines $rel @(Get-Content -LiteralPath $file.FullName) ''
    if ($hits -eq $sourceHits) {
        # Only when the source is clean: report what the rendered text alone reveals, line by
        # line and then as one joined text (for words split across table-cell lines).
        $plain = @(& $pandocPath -f $script:DocMarkdownFormat -t plain --wrap=none -- $file.FullName 2>&1)
        if ($LASTEXITCODE -ne 0) { $hits++; Write-Output "${rel}: pandoc could not read the file: $plain" }
        else {
            $before = $hits
            Test-Lines $rel $plain ' (as rendered)'
            if ($hits -eq $before) { Test-Lines $rel @((($plain -join ' ') -replace '\s+', ' ')) ' (as rendered, joined)' }
        }
    }
}

Write-Output ("Checked {0} file(s) under Documents/User-Manuals: {1} hit(s)." -f @($targets).Count, $hits)
if ($hits -gt 0) { exit 1 } else { exit 0 }
