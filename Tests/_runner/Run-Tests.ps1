#Requires -Version 7
<#
  Run-Tests.ps1 - one run of the BMMS tester (step WF3a1).

      pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -CheckOnly
      pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack selftest
      pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack access-matrix,other-pack

  For the owner, to look at the fixture by hand (the tester agent cannot use these two):
      ... -Pack selftest -LeaveSiteRunning    the site copy is not stopped at the end; it stays on
                                              http://localhost:18573 until the next run or -StopSite
      ... -StopSite                           stops a site copy that was left running; nothing else

  Every run, in this order (a refusal stops the run before any test):
    1. Preflight: local credentials (readable by your account only), baseline record, the fixture
       script unchanged since the baseline, Node and its packages.
    2. Rebuilds and re-syncs the site copy Tests\_site from the working tree and proves it current.
    3. Proves the copy's connection string names BMMS_Quality (and only it).
    4. Restores BMMS_Quality from the baseline (as bmms_tester), sets the fixture dates, and checks
       that every step of the repository's Check script is installed and the fixture is intact.
    5. Starts the site copy on http://localhost:18573 (IIS Express).
    6. Signs in as the fixture's Admin and reads "Database: BMMS_Quality" in the footer.
    7. Runs the self-test, then the packs named (-CheckOnly: stops after step 6).
    8. Stops the site copy (unless -LeaveSiteRunning was given), collects the new log lines,
       writes the results:
       Tests\_results\<date_time>\results.md (for reading) and results.json.

  Exit codes: 0 passed; 1 one or more checks failed; 2 refused (nothing was tested);
  3 void (the self-test did not catch its planted failures, a pack broke off, or the browser part stopped); 4 the runner failed.

  It works on BMMS_Quality and on Tests\_site only; both names are fixed in Tester.Common.ps1.
  It changes no product file: it writes only under Tests\_results, Tests\_site and Tests\_build.
#>
param(
    [string]$Pack,
    [switch]$CheckOnly,
    [switch]$LeaveSiteRunning,
    [switch]$StopSite
)
. (Join-Path $PSScriptRoot 'Tester.Common.ps1')

$words = @{ opens = 'opens'; denied = 'Access denied'; notfound = 'Page not found'; signin = 'sent to the sign-in page'; error = 'the error page'; 'no-answer' = 'no answer' }
function Say([string]$kind) { if ($words.ContainsKey($kind)) { $words[$kind] } elseif ($kind -match '^http-([0-9]+)$') { "HTTP $($Matches[1]) (not expected)" } else { $kind } }
function Cell([object]$text) { ("$text" -replace '\|', '\|' -replace '[\r\n]+', ' ').Trim() }

function Prop([object]$o, [string]$name) { if ($null -ne $o -and $o.PSObject.Properties[$name]) { $o.PSObject.Properties[$name].Value } else { $null } }

if ($StopSite) {
    if ($Pack -or $CheckOnly -or $LeaveSiteRunning) { Write-Host 'REFUSED: -StopSite is used alone. Nothing was done.'; exit 2 }
    $was = @(Get-QaSiteProcesses).Count
    Stop-QaSite
    if ($was -gt 0) { Write-Host "The site copy on $QaBaseUrl was stopped." } else { Write-Host "No site copy was running on $QaBaseUrl. Nothing was done." }
    exit 0
}

$siteLeft = $false
$started = Get-Date
$runId =$started.ToString('yyyy-MM-dd_HHmmss')
$dir = Join-Path $QaResultsRoot $runId
$run = [ordered]@{
    runId = $runId; startedAt = $started.ToString('yyyy-MM-dd HH:mm:ss'); finishedAt = $null; seconds = 0
    result = 'REFUSED'; summary = ''; mode = $(if ($CheckOnly) { 'check only' } else { 'packs' }); packsAsked = @()
    database = $QaDatabase; site = $QaBaseUrl; siteFolder = 'Tests\_site'
    build = $null; baseline = $null; steps = $null; fixtureCheck = $null
    proofs = [ordered]@{ connectionString = $false; process = $false; footer = '' }
    browser = ''; packs = @(); counts = $null; newAccessLogLines = 0; newErrorLogLines = 0; blockedRequests = 0
}
$checks = @(); $accessNew = @(); $errorNew = @(); $blocked = @()
$exitCode = 2
$logMarks = @{}

