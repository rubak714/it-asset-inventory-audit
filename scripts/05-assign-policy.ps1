<#
  Optional. Creates the policy definition, assigns it to the resource group,
  and starts a compliance scan. The audit effect changes nothing on the
  resources, it only flags the non-compliant ones.

  Note: compliance evaluation runs asynchronously. After the scan it can take
  a few minutes before Get-AzPolicyState shows full results. The reliable
  metric comes from 02-audit-compliance.ps1.
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo'
)

$ErrorActionPreference = 'Stop'

$policyFile = Join-Path $PSScriptRoot '..\policies\require-tracking-tags.policy.json'
$json = Get-Content $policyFile -Raw | ConvertFrom-Json
$rule = $json.properties.policyRule | ConvertTo-Json -Depth 20

$def = New-AzPolicyDefinition `
  -Name 'require-tracking-tags' `
  -DisplayName $json.properties.displayName `
  -Description $json.properties.description `
  -Policy $rule `
  -Mode 'Indexed'

$scope = (Get-AzResourceGroup -Name $ResourceGroup).ResourceId

$assignment = New-AzPolicyAssignment `
  -Name 'assign-require-tracking-tags' `
  -DisplayName 'IT asset tracking tags required' `
  -PolicyDefinition $def `
  -Scope $scope

Write-Host "Policy assigned. Starting compliance scan..." -ForegroundColor Cyan
Start-AzPolicyComplianceScan -ResourceGroupName $ResourceGroup

Write-Host "Current compliance state (may be delayed):" -ForegroundColor Cyan
Get-AzPolicyState -ResourceGroupName $ResourceGroup |
  Where-Object { $_.PolicyAssignmentName -eq 'assign-require-tracking-tags' } |
  Select-Object ResourceType, ComplianceState, Timestamp |
  Format-Table -AutoSize
