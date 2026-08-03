# 🗂️ azure-itam-compliance

IT asset management and compliance auditing across two domains: Azure cloud resources and a physical hardware and network estate.

Both use the same audit pattern. Inventory the assets, check each one against a policy, report what is non-compliant, fix it, and measure tracking accuracy again. Every run writes to one shared log.

- ☁️ Module 1: Azure resource governance (tagging policy on cloud resources)
- 🌐 Module 2: Hardware and network CMDB (switches, routers, firewalls, access points, WLAN controller, servers, laptops, printers) plus a documented LAN, VLAN plan, and Wi-Fi

Region for the cloud module: Germany West Central (DSGVO data residency). The Azure resources it creates (NSGs, VNets, route tables) are free.

## 🚧 Status

Work in progress. Building it up module by module.

- [x] ☁️ Module 1: Azure resource governance
- [ ] 🌐 Module 2: Hardware and network CMDB
- [ ] 📡 Network documentation and lab build

## ☁️ Module 1: Azure resource governance

I keep the six tracking fields as tags on the resource itself, so the record travels with the asset instead of living in a spreadsheet that drifts. The full policy is in `config/tagging-standard.md`.

Everything runs in PowerShell. The Az module and a login are assumed.

```powershell
# one time
Install-Module Az -Scope CurrentUser        # if not already installed
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"

# 1. create demo assets with intentionally messy tags
.\scripts\00-setup-demo-assets.ps1

# 2. pull the inventory
.\scripts\01-collect-inventory.ps1

# 3. audit BEFORE the fix  ->  note the accuracy
.\scripts\02-audit-compliance.ps1 -Label "before"

# 4. fix the tags / reconcile the assets
.\scripts\03-remediate-tags.ps1

# 5. audit AFTER the fix  ->  note the accuracy
.\scripts\02-audit-compliance.ps1 -Label "after"

# 6. optional: assign the Azure Policy (audit effect)
.\scripts\05-assign-policy.ps1

# 7. clean up so nothing costs money
.\scripts\04-teardown.ps1
```

The setup script builds a deliberately broken estate: eight resources, three tagged correctly and five with real faults. Starting from a clean estate would prove nothing, so I seed the kind of drift that actually happens.

The audit records a typed reason per finding (`missing:Owner`, `invalid:Environment=Production`) rather than a bare pass or fail, because whoever picks up the report needs to know what to fix.

The resource types used are NSG, VNet and route table. Those are free, so the lab can be rebuilt as often as needed. Region is Germany West Central for DSGVO data residency.

### 🛡️ Policy as code

`policies/require-tracking-tags.policy.json` expresses the same standard as an Azure Policy definition. The audit script is a point-in-time check I have to remember to run; the policy hands the rules to the platform so violations get flagged continuously, including on resources created after the audit.

The effect is `audit`, not `deny`. Deny would block deployments, which is the right end state but the wrong place to start.

## 📄 License

MIT. See `LICENSE`.
