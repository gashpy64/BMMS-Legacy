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

  With the access-matrix pack (step WF3a2), between 6 and 7: the standing proof. The runner adds one
  role to one entry of Tests\_site\XML\PageAccess.xml (planted.json of the pack; never the working
  tree's file), runs the proof rows, and puts the working tree's file back in a finally block. At the
  end of the run the hash of the site copy's PageAccess.xml must equal the working tree's.
  For the owner only (the tester agent cannot use it): -ProofFullMatrix runs every row of the matrix
  under the planted change (the one-time proof of the build); exactly one cell must fail there too.

  Every run checks that the site copy serves only callers on this machine (each network address, with the
  address and with "Host: localhost" as host name; anything but no connection, 400 or 403 refuses the run),
  and reads the firewall: a rule that lets inbound traffic in to port 18573, or a profile that is off, is a
  warning in the console and the report. -LeaveSiteRunning is refused only when a profile lets inbound
  traffic in by default. The runner changes no Windows rule.

  Exit codes: 0 passed; 1 one or more checks failed; 2 refused (nothing was tested);
  3 void (the self-test did not catch its planted failures, the access matrix's standing proof failed or
  PageAccess.xml of the site copy was not put back, a pack broke off, or the browser part stopped); 4 the runner failed.

  It works on BMMS_Quality and on Tests\_site only; both names are fixed in Tester.Common.ps1.
  It changes no product file: it writes only under Tests\_results, Tests\_site and Tests\_build.
#>
param(
    [string]$Pack,
    [switch]$CheckOnly,
    [switch]$LeaveSiteRunning,
    [switch]$StopSite,
    [switch]$ProofFullMatrix
)
. (Join-Path $PSScriptRoot 'Tester.Common.ps1')

$words = @{ opens = 'opens'; denied = 'Access denied'; notfound = 'Page not found'; signin = 'sent to the sign-in page'; error = 'the error page'; 'no-answer' = 'no answer'; decide = 'owner to decide'; remove = 'to be removed (RA1c1)'; pending = 'to be decided (RA1c2)'; 'not-opened' = 'not opened' }
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
$proofChecks = @(); $proofOthers = @(); $proof = $null
$exitCode = 2
$logMarks = @{}
$siteXml = Join-Path $QaSiteDir 'XML\PageAccess.xml'
$treeXml = Join-Path $QaRepo 'BMMS\XML\PageAccess.xml'

# Step WF3a2: the planted change of the standing proof, made in the site copy's PageAccess.xml only.
function Set-QaPlantedChange([object]$Def) {
    $full = [IO.Path]::GetFullPath($siteXml); $siteRoot = [IO.Path]::GetFullPath($QaSiteDir).TrimEnd('\') + '\'
    if (-not $full.StartsWith($siteRoot, [StringComparison]::OrdinalIgnoreCase) -or $full -ieq [IO.Path]::GetFullPath($treeXml) -or $siteRoot -ieq ([IO.Path]::GetFullPath((Join-Path $QaRepo 'BMMS')).TrimEnd('\') + '\')) { throw 'The planted change may be made in Tests\_site only, never in the working tree.' }
    if ("$($Def.page)" -notmatch '^[A-Za-z0-9/]+\.aspx$' -or "$($Def.addRole)" -notmatch '^[a-z_]+$') { throw 'planted.json names an unexpected page or role.' }
    $doc = [xml]::new(); $doc.PreserveWhitespace = $true; $doc.Load($siteXml)
    $node = @($doc.SelectNodes('/pageAccess/pages/page') | Where-Object { $_.GetAttribute('path') -ieq $Def.page })
    if ($node.Count -ne 1) { throw "planted.json names $($Def.page), which is not once in PageAccess.xml." }
    $roles = @($node[0].GetAttribute('roles') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($roles -contains $Def.addRole) { throw "PageAccess.xml already lets $($Def.addRole) open $($Def.page): the planted change would change nothing." }
    $node[0].SetAttribute('roles', (($roles + $Def.addRole) -join ','))
    $doc.Save($siteXml)
}

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
    $matrix = $packs -contains 'access-matrix'
    if ($ProofFullMatrix -and -not $matrix) { Stop-Qa '-ProofFullMatrix needs -Pack access-matrix.' }

    # ----- 1. preflight -----------------------------------------------------------------------
    Write-QaStep '1. Preflight'
    $null = Get-QaCredentials
    $baseline = Get-QaBaselineInfo
    Assert-QaFixtureUnchanged $baseline
    Assert-QaLoginsReach
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Stop-Qa 'Node.js was not found.' }
    if (-not (Test-Path -LiteralPath (Join-Path $QaTests 'node_modules\playwright-core\package.json'))) { Stop-Qa 'The Node packages are missing: run "npm ci" in the Tests folder (see Tests\README.md).' }
    $run.baseline = [ordered]@{ takenOn = $baseline.takenOn; lastStep = $baseline.lastStep; gitCommit = $baseline.gitCommit }
    # Owner decision 2026-11-11: firewall findings are warnings; only a profile that lets inbound traffic in by
    # default refuses -LeaveSiteRunning (the IP restriction is probed on every run, step 5).
    $openings = @(Get-QaFirewallOpenings)
    $run['firewallWarnings'] = @($openings | Where-Object { -not $_.Refuse } | ForEach-Object { $_.Text })
    $run['firewallRefusals'] = @($openings | Where-Object { $_.Refuse } | ForEach-Object { $_.Text })
    foreach ($w in $run.firewallWarnings) { Write-Host "     WARNING (firewall): $w. The site copy still serves only callers on this machine (checked at its start)." }
    foreach ($w in $run.firewallRefusals) { Write-Host "     WARNING (firewall): $w. This would refuse -LeaveSiteRunning. The site copy still serves only callers on this machine (checked at its start)." }
    if ($LeaveSiteRunning) {
        $hard = @($run.firewallRefusals)
        if ($hard.Count -gt 0) { Stop-Qa ("-LeaveSiteRunning is refused: " + ($hard -join '; ') + '. Run without -LeaveSiteRunning, or set that profile to block inbound traffic by default first (see Tests\README.md, "Limits").') }
    }

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
    # Step WF3a2: the two logins are asked again on the restored database (the check in step 1 saw the
    # database as the last run left it).
    Assert-QaLoginsReach
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
    $env:QA_BASE_URL = $QaBaseUrl; $env:QA_SITE_DIR = $QaSiteDir
    try {
        # Step WF3a2: the standing proof of the access matrix, before the real matrix.
        if ($matrix) {
            $plantedDef = Get-Content -LiteralPath (Join-Path $QaTests 'packs\access-matrix\planted.json') -Raw | ConvertFrom-Json
            $phase = $(if ($ProofFullMatrix) { 'planted-full' } else { 'planted' })
            Write-QaStep "6a. Database proof and the standing proof of the access matrix: $($plantedDef.addRole) added to $($plantedDef.page) in Tests\_site\XML\PageAccess.xml only ($(if ($ProofFullMatrix) { 'every row' } else { 'the proof rows' }))"
            try {
                Set-QaPlantedChange $plantedDef
                Start-Sleep -Milliseconds 1500   # the module reloads the policy when the file changes
                Push-Location $QaTests
                try { & node (Join-Path $QaTests 'lib\run.js') --results $dir --phase $phase --checks-file checks-planted.json --pack access-matrix 2>&1 | ForEach-Object { Write-Host "     $_" } }
                finally { Pop-Location }
            } finally {
                $putBack = $false
                for ($try = 1; $try -le 2 -and -not $putBack; $try++) {
                    try { Copy-Item -LiteralPath $treeXml -Destination $siteXml -Force -ErrorAction Stop; $putBack = $true } catch { Start-Sleep -Milliseconds 1000 }
                }
                if (-not $putBack) { Stop-QaSite; Write-QaStep 'The working tree''s PageAccess.xml could NOT be put back in the site copy; the site copy was stopped and the run will be VOID.' }
                Start-Sleep -Milliseconds 1500
            }
            if (-not $putBack) { throw [QaVoid]::new('the working tree''s PageAccess.xml could not be put back in the site copy (the site copy was stopped)') }
            Write-QaStep '6b. The working tree''s PageAccess.xml put back in the site copy'
        }
        Write-QaStep $(if ($CheckOnly) { '6. Database proof in the browser' } else { '6. Database proof, 7. self-test and packs: ' + ((@('selftest') + $packs) -join ', ') })
        $nodeArgs = @((Join-Path $QaTests 'lib\run.js'), '--results', $dir)
        if ($CheckOnly) { $nodeArgs += '--proof-only' } else { foreach ($p in (@('selftest') + $packs)) { $nodeArgs += @('--pack', $p) } }
        Push-Location $QaTests
        try { & node @nodeArgs 2>&1 | ForEach-Object { Write-Host "     $_" }; $nodeExit = $LASTEXITCODE }
        finally { Pop-Location }
    } finally { Remove-Item Env:QA_BASE_URL, Env:QA_SITE_DIR -ErrorAction SilentlyContinue }

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

    # Step WF3a2: the standing proof of the access matrix (its own checks file) and the put-back of PageAccess.xml.
    if ($matrix) {
        $proof = [ordered]@{ ran = $false; fatal = ''; plantedCells = 0; caught = $false; otherFailed = 0; cells = 0; xmlPutBack = $false; ok = $false; why = '' }
        $pf = Join-Path $dir 'checks-planted.json'
        if (Test-Path -LiteralPath $pf) {
            $pc = Get-Content -LiteralPath $pf -Raw | ConvertFrom-Json
            $proofChecks = @($pc.checks | ForEach-Object { $_.id = "p$($_.id)"; $_.pack = 'access-matrix (standing proof)'; $_ })
            $proof.ran = $true; $proof.fatal = "$($pc.fatal)"
            if ($pc.packs -and @($pc.packs | Where-Object { $_.error }).Count -gt 0) { $proof.fatal = (@($pc.packs | Where-Object { $_.error })[0]).error }
            $pl = @($proofChecks | Where-Object { $_.planted })
            $proof.plantedCells = $pl.Count; $proof.caught = ($pl.Count -eq 1 -and -not $pl[0].pass -and $pl[0].seen -eq 'opens')
            $proof.cells = @($proofChecks | Where-Object { $_.PSObject.Properties['grid'] }).Count
            # Every other cell of the proof must come out as in the real matrix run that follows (the planted
            # change must change exactly one cell); the proof's own checks (files, change in place, sign-in of
            # qa_inactive) must pass.
            $mainCells = @{}
            foreach ($k in @($checks | Where-Object { $_.PSObject.Properties['grid'] })) { $mainCells["$($k.grid.row)|$($k.grid.column)"] = $k }
            $others = foreach ($k in $proofChecks) {
                if ($k.planted) { continue }
                if (-not $k.PSObject.Properties['grid']) { if (-not $k.pass) { $k } ; continue }
                $m = $mainCells["$($k.grid.row)|$($k.grid.column)"]
                if (-not $m -or $m.seen -ne $k.seen -or [bool]$m.pass -ne [bool]$k.pass) { $k }
            }
            $proofOthers = @($others)
            $proof.otherFailed = $proofOthers.Count
        }
        $proof.xmlPutBack = (Test-Path -LiteralPath $siteXml) -and ((Get-QaFileHash $siteXml) -eq (Get-QaFileHash $treeXml))
        $proof.ok = $proof.ran -and -not $proof.fatal -and $proof.caught -and $proof.otherFailed -eq 0 -and $proof.xmlPutBack
        $proof.why = $(if (-not $proof.ran) { 'it did not run' } elseif ($proof.fatal) { "it broke off ($($proof.fatal))" } elseif (-not $proof.caught) { "the planted cell was not caught ($($proof.plantedCells) planted cell(s))" } elseif ($proof.otherFailed -gt 0) { "$($proof.otherFailed) other cell(s) or check(s) of the proof did not come out as in the real matrix run" } elseif (-not $proof.xmlPutBack) { 'Tests\_site\XML\PageAccess.xml is not the working tree''s file after the run' } else { '' })
        $run['standingProof'] = $proof
    }

    $real = @($checks | Where-Object { -not $_.planted })
    $planted = @($checks | Where-Object { $_.planted })
    $failed = @($real | Where-Object { -not $_.pass })
    $undecided = @($real | Where-Object { -not $_.pass -and $_.expected -eq 'decide' })
    $missed = @($planted | Where-Object { $_.pass })
    $broken = @($run.packs | Where-Object { $_.error })
    $run.counts = [ordered]@{ checks = $real.Count; passed = $real.Count - $failed.Count; failed = $failed.Count; ownerToDecide = $undecided.Count; planted = $planted.Count; plantedCaught = $planted.Count - $missed.Count }

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
    elseif ($matrix -and -not $proof.ok) {
        $run.result = 'VOID'; $exitCode = 3
        $run.summary = "The access matrix's standing proof failed: $($proof.why). The matrix cannot be trusted in this run; no result counts. Tell Claude."
    }
    elseif ($broken.Count -gt 0) {
        $run.result = 'VOID'; $exitCode = 3
        $run.summary = "A pack broke off before it finished: " + (($broken | ForEach-Object { "$($_.name) ($($_.error))" }) -join '; ') + '. The checks it did not reach are missing, so the run does not count.'
    }
    elseif ($failed.Count -gt 0 -or $errorNew.Count -gt 0 -or $blocked.Count -gt 0) {
        $run.result = 'FAILED'; $exitCode = 1
        $parts = @()
        if ($failed.Count -gt 0) { $parts += "$($failed.Count) of $($real.Count) checks failed" + $(if ($undecided.Count -gt 0) { " ($($undecided.Count) of them are cells marked 'owner to decide')" } else { '' }) }
        if ($errorNew.Count -gt 0) { $parts += "the error log has $($errorNew.Count) new line(s)" }
        if ($blocked.Count -gt 0) { $parts += "$($blocked.Count) request(s) to a host other than localhost were stopped" }
        $run.summary = ($parts -join '; ') + '. See "Failed checks" and the log section below. The self-test caught its 3 planted wrong expectations.' + $(if ($matrix) { ' The access matrix''s standing proof caught its planted change.' } else { '' })
    }
    else {
        $run.result = 'PASSED'; $exitCode = 0
        $run.summary = "All $($real.Count) checks passed. The self-test caught its 3 planted wrong expectations." + $(if ($matrix) { ' The access matrix''s standing proof caught its planted change.' } else { '' }) + ' No new line in the error log.'
    }
}
catch {
    if ($_.Exception.GetType().Name -eq 'QaRefusal') {
        $run.result = 'REFUSED'; $exitCode = 2
        $run.summary = $_.Exception.Message + $(if ($_.Exception.Message -match 'No test was run|Nothing was tested') { '' } else { ' Nothing was tested.' })
    }
    elseif ($_.Exception.GetType().Name -eq 'QaVoid') {
        $run.result = 'VOID'; $exitCode = 3
        $run.summary = "The run does not count: $($_.Exception.Message). The next run copies the working tree to Tests\_site again. Tell Claude."
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
    if ($run.Contains('firewallWarnings')) {
        $fwList = @($run.firewallWarnings) + @($run.firewallRefusals | ForEach-Object { "$_ (this would refuse -LeaveSiteRunning)" })
        $md.Add("- Firewall: " + $(if ($fwList.Count -eq 0) { 'no rule or profile that lets inbound traffic in to port ' + $QaPort + '.' } else { '**warning**: ' + ($fwList -join '; ') + '. Not a refusal (owner decision 2026-11-11): the site copy serves only callers on this machine, checked through every network address at its start.' }))
    }
    if (@($run.packs).Count -gt 0) { $md.Add('- Packs: ' + ((@($run.packs) | ForEach-Object { "$($_.name) ($($_.checks) checks, $($_.seconds) s)" }) -join '; ') + '.') }
    $mainOpened = @($checks | Where-Object { $_.PSObject.Properties['grid'] -and $_.seen -ne 'not-opened' }).Count
    $proofOpened = @($proofChecks | Where-Object { $_.PSObject.Properties['grid'] -and $_.seen -ne 'not-opened' }).Count
    $md.Add("- Time: $($run.seconds) seconds in all." + $(if ($mainOpened + $proofOpened -gt 0) { " Page requests of the access matrix: $mainOpened cells of the matrix and $proofOpened of the standing proof (one request each; the cells not opened are left out), plus the sign-ins and one Dashboard per role for its menu." } else { '' })); $md.Add('')

    if ($checks.Count -eq 0 -and $run.result -notin 'READY', 'REFUSED') { $md.Add('## Checks'); $md.Add(''); $md.Add('No checks were recorded in this run.'); $md.Add('') }
    if ($checks.Count -gt 0) {
        $real = @($checks | Where-Object { -not $_.planted }); $planted = @($checks | Where-Object { $_.planted })
        $isGrid = { param($k) [bool]$k.PSObject.Properties['grid'] }
        $failed = @($real | Where-Object { -not $_.pass -and $_.expected -ne 'decide' })
        $undecided = @($real | Where-Object { -not $_.pass -and $_.expected -eq 'decide' })
        $md.Add('## Failed checks'); $md.Add('')
        if ($failed.Count -eq 0 -and $undecided.Count -gt 0) { $md.Add("None apart from the $($undecided.Count) cell(s) marked ""owner to decide"" (next section).") }
        elseif ($failed.Count -eq 0 -and $run.result -eq 'FAILED') { $md.Add("None. The result is FAILED because of the logs below (error log: $($errorNew.Count) new line(s); requests to other hosts: $($blocked.Count)).") }
        elseif ($failed.Count -eq 0) { $md.Add('None.') }
        else {
            $md.Add('| No | Pack | Check | Expected | Seen | Detail | Screenshot |'); $md.Add('|---|---|---|---|---|---|---|')
            foreach ($k in $failed) { $md.Add("| $($k.id) | $(Cell $k.pack) | $(Cell $k.title) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $(Cell $k.detail) | $(if ($k.screenshot) { "[$($k.screenshot -replace '^screenshots/', '')]($($k.screenshot))" } else { 'none taken' }) |") }
            $md.Add(''); $md.Add("The screenshots are in the folder ``screenshots`` beside this file (``Tests\_results\$runId\screenshots``); a file name starts with the number of its check.")
            $md.Add(''); $md.Add('A failed check is reported to the owner as it is. The tester changes neither the product nor an expected result.')
        }
        $md.Add('')
        if ($undecided.Count -gt 0) {
            $md.Add('## Cells for the owner to decide'); $md.Add('')
            $md.Add('No written rule decides these cells (Tests\packs\access-matrix\README.md). Each counts as failed until the owner writes the cell into expected.csv. What the site does today:'); $md.Add('')
            $md.Add('| No | Role | Address | Seen | Detail | Screenshot |'); $md.Add('|---|---|---|---|---|---|')
            foreach ($k in $undecided) { $md.Add("| $($k.id) | $(Cell $k.role) | $(Cell $k.address) | $(Cell (Say $k.seen)) | $(Cell $k.detail) | $(if ($k.screenshot) { "[$($k.screenshot -replace '^screenshots/', '')]($($k.screenshot))" } else { 'none taken' }) |") }
            $md.Add('')
        }
        $grid = @($real | Where-Object { & $isGrid $_ })
        if ($grid.Count -gt 0) {
            $cols = @('admin', 'controller', 'manager', 'user', 'mgmt', 'mdsec', 'inactive', 'visitor')
            $md.Add('## Access matrix'); $md.Add('')
            $md.Add('Columns: admin = qa_admin (Admin), controller = qa_ctrl (Controller), manager = qa_manager, user = qa_user, mgmt = qa_mgmt (Management), mdsec = qa_mdsec (MD Secretariat), inactive = qa_inactive (an inactive account: its sign-in is refused), visitor = a browser that is not signed in.'); $md.Add('')
            $noteCells = @($grid | Where-Object { $_.expected -in 'remove', 'pending' })
            $okCells = @($grid | Where-Object { $_.pass -and $_.expected -notin 'remove', 'pending' }).Count
            $failCells = @($failed | Where-Object { & $isGrid $_ }).Count
            $md.Add("$($grid.Count) cells: $okCells ok, $failCells failed, $(@($undecided | Where-Object { & $isGrid $_ }).Count) owner to decide, $($noteCells.Count) notes (to be removed in RA1c1 or decided in RA1c2; never failures). ""ok"" = what the cell says came back, and the page access log agrees (one DENIED line for a refusal, none otherwise). A failing cell gives its number in ""Failed checks"".")
            $md.Add('')
            $md.Add('| Address | ' + ($cols -join ' | ') + ' |'); $md.Add('|---' + ('|---' * $cols.Count) + '|')
            $addresses = [System.Collections.Generic.List[string]]::new()
            foreach ($k in $grid) { if (-not $addresses.Contains($k.grid.row)) { $addresses.Add($k.grid.row) } }
            foreach ($a in $addresses) {
                $cellsText = foreach ($col in $cols) {
                    $k = @($grid | Where-Object { $_.grid.row -eq $a -and $_.grid.column -eq $col }) | Select-Object -First 1
                    if (-not $k) { '-' }
                    elseif ($k.expected -eq 'remove') { 'note RA1c1' }
                    elseif ($k.expected -eq 'pending') { "note RA1c2: $(Say $k.seen)" }
                    elseif ($k.expected -eq 'decide') { "owner to decide: $(Say $k.seen) ($($k.id))" }
                    elseif ($k.pass) { 'ok' }
                    else { "**FAIL** $(Say $k.expected) / seen $(Say $k.seen) ($($k.id))" }
                }
                $md.Add("| $(Cell $a) | " + (($cellsText | ForEach-Object { Cell $_ }) -join ' | ') + ' |')
            }
            $md.Add('')
            if ($noteCells.Count -gt 0) {
                $md.Add('## Notes: cells that are not judged yet'); $md.Add('')
                $md.Add('Owner decisions of 2026-11-11. These cells are never failures. A page "to be removed (RA1c1)" is not opened by the run; a cell "to be decided (RA1c2)" is opened and shows what the site does today.'); $md.Add('')
                $md.Add('| Address | Roles | Cell | Seen |'); $md.Add('|---|---|---|---|')
                foreach ($g in @($noteCells | Group-Object { "$($_.grid.row)|$($_.expected)|$($_.seen)" })) {
                    $k0 = $g.Group[0]
                    $md.Add("| $(Cell $k0.grid.row) | $((@($cols | Where-Object { $_ -in @($g.Group | ForEach-Object { $_.grid.column }) })) -join ', ') | $(Cell (Say $k0.expected)) | $(Cell (Say $k0.seen)) |")
                }
                $md.Add('')
            }
        }
        $noteChecks = @($checks | Where-Object { "$($_.title)" -like 'Note:*' })
        if ($noteChecks.Count -gt 0) {
            $md.Add('## Other notes for the owner'); $md.Add('')
            $md.Add('Facts the pack reports without failing (differences to look at, not faults found by the run):'); $md.Add('')
            foreach ($k in $noteChecks) { $md.Add("- $(Cell ($k.title -replace '^Note:\s*', '')): $(Cell $k.detail)") }
            $md.Add('')
        }
        $md.Add('## Self-test'); $md.Add('')
        $md.Add("The tester is given $($planted.Count) deliberately wrong expectations in every run. Each must come out as a failure; that shows the tester can tell a failure from a pass."); $md.Add('')
        if ($planted.Count -gt 0) {
            $md.Add('| No | Asked for | Wrong expectation given | Really seen | Caught |'); $md.Add('|---|---|---|---|---|')
            foreach ($k in $planted) { $md.Add("| $($k.id) | $(Cell $k.role) asks for $(Cell $k.address) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $(if ($k.pass) { 'NO - the run is void' } else { 'yes' }) |") }
            $md.Add(''); $md.Add('These rows are not failures. In "All checks" they read "caught (planted)".'); $md.Add('')
        }
    }
    if ($proof) {
        $md.Add('## Standing proof of the access matrix'); $md.Add('')
        $md.Add("Before the matrix, the runner added ``$($plantedDef.addRole)`` to the entry of $($plantedDef.page) in ``Tests\_site\XML\PageAccess.xml`` only (never in the working tree), ran $(if ($ProofFullMatrix) { 'every row' } else { 'the rows ' + (@($plantedDef.rows) -join ' and ') }) for every column ($($proof.cells) cells) and put the working tree's file back. Exactly one cell must fail: $($plantedDef.cell.column) on $($plantedDef.cell.address)."); $md.Add('')
        $pl = @($proofChecks | Where-Object { $_.planted }) | Select-Object -First 1
        $md.Add("- The planted cell: " + $(if ($pl) { "expected $(Say $pl.expected), seen $(Say $pl.seen): " + $(if (-not $pl.pass) { 'caught' } else { 'NOT caught' }) + $(if ($pl.screenshot) { " ([screenshot]($($pl.screenshot)))" } else { '' }) } else { 'not run' }) + '.')
        $md.Add("- Other cells and checks of the proof that did not come out as in the real matrix run: $($proof.otherFailed)" + $(if ($proof.otherFailed -gt 0) { ' (' + (($proofOthers | Select-Object -First 10 | ForEach-Object { "$($_.id) $($_.title): seen $(Say $_.seen)" }) -join '; ') + ')' } else { '' }) + '. Cells that fail in the real run too (a fault of the site, not of the proof) do not count here.')
        $md.Add("- Tests\_site\XML\PageAccess.xml after the run: " + $(if ($proof.xmlPutBack) { 'the same as the working tree''s file (SHA-256 compared)' } else { 'NOT the working tree''s file' }) + '.')
        $md.Add("- Result: " + $(if ($proof.ok) { 'the proof holds.' } else { "the proof failed ($($proof.why)); the run is VOID." }))
        $md.Add('')
    }

    $md.Add('## New lines in the logs of the site copy'); $md.Add('')
    $md.Add('A refusal ("Access denied") writes a DENIED line to the page access log, so new DENIED lines are normal for checks that expect a refusal. The self-test adds two for Master/User.aspx (its control and its planted check); the access matrix adds one for every "Access denied" cell, the standing proof''s cells first.'); $md.Add('')
    $md.Add("- Page access log (``Tests\_site\App_Data\PageAccessLog.txt``): $($accessNew.Count) new line(s)" + $(if ($accessNew.Count -gt 0) { ', all in `page-access-log-new.txt`:' } else { '.' }))
    if ($accessNew.Count -gt 0) { $md.Add(''); $md.Add('```'); foreach ($l in ($accessNew | Select-Object -First 40)) { $md.Add($l) }; if ($accessNew.Count -gt 40) { $md.Add("... and $($accessNew.Count - 40) more") }; $md.Add('```') }
    $errEntries = @($errorNew | Where-Object { $_ -match '^Date & Time\s*:' }).Count
    $md.Add("- Error log (``Tests\_site\Log``): $($errorNew.Count) new line(s), $errEntries entr$(if ($errEntries -eq 1) { 'y' } else { 'ies' })" + $(if ($errorNew.Count -gt 0) { ', all in `error-log-new.txt`. Every new line counts as a failure:' } else { '.' }))
    if ($errorNew.Count -gt 0) { $md.Add(''); $md.Add('```'); foreach ($l in ($errorNew | Select-Object -First 20)) { $md.Add($l.Substring(0, [Math]::Min(300, $l.Length))) }; if ($errorNew.Count -gt 20) { $md.Add("... and $($errorNew.Count - 20) more, see error-log-new.txt") }; $md.Add('```'); $md.Add('(Long lines are cut to 300 characters here; the file has them whole.)') }
    $md.Add("- Requests to a host other than localhost: $($blocked.Count)" + $(if ($blocked.Count -gt 0) { ' (stopped; each counts as a failure): ' + ((@($blocked) | Select-Object -First 5 | ForEach-Object { $_.url }) -join ', ') + $(if ($blocked.Count -gt 5) { " ... and $($blocked.Count - 5) more (see results.json)" } else { '' }) } else { '.' }))
    $md.Add('')

    if ($checks.Count -gt 0) {
        $md.Add('## All checks'); $md.Add('')
        $gridCount = @($checks | Where-Object { $_.PSObject.Properties['grid'] }).Count
        if ($gridCount -gt 0) { $md.Add("The $gridCount cells of the access matrix are in the section ""Access matrix"" above, not here."); $md.Add('') }
        $md.Add('| No | Pack | Check | Expected | Seen | Result |'); $md.Add('|---|---|---|---|---|---|')
        foreach ($k in @($checks | Where-Object { -not $_.PSObject.Properties['grid'] })) {
            $res = $(if ($k.planted) { if ($k.pass) { 'NOT CAUGHT (planted)' } else { 'caught (planted)' } } elseif ($k.pass) { 'pass' } else { 'FAIL' })
            $md.Add("| $($k.id) | $(Cell $k.pack) | $(Cell $k.title) | $(Cell (Say $k.expected)) | $(Cell (Say $k.seen)) | $res |")
        }
        $md.Add('')
    }
    $md.Add('## What the tester does not judge'); $md.Add('')
    $md.Add('Looks (alignment, borders, spacing, colours, the printed page, a document opened in Word) stay with the owner, who reads the screenshots and exports. The tester is no security audit. It complements the owner''s tests; it does not replace them.')
    $md | Set-Content -LiteralPath (Join-Path $dir 'results.md') -Encoding utf8
    ([ordered]@{ run = $run; checks = $checks; standingProofChecks = $proofChecks; blockedRequests = $blocked }) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $dir 'results.json') -Encoding utf8
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
