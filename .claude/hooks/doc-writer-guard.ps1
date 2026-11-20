#Requires -Version 7
<#
  doc-writer-guard.ps1 - PreToolUse hook of the doc-writer subagent only (declared in the
  "hooks" frontmatter of .claude/agents/doc-writer.md, so it runs only while doc-writer runs).
  It is a second layer: the main session's git status --short --ignored comparison before and
  after doc-writer runs (CLAUDE.md, documentation stage) stays in place.

  - Write / Edit: allowed only for a file inside <project>/Documents/, and not inside
    Documents/Export/ or Documents/_build/.
  - Bash: allowed only for one read-only git command (log, diff, show, status, ls-files, blame,
    describe, for-each-ref, rev-parse; not grep, which can start a pager program - doc-writer
    has the Grep tool). The command may hold only plain characters (letters, digits, spaces and
    . _ / : = @ % ^ ~ , + -): no quote, backslash, $, brace, glob, pipe, redirection or
    separator, so the shell changes nothing before git reads it.
    Every option is checked as a token: a long option is blocked when it is a prefix of a
    blocked option (git accepts shortened long options, for example --outp for --output), and a
    bundle of short options is blocked when it contains O (for example -iO).
  Anything else is blocked: exit code 2, reason on stderr (Claude Code shows it to the agent).
  Fails closed: any internal error, and input without a tool name, also blocks (exit 2). The
  hook command in the frontmatter ends with "|| exit 2", so a failure to start (pwsh missing,
  #Requires, a parse error) blocks as well.
  Note: git status may refresh git's own index file (.git/index) when file times are stale;
  that is git metadata only, no tracked or working file changes.
  Reads the hook input from stdin; writes nothing.
#>
$ErrorActionPreference = 'Stop'
function Block([string]$why) { [Console]::Error.WriteLine("doc-writer guard: $why"); exit 2 }

try {
    $in = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if (-not $in -or -not $in.tool_name) { Block 'malformed input' }

    $project = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $in.cwd }
    if (-not $project) { Block 'project folder unknown' }
    $project = [IO.Path]::GetFullPath($project)
    $sep = [IO.Path]::DirectorySeparatorChar
    $docs = [IO.Path]::GetFullPath((Join-Path $project 'Documents')) + $sep
    $noWrite = @(
        ([IO.Path]::GetFullPath((Join-Path $project 'Documents\Export')) + $sep),
        ([IO.Path]::GetFullPath((Join-Path $project 'Documents\_build')) + $sep)
    )

    switch ($in.tool_name) {
        { $_ -in 'Write', 'Edit', 'MultiEdit', 'NotebookEdit' } {
            $p = $in.tool_input.file_path
            if (-not $p) { $p = $in.tool_input.notebook_path }
            if (-not $p) { Block 'no file path' }
            $base = if ($in.cwd) { $in.cwd } else { $project }
            $full = [IO.Path]::GetFullPath($p, $base)
            if (-not $full.StartsWith($docs, [StringComparison]::OrdinalIgnoreCase)) { Block "writing outside Documents/ is not allowed: $full" }
            foreach ($d in $noWrite) {
                if ($full.StartsWith($d, [StringComparison]::OrdinalIgnoreCase)) { Block "Documents/Export/ and Documents/_build/ are not written by doc-writer: $full" }
            }
            exit 0
        }
        'Bash' {
            $c = [string]$in.tool_input.command
            if ($c -notmatch '^\s*git\s+(log|diff|show|status|ls-files|blame|describe|for-each-ref|rev-parse)(\s|$)') {
                Block 'only read-only git commands are allowed (log, diff, show, status, ls-files, blame, describe, for-each-ref, rev-parse)'
            }
            # Only plain characters: no quotes, backslash, $, braces, glob, pipe, redirection,
            # separator or line break, so the shell removes or expands nothing and git receives
            # exactly the tokens checked below. (HEAD~1 and %h stay possible; HEAD@{1} and a
            # quoted --format with spaces do not.)
            if ($c -cnotmatch '^[A-Za-z0-9 ._/:=@%^~,+-]+\z') { Block 'only letters, digits, spaces and . _ / : = @ % ^ ~ , + - are allowed in the command' }
            $blockedLong = @('output', 'ext-diff', 'textconv', 'open-files-in-pager', 'exec', 'upload-pack', 'no-index')
            foreach ($tok in (($c.Trim() -split '\s+') | Select-Object -Skip 2)) {
                $t = $tok
                if ($t -match '^--([A-Za-z][A-Za-z-]*)') {
                    $name = $Matches[1]
                    foreach ($b in $blockedLong) {
                        if ($b.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)) { Block "this git option is not allowed: $t" }
                    }
                } elseif ($t -cmatch '^-[A-Za-z]*O') {
                    # Defence in depth: -O opens files in a program for git grep (refused above);
                    # for diff, log and show it only names an order file, so nothing is lost.
                    Block "this git option is not allowed: $t"
                }
            }
            exit 0
        }
        default { exit 0 }
    }
} catch {
    Block "internal error, blocked: $($_.Exception.Message)"
}
