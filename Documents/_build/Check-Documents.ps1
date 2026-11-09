#Requires -Version 7.3
<#
  Check-Documents.ps1 - format checks of every Markdown document under Documents/
  (Documents/Export/ is skipped).

  Checks
  - plain ASCII and LF line endings (no CR, no byte above 127);
  - documents outside User-Manuals start with "# <Title>" and the 8-field header block, in order;
    Status is Draft, Reviewed by owner or Current;
  - user manuals start with "# <Title>", "- Audience:", "- Version:", "- Date:", and each has a
    register entry "### User-Manuals/<file>" in Documents/README.md with the 8 fields (and every
    register entry has its file);
  - screenshot placeholders have the exact form
    "[Screenshot: <screen> - supplied by Gashpy Software]";
  - no remote images (the export makes no network calls); with pandoc installed, every image
    target must be images/<name>.<png|jpg|gif|svg> next to the document and no raw block
    (openxml, html, ...) is allowed;
  - no secret-like text (connection-string parts, password assignments, private IP addresses,
    mail addresses other than the example domains);
  - every Mermaid block parses, when mermaid-cli is found (-Mmdc, or the tools folder, or PATH);
    otherwise the Mermaid check is reported as skipped. The parse writes temporary files only
    under Documents/Export/_check/ and starts Edge with all network traffic blocked.

  Exit code 0 when every check passes, 1 otherwise.

  Usage (from the repository root):
    pwsh -File Documents/_build/Check-Documents.ps1
    pwsh -File Documents/_build/Check-Documents.ps1 -Mmdc C:\Tools\bmms-doc-tools\node_modules\.bin\mmdc.cmd
