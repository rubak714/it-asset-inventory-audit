<#
  Pulls the inventory of the resource group and writes it as CSV.
  Each row is one asset with its tracking tags.
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo'
)

$ErrorActionPreference = 'Stop'
$reportDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$fields = 'Owner','CostCenter','Environment','DataClassification','AssetID','Lifecycle'

$rows = foreach ($r in Get-AzResource -ResourceGroupName $ResourceGroup) {
  $row = [ordered]@{
    Name = $r.Name
    Type = $r.ResourceType
    Location = $r.Location
  }
  foreach ($f in $fields) {
    $row[$f] = if ($r.Tags -and $r.Tags.ContainsKey($f)) { $r.Tags[$f] } else { '' }
  }
  [pscustomobject]$row
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $reportDir "inventory-$stamp.csv"
$rows | Export-Csv -Path $out -NoTypeInformation -Encoding UTF8

$rows | Format-Table -AutoSize
Write-Host "Inventory written to: $out" -ForegroundColor Green

# Note: to scale across many subscriptions, the same query runs through
# Azure Resource Graph, for example:
#   Search-AzGraph -Query "Resources | project name, type, resourceGroup, tags"
