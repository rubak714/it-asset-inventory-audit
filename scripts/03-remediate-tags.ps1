<#
  Cleans up the tags on all assets. Sets the correct target state per the
  asset management policy. Audit again afterwards.
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo'
)

$ErrorActionPreference = 'Stop'

# target state per asset (name -> full, valid tags)
$correct = @{
  'nsg-web-prod'   = @{ Owner='r.islam';  CostCenter='KST-4711'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0001'; Lifecycle='Active' }
  'nsg-app-prod'   = @{ Owner='m.keller'; CostCenter='KST-4711'; Environment='Prod'; DataClassification='Confidential'; AssetID='AST-0002'; Lifecycle='Active' }
  'vnet-core-prod' = @{ Owner='r.islam';  CostCenter='KST-4820'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0003'; Lifecycle='Active' }
  'nsg-db-test'    = @{ Owner='s.wagner'; CostCenter='KST-4820'; Environment='Test'; DataClassification='PersonalData'; AssetID='AST-0004'; Lifecycle='Active' }
  'vnet-dmz-test'  = @{ Owner='m.keller'; CostCenter='KST-4711'; Environment='Test'; DataClassification='Internal';     AssetID='AST-0005'; Lifecycle='Active' }
  'rt-egress-prod' = @{ Owner='s.wagner'; CostCenter='KST-4820'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0006'; Lifecycle='Active' }
  'vnet-legacy'    = @{ Owner='r.islam';  CostCenter='KST-4999'; Environment='Dev';  DataClassification='Internal';     AssetID='AST-0007'; Lifecycle='DecommissionPlanned' }
  'rt-internal'    = @{ Owner='s.wagner'; CostCenter='KST-4820'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0008'; Lifecycle='Active' }
}

foreach ($r in Get-AzResource -ResourceGroupName $ResourceGroup) {
  if ($correct.ContainsKey($r.Name)) {
    Write-Host "  fixing tags: $($r.Name)" -ForegroundColor DarkGray
    Update-AzTag -ResourceId $r.ResourceId -Tag $correct[$r.Name] -Operation Replace | Out-Null
  }
}

Write-Host "Remediation complete. Now audit again:" -ForegroundColor Green
Write-Host "  .\scripts\02-audit-compliance.ps1 -Label ""after""" -ForegroundColor Cyan
