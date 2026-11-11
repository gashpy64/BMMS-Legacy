#Requires -Version 7
<#
  tester-guard.ps1 - PreToolUse hook of the tester subagent only (declared in the "hooks"
  frontmatter of .claude/agents/tester.md, so it runs only while the tester runs).
  It is a second layer: the main session compares git status --short --ignored before and after
  the tester runs, and the runner itself refuses any database but BMMS_Quality.

  Allowed, and nothing else:
  - Bash: exactly one of these commands, as one line of plain text, run from the project folder:
      pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -CheckOnly
      pwsh -NoProfile -File Tests/_runner/Run-Tests.ps1 -Pack <name>[,<name>...]
          (a pack name is lower-case letters, digits and hyphens and starts with a letter or
          digit, so it can never be read as another switch of the runner)
      git status --short [--ignored] [--untracked-files=all]
    The whole command must match one of these patterns from its first to its last character,
    so no quote, $, backslash, pipe, redirection, separator or line break can be added.
    No sqlcmd: the runner runs the Check script and the fixture check itself, as bmms_tester,
    and saves their output in the results folder.
  - Read: only a file inside <project>/Tests/_results/ (results, screenshots, saved outputs).
    This is an allowed list, not a forbidden list: the local secrets (Tests/local/, every
    connectionStrings.config) are outside it whatever way a path to them is written.
  - Write / Edit: only a file inside <project>/Tests/_results/ (the tester has neither tool).
  A path is refused before it is resolved when it starts with \ or // (UNC and \?\ forms),
  has a colon anywhere but after the drive letter (alternate data streams) or has a ~ (8.3
  short names).
  - SubagentHandback: the harness tool that returns the record to the main session.
  Any other tool, and anything else, is blocked: exit code 2, the reason on stderr.
  Fails closed: an internal error, and input without a tool name, also block (exit 2). The hook
  command in the frontmatter ends with "|| exit 2", so a failure to start blocks as well.
  The tester needs no network tool; none is allowed here.
  Reads the hook input from stdin; writes nothing.
#>
$ErrorActionPreference = 'Stop'
function Block([string]$why) { [Console]::Error.WriteLine("tester guard: $why"); exit 2 }

try {
    $in = [Console]::In.ReadToEnd() | ConvertFrom-Json
    if (-not $in -or -not $in.tool_name) { Block 'malformed input' }

    $project = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $in.cwd }
    if (-not $project) { Block 'project folder unknown' }
    $project = [IO.Path]::GetFullPath($project).TrimEnd('\', '/')
    $sep = [IO.Path]::DirectorySeparatorChar
    $results = [IO.Path]::GetFullPath((Join-Path $project 'Tests\_results')) + $sep
    $local = [IO.Path]::GetFullPath((Join-Path $project 'Tests\local')) + $sep
    $base = if ($in.cwd) { $in.cwd } else { $project }

    # The full path of a file the tool names, or a block for a form that could hide where it points.
    function SafeFullPath([string]$p) {
        if (-not $p) { Block 'no file path' }
        if ($p -match '^(\\|//)') { Block 'paths that start with \ or // are not allowed' }
        if ($p.IndexOf('~') -ge 0) { Block 'paths with ~ are not allowed' }
        if ($p.Substring([Math]::Min(2, $p.Length)).IndexOf(':') -ge 0 -or ($p.Length -ge 2 -and $p[1] -eq ':' -and $p[0] -notmatch '[A-Za-z]')) { Block 'paths with a colon after the drive letter are not allowed' }
        if ($p.IndexOf([char]0) -ge 0) { Block 'malformed path' }
        return [IO.Path]::GetFullPath($p, $base)
    }
    function InResults([string]$full) { $full.StartsWith($results, [StringComparison]::OrdinalIgnoreCase) }

    switch ($in.tool_name) {
        'Bash' {
            $c = [string]$in.tool_input.command
            $cwd = [IO.Path]::GetFullPath($base).TrimEnd('\', '/')
            if ($cwd -ine $project) { Block "commands run from the project folder only (now: $cwd)" }
            $allowed = @(
                '^pwsh -NoProfile -File Tests/_runner/Run-Tests\.ps1 -CheckOnly\z',
                '^pwsh -NoProfile -File Tests/_runner/Run-Tests\.ps1 -Pack [a-z0-9][a-z0-9-]*(,[a-z0-9][a-z0-9-]*)*\z',
                '^git status --short( --ignored)?( --untracked-files=all)?\z'
            )
            foreach ($pattern in $allowed) { if ($c -cmatch $pattern) { exit 0 } }
            Block 'only the test runner (Run-Tests.ps1 -CheckOnly or -Pack) and git status --short are allowed, each written exactly as in the tester instructions'
        }
        { $_ -in 'Write', 'Edit', 'MultiEdit', 'NotebookEdit' } {
            $p = $in.tool_input.file_path
            if (-not $p) { $p = $in.tool_input.notebook_path }
            $full = SafeFullPath ([string]$p)
            if (-not (InResults $full)) { Block "the tester writes only inside Tests/_results/: $full" }
            exit 0
        }
        'Read' {
            $full = SafeFullPath ([string]$in.tool_input.file_path)
            if (-not (InResults $full)) { Block 'the tester reads only files inside Tests/_results/ (the results of its runs)' }
            exit 0
        }
        # The harness's own tool for returning the record to the main session: it touches no file and runs no command.
        'SubagentHandback' { exit 0 }
        default { Block "the tester does not use the tool $($in.tool_name)" }
    }
} catch {
    Block "internal error, blocked: $($_.Exception.Message)"
}
