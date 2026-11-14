#Requires -Version 7.3
<#
  DocTools.ps1 - helpers shared by Check-Documents.ps1, Export-Documents.ps1 and
  New-ReferenceDocx.ps1. Dot-source it; it defines functions only and does nothing on its own.

  The external tools are looked up in this order:
  - mermaid-cli: -Mmdc, then $env:BMMS_DOC_TOOLS\node_modules\.bin\mmdc.cmd, then
    C:\Tools\bmms-doc-tools\node_modules\.bin\mmdc.cmd, then mmdc on PATH;
  - pandoc: -Pandoc, then pandoc on PATH, then the winget per-user and per-machine folders;
  - Edge: -Edge, then the standard install folders.
#>

Set-StrictMode -Version Latest

function Get-DocRepoRoot {
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-DocRelPath([string]$Repo, [string]$FullName) {
    [IO.Path]::GetRelativePath($Repo, $FullName).Replace('\', '/')
}

function Test-DocUnder([string]$Path, [string]$Dir) {
    $p = [IO.Path]::GetFullPath($Path)
    $d = [IO.Path]::GetFullPath($Dir).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $p.StartsWith($d, [StringComparison]::OrdinalIgnoreCase)
}

# Reads "- Field: value" lines (with two-space continuation lines) starting at $Start, until a
# blank line. Returns an ordered dictionary, or $null when the first line is not a field.
function Read-DocFields([string[]]$Lines, [int]$Start) {
    $fields = [ordered]@{}
    $last = $null
    for ($i = $Start; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line.Trim() -eq '') { break }
        if ($line -match '^- ([A-Za-z][A-Za-z ]*):(.*)$') {
            $last = $Matches[1]
            $fields[$last] = $Matches[2].Trim()
        } elseif ($line -match '^  \S' -and $null -ne $last) {
            $fields[$last] = ($fields[$last] + ' ' + $line.Trim()).Trim()
        } else {
            break
        }
    }
    if ($fields.Count -eq 0) { return $null }
    $fields
}

# Header block of an internal document: line 1 "# Title", line 2 blank, fields from line 3.
function Get-DocHeader([string[]]$Lines) {
    if ($Lines.Count -lt 3 -or $Lines[1].Trim() -ne '') { return $null }
    Read-DocFields -Lines $Lines -Start 2
}

# Register of the user manuals in Documents/README.md: "### User-Manuals/<file>" followed by a
# blank line and the fields. Returns a hashtable: "User-Manuals/<file>" -> ordered fields.
function Get-DocRegister([string]$ReadmePath) {
    $reg = @{}
    if (-not (Test-Path -LiteralPath $ReadmePath)) { return $reg }
    $lines = (Get-Content -Raw -LiteralPath $ReadmePath).Replace("`r", '').Split("`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^### (User-Manuals/\S+\.md)\s*$') {
            $key = $Matches[1]
            $start = $i + 1
            while ($start -lt $lines.Count -and $lines[$start].Trim() -eq '') { $start++ }
            $f = Read-DocFields -Lines $lines -Start $start
            $reg[$key] = if ($null -eq $f) { [ordered]@{} } else { $f }
        }
    }
    $reg
}

# Returns the first secret-like match in a line, or $null.
function Find-DocSecret([string]$Line) {
    $patterns = @(
        '(?i)\b(password|pwd)\s*=\s*[^\s<;"]+',
        '(?i)\bData Source\s*=',
        '(?i)\bInitial Catalog\s*=',
        '(?i)\bUser ID\s*=',
        '\b(?:10|127)\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
        '\b192\.168\.\d{1,3}\.\d{1,3}\b',
        '\b172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}\b',
        '(?i)[A-Za-z0-9._%+-]+@(?![A-Za-z0-9-]+\.example\b|example\.(?:com|org|net)\b)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+'
    )
    foreach ($p in $patterns) {
        $m = [regex]::Match($Line, $p)
        if ($m.Success) { return $m.Value }
    }
    $null
}

function Find-DocMmdc([string]$Hint) {
    $cands = @()
    if ($Hint) { $cands += $Hint }
    if ($env:BMMS_DOC_TOOLS) { $cands += (Join-Path $env:BMMS_DOC_TOOLS 'node_modules\.bin\mmdc.cmd') }
    $cands += 'C:\Tools\bmms-doc-tools\node_modules\.bin\mmdc.cmd'
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path } }
    $cmd = Get-Command mmdc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $null
}

