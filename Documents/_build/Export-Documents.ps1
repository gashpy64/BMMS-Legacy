#Requires -Version 7.3
<#
  Export-Documents.ps1 - exports BMMS documents to Word and PDF with the Gashpy Software label.

  Made at release, not at every step. Writes only under Documents/Export/<label folder>/ and
  makes no network calls:
  - mermaid-cli renders each Mermaid block to PNG with the installed Edge, all network traffic
    blocked and the Edge profile inside the work folder;
  - pandoc converts the Markdown to .docx with Documents/_build/gashpy-reference.docx;
  - Word (COM) fills in the title, version and date in the header and footer, builds the table of
    contents, saves the .docx and saves the PDF.

  Refuses (before writing anything) any file that is outside Documents/ or inside
  Documents/Export/, whose name is not plain (letters, digits, dot, dash, underscore), that has
  an inline [[CONFIRM: ...]], a non-empty "To confirm" field (in its header block or, for a user
  manual, in its register entry), an image target other than images/<name>.<png|jpg|gif|svg>,
  any raw block (openxml, html, ...), or - for a user manual - any hit of Check-UserManuals.ps1.
  The PDF is saved without document properties; the .docx is saved without personal
  information (author, last modified by).
  Word updates only the table of contents (and the page numbers it lays out itself); no other
  field is refreshed.

  Label: "Version X.Y.Z" when HEAD carries tag vX.Y.Z equal to AssemblyInformationalVersion
  (and Documents/ has no uncommitted change); otherwise "Draft - <date>". The latest step tag
  appears only in the Export folder name (Documents/Export/Draft-<step tag>-<date>/), never in
  the document.

  The Glossary (User-Manuals/Glossary.md) is not exported on its own: it is appended to the
  Overall manual's export, and it passes the same pre-checks.

  Usage (from the repository root):
    pwsh -File Documents/_build/Export-Documents.ps1
        (the Overall manual with the Glossary, and the four role manuals)
    pwsh -File Documents/_build/Export-Documents.ps1 -Files Documents/Data-Flow/00-Notation.md
