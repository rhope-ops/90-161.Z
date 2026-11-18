# PSScriptAnalyzer settings for the PowerShell under scripts/gov, read by scripts/lint.sh (-Settings).
# Severities Error and Warning (the separate parser pass in lint.sh reports parse errors); syntax checked against
# Windows PowerShell 5.1; Write-Host allowed.
@{
    Severity     = @('Error', 'Warning')
    Rules        = @{
        PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('5.1') }
    }
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
