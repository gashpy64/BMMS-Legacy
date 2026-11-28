#Requires -Version 7.3
<#
  New-ReferenceDocx.ps1 - builds the Gashpy Software Word template that Export-Documents.ps1
  passes to pandoc (Documents/_build/gashpy-reference.docx).

  Run only when the template is to change; the result is committed. Starts from pandoc's own
  default reference.docx and sets with Word (COM):
  - A4, 2 cm margins, a first page (the cover) without header and footer;
  - text-only cover styles: Title, Subtitle (the version label), Author ("Gashpy Software"), Date;
  - body and heading styles in the BMMS colours (Design: BMMS/CSS/bmms-colours.css);
  - header: %%TITLE%% (right); footer: "Gashpy Software | %%VERSION%% | %%DATE%%" and
    "Page X of Y". Export-Documents.ps1 replaces the %%...%% placeholders per document.
  No logo. Temporary files go under Documents/Export/_template/ and are removed. No network.

  Usage (from the repository root):
    pwsh -File Documents/_build/New-ReferenceDocx.ps1
#>
[CmdletBinding()]
param([string]$Pandoc)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Native programs get their arguments quoted the standard way (each argument stays one argument).
$PSNativeCommandArgumentPassing = 'Standard'

. (Join-Path $PSScriptRoot 'DocTools.ps1')

$repo = Get-DocRepoRoot
$work = Join-Path $repo 'Documents\Export\_template'
$target = Join-Path $PSScriptRoot 'gashpy-reference.docx'

$pandocPath = Find-DocPandoc -Hint $Pandoc
if (-not $pandocPath) { throw 'pandoc not found; install it or pass -Pandoc <path to pandoc.exe>.' }

if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
$base = Join-Path $work 'base.docx'
& $pandocPath -o $base --print-default-data-file reference.docx
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $base)) { throw 'pandoc could not write its default reference.docx.' }

# Word colours are R + G*256 + B*65536.
function RGBc([int]$r, [int]$g, [int]$b) { $r + $g * 256 + $b * 65536 }
$primary = RGBc 0x1E 0x5A 0xA8   # --bmms-primary
$heading = RGBc 0x11 0x18 0x27   # --bmms-heading
$text    = RGBc 0x1F 0x29 0x37   # --bmms-text
$muted   = RGBc 0x4B 0x55 0x63   # --bmms-text-muted

function Set-Style($doc, [string]$name, [double]$size, [int]$color, [bool]$bold, [string]$font = 'Calibri', [double]$before = -1, [double]$after = -1) {
    try { $s = $doc.Styles.Item($name) } catch { Write-Output "Style '$name' not in the template; skipped."; return }
    $s.Font.Name = $font
    $s.Font.Size = $size
    $s.Font.Color = $color
    $s.Font.Bold = [int]$bold
    if ($before -ge 0) { $s.ParagraphFormat.SpaceBefore = $before }
    if ($after -ge 0) { $s.ParagraphFormat.SpaceAfter = $after }
}

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $doc = $word.Documents.Open($base, $false, $false, $false)
    try {
        $ps = $doc.Sections.Item(1).PageSetup
        $ps.PaperSize = 7                       # wdPaperA4
        $cm = 28.3465
        $ps.TopMargin = 2 * $cm; $ps.BottomMargin = 2 * $cm
        $ps.LeftMargin = 2 * $cm; $ps.RightMargin = 2 * $cm
        $ps.DifferentFirstPageHeaderFooter = -1

        Set-Style $doc 'Normal'      10.5 $text    $false
        Set-Style $doc 'Body Text'   10.5 $text    $false
        Set-Style $doc 'First Paragraph' 10.5 $text $false
        Set-Style $doc 'Title'       28   $primary $true 'Calibri' 150 12
        Set-Style $doc 'Subtitle'    14   $muted   $false 'Calibri' 6 6
        Set-Style $doc 'Author'      14   $heading $true 'Calibri' 36 6
        Set-Style $doc 'Date'        12   $muted   $false 'Calibri' 6 6
        Set-Style $doc 'Heading 1'   16   $primary $true 'Calibri' 18
        Set-Style $doc 'Heading 2'   13   $primary $true 'Calibri' 12
        Set-Style $doc 'Heading 3'   11.5 $heading $true 'Calibri' 10
        Set-Style $doc 'TOC Heading' 16   $primary $true
        try {
            $t = $doc.Styles.Item('Table')
            $t.Table.Borders.Enable = 1
        } catch { Write-Output "Table style borders not set: $($_.Exception.Message)" }

        $sec = $doc.Sections.Item(1)
        $textWidth = $ps.PageWidth - $ps.LeftMargin - $ps.RightMargin

        $hdr = $sec.Headers.Item(1).Range        # wdHeaderFooterPrimary
        $hdr.Text = '%%TITLE%%'
        $hdr.Font.Name = 'Calibri'; $hdr.Font.Size = 9; $hdr.Font.Color = $muted
        $hdr.ParagraphFormat.Alignment = 2       # right

        $ftr = $sec.Footers.Item(1).Range
        $ftr.Text = "Gashpy Software | %%VERSION%% | %%DATE%%`tPage "
        $ftr.Font.Name = 'Calibri'; $ftr.Font.Size = 9; $ftr.Font.Color = $muted
        $ftr.ParagraphFormat.TabStops.ClearAll()
        [void]$ftr.ParagraphFormat.TabStops.Add($textWidth, 2)   # right tab
        # Append PAGE, " of ", NUMPAGES before the footer's closing paragraph mark.
        $story = $sec.Footers.Item(1)
        $at = $story.Range; $at.SetRange($at.End - 1, $at.End - 1)
        [void]$story.Range.Fields.Add($at, 33)                    # wdFieldPage
        $at = $story.Range; $at.SetRange($at.End - 1, $at.End - 1)
        $at.InsertAfter(' of ')
        $at = $story.Range; $at.SetRange($at.End - 1, $at.End - 1)
        [void]$story.Range.Fields.Add($at, 26)                    # wdFieldNumPages

        $sec.Headers.Item(2).Range.Text = ''     # wdHeaderFooterFirstPage: the cover stays clean
        $sec.Footers.Item(2).Range.Text = ''

        $doc.RemovePersonalInformation = $true   # no Windows user name in the template
        $doc.SaveAs2($target, 16)                # wdFormatDocumentDefault
    } finally {
        $doc.Close(0)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($doc)
    }
} finally {
    $word.Quit(0)
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output "Template written: $(Get-DocRelPath $repo $target)"