# Only a real pandoc.exe is accepted (never a .cmd or .bat shim, which cmd.exe would read).
function Find-DocPandoc([string]$Hint) {
    if ($Hint -and $Hint -match '\.exe$' -and (Test-Path -LiteralPath $Hint)) { return (Resolve-Path -LiteralPath $Hint).Path }
    $cmd = Get-Command pandoc -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Source -match '\.exe$' } | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($c in @((Join-Path $env:LOCALAPPDATA 'Pandoc\pandoc.exe'), 'C:\Program Files\Pandoc\pandoc.exe')) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $null
}

function Find-DocEdge([string]$Hint) {
    $cands = @()
    if ($Hint) { $cands += $Hint }
    $cands += 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
    $cands += 'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { return $c } }
    throw 'Microsoft Edge not found; pass -Edge <path to msedge.exe>.'
}

# Puppeteer launch options for mermaid-cli: the installed Edge, its profile inside $WorkDir, and
# every network request blocked (all host names fail to resolve and all traffic goes to a dead
# local proxy). Mermaid-cli renders from local files only.
function New-DocPuppeteerConfig([string]$WorkDir, [string]$EdgePath) {
    $conf = [ordered]@{
        executablePath = $EdgePath
        headless       = $true
        userDataDir    = (Join-Path $WorkDir 'edge-profile')
        args           = @(
            '--no-first-run', '--no-default-browser-check', '--disable-extensions',
            '--disable-background-networking', '--disable-component-update', '--disable-sync',
            '--disable-default-apps', '--disable-domain-reliability',
            '--disable-client-side-phishing-detection', '--metrics-recording-only',
            '--proxy-server=http://127.0.0.1:9', '--proxy-bypass-list=<-loopback>',
            '--host-resolver-rules=MAP * ~NOTFOUND'
        )
    }
    $path = Join-Path $WorkDir 'puppeteer.json'
    [IO.File]::WriteAllText($path, ($conf | ConvertTo-Json -Depth 4), [Text.Encoding]::ASCII)
    $path
}

# Mermaid's own settings: strict security level and no HTML labels, so a label cannot load or
# show anything but text.
function New-DocMermaidConfig([string]$WorkDir) {
    # "secure" stops a %%{init}%% directive inside a diagram from changing these settings.
    $conf = [ordered]@{
        securityLevel = 'strict'; htmlLabels = $false; flowchart = [ordered]@{ htmlLabels = $false }
        secure = @('secure', 'securityLevel', 'startOnLoad', 'maxTextSize', 'maxEdges',
                   'suppressErrorRendering', 'dompurifyConfig', 'themeCSS', 'htmlLabels', 'flowchart')
    }
    $path = Join-Path $WorkDir 'mermaid.json'
    [IO.File]::WriteAllText($path, ($conf | ConvertTo-Json -Depth 4), [Text.Encoding]::ASCII)
    $path
}

# mermaid-cli is started through node with its own script (src/cli.js), never through the
# mmdc.cmd batch file, so no path or argument is read by cmd.exe.
function Invoke-DocMmdc([string]$MmdcPath, [string]$InFile, [string]$OutFile, [string]$PuppeteerConfig, [int]$Scale = 1) {
    $binDir = [IO.Path]::GetDirectoryName($MmdcPath)
    $cli = [IO.Path]::GetFullPath((Join-Path $binDir '..\@mermaid-js\mermaid-cli\src\cli.js'))
    if (-not (Test-Path -LiteralPath $cli)) { throw "mermaid-cli script not found: $cli" }
    $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Source -match '\.exe$' } | Select-Object -First 1
    if (-not $node) { throw 'node not found.' }
    $mconf = New-DocMermaidConfig -WorkDir ([IO.Path]::GetDirectoryName($PuppeteerConfig))
    $mmArgs = @($cli, '-i', $InFile, '-o', $OutFile, '-p', $PuppeteerConfig, '-c', $mconf, '-b', 'white', '-q')
    if ($Scale -gt 1) { $mmArgs += @('-s', "$Scale") }
    $out = & $node.Source @mmArgs 2>&1 | Out-String
    $ok = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $OutFile)
    $msg = ($out -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 3) -join ' / '
    [pscustomobject]@{ Ok = $ok; Message = $msg }
}

