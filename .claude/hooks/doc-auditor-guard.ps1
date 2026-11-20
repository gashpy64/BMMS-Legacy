#Requires -Version 7
<#
  doc-auditor-guard.ps1 - PreToolUse hook of the doc-auditor subagent only (declared in the
  "hooks" frontmatter of .claude/agents/doc-auditor.md, so it runs only while doc-auditor runs).
  It is a second layer: the main session's git status --short --ignored comparison before and
  after an audit run (Documents/Audit/README.md) stays in place. The doc-writer has its own guard
  (doc-writer-guard.ps1), which this file does not change.

  - Write: allowed only for one of the four files of the CURRENT run folder:
      Documents/Audit/DA-<8 digits>-<short SHA>/<name>.md
    where <name> is Audit-Summary, Coverage-Matrix, Gap-Register or Drift-Register and <short SHA>
    is what "git rev-parse --short HEAD" gives now (the guard runs it; a git failure blocks).
    The path is resolved first (.. , / and \), then the part below the project folder must match
    that pattern exactly, letter case included. So Documents/Audit/README.md, an earlier run
    folder (another SHA), any other file name or extension, Documents/Standards/, 8.3 short
    names, alternate data streams (a ":" after the drive) and any other path are blocked. No
    folder on the way (Documents, Audit, the run folder) may be a junction or symbolic link.
  - Edit, MultiEdit, NotebookEdit: always blocked (the auditor writes whole files only).
  - Read, Grep, Glob: allowed, except a target that is a file named connectionStrings.config (the
    .example is allowed; trailing dots and spaces, which Windows drops, are dropped first) or lies
    under a folder named Log or App_Data (anywhere). Any ":" after the drive letter (an NTFS stream
    such as "::$DATA") and any path part holding "~" and a digit (an 8.3 short name) are blocked.
    For Grep the path, the glob and the type are checked: the whole glob must be one pattern ending
    in one of the allowed file extensions (.cs .aspx .ascx .master .asax .sql .md .js .css .xml .xsl
    .ps1 .psm1 .json .csproj .sln .resx .html .htm) or one trailing {ext,ext} list of them, with no
    comma or whitespace outside it (the Grep tool splits a glob there into several ripgrep globs),
    and may not name Log or App_Data; a type must be one of cs,
    sql, md, js, css, xml, ps, json, html. A glob overrides ripgrep's .gitignore rules, so this
    keeps connectionStrings.config (.config is not allowed) and the logs (.txt is not allowed) out.
    A recursive Grep without a glob from a folder above them relies on ripgrep leaving out what
    .gitignore lists: BMMS/connectionStrings.config and Log/ are listed, App_Data only for
    PageAccessLog.txt (a later file in App_Data would be searched; .gitignore is outside the scope
    of step DA1: Known items). Glob lists names only, so a Glob is checked by its path alone.
  - Bash: allowed only for one read-only git command (log, diff, show, status, ls-files, blame,
    describe, for-each-ref, rev-parse), plain characters only, options checked token by token as
    in doc-writer-guard.ps1 (kept as a copy so that file stays unchanged). In addition: the options
    that make git read a file of the working tree are blocked (--contents and --ignore-revs-file of
    blame, -S of blame, among the blocked long options); and every token, the value after "=" of
    an option, the path after ":" of a revision and the rest of an attached short option are
    checked as Read paths are (protected names, Log and App_Data; a short name in a token that
    holds "/" or "\").
  - SubagentHandback (the agent's hand-back tool, which returns its record): allowed, by that exact
    name only (case-sensitive).
  Anything else is blocked: exit code 2, reason on stderr (Claude Code shows it to the agent).
  Fails closed: any internal error, input without a tool name, and any other unknown tool block (exit 2).
  The hook command in the frontmatter ends with "|| exit 2", so a failure to start (pwsh missing,
  #Requires, a parse error) blocks as well.
  Reads the hook input from stdin; writes nothing.
#>
$ErrorActionPreference = 'Stop'
function Block([string]$why) { [Console]::Error.WriteLine("doc-auditor guard: $why"); exit 2 }

# True when the path names a protected file: connectionStrings.config (also with a stream or a
# trailing dot or space; not the .example), or anything under a folder named Log or App_Data.
function Test-Protected([string]$path) {
    $parts = $path.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)
    foreach ($seg in $parts) {
        foreach ($sub in ($seg -split ':')) {
            $bare = $sub.TrimEnd('.', ' ')
            if ($bare -ieq 'Log' -or $bare -ieq 'App_Data') { return $true }
            if ($bare -like 'connectionStrings.config*' -and $bare -notlike 'connectionStrings.config.example') { return $true }
        }
    }
    $false
}

# Read, Grep and Glob paths: blocked when they name a protected file, use an NTFS stream (a ":"
# after the drive letter) or an 8.3 short name ("~" and a digit in a part).
function Test-ReadPath([string]$full, [string]$what) {
    if ($full.IndexOf(':', 2) -ge 0) { Block "a ':' after the drive letter (an NTFS stream) is not allowed: $full" }
    foreach ($seg in $full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($seg -match '~[0-9]') { Block "8.3 short names are not allowed: $full" }
    }
    if (Test-Protected $full) { Block "connectionStrings.config and files under Log or App_Data are not $what`: $full" }
}

try {
    $in = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if (-not $in -or -not $in.tool_name) { Block 'malformed input' }

    $project = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $in.cwd }
    if (-not $project) { Block 'project folder unknown' }
    $project = [IO.Path]::GetFullPath($project).TrimEnd('\', '/')
    $base = if ($in.cwd) { $in.cwd } else { $project }

    switch ($in.tool_name) {
        { $_ -in 'Edit', 'MultiEdit', 'NotebookEdit' } {
            Block 'doc-auditor does not edit files; it writes the four files of its run folder whole'
        }
        'Write' {
            $p = [string]$in.tool_input.file_path
            if (-not $p) { Block 'no file path' }
            $full = [IO.Path]::GetFullPath($p, $base)
            if (-not $full.StartsWith($project + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                Block "writing outside the project is not allowed: $full"
            }
            $sha = (& git -C $project rev-parse --short HEAD 2>$null)
            if ($LASTEXITCODE -ne 0 -or -not $sha) { Block 'git rev-parse --short HEAD failed, blocked' }
            $sha = ([string]$sha).Trim()
            if ($sha -cnotmatch '^[0-9a-f]{4,40}\z') { Block "unexpected HEAD SHA: $sha" }
            $rel = $full.Substring($project.Length + 1).Replace('/', '\')
            $pattern = '^Documents\\Audit\\DA-[0-9]{8}-' + $sha + '\\(Audit-Summary|Coverage-Matrix|Gap-Register|Drift-Register)\.md\z'
            if ($rel -cnotmatch $pattern) {
                Block "doc-auditor writes only Documents/Audit/DA-<yyyymmdd>-$sha/(Audit-Summary|Coverage-Matrix|Gap-Register|Drift-Register).md: $rel"
            }
            # No junction or symbolic link on the way
            $dir = $project
            foreach ($seg in ($rel.Split('\') | Select-Object -SkipLast 1)) {
                $dir = Join-Path $dir $seg
                if (Test-Path -LiteralPath $dir) {
                    $item = Get-Item -LiteralPath $dir -Force
                    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { Block "a junction or link on the way is not allowed: $dir" }
                }
            }
            if (Test-Path -LiteralPath $full) {
                $item = Get-Item -LiteralPath $full -Force
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { Block "the target is a link: $full" }
            }
            exit 0
        }
        'Read' {
            $p = [string]$in.tool_input.file_path
            if (-not $p) { Block 'no file path' }
            Test-ReadPath ([IO.Path]::GetFullPath($p, $base)) 'read'
            exit 0
        }
        'Grep' {
            $p = [string]$in.tool_input.path
            if ($p) { Test-ReadPath ([IO.Path]::GetFullPath($p, $base)) 'searched' }
            $g = [string]$in.tool_input.glob
            if ($g) {
                if ($g -match '(?i)(^|[\\/{,])(Log|App_Data)([\\/},]|$)' -or (Test-Protected $g)) { Block "Log, App_Data and connectionStrings.config are not searched: $g" }
                if ($g.IndexOf(':') -ge 0 -or $g -match '~[0-9]') { Block "this glob is not allowed: $g" }
                # The Grep tool splits a glob on commas and whitespace into several ripgrep globs, so the WHOLE glob
                # must have one allowed form: path characters, then "." and one allowed extension or one trailing
                # {ext,ext} list of allowed extensions. No whitespace, no comma outside that list.
                $ext = '(cs|aspx|ascx|master|asax|sql|md|js|css|xml|xsl|ps1|psm1|json|csproj|sln|resx|html|htm)'
                if ($g -cnotmatch ('^(?i)[A-Za-z0-9_*?./-]*\.(' + $ext + '|\{' + $ext + '(,' + $ext + ')*\})\z')) {
                    Block "a Grep glob must be one pattern ending in an allowed file extension or {ext,ext} list (.cs .aspx .ascx .master .asax .sql .md .js .css .xml .xsl .ps1 .psm1 .json .csproj .sln .resx .html .htm), with no comma or space outside it: $g"
                }
            }
            $t = [string]$in.tool_input.type
            if ($t -and $t -notin @('cs', 'sql', 'md', 'js', 'css', 'xml', 'ps', 'json', 'html')) { Block "this Grep type is not allowed: $t" }
            exit 0
        }
        'Glob' {
            $p = [string]$in.tool_input.path
            if ($p) { Test-ReadPath ([IO.Path]::GetFullPath($p, $base)) 'listed' }
            exit 0
        }
        'Bash' {
            $c = [string]$in.tool_input.command
            if ($c -notmatch '^\s*git\s+(log|diff|show|status|ls-files|blame|describe|for-each-ref|rev-parse)(\s|$)') {
                Block 'only read-only git commands are allowed (log, diff, show, status, ls-files, blame, describe, for-each-ref, rev-parse)'
            }
            if ($c -cnotmatch '^[A-Za-z0-9 ._/:=@%^~,+-]+\z') { Block 'only letters, digits, spaces and . _ / : = @ % ^ ~ , + - are allowed in the command' }
            $blockedLong = @('output', 'ext-diff', 'textconv', 'open-files-in-pager', 'exec', 'upload-pack', 'no-index',
                             'contents', 'ignore-revs-file')
            $isBlame = $c -match '^\s*git\s+blame(\s|$)'
            foreach ($tok in (($c.Trim() -split '\s+') | Select-Object -Skip 2)) {
                if ($tok -match '^--([A-Za-z][A-Za-z-]*)') {
                    $name = $Matches[1]
                    foreach ($b in $blockedLong) {
                        if ($b.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)) { Block "this git option is not allowed: $tok" }
                    }
                } elseif ($tok -cmatch '^-[A-Za-z]*O') {
                    Block "this git option is not allowed: $tok"
                } elseif ($isBlame -and $tok -cmatch '^-[A-Za-z]*S') {
                    # blame -S <file> reads a revisions file from the working tree
                    Block "this git option is not allowed: $tok"
                }
                # Every piece that can name a file: the token, the value after "=", the path after ":" of a
                # revision, the rest of an attached short option (-S<file>)
                $pieces = [System.Collections.Generic.List[string]]::new()
                $pieces.Add($tok)
                if ($tok.IndexOf('=') -ge 0) { $pieces.Add($tok.Substring($tok.IndexOf('=') + 1)) }
                if ($tok.IndexOf(':') -ge 0) { $pieces.Add($tok.Substring($tok.IndexOf(':') + 1)) }
                if ($tok -cmatch '^-[A-Za-z](.+)$') { $pieces.Add($Matches[1]) }
                foreach ($piece in $pieces) {
                    if (Test-Protected $piece) { Block "connectionStrings.config and files under Log or App_Data are not read: $tok" }
                    if ($piece -match '[\\/]' -and $piece -match '~[0-9]') { Block "8.3 short names are not allowed: $tok" }
                }
            }
            exit 0
        }
        # The agent's hand-back tool, by its exact name only (case-sensitive): it returns the record to the main
        # session and touches no file. Every other unknown tool stays blocked (DA1 gate B, 2026-11-20).
        { $_ -ceq 'SubagentHandback' } { exit 0 }
        default { Block "tool not allowed for doc-auditor: $($in.tool_name)" }
    }
} catch {
    Block "internal error, blocked: $($_.Exception.Message)"
}
