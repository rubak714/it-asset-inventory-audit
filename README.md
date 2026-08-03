# 🗂️ azure-itam-compliance

IT asset management and compliance auditing across two domains: Azure cloud resources and a physical hardware and network estate.

Both use the same audit pattern. Inventory the assets, check each one against a policy, report what is non-compliant, fix it, and measure tracking accuracy again. Every run writes to one shared log.

- ☁️ Module 1: Azure resource governance (tagging policy on cloud resources)
- 🌐 Module 2: Hardware and network CMDB (switches, routers, firewalls, access points, WLAN controller, servers, laptops, printers) plus a documented LAN, VLAN plan, and Wi-Fi

Region for the cloud module: Germany West Central (DSGVO data residency). The Azure resources it creates (NSGs, VNets, route tables) are free.

## 🚧 Status

Work in progress. Building it up module by module.

- [x] ☁️ Module 1: Azure resource governance
- [x] 🌐 Module 2: Hardware and network CMDB
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

## 🌐 Module 2: Hardware and network inventory

No cloud login needed and no Az module. This module works on a CSV CMDB of physical devices, because most asset management work is physical. The rules are in `config/hardware-inventory-standard.md`.

```powershell
# 1. audit the CMDB BEFORE the fix  ->  note the accuracy
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"

# 2. reconcile the broken records (writes a clean copy)
.\scripts\11-remediate-hardware.ps1

# 3. audit AFTER the fix  ->  note the accuracy
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"
```

The seed CMDB holds 15 devices: a core switch, two access switches, an edge router, a perimeter firewall, a WLAN controller, three access points, a file server, two laptops and a printer. Every row maps to a device in the topology, so the inventory describes a network that exists rather than a list of plausible hostnames.

Six records are broken on purpose, and each fault is one I would expect to actually find:

| Asset | Fault |
|---|---|
| `AST-1010` | access point in reception with no owner |
| `AST-1011` | laptop with no warranty end date |
| `AST-1012` | access switch recorded as `10.0.10.300`, not a valid address |
| `AST-1013` | laptop on VLAN 25, which is not in the plan |
| `AST-1014` | printer with no cost center |
| `AST-1015` | access point with no VLAN at all |

### 🔍 The network checks

Beyond the required fields, the audit does three things a generic spreadsheet validator would miss.

IPv4 is parsed octet by octet rather than pattern matched, so `10.0.10.300` is caught as out of range instead of slipping past a loose regex. VLAN is checked against the actual plan, so a device on VLAN 25 is a finding even though 25 is a perfectly legal VLAN number in general. MAC is optional, but a malformed one still fails, because a half-typed MAC is worse than an empty field.

Those three are what turn this from a spreadsheet linter into something that catches documentation drifting away from the real network.

### 🔁 Why reconciliation writes a new file

`11-remediate-hardware.ps1` keys its corrections by AssetID and writes a clean copy rather than editing the seed in place.

The before state has to stay reproducible, otherwise the 60% cannot be re-measured by anyone checking my work. And a script that rewrites the source inventory on every run is how one bad assumption becomes a permanently corrupted CMDB.

## 📊 The metric (tracking accuracy)

Tracking accuracy is the share of assets that fully comply with the policy: all required fields present, and the constrained values valid.

| Module | Assets | Before | After |
|--------|--------|--------|-------|
| ☁️ Cloud | 8 | 3/8 = **37.5%** | 8/8 = **100%** |
| 🌐 Hardware | 15 | 9/15 = **60%** | 15/15 = **100%** |

Both numbers are measured, not projected. The cloud module was run in Azure Cloud Shell against a live subscription in Germany West Central. The hardware module was run locally. Both appended to the same log:

```
"Timestamp","Label","Total","Compliant","NonCompliant","AccuracyPct"
"2026-08-03T20:23:39.5811949+00:00","before","8","3","5","37.5"
"2026-08-03T20:24:57.5388757+00:00","after","8","8","0","100"
"2026-08-04T02:35:18.1292292+06:00","hardware-before","15","9","6","60"
"2026-08-04T02:35:18.1965662+06:00","hardware-after","15","15","0","100"
```

The offsets differ, `+00:00` on the cloud rows and `+06:00` on the hardware rows, because those runs happened on two different machines. The log is append-only, so runs accumulate into one record instead of overwriting each other.

## 🧾 Evidence

Everything above is backed by a generated file in `reports/`.

| File | What it holds |
|---|---|
| `reports/accuracy-log.csv` | Every audit run, both modules, timestamped |
| `reports/audit-before.csv` | Cloud, per-resource findings before remediation |
| `reports/audit-after.csv` | Cloud, same eight resources after |
| `reports/audit-hardware-before.csv` | Hardware, per-device findings before reconciliation |
| `reports/audit-hardware-after.csv` | Hardware, same fifteen devices after |

The detail reports are the more useful artifact. They do not just say five resources failed, they say which check each one failed and why:

```
"vnet-dmz-test","Microsoft.Network/virtualNetworks","False","invalid:Environment=Production"
"rt-internal","Microsoft.Network/routeTables","False","missing:Owner; missing:CostCenter; missing:Environment; missing:DataClassification; missing:AssetID; missing:Lifecycle"
```

### 🖥️ The cloud run

Building the deliberately messy estate:

![Creating the demo estate](images/setup-demo-assets.png)

The audit finding all five seeded faults, and scoring 37.5%:

![Audit before remediation](images/audit-before.png)

`vnet-dmz-test` is the line worth reading twice. `Environment=Production` is present, so a check that only asked "is this field filled in" would pass it. It fails here because the standard allows `Prod`, `Test`, `Dev` and nothing else. That is the difference between a completeness check and a compliance audit.

The log after both runs:

![Accuracy log](images/accuracy-log.png)

The inventory pull, showing all eight resources fully tagged after remediation:

![Inventory](images/collect-inventory.png)

## 📄 License

MIT. See `LICENSE`.
