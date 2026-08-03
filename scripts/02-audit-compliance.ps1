<#
  Checks every asset against the asset management policy and computes
  the tracking accuracy (share of compliant assets).
  Writes a detail report and appends a line to accuracy-log.csv.

  Example:
    .\scripts\02-audit-compliance.ps1 -Label "before"
    .\scripts\02-audit-compliance.ps1 -Label "after"
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo',
  [string]$Label         = (Get-Date -Format 'yyyyMMdd-HHmmss')
)

$ErrorActionPreference = 'Stop'
$reportDir = Join-Path $PSScriptRoot '..\reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$required = 'Owner','CostCenter','Environment','DataClassification','AssetID','Lifecycle'
$allowed = @{
  Environment        = @('Prod','Test','Dev')
  DataClassification = @('Public','Internal','Confidential','PersonalData')
  Lifecycle          = @('Active','DecommissionPlanned','Retired')
}

$rows = foreach ($r in Get-AzResource -ResourceGroupName $ResourceGroup) {
  $tags = @{}
  if ($r.Tags) { foreach ($k in $r.Tags.Keys) { $tags[$k] = $r.Tags[$k] } }

  $issues = New-Object System.Collections.Generic.List[string]
  foreach ($key in $required) {
    if (-not $tags.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$tags[$key])) {
      $issues.Add("missing:$key")
    }
    elseif ($allowed.ContainsKey($key) -and ($allowed[$key] -notcontains $tags[$key])) {
      $issues.Add("invalid:$key=$($tags[$key])")
    }
  }

  [pscustomobject]@{
    Name      = $r.Name
    Type      = $r.ResourceType
    Compliant = ($issues.Count -eq 0)
    Issues    = ($issues -join '; ')
  }
}

$total = @($rows).Count
$ok    = @($rows | Where-Object Compliant).Count
$accuracy = if ($total) { [math]::Round(100 * $ok / $total, 1) } else { 0 }

# detail report
$detail = Join-Path $reportDir "audit-$Label.csv"
$rows | Export-Csv -Path $detail -NoTypeInformation -Encoding UTF8

# append summary line
$summary = [pscustomobject]@{
  Timestamp    = (Get-Date -Format 'o')
  Label        = $Label
  Total        = $total
  Compliant    = $ok
  NonCompliant = ($total - $ok)
  AccuracyPct  = $accuracy
}
$logPath = Join-Path $reportDir 'accuracy-log.csv'
if (Test-Path $logPath) {
  $summary | Export-Csv -Path $logPath -NoTypeInformation -Append -Encoding UTF8
} else {
  $summary | Export-Csv -Path $logPath -NoTypeInformation -Encoding UTF8
}

# output
$rows | Format-Table Name, Compliant, Issues -AutoSize
Write-Host ""
Write-Host "Audit '$Label': $ok of $total compliant" -ForegroundColor Cyan
$color = if ($accuracy -ge 90) { 'Green' } elseif ($accuracy -ge 50) { 'Yellow' } else { 'Red' }
Write-Host "Tracking accuracy: $accuracy %" -ForegroundColor $color
Write-Host "Detail report: $detail"
Write-Host "Log: $logPath"
