#!/usr/bin/env bash
# Lint PowerShell in scripts/gov with PSScriptAnalyzer, including PS 5.1 syntax compatibility.
# Usage: scripts/lint.sh [FILE...]: no argument = every .ps1 and .psm1 under scripts/gov; with files = only those
# (the fast lane of tests/run.sh passes the changed ones). Needs: pwsh 7 and PSScriptAnalyzer (see docs/dev-setup.md).
# Exit 1 on any Error or Warning.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PSSA="${PSSA:-/opt/psmods/PSScriptAnalyzer/PSScriptAnalyzer.psd1}"
LINT_FILES="$(printf '%s\n' "$@")"; export LINT_FILES  # empty = every file
pwsh -NoProfile -Command "
Import-Module '$PSSA'
\$settings = @{
  Severity = @('Error','Warning')
  Rules = @{ PSUseCompatibleSyntax = @{ Enable = \$true; TargetVersions = @('5.1') } }
  ExcludeRules = @('PSAvoidUsingWriteHost')
}
\$files = if (\$env:LINT_FILES) { @(\$env:LINT_FILES -split \"\`n\" | Where-Object { \$_ } | ForEach-Object { Get-Item -LiteralPath \$_ }) } else { Get-ChildItem -Path scripts/gov -Recurse -Include *.ps1,*.psm1 }
\$all = foreach (\$f in \$files) {
  \$t = \$null; \$e = \$null
  [void][System.Management.Automation.Language.Parser]::ParseFile(\$f.FullName, [ref]\$t, [ref]\$e)
  foreach (\$x in \$e) { [pscustomobject]@{ RuleName='ParseError'; Severity='Error'; ScriptName=\$f.Name; Line=\$x.Extent.StartLineNumber; Message=\$x.Message } }
  Invoke-ScriptAnalyzer -Path \$f.FullName -Settings \$settings
}
\$all | Format-Table RuleName,Severity,ScriptName,Line,Message -AutoSize -Wrap | Out-String -Width 220
'LINT files=' + @(\$files).Count + ' findings=' + @(\$all).Count
if (@(\$all).Count -gt 0) { exit 1 }
"
