<#
  Reconciles the hardware CMDB. Applies the known-good values to the records
  that failed the audit and writes a clean copy. Audit the clean file to see
  the after number.

  Corrections are keyed by AssetID, the same way a real reconciliation would
  set values from the source of truth (the actual device config).
#>

param(
  [string]$InPath  = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'data') 'hardware-inventory.csv'),
  [string]$OutPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'data') 'hardware-inventory-clean.csv')
)

$ErrorActionPreference = 'Stop'

# AssetID -> field:value corrections for the six broken records
$fixes = @{
  'AST-1010' = @{ Owner       = 'm.keller' }      # AP with no owner
  'AST-1011' = @{ WarrantyEnd = '2027-06-30' }    # laptop with no warranty date
  'AST-1012' = @{ IPAddress   = '10.0.10.13' }    # switch with invalid IP octet
  'AST-1013' = @{ VLAN        = '20' }            # laptop on out-of-plan VLAN 25
  'AST-1014' = @{ CostCenter  = 'KST-4820' }      # printer with no cost center
  'AST-1015' = @{ VLAN        = '40' }            # AP with no VLAN
}

$devices = Import-Csv -Path $InPath

foreach ($d in $devices) {
  if ($fixes.ContainsKey($d.AssetID)) {
    foreach ($field in $fixes[$d.AssetID].Keys) {
      Write-Host "  $($d.AssetID): set $field = $($fixes[$d.AssetID][$field])" -ForegroundColor DarkGray
      $d.$field = $fixes[$d.AssetID][$field]
    }
  }
}

$devices | Export-Csv -Path $OutPath -NoTypeInformation -Encoding UTF8

Write-Host "Clean inventory written to: $OutPath" -ForegroundColor Green
Write-Host "Now audit it:" -ForegroundColor Cyan
Write-Host "  .\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label ""hardware-after""" -ForegroundColor Cyan
