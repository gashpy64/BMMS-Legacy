#Requires -Version 7
<#
  Update-Baseline.ps1 - brings the tester's baseline up to date after a new database step (WF3a1).

  Run by the owner (or by the main Claude session on the owner's approval of the step's build).
  The tester agent cannot run it. Everything it does on the server it does as bmms_tester, the
  login that owns BMMS_Quality and has no access to any other database: a Fix script that tried
  to work on another database would be refused by the server. The owner's Windows login
  (sysadmin) is not used.

      pwsh -NoProfile -File Tests\_runner\Update-Baseline.ps1 -ConfirmDatabase BMMS_Quality -FixScript BMMS-Fix-Something-Step42.sql
      (several scripts: -FixScript a.sql,b.sql - they run in the order given)

  When: a step adds a Fix script (step 42 and on). From then the repository's Check script has
  a row that reads Missing on the baseline, and Run-Tests.ps1 refuses with "out of date".

  What it does, on BMMS_Quality only (the name is fixed in Tester.Common.ps1):
    1. Restores the present baseline and sets the fixture dates.
    2. Runs each Fix script named. Only a file named BMMS-Fix-<name>.sql in the repository's
       Database folder is accepted, and not one that changes database (USE), connects elsewhere
       or runs another file or a program (sqlcmd :connect, :r, !!). The script's own connection
       must still be on BMMS_Quality when it ends. Before anything runs, bmms_tester is asked
       which databases it can open: any besides BMMS_Quality (and the system databases) stops it.
    3. Runs the fixture check: the new step must leave the fixture data intact.
    4. Runs the Check script: every row must now read Installed.
    5. Takes the baseline backup again (the same file) and updates Tests\local\baseline.json.
  If any of 2 to 4 fails, the old baseline file is left as it was and is restored once more, so
  BMMS_Quality is back where it started.

  A change to the fixture itself (new accounts or data states) is not done here: run
  Setup-Quality.ps1 again, which clears BMMS_Quality and builds the fixture afresh.
#>
param(
    [Parameter(Mandatory)][string]$ConfirmDatabase,
    [Parameter(Mandatory)][string]$FixScript
)
. (Join-Path $PSScriptRoot 'Tester.Common.ps1')

