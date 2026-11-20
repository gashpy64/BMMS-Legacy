#Requires -Version 7.3
<#
  Export-Catalog.ps1 - read-only catalog of BMMS_Test for a documentation audit (step DA1).

  Writes a folder OUTSIDE the repository (default %LOCALAPPDATA%\BMMS-Audit\catalog-<yyyymmdd>-<short SHA>\)
  with the definitions of the database, read from the sys.* views and SERVERPROPERTY with sqlcmd:
    catalog.txt          export date and time, server, database, SQL Server version, edition,
                         compatibility level, object counts, the repository commit
    modules\<schema>.<name>.sql
                         the text of every procedure, function, view and trigger (OBJECT_DEFINITION)
    columns.txt          tables and columns (type, length, precision, scale, nullable, identity,
                         computed, default constraint)
    keys.txt             primary and unique keys with their columns
    foreign-keys.txt     foreign keys with their columns and actions
    constraints.txt      check and default constraints with their definitions
    indexes.txt          indexes with key and included columns, filter, unique, disabled
    parameters.txt       parameters of procedures and functions
    installed-steps.txt  the output of Database/BMMS-Check-InstalledSteps.sql (read only)
  It reads no row values of any table (the read-only Check script outputs row counts only). It
  runs only SELECT statements and that Check script, and it compares a fingerprint of the database
  (object count, latest modify_date, sum of the modules' text lengths) before and after, and
  fails when they differ.

  The catalog holds the texts of the procedures as installed, among them spr_sys_ResetDatabase
  with the seed users' password hashes and salts. Keep the folder on this machine; delete the
  older catalog folder after the next export (Documents/Audit/README.md).

  Refuses:
  - any database other than BMMS_Test (exact name);
  - an output folder inside the repository working tree (it would show in git status);
  - an output folder that already exists (unless -Replace).

  Usage (from the repository root; -Server and -Database are mandatory):
    pwsh -NoProfile -File Documents/_build/Export-Catalog.ps1 -Server .\SQLEXPRESS -Database BMMS_Test -Replace
  Exit code 0 when the catalog was written, 1 when refused or failed.
#>
[CmdletBinding()]
param(
    # Both always given explicitly (owner, DA1 gate B): no default instance or database
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][string]$Database,
    [string]$OutRoot = (Join-Path $env:LOCALAPPDATA 'BMMS-Audit'),
    [switch]$Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'DocTools.ps1')

function Stop-Catalog([string]$msg) { Write-Output "Catalog export refused: $msg"; exit 1 }

$repo = Get-DocRepoRoot

if ($Database -cne 'BMMS_Test') { Stop-Catalog "only the database BMMS_Test is exported (asked: $Database). Nothing was read or written." }
if (-not $OutRoot) { Stop-Catalog 'no output folder (LOCALAPPDATA is not set); pass -OutRoot.' }

$sha = (& git -C $repo rev-parse --short HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $sha) { Stop-Catalog 'git rev-parse --short HEAD failed.' }
$sha = ([string]$sha).Trim()
$stamp = Get-Date
$out = [IO.Path]::GetFullPath((Join-Path $OutRoot ('catalog-' + $stamp.ToString('yyyyMMdd') + '-' + $sha)))