# The Markdown reading used everywhere: pandoc markdown without YAML metadata blocks, so a
# document cannot carry metadata (which pandoc would also turn into content).
$script:DocMarkdownFormat = 'markdown-yaml_metadata_block'

# Structure check through pandoc's own reading of the Markdown (pandoc -t json), so that no
# spelling of an image or raw block gets past a line pattern:
# - every image target must be a plain relative path <prefix>/<name>.<png|jpg|jpeg|gif|svg>
#   whose prefix is one of $ImageRoots (default: images, next to the document) and which exists
#   there (no URL, no network share, no absolute or parent path);
# - raw blocks and raw inlines (openxml, html, latex, ...) are not allowed;
# - the metadata must be empty.
# Returns a list of problem texts (empty when the file passes). Runs pandoc locally; no network.
function Test-DocAst([string]$PandocPath, [string]$File, [hashtable]$ImageRoots) {
    $problems = [System.Collections.Generic.List[string]]::new()
    if (-not $ImageRoots) { $ImageRoots = @{ 'images' = [IO.Path]::GetDirectoryName($File) } }
    $json = & $PandocPath -f $script:DocMarkdownFormat -t json -- $File 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { $problems.Add("pandoc could not read the file: $($json.Trim())"); return , $problems }
    $ast = $json | ConvertFrom-Json -Depth 200 -AsHashtable
    if ($ast['meta'] -and $ast['meta'].Count -gt 0) { $problems.Add('metadata is not allowed in a document') }
    $prefixes = ($ImageRoots.Keys | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $stack = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push($ast['blocks'])
    $stack.Push($ast['meta'])
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($node -is [System.Collections.IDictionary]) {
            $t = $node['t']
            if ($t -eq 'Image') {
                $target = [string]$node['c'][2][0]
                if ($target -notmatch "^($prefixes)/[A-Za-z0-9._-]+\.(png|jpg|jpeg|gif|svg)$") {
                    $problems.Add("image target not allowed (only images/<name>.png and similar): '$target'")
                } else {
                    $prefix = $target.Substring(0, $target.IndexOf('/'))
                    if (-not (Test-Path -LiteralPath (Join-Path $ImageRoots[$prefix] $target.Substring($prefix.Length + 1)))) {
                        $problems.Add("image not found: '$target'")
                    }
                }
            } elseif ($t -eq 'RawBlock' -or $t -eq 'RawInline') {
                $fmt = [string]$node['c'][0]
                $problems.Add("raw $fmt content is not allowed in a document")
            }
            foreach ($v in $node.Values) { if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { $stack.Push($v) } }
        } elseif ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
            foreach ($v in $node) { if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { $stack.Push($v) } }
        }
    }
    , $problems
}

# Word Find/Replace treats ^ in the replacement text as a code (^c pastes the clipboard).
function ConvertTo-WordReplaceText([string]$Text) { $Text.Replace('^', '^^') }

# Export label. A release is HEAD carrying a tag vX.Y.Z equal to AssemblyInformationalVersion;
# anything else is a draft. A draft shows only "Draft - <date>" in the document (cover, subtitle,
# footer, Version line), so no step tag reaches its text; the latest step tag is used only in the
# name of the Export folder (Draft-<step tag>-<date>).
function Get-DocLabel([string]$Repo) {
    $date = (Get-Date).ToString('yyyy-MM-dd')
    $asmInfo = Join-Path $Repo 'BMMS\Properties\AssemblyInfo.cs'
    $version = $null
    if (Test-Path -LiteralPath $asmInfo) {
        $m = [regex]::Match((Get-Content -Raw -LiteralPath $asmInfo), 'AssemblyInformationalVersion\("([^"]+)"\)')
        if ($m.Success) { $version = $m.Groups[1].Value }
    }
    $headTags = @(& git -C $Repo tag --points-at HEAD 2>$null)
    $release = $headTags | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' -and $version -and $_ -eq "v$version" } | Select-Object -First 1
    if ($release) {
        return [pscustomobject]@{ Label = "Version $version"; Folder = $release; Date = $date; IsRelease = $true }
    }
    $stepTag = (& git -C $Repo describe --tags --abbrev=0 2>$null)
    if (-not $stepTag) { $stepTag = 'untagged' }
    [pscustomobject]@{
        Label     = "Draft - $date"
        Folder    = "Draft-$stepTag-$date"
        Date      = $date
        IsRelease = $false
    }
}