try {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    # ----- which packs ------------------------------------------------------------------------
    $packs = @()
    if ($Pack) {
        foreach ($p in ($Pack -split ',')) {
            if ($p -cnotmatch '^[a-z0-9][a-z0-9-]*$') { Stop-Qa "Pack names are lower-case letters, digits and hyphens and start with a letter or digit: '$p'." }
            if (-not (Test-Path -LiteralPath (Join-Path $QaTests "packs\$p\pack.js"))) { Stop-Qa "There is no pack '$p' in Tests\packs." }
            if ($p -ne 'selftest' -and $packs -notcontains $p) { $packs += $p }
        }
    } elseif (-not $CheckOnly) { Stop-Qa 'Give -Pack <name> (several: a,b) or -CheckOnly.' }
    $run.packsAsked = @($packs)

    # ----- 1. preflight -----------------------------------------------------------------------
    Write-QaStep '1. Preflight'
    $null = Get-QaCredentials
    $baseline = Get-QaBaselineInfo
    Assert-QaFixtureUnchanged $baseline
    Assert-QaLoginsReach
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Stop-Qa 'Node.js was not found.' }
    if (-not (Test-Path -LiteralPath (Join-Path $QaTests 'node_modules\playwright-core\package.json'))) { Stop-Qa 'The Node packages are missing: run "npm ci" in the Tests folder (see Tests\README.md).' }
    $run.baseline = [ordered]@{ takenOn = $baseline.takenOn; lastStep = $baseline.lastStep; gitCommit = $baseline.gitCommit }

    # ----- 2. and 3. the site copy ------------------------------------------------------------
    Write-QaStep '2. Site copy: build and sync from the working tree'
    Stop-QaSite
    Sync-QaSite
    $run.build = Get-QaBuildMarker
    Write-QaStep '3. Connection string of the site copy'
    Assert-QaSiteConnection
    $run.proofs.connectionString = $true

    # ----- 4. the database --------------------------------------------------------------------
    Write-QaStep "4. $QaDatabase restored from the baseline (open connections to it are closed)"
    Restore-QaBaseline -As Tester
    $null = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureDatesScript
    $steps = Assert-QaStepsInstalled -As Tester -What 'The baseline'
    $steps.Rows | ForEach-Object { "{0,3} {1,-50} {2,-10} {3}" -f $_.Step, $_.Script, $_.Status, $_.Detail } | Set-Content -LiteralPath (Join-Path $dir 'installed-steps.txt')
    $run.steps = [ordered]@{ rows = $steps.Rows.Count; allInstalled = $true; lastStep = ($steps.Rows | Where-Object { $_.Step -lt 100 } | Sort-Object Step | Select-Object -Last 1).Step; history = $steps.History }
    $fc = Invoke-QaSqlcmd -As Tester -InputFile $QaFixtureCheckScript -NoThrow
    $fcLine = ($fc.Lines | Where-Object { $_ -match 'FIXTURE CHECK:' } | Select-Object -First 1)
    $fc.Lines | Set-Content -LiteralPath (Join-Path $dir 'fixture-check.txt')
    if ($fc.ExitCode -ne 0 -or "$fcLine" -notmatch '^FIXTURE CHECK: PASS') {
        Stop-Qa "The fixture check failed after the restore ($fcLine). See fixture-check.txt in the results folder."
    }
    $run.fixtureCheck = "$fcLine".Trim()

    # ----- 5. start ---------------------------------------------------------------------------
    Write-QaStep "5. Site copy started on $QaBaseUrl"
    $accessLog = Join-Path $QaSiteDir 'App_Data\PageAccessLog.txt'
    $logMarks[$accessLog] = $(if (Test-Path -LiteralPath $accessLog) { (Get-Item -LiteralPath $accessLog).Length } else { 0 })
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $QaSiteDir 'Log') -File -ErrorAction SilentlyContinue)) { $logMarks[$f.FullName] = $f.Length }
    $null = Start-QaSite
    $run.proofs.process = $true

    # ----- 6. and 7. the browser --------------------------------------------------------------
    Write-QaStep $(if ($CheckOnly) { '6. Database proof in the browser' } else { '6. Database proof, 7. self-test and packs: ' + ((@('selftest') + $packs) -join ', ') })
    $nodeArgs = @((Join-Path $QaTests 'lib\run.js'), '--results', $dir)
    if ($CheckOnly) { $nodeArgs += '--proof-only' } else { foreach ($p in (@('selftest') + $packs)) { $nodeArgs += @('--pack', $p) } }
    $env:QA_BASE_URL = $QaBaseUrl; $env:QA_SITE_DIR = $QaSiteDir
    Push-Location $QaTests
    try { & node @nodeArgs 2>&1 | ForEach-Object { Write-Host "     $_" }; $nodeExit = $LASTEXITCODE }
    finally { Pop-Location; Remove-Item Env:QA_BASE_URL, Env:QA_SITE_DIR -ErrorAction SilentlyContinue }

    # ----- 8. collect -------------------------------------------------------------------------
    if ($LeaveSiteRunning -and @(Get-QaSiteProcesses).Count -eq 1) { $siteLeft = $true; Write-QaStep "8. Site copy left running on $QaBaseUrl (-LeaveSiteRunning); results" }
    else { Write-QaStep '8. Site copy stopped; results'; Stop-QaSite }
    function Read-NewLines([string]$file, [long]$from) {
        if (-not (Test-Path -LiteralPath $file)) { return @() }
        $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
        try { if ($fs.Length -le $from) { return @() }; $null = $fs.Seek($from, 'Begin'); $sr = [IO.StreamReader]::new($fs); return @($sr.ReadToEnd() -split "`r?`n" | Where-Object { $_.Trim() }) }
        finally { $fs.Dispose() }
    }
    $accessNew = @(Read-NewLines $accessLog $logMarks[$accessLog])
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $QaSiteDir 'Log') -File -ErrorAction SilentlyContinue)) {
        $from = $(if ($logMarks.ContainsKey($f.FullName)) { $logMarks[$f.FullName] } else { 0 })
        $errorNew += @(Read-NewLines $f.FullName $from)
    }
    if ($accessNew.Count -gt 0) { $accessNew | Set-Content -LiteralPath (Join-Path $dir 'page-access-log-new.txt') }
    if ($errorNew.Count -gt 0) { $errorNew | Set-Content -LiteralPath (Join-Path $dir 'error-log-new.txt') }
    $run.newAccessLogLines = $accessNew.Count; $run.newErrorLogLines = $errorNew.Count

    $checksFile = Join-Path $dir 'checks.json'
    if (-not (Test-Path -LiteralPath $checksFile)) { throw "The browser part wrote no checks.json (exit $nodeExit)." }
    $c = Get-Content -LiteralPath $checksFile -Raw | ConvertFrom-Json
    $checks = @($c.checks); $blocked = @($c.blockedRequests)
    $run.browser = "$(Prop $c 'browser')";$run.packs = @($c.packs); $run.blockedRequests = $blocked.Count
    if ($c.proof) { $run.proofs.footer = "$($c.proof.footerDatabase)"; $run.proofs['signedInAs'] = "$($c.proof.signedInAs)"; $run.proofs['productFooter'] = "$($c.proof.footer)" }

    $real = @($checks | Where-Object { -not $_.planted })
    $planted = @($checks | Where-Object { $_.planted })
    $failed = @($real | Where-Object { -not $_.pass })
    $missed = @($planted | Where-Object { $_.pass })
    $broken = @($run.packs | Where-Object { $_.error })
    $run.counts = [ordered]@{ checks = $real.Count; passed = $real.Count - $failed.Count; failed = $failed.Count; planted = $planted.Count; plantedCaught = $planted.Count - $missed.Count }

    if ($c.fatal) {
        if ("$($c.fatal)" -match 'does not show "Database:') { $run.result = 'REFUSED'; $exitCode = 2; $run.summary = "$($c.fatal) Nothing was tested." }
        else { $run.result = 'VOID'; $exitCode = 3; $run.summary = "The run does not count: the browser part stopped ($($c.fatal))." }
    }
    elseif ($CheckOnly) {
        $run.result = 'READY'; $exitCode = 0
        $run.summary = "Check only: the site copy runs the current working tree on $QaDatabase, the baseline is current and the fixture is intact. No pack was run."
    }
    elseif ($planted.Count -lt 3 -or $missed.Count -gt 0) {
        $run.result = 'VOID'; $exitCode = 3
        $run.summary = "The self-test did not run or did not catch all 3 planted wrong expectations ($($planted.Count - $missed.Count) caught). The tester cannot be trusted in this run; no result counts."
    }
    elseif ($broken.Count -gt 0) {
        $run.result = 'VOID'; $exitCode = 3
        $run.summary = "A pack broke off before it finished: " + (($broken | ForEach-Object { "$($_.name) ($($_.error))" }) -join '; ') + '. The checks it did not reach are missing, so the run does not count.'
    }
    elseif ($failed.Count -gt 0 -or $errorNew.Count -gt 0 -or $blocked.Count -gt 0) {
        $run.result = 'FAILED'; $exitCode = 1
        $parts = @()
        if ($failed.Count -gt 0) { $parts += "$($failed.Count) of $($real.Count) checks failed" }
        if ($errorNew.Count -gt 0) { $parts += "the error log has $($errorNew.Count) new line(s)" }
        if ($blocked.Count -gt 0) { $parts += "$($blocked.Count) request(s) to a host other than localhost were stopped" }
        $run.summary = ($parts -join '; ') + '. See "Failed checks" and the log section below. The self-test caught its 3 planted wrong expectations.'
    }
    else {
        $run.result = 'PASSED'; $exitCode = 0
        $run.summary = "All $($real.Count) checks passed. The self-test caught its 3 planted wrong expectations. No new line in the error log."
    }
}
catch {
    if ($_.Exception.GetType().Name -eq 'QaRefusal') {
        $run.result = 'REFUSED'; $exitCode = 2
        $run.summary = $_.Exception.Message + $(if ($_.Exception.Message -match 'No test was run|Nothing was tested') { '' } else { ' Nothing was tested.' })
    }
    else { $run.result = 'RUNNER FAILED'; $exitCode = 4; $run.summary = "The tester itself failed ($($_.Exception.Message)). Nothing can be said about the site; the run does not count. Tell Claude." }
}
finally {
    if (-not $siteLeft) { try { Stop-QaSite } catch { } }
}

