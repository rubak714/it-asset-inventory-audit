<#
  Deletes the resource group and all demo assets.
  After this, nothing costs money.
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo'
)

$ErrorActionPreference = 'Stop'

$confirm = Read-Host "Really delete resource group '$ResourceGroup'? (yes/no)"
if ($confirm -eq 'yes') {
  Remove-AzResourceGroup -Name $ResourceGroup -Force
  Write-Host "Deleted." -ForegroundColor Green
} else {
  Write-Host "Cancelled. Nothing deleted." -ForegroundColor Yellow
}