if ((Test-DocUnder $out $repo) -or ([IO.Path]::GetFullPath($out).TrimEnd('\') -ieq $repo.TrimEnd('\'))) {
    Stop-Catalog "the output folder is inside the repository working tree ($out). Use a folder outside it."
}
if (Test-Path -LiteralPath $out) {
    if (-not $Replace) { Stop-Catalog "the folder exists already: $out (pass -Replace to write it again)." }
    Remove-Item -LiteralPath $out -Recurse -Force
}

$sqlcmd = (Get-Command sqlcmd -ErrorAction SilentlyContinue)
if (-not $sqlcmd) { Stop-Catalog 'sqlcmd was not found.' }

# One read-only query; returns the output lines. -b stops on an error, -C trusts the local certificate.
function Invoke-CatalogQuery([string]$Query, [switch]$Raw) {
    $qa = @('-S', $Server, '-E', '-C', '-b', '-d', $Database)
    # -y 0: a text column of any length, unpadded (sqlcmd refuses -h -1 with it); its header lines are blank
    if ($Raw) { $qa += @('-y', '0') } else { $qa += @('-W', '-s', '|') }
    $qa += @('-Q', "SET NOCOUNT ON; $Query")
    $o = & $sqlcmd.Source @qa 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed: $(($o | Select-Object -First 3) -join ' ')" }
    , @($o | ForEach-Object { [string]$_ })
}

# One value: the first line after the header and its dashes (tabular output)
function Get-CatalogScalar([string]$Query) {
    $o = Invoke-CatalogQuery "SELECT ($Query) AS V"
    $i = 0; while ($i -lt $o.Count -and $o[$i] -notmatch '^-+\s*$') { $i++ }
    if ($i + 1 -ge $o.Count) { throw "no value returned for: $Query" }
    $o[$i + 1].Trim()
}

function Write-CatalogFile([string]$Name, [string[]]$Lines) {
    $text = (($Lines | ForEach-Object { $_.Replace("`r", '').TrimEnd() }) -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $out $Name), $text, [Text.UTF8Encoding]::new($false))
}

$fingerprintQuery = "SELECT CAST(COUNT(*) AS VARCHAR(12)) + '|' + CONVERT(VARCHAR(23), MAX(o.modify_date), 121) + '|' " +
                    "+ CAST((SELECT SUM(CAST(LEN(m.definition) AS BIGINT)) FROM sys.sql_modules m) AS VARCHAR(20)) " +
                    "FROM sys.objects o WHERE o.is_ms_shipped = 0"

try {
    # The database must be named exactly BMMS_Test (a guard against a mistyped -Server pointing elsewhere)
    $dbName = Get-CatalogScalar 'DB_NAME()'
    if ($dbName -cne 'BMMS_Test') { Stop-Catalog "connected to '$dbName', not BMMS_Test. Nothing was written." }
    $before = Get-CatalogScalar $fingerprintQuery

    New-Item -ItemType Directory -Path $out | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $out 'modules') | Out-Null

    $info = Invoke-CatalogQuery @"
SELECT 'Export' AS Item, CONVERT(VARCHAR(19), GETDATE(), 120) AS Value
UNION ALL SELECT 'Server', CAST(SERVERPROPERTY('ServerName') AS VARCHAR(200))
UNION ALL SELECT 'Database', DB_NAME()
UNION ALL SELECT 'ProductVersion', CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50))
UNION ALL SELECT 'ProductLevel', CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50))
UNION ALL SELECT 'Edition', CAST(SERVERPROPERTY('Edition') AS VARCHAR(200))
UNION ALL SELECT 'CompatibilityLevel', CAST(compatibility_level AS VARCHAR(10)) FROM sys.databases WHERE name = DB_NAME()
UNION ALL SELECT 'Objects ' + type_desc, CAST(COUNT(*) AS VARCHAR(12)) FROM sys.objects WHERE is_ms_shipped = 0 GROUP BY type_desc
"@
    Write-CatalogFile 'catalog.txt' (@("Repository commit: $sha", "Catalog folder: $out", '') + $info)

    $mods = Invoke-CatalogQuery @"