#>
[CmdletBinding()]
param(
    [string[]]$Files = @(
        'Documents/User-Manuals/00-Overall.md',
        'Documents/User-Manuals/01-User.md',
        'Documents/User-Manuals/02-Manager.md',
        'Documents/User-Manuals/03-Controller.md',
        'Documents/User-Manuals/04-Admin.md'
    ),
    [switch]$NoPdf,
    [switch]$KeepWork,
    [string]$Pandoc,
    [string]$Mmdc,
    [string]$Edge
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Native programs get their arguments quoted the standard way (each argument stays one argument).
$PSNativeCommandArgumentPassing = 'Standard'

. (Join-Path $PSScriptRoot 'DocTools.ps1')

# "pwsh -File" passes "a.md,b.md" as one string: split it.
$Files = @($Files | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$repo = Get-DocRepoRoot
$docs = Join-Path $repo 'Documents'
$exportDir = Join-Path $docs 'Export'
$manualDir = Join-Path $docs 'User-Manuals'
$reference = Join-Path $PSScriptRoot 'gashpy-reference.docx'
$register = Get-DocRegister -ReadmePath (Join-Path $docs 'README.md')

# ---- tools ----
$pandocPath = Find-DocPandoc -Hint $Pandoc
if (-not $pandocPath) { throw 'pandoc not found; install it or pass -Pandoc <path to pandoc.exe>.' }
if (-not (Test-Path -LiteralPath $reference)) { throw "Word template missing: $reference (run New-ReferenceDocx.ps1)." }

# ---- label ----
$lab = Get-DocLabel -Repo $repo
if ($lab.IsRelease) {
    $dirty = @(& git -C $repo status --porcelain -- Documents)
    if ($dirty.Count -gt 0) { throw "Release export refused: Documents/ has uncommitted changes." }
}

# ---- pre-checks: all files must pass before anything is written ----
$refusals = [System.Collections.Generic.List[string]]::new()
$glossary = Join-Path $manualDir 'Glossary.md'
$overall = Join-Path $manualDir '00-Overall.md'
$checkList = [System.Collections.Generic.List[string]]::new()
foreach ($f in $Files) {
    $checkList.Add($f)
    if ([IO.Path]::GetFullPath((Join-Path $repo $f)) -eq $overall) { $checkList.Add((Get-DocRelPath $repo $glossary)) }
}
$items = foreach ($f in $checkList) {
    $full = [IO.Path]::GetFullPath((Join-Path $repo $f))
    $rel = Get-DocRelPath $repo $full
    if (-not (Test-Path -LiteralPath $full)) { $refusals.Add("${rel}: file not found"); continue }
    if (-not (Test-DocUnder $full $docs) -or (Test-DocUnder $full $exportDir) -or [IO.Path]::GetExtension($full) -ne '.md') {
        $refusals.Add("${rel}: only Markdown files inside Documents/ (not Documents/Export/) can be exported"); continue
    }
    if ([IO.Path]::GetFileName($full) -notmatch '^[A-Za-z0-9._-]+\.md$') { $refusals.Add("${rel}: file name must use only letters, digits, dot, dash and underscore"); continue }
    foreach ($pr in (Test-DocAst -PandocPath $pandocPath -File $full)) { $refusals.Add("${rel}: $pr") }
    $text = (Get-Content -Raw -LiteralPath $full).Replace("`r", '')
    $lines = $text.Split("`n")
    $isManual = Test-DocUnder $full $manualDir
    if ($text.IndexOf('[[CONFIRM', [StringComparison]::OrdinalIgnoreCase) -ge 0) { $refusals.Add("${rel}: has an open [[CONFIRM: ...]] point") }
    if ($isManual) {
        $key = $rel.Substring('Documents/'.Length)
        if (-not $register.ContainsKey($key)) { $refusals.Add("${rel}: no register entry in Documents/README.md") }
        elseif (-not $register[$key].Contains('To confirm')) { $refusals.Add("${rel}: register entry has no 'To confirm' field") }
        elseif ($register[$key]['To confirm']) { $refusals.Add("${rel}: register 'To confirm' is not empty: $($register[$key]['To confirm'])") }
        $chk = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Check-UserManuals.ps1') -Files $rel -Pandoc $pandocPath 2>&1
        if ($LASTEXITCODE -ne 0) { $refusals.Add("${rel}: Check-UserManuals.ps1 found internal material:`n    " + (($chk | Out-String).Trim() -replace "`n", "`n    ")) }
    } else {
        $h = Get-DocHeader -Lines $lines
        if ($null -eq $h -or -not $h.Contains('To confirm')) { $refusals.Add("${rel}: header block or its 'To confirm' field missing") }
        elseif ($h['To confirm']) { $refusals.Add("${rel}: 'To confirm' is not empty: $($h['To confirm'])") }
    }
    if ($lines[0] -notmatch '^# (.+)$') { $refusals.Add("${rel}: line 1 is not '# <Title>'"); continue }
    $title = $Matches[1].Trim()
    if ($title -notmatch "^[A-Za-z0-9 ,.:()'&/-]+$") { $refusals.Add("${rel}: the title may use only letters, digits, spaces and , . : ( ) ' & / -"); continue }
    [pscustomobject]@{ Full = $full; Rel = $rel; Lines = $lines; Title = $title; IsManual = $isManual; IsGlossary = ($full -eq $glossary) }
}
$glossaryItem = $items | Where-Object { $_.IsGlossary } | Select-Object -First 1
$exportItems = @($items | Where-Object { -not $_.IsGlossary })
$hasMermaid = @($items | Where-Object { ($_.Lines -match '^```mermaid\s*$').Count -gt 0 }).Count -gt 0
$mmdcPath = $null; $edgePath = $null
if ($hasMermaid) {
    $mmdcPath = Find-DocMmdc -Hint $Mmdc
    if (-not $mmdcPath) { $refusals.Add('mermaid-cli not found; install it or pass -Mmdc <path to mmdc.cmd>') }
    $edgePath = Find-DocEdge -Hint $Edge
}
if ($refusals.Count -gt 0) {
    Write-Output 'Export refused, nothing written:'
    $refusals | ForEach-Object { Write-Output "- $_" }
    exit 1
}

# ---- output folder ----
$outDir = Join-Path $exportDir $lab.Folder
if (-not (Test-DocUnder $outDir $exportDir)) { throw 'Output folder is outside Documents/Export.' }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$pageBreak = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
$tocXml = '<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t>Contents</w:t></w:r></w:p>' +
          '<w:p><w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>' +
          '<w:r><w:instrText xml:space="preserve"> TOC \o "1-2" \h \z \u </w:instrText></w:r>' +
          '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Contents</w:t></w:r>' +
          '<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>'

$word = $null
$results = [System.Collections.Generic.List[string]]::new()
try {
    foreach ($it in $exportItems) {
        $name = [IO.Path]::GetFileNameWithoutExtension($it.Full)
        $work = Join-Path $outDir "work-$name"
        if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $work 'img') | Out-Null

        # Body: everything after the title line; Version and Date lines of a manual filled in;
        # Mermaid blocks rendered to PNG.
        $pconf = if ($mmdcPath) { New-DocPuppeteerConfig -WorkDir $work -EdgePath $edgePath } else { $null }
        $sb = [System.Text.StringBuilder]::new()
        $n = 0
        $bodyLines = [System.Collections.Generic.List[string]]::new()
        $bodyLines.AddRange([string[]]$it.Lines)
        if ($it.Full -eq $overall -and $glossaryItem) {
            # The Glossary follows the Overall manual: its title becomes a section; its Audience,
            # Version and Date lines are left out.
            $bodyLines.Add('')
            $bodyLines.Add('## ' + $glossaryItem.Title)
            foreach ($g in ($glossaryItem.Lines | Select-Object -Skip 1)) {
                if ($g -match '^- (Audience|Version|Date): ') { continue }
                $bodyLines.Add(($g -replace '^## ', '### '))
            }
        }
        for ($i = 1; $i -lt $bodyLines.Count; $i++) {
            $line = $bodyLines[$i]
            if ($it.IsManual -and $line -eq '- Version: filled in at export') { $line = "- Version: $($lab.Label)" }
            if ($it.IsManual -and $line -eq '- Date: filled in at export') { $line = "- Date: $($lab.Date)" }
            if ($line -match '^```mermaid\s*$') {
                $j = $i + 1
                $code = [System.Text.StringBuilder]::new()
                while ($j -lt $bodyLines.Count -and $bodyLines[$j] -notmatch '^```\s*$') { [void]$code.AppendLine($bodyLines[$j]); $j++ }
                $n++
                $mmd = Join-Path $work ("img\{0}-{1:D3}.mmd" -f $name, $n)
                $png = Join-Path $work ("img\{0}-{1:D3}.png" -f $name, $n)
                [IO.File]::WriteAllText($mmd, $code.ToString(), [Text.Encoding]::ASCII)
                $r = Invoke-DocMmdc -MmdcPath $mmdcPath -InFile $mmd -OutFile $png -PuppeteerConfig $pconf -Scale 2
                if (-not $r.Ok) { throw "$($it.Rel): Mermaid block $n did not render: $($r.Message)" }
                [void]$sb.AppendLine(("![](img/{0}-{1:D3}.png)" -f $name, $n))
                $i = $j
                continue
            }
            [void]$sb.AppendLine($line)
        }
        # The text as pandoc will read it (the Overall manual with the Glossary joined, Mermaid
        # blocks replaced by their pictures) is checked once more as a whole: images only from
        # images/ next to the document or img/ in the work folder, no raw block, no metadata.
        $checkMd = Join-Path $work "$name.check.md"
        [IO.File]::WriteAllText($checkMd, $sb.ToString(), [Text.Encoding]::ASCII)
        $roots = @{ 'images' = [IO.Path]::GetDirectoryName($it.Full); 'img' = (Join-Path $work 'img') }
        $joined = Test-DocAst -PandocPath $pandocPath -File $checkMd -ImageRoots $roots
        if ($joined.Count -gt 0) { throw "$($it.Rel): the text to export failed the check: $($joined -join '; ')" }

        # Only now the script's own cover break and table of contents are put in front.
        $md = Join-Path $work "$name.md"
        $front = '```{=openxml}' + "`n" + $pageBreak + $tocXml + $pageBreak + "`n" + '```' + "`n`n"
        [IO.File]::WriteAllText($md, $front + $sb.ToString(), [Text.Encoding]::ASCII)

        $docx = Join-Path $work "$name.docx"
        $resPath = $work + ';' + [IO.Path]::GetDirectoryName($it.Full)
        $pArgs = @($md, '-f', 'markdown-yaml_metadata_block', '-t', 'docx', '--reference-doc', $reference,
                   '--resource-path', $resPath, '--shift-heading-level-by=-1',
                   '-M', "title=$($it.Title)", '-M', "subtitle=$($lab.Label)",
                   '-M', 'author=Gashpy Software', '-o', $docx)
        # A draft label already carries the date; a release label gets the date on its own line.
        if ($lab.IsRelease) { $pArgs += @('-M', "date=$($lab.Date)") }
        $pout = & $pandocPath @pArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $docx)) { throw "$($it.Rel): pandoc failed: $pout" }

        if ($null -eq $word) {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $word.DisplayAlerts = 0
        }
        $doc = $word.Documents.Open($docx, $false, $false, $false)
        try {
            # Footer "Gashpy Software | <label> | <date>": a draft label already carries the date.
            $map = [ordered]@{}
            if (-not $lab.IsRelease) { $map[' | %%DATE%%'] = '' }
            $map['%%TITLE%%'] = ConvertTo-WordReplaceText $it.Title
            $map['%%VERSION%%'] = ConvertTo-WordReplaceText $lab.Label
            $map['%%DATE%%'] = ConvertTo-WordReplaceText $lab.Date
            foreach ($story in $doc.StoryRanges) {
                $rng = $story
                while ($null -ne $rng) {
                    foreach ($k in $map.Keys) {
                        $find = $rng.Find
                        [void]$find.Execute($k, $true, $false, $false, $false, $false, $true, 1, $false, $map[$k], 2)
                    }
                    $rng = $rng.NextStoryRange
                }
            }
            # Diagrams and screenshots: no taller than 80 percent of the text height (so a heading
            # fits above them on the same page) and no wider than the text width.
            $ps = $doc.Sections.Item(1).PageSetup
            $maxH = ($ps.PageHeight - $ps.TopMargin - $ps.BottomMargin) * 0.8
            $maxW = $ps.PageWidth - $ps.LeftMargin - $ps.RightMargin
            foreach ($shape in $doc.InlineShapes) {
                $shape.LockAspectRatio = -1
                if ($shape.Height -gt $maxH) { $shape.Height = $maxH }
                if ($shape.Width -gt $maxW) { $shape.Width = $maxW }
            }
            # Only the table of contents is updated; PAGE and NUMPAGES are laid out by Word itself.
            foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
            # No personal data in the shipped files: Word drops the author and 'last modified by'
            # (the Windows user name) when it saves.
            $doc.RemovePersonalInformation = $true
            $doc.Save()
            if (-not $NoPdf) {
                $pdf = Join-Path $work "$name.pdf"
                # PDF without document properties (IncludeDocProps = false): no author, company or
                # user name in the PDF. Arguments: file, wdExportFormatPDF, no open, print quality,
                # whole document, from, to, content only, IncludeDocProps.
                $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 0, 1, 1, 0, $false)
            }
        } finally {
            $doc.Close(0)
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($doc)
        }

        Move-Item -LiteralPath $docx -Destination (Join-Path $outDir "$name.docx") -Force
        $results.Add((Get-DocRelPath $repo (Join-Path $outDir "$name.docx")))
        if (-not $NoPdf) {
            Move-Item -LiteralPath (Join-Path $work "$name.pdf") -Destination (Join-Path $outDir "$name.pdf") -Force
            $results.Add((Get-DocRelPath $repo (Join-Path $outDir "$name.pdf")))
        }
        if (-not $KeepWork) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
} finally {
    if ($null -ne $word) {
        $word.Quit(0)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }
}

Write-Output "Exported with label '$($lab.Label)':"
$results | ForEach-Object { Write-Output "- $_" }
exit 0
