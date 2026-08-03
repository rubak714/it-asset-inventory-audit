# 🗂️ IT Asset Inventory and Compliance Audit

![Azure](https://img.shields.io/badge/Azure-Germany%20West%20Central-0078D4?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Packet Tracer](https://img.shields.io/badge/Cisco%20Packet%20Tracer-9.0.0-1BA0D7?logo=cisco&logoColor=white)
![Azure Policy](https://img.shields.io/badge/Azure%20Policy-as%20code-0078D4?logo=microsoftazure&logoColor=white)
![Evidence](https://img.shields.io/badge/evidence-4%20measured%20runs-success)
![Status](https://img.shields.io/badge/status-Wi--Fi%20pending-orange)
![License](https://img.shields.io/badge/license-MIT-green)

I audit two estates against one policy: Azure cloud resources, and a physical hardware and network estate. Same six fields, same engine, same log.

<p align="center">
  <img src="network/screenshots/00-final-pkt-screenshot.png" alt="The LAN I built and verified in Packet Tracer" width="700">
</p>

<p align="center">
  <em>The LAN behind my CMDB. Eight devices, seven links, five VLANs. I built and verified all of it.<br>
  Every device maps to an AssetID in <a href="data/hardware-inventory.csv">my inventory</a>, and the lab file is <a href="network/koeln-hq-lan.pkt">in this repo</a> so you can open it.</em>
</p>

> [!NOTE]
> This is a portfolio project on a lab estate, not production work. What is real is the measurement: four audit runs, timestamped, in [`reports/accuracy-log.csv`](reports/accuracy-log.csv). I would rather say that up front than let you assume more.

## 📄 Table of Contents

- [🗺️ Architectural design](#-architectural-design)
- [🏛️ Stack](#-stack)
- [📊 Honest metrics](#-honest-metrics)
- [☁️ Module 1: cloud resource governance](#-module-1-cloud-resource-governance)
- [🌐 Module 2: hardware and network CMDB](#-module-2-hardware-and-network-cmdb)
- [📡 The network lab](#-the-network-lab)
- [🧾 Evidence](#-evidence)
- [📁 Repository layout](#-repository-layout)
- [🔒 Security approach](#-security-approach)
- [🚫 Things I considered and chose not to do](#-things-i-considered-and-chose-not-to-do)
- [🤖 How I built this](#-how-i-built-this)
- [🤝 Contributing](#-contributing)

## 🗺️ Architectural design

I run one audit engine over two estates and write to one log.

```
   ☁️ AZURE ESTATE                      🌐 PHYSICAL ESTATE
   8 resources, tagged                  15 devices, CSV CMDB
          │                                     │
          ▼                                     ▼
   ┌─────────────────┐                 ┌─────────────────┐
   │ tagging         │                 │ hardware        │
   │ standard        │                 │ standard        │
   └────────┬────────┘                 └────────┬────────┘
            │      SAME SIX REQUIRED FIELDS     │
            └──────────────┬────────────────────┘
                           ▼
                  ┌──────────────────┐
                  │   AUDIT ENGINE   │  present? valid? in plan?
                  └────────┬─────────┘
                           ▼
                  reports/accuracy-log.csv
                     append-only, timestamped
```

I use the same six fields on both sides: `Owner`, `CostCenter`, `Environment`, `DataClassification`, `AssetID`, `Lifecycle`.

- ☁️ Cloud resources hold them as **tags**
- 🌐 Physical devices hold them as **CSV columns**

That is the decision everything else rests on. Asset management is one discipline, not two, so I score a switch and a virtual network the same way and put both results in the same file.

The loop is four steps, and I run it identically on both estates:

| Step | What I do |
|---|---|
| 1. Inventory | List every asset that exists |
| 2. Audit | Check each one against the written policy, score it |
| 3. Remediate | Fix the broken records |
| 4. Re-audit | Measure again, prove the number moved |

Step 4 is what turns a claim into evidence. Anyone can say they improved records. I can show a before and an after in a timestamped file.

## 🏛️ Stack

| Layer | What I chose | Why I chose it |
|---|---|---|
| Automation | PowerShell 5.1 and 7 | I want these to run on a plain Windows desktop with nothing installed, and in Cloud Shell |
| Cloud | Azure, Germany West Central | DSGVO data residency, and NSG, VNet and route table are free |
| Policy as code | Azure Policy, `audit` effect | Flags violations continuously instead of only when I remember to run a script |
| Network lab | Cisco Packet Tracer 9.0.0 | Free, and the only free simulator that does Wi-Fi |
| Device OS | Cisco IOS 15.0 and 15.1 | Real config syntax, not a toy abstraction |
| Records | CSV | A CMDB does not need a product. One row per device, and I can grep and diff it |

## 📊 Honest metrics

I define tracking accuracy as the share of assets that fully comply: every required field present, and every constrained value valid.

| Module | Assets | Before | After | Source |
|--------|--------|--------|-------|--------|
| ☁️ Cloud | 8 | 3/8 = **37.5%** | 8/8 = **100%** | [`accuracy-log.csv`](reports/accuracy-log.csv) |
| 🌐 Hardware | 15 | 9/15 = **60%** | 15/15 = **100%** | [`accuracy-log.csv`](reports/accuracy-log.csv) |

<p align="center">
  <img src="images/accuracy-log.png" alt="The accuracy log after both runs" width="640">
</p>

I measured both. The cloud module ran in Azure Cloud Shell against my live subscription. The hardware module ran on my own machine.

> [!IMPORTANT]
> A jump to 100% on a lab estate shows the method and proves little about experience. The estate is small and I seeded the faults myself. What is genuinely real: the measurement, the fact anyone can reproduce it, and the two faults the lab found that I did not plant.

The timestamps carry different offsets, `+00:00` on the cloud rows and `+06:00` on the hardware rows, because those runs really did happen on two different machines. The log is append-only, so runs stack up instead of overwriting each other.

## ☁️ Module 1: cloud resource governance

I keep the six tracking fields as tags on the resource itself, so the record travels with the asset instead of sitting in a spreadsheet that drifts. My full policy is in [`config/tagging-standard.md`](config/tagging-standard.md).

```powershell
# one time
Install-Module Az -Scope CurrentUser
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"

.\scripts\00-setup-demo-assets.ps1                      # seed a messy estate
.\scripts\01-collect-inventory.ps1                      # pull the inventory
.\scripts\02-audit-compliance.ps1 -Label "before"       # audit  ->  37.5%
.\scripts\03-remediate-tags.ps1                         # fix the tags
.\scripts\02-audit-compliance.ps1 -Label "after"        # audit  ->  100%
.\scripts\05-assign-policy.ps1                          # optional: Azure Policy
.\scripts\04-teardown.ps1                               # delete everything
```

> [!WARNING]
> In Azure Cloud Shell, pick **PowerShell** from the dropdown, not Bash, and use forward slashes: `./scripts/00-setup-demo-assets.ps1`. I lost time to this. Bash cannot run `.ps1` files at all and tells you nothing useful when it fails. See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

I build the starting estate broken on purpose: three resources tagged correctly, five with real faults. Starting clean would score 100% straight away and demonstrate nothing.

<p align="center">
  <img src="images/audit-before.png" alt="My audit catching all five seeded faults" width="760">
</p>

Read the `vnet-dmz-test` line twice. `Environment=Production` is **present**, so a check that only asked whether the field was filled in would pass it. It fails because my standard allows `Prod`, `Test`, `Dev` and nothing else.

That is why I validate values rather than counting populated fields, and it is the difference between a completeness check and a compliance audit.

I also make every finding typed, `missing:Owner` or `invalid:Environment=Production`, never a bare pass or fail. Whoever picks up the report has to know what to fix.

**Policy as code.** [`policies/require-tracking-tags.policy.json`](policies/require-tracking-tags.policy.json) hands the same rules to Azure, so resources created after my audit get flagged too. I set the effect to `audit` rather than `deny`, for the reason in [Security approach](#-security-approach).

## 🌐 Module 2: hardware and network CMDB

This one needs no cloud login and no Az module, because most asset management work is physical. My rules are in [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md), my data in [`data/hardware-inventory.csv`](data/hardware-inventory.csv).

```powershell
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"
.\scripts\11-remediate-hardware.ps1
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"
```

I modelled fifteen devices: a core switch, two access switches, an edge router, a perimeter firewall, a WLAN controller, three access points, a file server, two laptops and a printer.

Six records are broken on purpose, and I picked faults I would actually expect to find:

| Asset | Fault I planted |
|---|---|
| `AST-1010` | access point in reception with no owner |
| `AST-1011` | laptop with no warranty end date |
| `AST-1012` | access switch recorded as `10.0.10.300`, not a valid address |
| `AST-1013` | laptop on VLAN 25, which is not in my plan |
| `AST-1014` | printer with no cost center |
| `AST-1015` | access point with no VLAN at all |

Three of my checks go beyond what a spreadsheet validator would do:

- **I parse IPv4 octet by octet** rather than pattern matching, so `10.0.10.300` is caught as out of range instead of slipping past a loose regex
- **I check VLAN against my actual plan**, so VLAN 25 is a finding even though 25 is a perfectly legal VLAN number in general
- **I validate MAC only when present**, because the field is optional but a half-typed MAC is worse than an empty one

**Why my reconciliation writes a new file.** [`11-remediate-hardware.ps1`](scripts/11-remediate-hardware.ps1) keys corrections by AssetID and writes a clean copy instead of editing the seed:

- I need the before state to stay reproducible, or nobody can re-measure my 60% and check my work
- A script that rewrites the source inventory on every run is how one bad assumption becomes a permanently corrupted CMDB

## 📡 The network lab

My hardware module would be a spreadsheet exercise if I had invented the devices. I did not.

Design: [`docs/network-topology.md`](docs/network-topology.md) · Build steps: [`docs/lab-build.md`](docs/lab-build.md) · Exported configs: [`network/configs/`](network/configs/) · Evidence index: [`network/README.md`](network/README.md)

| VLAN | Name | Use | Subnet | Gateway |
|------|------|-----|--------|---------|
| 10 | MGMT | switches, router, APs, controller | 10.0.10.0/24 | 10.0.10.1 |
| 20 | CLIENTS | laptops, printers | 10.0.20.0/24 | 10.0.20.1 |
| 30 | SERVERS | file and app servers | 10.0.30.0/24 | 10.0.30.1 |
| 40 | WIFI | wireless clients | 10.0.40.0/24 | 10.0.40.1 |
| 99 | NATIVE | trunk native and parking | not routed | none |

I made every switch-to-switch and switch-to-router link an 802.1Q trunk with an explicit allowed VLAN list and 99 as native. Client ports are untagged access ports in VLAN 20, and I configured the whole block per floor so anyone can plug in anywhere.

<p align="center">
  <img src="network/screenshots/07-core-show-interfaces-trunk.png" alt="show interfaces trunk on my core switch" width="700">
</p>

### 🎯 How I know it actually routes

<p align="center">
  <img src="network/screenshots/03-ping-server-cross-vlan.png" alt="Cross-VLAN ping returning TTL 127" width="560">
</p>

Look at the TTL.

| My ping from `nb-1123` | TTL | What it means |
|---|---|---|
| `10.0.20.1` gateway | 255 | the router answered directly |
| `10.0.20.52` other laptop | 128 | same VLAN, never routed |
| `10.0.20.80` printer | 128 | same VLAN |
| `10.0.30.10` file server | **127** | **routed exactly once** |

Replies start at TTL 128, and every router that forwards one subtracts 1. A reply coming back at 127 is the packet itself telling me exactly one router handled it.

My diagram asks you to believe it. A TTL of 127 does not.

<details>
<summary>📸 All ten of my verification captures</summary>

<br>

| Capture | What it proves |
|---|---|
| [`00-final-pkt-screenshot.png`](network/screenshots/00-final-pkt-screenshot.png) | Topology, every link green |
| [`01-ipconfig-nb-1123.png`](network/screenshots/01-ipconfig-nb-1123.png) | DHCP gave `10.0.20.51`, matching `AST-1011` |
| [`02-ping-gateway.png`](network/screenshots/02-ping-gateway.png) | Gateway reachable, TTL 255 |
| [`03-ping-server-cross-vlan.png`](network/screenshots/03-ping-server-cross-vlan.png) | Inter-VLAN routing, TTL 127 |
| [`04-ping-across-access-switches.png`](network/screenshots/04-ping-across-access-switches.png) | Across the core to the other floor |
| [`05-ping-printer.png`](network/screenshots/05-ping-printer.png) | Printer at its static address |
| [`06-core-show-vlan-brief.png`](network/screenshots/06-core-show-vlan-brief.png) | Five VLANs, server port in VLAN 30 |
| [`07-core-show-interfaces-trunk.png`](network/screenshots/07-core-show-interfaces-trunk.png) | Three trunks, native 99 |
| [`08-router-show-ip-interface-brief.png`](network/screenshots/08-router-show-ip-interface-brief.png) | Five subinterfaces up |
| [`09-router-show-ip-dhcp-binding.png`](network/screenshots/09-router-show-ip-dhcp-binding.png) | Which MAC received which address |

<p align="center">
  <img src="network/screenshots/09-router-show-ip-dhcp-binding.png" alt="DHCP bindings on my router" width="620">
</p>

This one is the router's own record of what it leased. `10.0.20.51` and `10.0.20.52` went to my two laptops, matching `AST-1011` and `AST-1013` without me touching anything.

</details>

### 🔍 What building it changed

Building the lab was not a formality. It found two faults in configs that read perfectly on paper:

- **I had the printer on the wrong floor.** Cabled to the first-floor switch when my CMDB puts it in `OG2-Flur`. No field-level audit could ever catch this, because which switch a device hangs off is not one of my checked fields.
- **My DHCP pool could hand out the printer's static address.** The pool covered all of `10.0.20.0/24` and excluded only `.1` to `.50`, while the printer sits on `.80`. It would have worked perfectly until the day a new device joined, which is the worst way for something to break.

I put both fixes in the exported configs and wrote them up as corrections in [`docs/lab-build.md`](docs/lab-build.md) rather than quietly folding them in.

## 🧾 Evidence

Every number above has a generated file behind it.

| File | What it holds |
|---|---|
| [`reports/accuracy-log.csv`](reports/accuracy-log.csv) | Every run I did, both modules, timestamped |
| [`reports/audit-before.csv`](reports/audit-before.csv) | Cloud, per-resource findings before remediation |
| [`reports/audit-after.csv`](reports/audit-after.csv) | Cloud, same eight resources after |
| [`reports/audit-hardware-before.csv`](reports/audit-hardware-before.csv) | Hardware, per-device findings before reconciliation |
| [`reports/audit-hardware-after.csv`](reports/audit-hardware-after.csv) | Hardware, same fifteen devices after |

```
"Timestamp","Label","Total","Compliant","NonCompliant","AccuracyPct"
"2026-08-03T20:23:39.5811949+00:00","before","8","3","5","37.5"
"2026-08-03T20:24:57.5388757+00:00","after","8","8","0","100"
"2026-08-04T02:35:18.1292292+06:00","hardware-before","15","9","6","60"
"2026-08-04T02:35:18.1965662+06:00","hardware-after","15","15","0","100"
```

I find the detail reports more useful than the summary. They do not just say five resources failed, they say which check each one failed and why:

```
"vnet-dmz-test","Microsoft.Network/virtualNetworks","False","invalid:Environment=Production"
"rt-internal","Microsoft.Network/routeTables","False","missing:Owner; missing:CostCenter; missing:Environment; missing:DataClassification; missing:AssetID; missing:Lifecycle"
```

## 📁 Repository layout

| Path | What is in it |
|---|---|
| [`config/tagging-standard.md`](config/tagging-standard.md) | My cloud asset policy: required tags, allowed values, cadence |
| [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md) | My hardware CMDB policy: required fields, valid values |
| [`data/hardware-inventory.csv`](data/hardware-inventory.csv) | My CMDB, 15 devices, 6 broken on purpose |
| [`scripts/00-setup-demo-assets.ps1`](scripts/00-setup-demo-assets.ps1) | Creates demo Azure resources with messy tags |
| [`scripts/01-collect-inventory.ps1`](scripts/01-collect-inventory.ps1) | Cloud inventory as CSV |
| [`scripts/02-audit-compliance.ps1`](scripts/02-audit-compliance.ps1) | Cloud audit, accuracy, log |
| [`scripts/03-remediate-tags.ps1`](scripts/03-remediate-tags.ps1) | Fix the cloud tags |
| [`scripts/04-teardown.ps1`](scripts/04-teardown.ps1) | Delete the resource group |
| [`scripts/05-assign-policy.ps1`](scripts/05-assign-policy.ps1) | Assign the Azure Policy, read compliance |
| [`scripts/10-audit-hardware.ps1`](scripts/10-audit-hardware.ps1) | Hardware audit, accuracy, log |
| [`scripts/11-remediate-hardware.ps1`](scripts/11-remediate-hardware.ps1) | Reconcile the CMDB, write a clean copy |
| [`policies/`](policies/) | My Azure Policy definition, audit effect |
| [`docs/network-topology.md`](docs/network-topology.md) | LAN, VLAN plan, IP scheme, Wi-Fi, diagram |
| [`docs/lab-build.md`](docs/lab-build.md) | How I built the lab, with my corrections marked |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Every problem I actually hit |
| [`network/README.md`](network/README.md) | Index of my network evidence |
| [`network/koeln-hq-lan.pkt`](network/koeln-hq-lan.pkt) | My Packet Tracer lab, openable |
| [`network/configs/`](network/configs/) | Running-configs I exported from the lab |
| [`network/screenshots/`](network/screenshots/) | My ten verification captures |
| [`reports/`](reports/) | Generated audit reports and my accuracy log |
| [`images/`](images/) | Terminal captures from my cloud run |

## 🔒 Security approach

- **I set the policy effect to `audit`, not `deny`.** I want to see the real violation rate first. Turn deny on too early and you block deployments on day one, and then someone disables the policy entirely.
- **I park native VLAN 99 empty.** Untagged frames land somewhere harmless. A native VLAN mismatch is the basis of VLAN hopping, and when my two trunk ends disagreed during the build, spanning tree blocked the VLAN rather than carry it. That is the behaviour I want.
- **I give every trunk an explicit allowed VLAN list.** Without one, a trunk carries every VLAN that exists now or later, so a VLAN I create by accident next year would silently start crossing links it was never meant to.
- **I keep management separate.** Switch and router addresses live in VLAN 10, reachable only from admin subnets.
- **I require `DataClassification`.** `PersonalData` marks anything under DSGVO obligations, and I keep the estate in Germany West Central so residency stays inside Germany.
- **I commit nothing secret.** No credentials, keys or subscription identifiers. The Azure module authenticates interactively.

## 🚫 Things I considered and chose not to do

| What I skipped | Why I skipped it |
|---|---|
| A CMDB product like ServiceNow or GLPI | I want the audit logic readable in the repo, not hidden behind a UI |
| `deny` on the Azure Policy | Right destination, wrong opening move. See above |
| Multi-argument `Join-Path` | Reads better, but needs PowerShell 6+. I want these running on a plain 5.1 desktop |
| Azure Resource Graph for inventory | The right tool once this crosses subscriptions. I noted it in the script as the scaling path instead of building it early |
| GNS3 or containerlab | Both more realistic than Packet Tracer, but neither does Wi-Fi, and Wi-Fi is part of what I am showing |
| Squashing my pull requests | Tidier history, but it throws away the record of how I built this |
| Claiming the firewall and Wi-Fi are built | They are designed and in my CMDB, not constructed. I mark them in [`docs/network-topology.md`](docs/network-topology.md) |

## 🤖 How I built this

I worked in chunks. Each one is an issue, a branch, small commits, a pull request and a merge.

| Chunk | Issue | PR | What I landed |
|---|---|---|---|
| Skeleton | | | README, LICENSE, .gitignore |
| Cloud module | [#1](../../issues/1) | [#2](../../pull/2) | Tagging standard, six scripts, Azure Policy |
| Path fix | [#3](../../issues/3) | [#4](../../pull/4) | Backslash paths broke on Linux |
| Hardware CMDB | [#5](../../issues/5) | [#6](../../pull/6) | Standard, seed data, audit, reconciliation |
| Evidence | [#7](../../issues/7) | [#8](../../pull/8) | Reports from both live runs |
| Network lab | | [#9](../../pull/9) | The LAN, configs, screenshots, docs |
| Troubleshooting | | [#10](../../pull/10) | Every problem I hit |

I put the reasoning in the pull requests. The code shows what I did; the PR shows why, including the decisions that could reasonably have gone the other way.

I kept the commits small on purpose. I want the history to read as a sequence of decisions rather than one large drop.

## 🤝 Contributing

I welcome issues and pull requests, especially on the network side.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for how to run the modules, what a useful change looks like, and the conventions I follow.

What would help me most:

- 📶 A Wi-Fi build in the lab
- 🔍 Additional audit checks, with a stated reason for each
- 🌍 A second network topology my CMDB could describe

---

## License

Licensed under the [MIT License](LICENSE).

---