SELECT SCHEMA_NAME(o.schema_id) + '.' + o.name AS Name, o.type_desc
FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.is_ms_shipped = 0 ORDER BY 1
"@
    $count = 0
    foreach ($row in ($mods | Select-Object -Skip 2)) {
        if ($row -notmatch '^([A-Za-z0-9_]+)\.([A-Za-z0-9_#$@]+)\|') { continue }
        $schema = $Matches[1]; $name = $Matches[2]
        $lines = Invoke-CatalogQuery -Raw "SELECT OBJECT_DEFINITION(OBJECT_ID(N'[$schema].[$name]'))"
        # sqlcmd pads the output; leading and trailing empty lines of the output are dropped
        $start = 0; while ($start -lt $lines.Count -and $lines[$start].Trim() -eq '') { $start++ }
        $end = $lines.Count - 1; while ($end -ge $start -and $lines[$end].Trim() -eq '') { $end-- }
        $body = if ($end -ge $start) { $lines[$start..$end] } else { @() }
        Write-CatalogFile ("modules\$schema.$name.sql") $body
        $count++
    }

    Write-CatalogFile 'columns.txt' (Invoke-CatalogQuery @"
SELECT SCHEMA_NAME(t.schema_id) + '.' + t.name AS TableName, c.column_id, c.name AS ColumnName, ty.name AS TypeName,
       c.max_length, c.precision, c.scale, c.is_nullable, c.is_identity, c.is_computed,
       ISNULL(dc.name, '') AS DefaultName
FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
WHERE t.is_ms_shipped = 0 ORDER BY 1, 2
"@)

    Write-CatalogFile 'keys.txt' (Invoke-CatalogQuery @"
SELECT OBJECT_SCHEMA_NAME(k.parent_object_id) + '.' + OBJECT_NAME(k.parent_object_id) AS TableName, k.name AS KeyName, k.type_desc,
       ic.key_ordinal, COL_NAME(ic.object_id, ic.column_id) AS ColumnName
FROM sys.key_constraints k JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
ORDER BY 1, 2, 4
"@)

    Write-CatalogFile 'foreign-keys.txt' (Invoke-CatalogQuery @"
SELECT OBJECT_SCHEMA_NAME(f.parent_object_id) + '.' + OBJECT_NAME(f.parent_object_id) AS TableName, f.name AS KeyName,
       fc.constraint_column_id, COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName,
       OBJECT_SCHEMA_NAME(f.referenced_object_id) + '.' + OBJECT_NAME(f.referenced_object_id) AS RefTable,
       COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS RefColumn,
       f.delete_referential_action_desc, f.update_referential_action_desc, f.is_disabled, f.is_not_trusted
FROM sys.foreign_keys f JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = f.object_id
ORDER BY 1, 2, 3
"@)

    Write-CatalogFile 'constraints.txt' (Invoke-CatalogQuery @"
SELECT 'CHECK' AS Kind, OBJECT_SCHEMA_NAME(c.parent_object_id) + '.' + OBJECT_NAME(c.parent_object_id) AS TableName, c.name,
       ISNULL(COL_NAME(c.parent_object_id, c.parent_column_id), '') AS ColumnName, REPLACE(REPLACE(c.definition, CHAR(13), ' '), CHAR(10), ' ') AS Definition
FROM sys.check_constraints c
UNION ALL
SELECT 'DEFAULT', OBJECT_SCHEMA_NAME(d.parent_object_id) + '.' + OBJECT_NAME(d.parent_object_id), d.name,
       COL_NAME(d.parent_object_id, d.parent_column_id), REPLACE(REPLACE(d.definition, CHAR(13), ' '), CHAR(10), ' ')
FROM sys.default_constraints d
ORDER BY 1, 2, 3
"@)

    Write-CatalogFile 'indexes.txt' (Invoke-CatalogQuery @"
SELECT OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS TableName, i.name AS IndexName, i.type_desc,
       i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.has_filter, ISNULL(i.filter_definition, '') AS FilterDefinition,
       ic.key_ordinal, ic.is_included_column, ic.is_descending_key, COL_NAME(ic.object_id, ic.column_id) AS ColumnName
FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.objects o ON o.object_id = i.object_id
WHERE o.is_ms_shipped = 0 AND o.type = 'U' AND i.name IS NOT NULL
ORDER BY 1, 2, ic.is_included_column, ic.key_ordinal, ic.index_column_id
"@)

    Write-CatalogFile 'parameters.txt' (Invoke-CatalogQuery @"
SELECT OBJECT_SCHEMA_NAME(p.object_id) + '.' + OBJECT_NAME(p.object_id) AS ObjectName, o.type_desc, p.parameter_id,
       p.name AS ParameterName, TYPE_NAME(p.user_type_id) AS TypeName, p.max_length, p.precision, p.scale, p.is_output, p.has_default_value
FROM sys.parameters p JOIN sys.objects o ON o.object_id = p.object_id
WHERE o.is_ms_shipped = 0 ORDER BY 1, 3
"@)

    $checkScript = Join-Path $repo 'Database\BMMS-Check-InstalledSteps.sql'
    $steps = & $sqlcmd.Source -S $Server -E -C -I -b -d $Database -W -s '|' -i $checkScript 2>&1
    if ($LASTEXITCODE -ne 0) { throw "BMMS-Check-InstalledSteps.sql failed: $(($steps | Select-Object -First 3) -join ' ')" }
    Write-CatalogFile 'installed-steps.txt' @($steps | ForEach-Object { [string]$_ })

    $after = Get-CatalogScalar $fingerprintQuery
    if ($after -ne $before) { throw "the database changed during the export (fingerprint $before, now $after)" }

    Write-Output "Catalog written: $out"
    Write-Output "  $count module texts; columns, keys, foreign keys, constraints, indexes, parameters, installed steps."
    Write-Output "  Database fingerprint before and after: $before (unchanged: no schema change during the export; only SELECT statements were run)."
    exit 0
} catch {
    Write-Output "Catalog export failed: $($_.Exception.Message)"
    exit 1
}