$exitCode = 0
$restored = $false
try {
    if ($ConfirmDatabase -cne $QaDatabase) { Stop-Qa "-ConfirmDatabase must be exactly $QaDatabase. Nothing was done." }
    $scripts = @()
    foreach ($name in ($FixScript -split ',')) {
        $n = $name.Trim()
        if ($n -cnotmatch '^BMMS-Fix-[A-Za-z0-9-]+\.sql$') { Stop-Qa "'$n' is not a Fix script name (BMMS-Fix-<name>.sql). Nothing was done." }
        $path = Join-Path $QaRepo "Database\$n"
        if (-not (Test-Path -LiteralPath $path)) { Stop-Qa "Database\$n does not exist. Nothing was done." }
        $text = Get-Content -LiteralPath $path -Raw
        # A USE statement (a line, or the part after a semicolon, that is USE and one name: not a comment
        # line that begins with the word "use" or "used"), or a sqlcmd command at the start of a line.
        # This scan is a second layer; the wall is that bmms_tester can open no other database.
        if ($text -match '(?im)(^|;)[ \t]*USE[ \t]*\[?[A-Za-z_][A-Za-z0-9_$#@]*\]?[ \t]*(;|\r?$)' -or
            $text -match '(?im)^[ \t]*:[ \t]*(!!|(connect|r|ed|out|error|perftrace|serverlist|list|listvar|setvar|on|exit|quit|xml|help|reset)\b)' -or
            $text -match '(?im)^[ \t]*!!') {
            Stop-Qa "Database\$n changes database (USE) or uses a sqlcmd command (:connect, :r, !!). This script cannot run it. Nothing was done."
        }
        $scripts += $path
    }
    $baseline = Get-QaBaselineInfo
    $null = Get-QaCredentials
    Assert-QaDatabase -As Tester
    Assert-QaFixtureUnchanged $baseline
    Assert-QaLoginsReach

    Write-QaStep "1. $QaDatabase restored from the present baseline"
    Stop-QaSite
    Restore-QaBaseline -As Tester
    $restored = $true
    $null = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureDatesScript

    Write-QaStep '2. Fix scripts'
    foreach ($s in $scripts) {
        Write-Host "     $(Split-Path -Leaf $s)"
        # The script runs through a wrapper, so the same connection is asked where it is at the end.
        $wrapper = Join-Path $QaLocalDir ('fix-' + [guid]::NewGuid().ToString('N') + '.sql')
        try {
            @(":r `"$s`"", 'GO', "IF (DB_NAME() COLLATE Latin1_General_BIN <> N'BMMS_Quality') RAISERROR('The Fix script left BMMS_Quality.', 16, 1); ELSE PRINT 'STILL ON BMMS_Quality';") | Set-Content -LiteralPath $wrapper -Encoding ascii
            $r = Invoke-QaSqlcmd -As Tester -InputFile $wrapper
        } finally { Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue }
        if (-not ($r.Lines -match 'STILL ON BMMS_Quality')) { throw "After $(Split-Path -Leaf $s) the connection was not shown to be on $QaDatabase." }
        $r.Lines | Where-Object { $_.Trim() } | Select-Object -Last 3 | ForEach-Object { Write-Host "       $_" }
    }

    Write-QaStep '3. Fixture check'
    $r = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureCheckScript
    $pass = ($r.Lines | Where-Object { $_ -match '^FIXTURE CHECK: PASS' } | Select-Object -First 1)
    if (-not $pass) { throw 'The fixture check did not pass after the Fix script(s).' }
    Write-Host "     $pass"

    Write-QaStep '4. Steps installed'
    $steps = Assert-QaStepsInstalled -As Tester -What "$QaDatabase after the Fix script(s)"
    Write-Host "     $($steps.Rows.Count) step rows, all Installed."

    # Step WF3a2: the two logins are asked again after the Fix scripts, before the backup keeps their state.
    Write-QaStep '5. Logins checked again, baseline backup taken again'
    Assert-QaLoginsReach
    $null = Invoke-QaSqlcmd -As Tester -Query "SET NOCOUNT ON; IF (DB_NAME() COLLATE Latin1_General_BIN <> N'BMMS_Quality') BEGIN RAISERROR('Not on BMMS_Quality.', 16, 1); RETURN; END; BACKUP DATABASE [BMMS_Quality] TO DISK = N'$($baseline.backupPath)' WITH INIT, CHECKSUM, NAME = N'BMMS_Quality tester baseline';"
    [ordered]@{
        takenOn            = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        backupPath         = $baseline.backupPath
        stepRows           = $steps.Rows.Count
        lastStep           = ($steps.Rows | Where-Object { $_.Step -lt 100 } | Sort-Object Step | Select-Object -Last 1).Step
        fixtureSha256      = (Get-QaFileHash $QaFixtureScript)
        fixtureCheckSha256 = (Get-QaFileHash $QaFixtureCheckScript)
        fixtureDatesSha256 = (Get-QaFileHash $QaFixtureDatesScript)
        gitCommit          = "$(& git -C $QaRepo rev-parse --short HEAD 2>$null)"
    } | ConvertTo-Json | Set-Content -LiteralPath $QaBaselineInfo -Encoding utf8
    Protect-QaLocalDir
    $restored = $false

    Write-Host ''
    Write-Host 'BASELINE UPDATED. Changed on the SQL Server:'
    Write-Host "  1. $QaDatabase restored from the old baseline (open connections to it were closed)."
    Write-Host ('  2. Run on it: ' + (($scripts | ForEach-Object { Split-Path -Leaf $_ }) -join ', ') + '.')
    Write-Host "  3. Baseline backup replaced: $($baseline.backupPath)"
    Write-Host 'Not touched: every other database.'
}
catch {
    Write-Host ''
    if ($_.Exception.GetType().Name -eq 'QaRefusal') { Write-Host "REFUSED: $($_.Exception.Message)"; $exitCode = 2 }
    else { Write-Host "UPDATE FAILED: $($_.Exception.Message)"; $exitCode = 1 }
    if ($restored) {
        try { Restore-QaBaseline -As Tester; Write-Host "The old baseline file was not replaced; $QaDatabase was restored from it again." }
        catch { Write-Host "The old baseline file was not replaced, but $QaDatabase could not be restored from it again: $($_.Exception.Message)" }
    }
}
exit $exitCode