# ----- results.md and results.json --------------------------------------------------------------
$finished = Get-Date
$run.finishedAt = $finished.ToString('yyyy-MM-dd HH:mm:ss'); $run.seconds = [int]($finished - $started).TotalSeconds
try {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $md = [System.Collections.Generic.List[string]]::new()
    $md.Add("# BMMS tester run $($run.startedAt)"); $md.Add('')
    $md.Add("**Result: $($run.result).** $($run.summary)"); $md.Add('')
    $md.Add('What the result words mean: PASSED = every check gave what was expected; FAILED = at least one did not (listed below); REFUSED = the tester would not start, nothing was tested; VOID = the run does not count; RUNNER FAILED = the tester itself broke, the run does not count; READY = check only, no pack run.'); $md.Add('')

    $tested = $run.result -in 'PASSED', 'FAILED', 'READY'
    $heading = $(if ($tested) { '## What was tested' } elseif ($run.result -eq 'VOID') { '## Where the tester worked (the run does not count)' } else { '## Where the tester worked (nothing was tested in this run)' })
    $md.Add($heading); $md.Add('')
    $md.Add("- Site: the copy of the working tree in ``Tests\_site``, on $QaBaseUrl. Your own site and BMMS_Test are never used.")
    if ($siteLeft) {
        $md.Add("- **The site copy was left running** on $QaBaseUrl because the run was started with ``-LeaveSiteRunning``. Sign in there with a ``qa_`` account, for example ``qa_admin`` (the passwords are in ``Tests\local\credentials.json``). It shows $QaDatabase as restored for this run; whatever you change there is gone at the next run. To stop it: ``pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -StopSite`` (the next tester run stops it too).")
    }
    if ($run.build) {
        $mod = $(if ($run.build.modifiedFiles -eq 0) { 'no uncommitted change' } else { "$($run.build.modifiedFiles) uncommitted file(s)" })
        $md.Add("- Build: version $($run.build.productVersion), built $($run.build.builtOn) from commit $($run.build.gitCommit) with $mod. BMMS.dll SHA-256 starts $($run.build.bmmsDllSha256.Substring(0, 12)).")
    }
    $md.Add("- Database: $QaDatabase. Proof 1, the site copy's connection string names it and signs in as $QaSiteLogin (a login that can open no other database; asked of the server before the run): $(if ($run.proofs.connectionString) { 'yes' } else { 'not reached (the run stopped before this)' }). Proof 2, the process on the test port is the one started from ``Tests\_site``: $(if ($run.proofs.process) { 'yes' } else { 'not reached (the run stopped before this)' }). Proof 3, the footer read in the browser: $(if ($run.proofs.footer) { '"' + $run.proofs.footer + '"' + $(if ($run.proofs.Contains('signedInAs')) { ' (signed in as ' + $run.proofs.signedInAs + ')' } else { '' }) } else { 'not reached (the run stopped before this)' }).")
    if ($run.baseline) { $md.Add("- Baseline: taken $($run.baseline.takenOn) (step $($run.baseline.lastStep)); restored at the start of this run.") }
    if ($run.steps) { $md.Add("- Steps in the database: $($run.steps.rows) rows of the Check script, all Installed (last step $($run.steps.lastStep)). $(if ("$($run.steps.history)" -match '^history rows (.*)$') { 'History check: rows ' + $Matches[1] } else { "History check: $($run.steps.history)" }).") }
    if ($run.fixtureCheck) { $md.Add("- Fixture: $($run.fixtureCheck).") }
    if ($run.browser) { $md.Add("- Browser: $($run.browser), window 1366 x 768.") }
    if (@($run.packs).Count -gt 0) { $md.Add('- Packs: ' + ((@($run.packs) | ForEach-Object { "$($_.name) ($($_.checks) checks, $($_.seconds) s)" }) -join '; ') + '.') }
    $md.Add("- Time: $($run.seconds) seconds in all."); $md.Add('')

    if ($checks.Count -eq 0 -and $run.result -notin 'READY', 'REFUSED') { $md.Add('## Checks'); $md.Add(''); $md.Add('No checks were recorded in this run.'); $md.Add('') }
    if ($checks.Count -gt 0) {
        $real = @($checks | Where-Object { -not $_.planted }); $failed = @($real | Where-Object { -not $_.pass }); $planted = @($checks | Where-Object { $_.planted })
        $md.Add('## Failed checks'); $md.Add('')
        if ($failed.Count -eq 0 -and $run.result -eq 'FAILED') { $md.Add("None. The result is FAILED because of the logs below (error log: $($errorNew.Count) new line(s); requests to other hosts: $($blocked.Count)).") }
        elseif ($failed.Count -eq 0) { $md.Add('None.') }
        else {
            $md.Add('| No | Pack | Check | Expected | Seen | Detail | Screenshot |'); $md.Add('|---|---|---|---|---|---|---|')
            foreach ($k in $failed) { $md.Add("| $($k.id) | $(Cell $k.pack) | $(Cell $k.title) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $(Cell $k.detail) | $(if ($k.screenshot) { "[$($k.screenshot -replace '^screenshots/', '')]($($k.screenshot))" } else { 'none taken' }) |") }
            $md.Add(''); $md.Add("The screenshots are in the folder ``screenshots`` beside this file (``Tests\_results\$runId\screenshots``); a file name starts with the number of its check.")
            $md.Add(''); $md.Add('A failed check is reported to the owner as it is. The tester changes neither the product nor an expected result.')
        }
        $md.Add('')
        $md.Add('## Self-test'); $md.Add('')
        $md.Add("The tester is given $($planted.Count) deliberately wrong expectations in every run. Each must come out as a failure; that shows the tester can tell a failure from a pass."); $md.Add('')
        if ($planted.Count -gt 0) {
            $md.Add('| No | Asked for | Wrong expectation given | Really seen | Caught |'); $md.Add('|---|---|---|---|---|')
            foreach ($k in $planted) { $md.Add("| $($k.id) | $(Cell $k.role) asks for $(Cell $k.address) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $(if ($k.pass) { 'NO - the run is void' } else { 'yes' }) |") }
            $md.Add(''); $md.Add('These rows are not failures. In "All checks" they read "caught (planted)".'); $md.Add('')
        }
    }

    $md.Add('## New lines in the logs of the site copy'); $md.Add('')
    $md.Add('A refusal ("Access denied") writes a DENIED line to the page access log, so new DENIED lines are normal for checks that expect a refusal. The self-test adds two for Master/User.aspx (its control and its planted check).'); $md.Add('')
    $md.Add("- Page access log (``Tests\_site\App_Data\PageAccessLog.txt``): $($accessNew.Count) new line(s)" + $(if ($accessNew.Count -gt 0) { ', all in `page-access-log-new.txt`:' } else { '.' }))
    if ($accessNew.Count -gt 0) { $md.Add(''); $md.Add('```'); foreach ($l in ($accessNew | Select-Object -First 40)) { $md.Add($l) }; if ($accessNew.Count -gt 40) { $md.Add("... and $($accessNew.Count - 40) more") }; $md.Add('```') }
    $md.Add("- Error log (``Tests\_site\Log``): $($errorNew.Count) new line(s)" + $(if ($errorNew.Count -gt 0) { ', all in `error-log-new.txt`. Every new line counts as a failure:' } else { '.' }))
    if ($errorNew.Count -gt 0) { $md.Add(''); $md.Add('```'); foreach ($l in ($errorNew | Select-Object -First 20)) { $md.Add($l.Substring(0, [Math]::Min(300, $l.Length))) }; if ($errorNew.Count -gt 20) { $md.Add("... and $($errorNew.Count - 20) more, see error-log-new.txt") }; $md.Add('```'); $md.Add('(Long lines are cut to 300 characters here; the file has them whole.)') }
    $md.Add("- Requests to a host other than localhost: $($blocked.Count)" + $(if ($blocked.Count -gt 0) { ' (stopped; each counts as a failure): ' + ((@($blocked) | Select-Object -First 5 | ForEach-Object { $_.url }) -join ', ') + $(if ($blocked.Count -gt 5) { " ... and $($blocked.Count - 5) more (see results.json)" } else { '' }) } else { '.' }))
    $md.Add('')

    if ($checks.Count -gt 0) {
        $md.Add('## All checks'); $md.Add('')
        $md.Add('| No | Pack | Check | Expected | Seen | Result |'); $md.Add('|---|---|---|---|---|---|')
        foreach ($k in $checks) {
            $res = $(if ($k.planted) { if ($k.pass) { 'NOT CAUGHT (planted)' } else { 'caught (planted)' } } elseif ($k.pass) { 'pass' } else { 'FAIL' })
            $md.Add("| $($k.id) | $(Cell $k.pack) | $(Cell $k.title) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $res |")
        }
        $md.Add('')
    }
    $md.Add('## What the tester does not judge'); $md.Add('')
    $md.Add('Looks (alignment, borders, spacing, colours, the printed page, a document opened in Word) stay with the owner, who reads the screenshots and exports. The tester is no security audit. It complements the owner''s tests; it does not replace them.')
    $md | Set-Content -LiteralPath (Join-Path $dir 'results.md') -Encoding utf8
    ([ordered]@{ run = $run; checks = $checks; blockedRequests = $blocked }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $dir 'results.json') -Encoding utf8
} catch {
    Write-Host "The results files could not be written: $($_.Exception.Message)"
    if ($exitCode -eq 0) { $exitCode = 4 }
}

Write-Host ''
Write-Host "RESULT: $($run.result). $($run.summary)"
Write-Host "Results: Tests\_results\$runId\results.md"
if ($siteLeft) { Write-Host "The site copy is still running on $QaBaseUrl. To stop it: pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -StopSite" }
if ($run.result -eq 'FAILED') { Write-Host "Screenshots: Tests\_results\$runId\screenshots" }
exit $exitCode
