<#
  Creates a resource group with eight demo assets.
  Three are tagged correctly, five have deliberately missing or invalid
  tags. That is the messy starting state for the audit.
  The resource types used (NSG, VNet, route table) are free.
#>

param(
  [string]$ResourceGroup = 'rg-itam-audit-demo',
  [string]$Location       = 'germanywestcentral'
)

$ErrorActionPreference = 'Stop'

Write-Host "Creating resource group '$ResourceGroup'..." -ForegroundColor Cyan
New-AzResourceGroup -Name $ResourceGroup -Location $Location -Force | Out-Null

# Kind: nsg | vnet | rt. Tags = target state, some deliberately messy.
$assets = @(
  [pscustomobject]@{ Name='nsg-web-prod';   Kind='nsg';  Tags=@{ Owner='r.islam';  CostCenter='KST-4711'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0001'; Lifecycle='Active' } }
  [pscustomobject]@{ Name='nsg-app-prod';   Kind='nsg';  Tags=@{ Owner='m.keller'; CostCenter='KST-4711'; Environment='Prod'; DataClassification='Confidential'; AssetID='AST-0002'; Lifecycle='Active' } }
  [pscustomobject]@{ Name='vnet-core-prod'; Kind='vnet'; Tags=@{ Owner='r.islam';  CostCenter='KST-4820'; Environment='Prod'; DataClassification='Internal';     AssetID='AST-0003'; Lifecycle='Active' } }
  # missing: DataClassification
  [pscustomobject]@{ Name='nsg-db-test';    Kind='nsg';  Tags=@{ Owner='s.wagner'; CostCenter='KST-4820'; Environment='Test'; AssetID='AST-0004'; Lifecycle='Active' } }
  # invalid: Environment='Production'
  [pscustomobject]@{ Name='vnet-dmz-test';  Kind='vnet'; Tags=@{ Owner='m.keller'; CostCenter='KST-4711'; Environment='Production'; DataClassification='Internal'; AssetID='AST-0005'; Lifecycle='Active' } }
  # missing: Owner and CostCenter
  [pscustomobject]@{ Name='rt-egress-prod'; Kind='rt';   Tags=@{ Environment='Prod'; DataClassification='Internal'; AssetID='AST-0006'; Lifecycle='Active' } }
  # invalid: DataClassification='Secret', missing: AssetID
  [pscustomobject]@{ Name='vnet-legacy';    Kind='vnet'; Tags=@{ Owner='r.islam'; CostCenter='KST-4999'; Environment='Dev'; DataClassification='Secret'; Lifecycle='DecommissionPlanned' } }
  # no tags at all
  [pscustomobject]@{ Name='rt-internal';    Kind='rt';   Tags=$null }
)

$i = 0
foreach ($a in $assets) {
  Write-Host "  creating $($a.Name) ($($a.Kind))" -ForegroundColor DarkGray
  switch ($a.Kind) {
    'nsg'  { $res = New-AzNetworkSecurityGroup -Name $a.Name -ResourceGroupName $ResourceGroup -Location $Location -Force }
    'vnet' { $res = New-AzVirtualNetwork      -Name $a.Name -ResourceGroupName $ResourceGroup -Location $Location -AddressPrefix "10.$i.0.0/16" -Force }
    'rt'   { $res = New-AzRouteTable          -Name $a.Name -ResourceGroupName $ResourceGroup -Location $Location -Force }
  }
  if ($a.Tags) {
    Update-AzTag -ResourceId $res.Id -Tag $a.Tags -Operation Replace | Out-Null
  }
  $i++
}

Write-Host "Done. 8 assets created: 3 compliant and 5 non-compliant." -ForegroundColor Green
Write-Host "Next: .\scripts\01-collect-inventory.ps1" -ForegroundColor Cyan
