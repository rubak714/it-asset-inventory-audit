<#
  Audits the hardware and network CMDB (switches, routers, firewalls,
  access points, WLAN controller, servers, laptops, printers) against the
  hardware inventory standard. Computes tracking accuracy and appends a line
  to the same accuracy-log.csv as the cloud module.

  Example:
    .\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"
    .\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"
#>

param(
  [string]$CsvPath = (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'data') 'hardware-inventory.csv'),
  [string]$Label   = 'hardware'
)

$ErrorActionPreference = 'Stop'
$reportDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$required = 'AssetID','DeviceType','Hostname','Site','Owner','CostCenter','Lifecycle','IPAddress','VLAN','WarrantyEnd'
$allowedType     = 'CoreSwitch','AccessSwitch','Router','Firewall','AccessPoint','WLANController','Server','Laptop','Printer'
$allowedLifecycle= 'Active','DecommissionPlanned','Retired'
$allowedVlan     = '10','20','30','40','99'

function Test-IPv4([string]$ip) {
  if ([string]::IsNullOrWhiteSpace($ip)) { return $false }
  $parts = $ip.Split('.')
  if ($parts.Count -ne 4) { return $false }
  foreach ($p in $parts) {
    if ($p -notmatch '^\d{1,3}$') { return $false }
    if ([int]$p -lt 0 -or [int]$p -gt 255) { return $false }
  }
  return $true
}

function Test-Mac([string]$m) {
  if ([string]::IsNullOrWhiteSpace($m)) { return $true }   # optional field
  return ($m -match '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
}

$devices = Import-Csv -Path $CsvPath

$rows = foreach ($d in $devices) {
  $issues = New-Object System.Collections.Generic.List[string]

  foreach ($f in $required) {
    if ([string]::IsNullOrWhiteSpace([string]$d.$f)) { $issues.Add("missing:$f") }
  }
  if (-not [string]::IsNullOrWhiteSpace($d.DeviceType) -and ($allowedType -notcontains $d.DeviceType)) {
    $issues.Add("invalid:DeviceType=$($d.DeviceType)")
  }
  if (-not [string]::IsNullOrWhiteSpace($d.Lifecycle) -and ($allowedLifecycle -notcontains $d.Lifecycle)) {
    $issues.Add("invalid:Lifecycle=$($d.Lifecycle)")
  }
  if (-not [string]::IsNullOrWhiteSpace($d.VLAN) -and ($allowedVlan -notcontains $d.VLAN)) {
    $issues.Add("invalid:VLAN=$($d.VLAN)")
  }
  if (-not [string]::IsNullOrWhiteSpace($d.IPAddress) -and -not (Test-IPv4 $d.IPAddress)) {
    $issues.Add("invalid:IPAddress=$($d.IPAddress)")
  }
  if (-not (Test-Mac $d.MACAddress)) {
    $issues.Add("invalid:MACAddress=$($d.MACAddress)")
  }

  [pscustomobject]@{
    AssetID    = $d.AssetID
    Hostname   = $d.Hostname
    DeviceType = $d.DeviceType
    Compliant  = ($issues.Count -eq 0)
    Issues     = ($issues -join '; ')
  }
}

$total = @($rows).Count
$ok    = @($rows | Where-Object Compliant).Count
$accuracy = if ($total) { [math]::Round(100 * $ok / $total, 1) } else { 0 }

$detail = Join-Path $reportDir "audit-$Label.csv"
$rows | Export-Csv -Path $detail -NoTypeInformation -Encoding UTF8

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

$rows | Format-Table AssetID, Hostname, DeviceType, Compliant, Issues -AutoSize
Write-Host ""
Write-Host "Audit '$Label': $ok of $total compliant" -ForegroundColor Cyan
$color = if ($accuracy -ge 90) { 'Green' } elseif ($accuracy -ge 50) { 'Yellow' } else { 'Red' }
Write-Host "Tracking accuracy: $accuracy %" -ForegroundColor $color
Write-Host "Detail report: $detail"
Write-Host "Log: $logPath"