#>
[CmdletBinding()]
param(
    [string]$Mmdc,
    [string]$Edge
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Native programs get their arguments quoted the standard way (each argument stays one argument).
$PSNativeCommandArgumentPassing = 'Standard'

. (Join-Path $PSScriptRoot 'DocTools.ps1')

$repo = Get-DocRepoRoot
$docs = Join-Path $repo 'Documents'
$exportDir = Join-Path $docs 'Export'
$failures = [System.Collections.Generic.List[string]]::new()
function Add-Fail([string]$msg) { $failures.Add($msg) }

$exportReadme = Join-Path $exportDir 'README.md'
$files = Get-ChildItem -LiteralPath $docs -Recurse -File -Force -Filter '*.md' |
    Where-Object { (-not (Test-DocUnder $_.FullName $exportDir)) -or ($_.FullName -eq $exportReadme) }

$headerFields = @('Title', 'Audience', 'Shipped', 'Applies to', 'Last updated by', 'Status', 'Verified against', 'To confirm')
$statuses = @('Draft', 'Reviewed by owner', 'Current')

$readme = Join-Path $docs 'README.md'
$register = Get-DocRegister -ReadmePath $readme

$mermaidBlocks = [System.Collections.Generic.List[object]]::new()

foreach ($f in $files) {
    $rel = Get-DocRelPath $repo $f.FullName
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    if ($bytes -contains 13) { Add-Fail "${rel}: CR found (LF line endings required)" }
    $high = @($bytes | Where-Object { $_ -gt 127 }).Count
    if ($high -gt 0) { Add-Fail "${rel}: $high byte(s) above 127 (plain ASCII required)" }

    $text = [Text.Encoding]::ASCII.GetString($bytes).Replace("`r", '')
    $lines = $text.Split("`n")

    if ($lines[0] -notmatch '^# \S') { Add-Fail "${rel}: line 1 is not '# <Title>'" }

    $isManual = $rel.StartsWith('Documents/User-Manuals/')
    if ($isManual) {
        $expect = @('- Audience: ', '- Version: ', '- Date: ')
        for ($k = 0; $k -lt 3; $k++) {
            if ($lines.Count -le 2 + $k -or -not $lines[2 + $k].StartsWith($expect[$k])) {
                Add-Fail "${rel}: line $(3 + $k) must start with '$($expect[$k].Trim())'"
            }
        }
        $key = $rel.Substring('Documents/'.Length)
        if (-not $register.ContainsKey($key)) {
            Add-Fail "${rel}: no register entry '### $key' in Documents/README.md"
        } else {
            $entry = $register[$key]
            foreach ($h in $headerFields) { if (-not $entry.Contains($h)) { Add-Fail "Documents/README.md register ${key}: field '$h' missing" } }
            if ($entry.Contains('Status') -and $statuses -notcontains $entry['Status']) { Add-Fail "Documents/README.md register ${key}: Status '$($entry['Status'])' not allowed" }
        }
    } else {
        $fields = Get-DocHeader -Lines $lines
        if ($null -eq $fields) {
            Add-Fail "${rel}: header block missing (line 3 onwards must be the 8 fields)"
        } else {
            $names = @($fields.Keys)
            for ($k = 0; $k -lt $headerFields.Count; $k++) {
                if ($names.Count -le $k -or $names[$k] -ne $headerFields[$k]) {
                    Add-Fail "${rel}: header field $($k + 1) must be '$($headerFields[$k])'"
                    break
                }
            }
            if ($fields.Contains('Status') -and $statuses -notcontains $fields['Status']) { Add-Fail "${rel}: Status '$($fields['Status'])' not allowed" }
        }
    }

    $inFence = $false
    $fenceLang = ''
    $blockStart = 0
    $block = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^```') {
            if (-not $inFence) {
                $inFence = $true; $fenceLang = $line.Substring(3).Trim(); $blockStart = $i + 1; [void]$block.Clear()
            } else {
                if ($fenceLang -eq 'mermaid') { $mermaidBlocks.Add([pscustomobject]@{ File = $rel; Line = $blockStart; Text = $block.ToString() }) }
                $inFence = $false
            }
            continue
        }
        if ($inFence) { [void]$block.AppendLine($line); continue }

        # Placeholders quoted as inline code (in the rules) are not placeholders.
        $plain = [regex]::Replace($line, '`[^`]*`', '')
        if ($plain -match '\[Screenshot' -and $plain.Trim() -notmatch '^\[Screenshot: [^\]]+ - supplied by Gashpy Software\]$') {
            Add-Fail "${rel}:$($i + 1): screenshot placeholder not in the form '[Screenshot: <screen> - supplied by Gashpy Software]'"
        }
        if ($line -match '!\[[^\]]*\]\(\s*(https?:|//)' -or $line -match '<img[^>]+src\s*=\s*["'']?(https?:|//)') {
            Add-Fail "${rel}:$($i + 1): remote image (only local images are allowed)"
        }
        $secret = Find-DocSecret $line
        if ($secret) { Add-Fail "${rel}:$($i + 1): secret-like text '$secret'" }
    }
    if ($inFence) { Add-Fail "${rel}: code fence opened at line $blockStart is not closed" }
}

# Structure check through pandoc (image targets, raw blocks), when pandoc is installed.
$pandocPath = Find-DocPandoc
$astNote = ''
if ($pandocPath) {
    foreach ($f in $files) {
        foreach ($pr in (Test-DocAst -PandocPath $pandocPath -File $f.FullName)) { Add-Fail "$(Get-DocRelPath $repo $f.FullName): $pr" }
    }
    $astNote = 'checked'
} else {
    $astNote = 'SKIPPED: pandoc not found'
}

foreach ($key in $register.Keys) {
    if (-not (Test-Path -LiteralPath (Join-Path $docs $key))) { Add-Fail "Documents/README.md register: '$key' has no file" }
}

# Mermaid parse
$mmdcPath = Find-DocMmdc -Hint $Mmdc
$mermaidNote = ''
if ($mermaidBlocks.Count -eq 0) {
    $mermaidNote = 'no Mermaid blocks'
} elseif (-not $mmdcPath) {
    $mermaidNote = "SKIPPED: mermaid-cli not found ($($mermaidBlocks.Count) block(s) not parsed)"
} else {
    $edgePath = Find-DocEdge -Hint $Edge
    $work = Join-Path $exportDir '_check'
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
    New-Item -ItemType Directory -Path $work | Out-Null
    $pconf = New-DocPuppeteerConfig -WorkDir $work -EdgePath $edgePath
    $n = 0; $bad = 0
    foreach ($b in $mermaidBlocks) {
        $n++
        $in = Join-Path $work ("m{0:D3}.mmd" -f $n)
        $out = Join-Path $work ("m{0:D3}.svg" -f $n)
        [IO.File]::WriteAllText($in, $b.Text, [Text.Encoding]::ASCII)
        $res = Invoke-DocMmdc -MmdcPath $mmdcPath -InFile $in -OutFile $out -PuppeteerConfig $pconf
        if (-not $res.Ok) { $bad++; Add-Fail "$($b.File):$($b.Line): Mermaid block does not parse: $($res.Message)" }
    }
    Remove-Item -LiteralPath $work -Recurse -Force
    $mermaidNote = "$n block(s) parsed, $bad failed"
}

Write-Output ("Checked {0} Markdown file(s) under Documents/; register entries: {1}; images and raw blocks: {2}; Mermaid: {3}." -f @($files).Count, $register.Count, $astNote, $mermaidNote)
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "FAIL $_" }
    Write-Output ("{0} failure(s)." -f $failures.Count)
    exit 1
}
Write-Output 'All document checks passed.'
exit 0
