# 🗂️ IT Asset Inventory and Compliance Audit

![Azure](https://img.shields.io/badge/Azure-Germany%20West%20Central-0078D4?logo=microsoftazure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white)
![Packet Tracer](https://img.shields.io/badge/Cisco%20Packet%20Tracer-9.0.0-1BA0D7?logo=cisco&logoColor=white)
![Azure Policy](https://img.shields.io/badge/Azure%20Policy-as%20code-0078D4?logo=microsoftazure&logoColor=white)
![Evidence](https://img.shields.io/badge/evidence-4%20measured%20runs-success)
![Status](https://img.shields.io/badge/status-Wi--Fi%20pending-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Asset management and compliance auditing across two estates: Azure cloud resources and a physical hardware and network estate. Both are measured by the same policy and the same metric.

<p align="center">
  <img src="network/screenshots/00-final-pkt-screenshot.png" alt="The LAN built and verified in Packet Tracer" width="700">
</p>

<p align="center">
  <em>The LAN behind the CMDB. Eight devices, seven links, five VLANs, built and verified.<br>
  Every device maps to an AssetID in <a href="data/hardware-inventory.csv">the inventory</a>. The lab file is <a href="network/koeln-hq-lan.pkt">in the repo</a>.</em>
</p>

> [!NOTE]
> This is a portfolio project built on a lab estate, not production work. The method and the measurements are real: four audit runs, timestamped, in [`reports/accuracy-log.csv`](reports/accuracy-log.csv). I would rather say that plainly than let a reader assume more.

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

One audit engine, two estates, one log.

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

The six fields are identical on both sides: `Owner`, `CostCenter`, `Environment`, `DataClassification`, `AssetID`, `Lifecycle`. Cloud resources hold them as tags, physical devices hold them as CSV columns.

That is the decision the whole project rests on. Asset management is one discipline, not two, so a cloud resource and a switch should be scored the same way and land in the same log.

The audit loop runs the same on both:

| Step | What happens |
|---|---|
| 1. Inventory | list every asset that exists |
| 2. Audit | check each against the written policy, score it |
| 3. Remediate | fix the broken records |
| 4. Re-audit | measure again, prove the number moved |

Step 4 is what turns a claim into evidence. Anyone can say they improved records. A before and after pair in a timestamped file is different.

## 🏛️ Stack

| Layer | Choice | Why |
|---|---|---|
| Automation | PowerShell 5.1 and 7 | Runs on a plain Windows desktop with nothing installed, and in Cloud Shell |
| Cloud | Azure, Germany West Central | DSGVO data residency. NSG, VNet and route table are free |
| Policy as code | Azure Policy, `audit` effect | Flags violations continuously instead of only when I remember to run a script |
| Network lab | Cisco Packet Tracer 9.0.0 | Free with a Networking Academy account, and the only free simulator that does Wi-Fi |
| Device OS | Cisco IOS 15.0 / 15.1 | Real config syntax, not a toy abstraction |
| Records | CSV | A CMDB does not need a product. One row per device, greppable and diffable |

## 📊 Honest metrics

Tracking accuracy is the share of assets that fully comply: all required fields present, and the constrained values valid.

| Module | Assets | Before | After | Source |
|--------|--------|--------|-------|--------|
| ☁️ Cloud | 8 | 3/8 = **37.5%** | 8/8 = **100%** | [`accuracy-log.csv`](reports/accuracy-log.csv) |
| 🌐 Hardware | 15 | 9/15 = **60%** | 15/15 = **100%** | [`accuracy-log.csv`](reports/accuracy-log.csv) |

<p align="center">
  <img src="images/accuracy-log.png" alt="The accuracy log after both runs" width="640">
</p>

Both are measured. The cloud module ran in Azure Cloud Shell against a live subscription. The hardware module ran locally.

> [!IMPORTANT]
> A jump to 100% in a lab is good for showing the method and weak as a claim about experience. The estate is small and the faults were seeded by me. What is real is the measurement, the reproducibility, and the two faults the lab found that I did not plant.

The offsets in the log differ, `+00:00` on the cloud rows and `+06:00` on the hardware rows, because those runs genuinely happened on two different machines. The log is append-only, so runs accumulate rather than overwrite.

## ☁️ Module 1: cloud resource governance

The six tracking fields live as tags on the resource itself, so the record travels with the asset instead of sitting in a spreadsheet that drifts. Full policy: [`config/tagging-standard.md`](config/tagging-standard.md).

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
> In Azure Cloud Shell, choose **PowerShell** and not Bash, and use forward slashes: `./scripts/00-setup-demo-assets.ps1`. Bash cannot run these files at all and says nothing useful when it fails. See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

[`00-setup-demo-assets.ps1`](scripts/00-setup-demo-assets.ps1) builds a deliberately broken estate: three resources tagged correctly, five with real faults. Starting clean would score 100% immediately and demonstrate nothing.

<p align="center">
  <img src="images/audit-before.png" alt="The audit catching all five seeded faults" width="760">
</p>

Read the `vnet-dmz-test` line twice. `Environment=Production` is **present**, so a check that only asked whether the field was populated would pass it. It fails because the standard allows `Prod`, `Test`, `Dev` and nothing else.

That is the difference between a completeness check and a compliance audit, and it is the reason the standard defines allowed values rather than just required keys.

Findings are typed (`missing:Owner`, `invalid:Environment=Production`) rather than a bare pass or fail, because whoever picks up the report has to know what to fix.

**Policy as code.** [`policies/require-tracking-tags.policy.json`](policies/require-tracking-tags.policy.json) hands the same rules to Azure itself, so resources created after the audit get flagged too. The effect is `audit` and not `deny`: deny is the right end state but the wrong opening move, since switching it on before you know what it catches blocks deployments on day one.

## 🌐 Module 2: hardware and network CMDB

No cloud login and no Az module, because most asset management work is physical. Rules: [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md). Data: [`data/hardware-inventory.csv`](data/hardware-inventory.csv).

```powershell
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"
.\scripts\11-remediate-hardware.ps1
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"
```

Fifteen devices: a core switch, two access switches, an edge router, a perimeter firewall, a WLAN controller, three access points, a file server, two laptops and a printer.

Six records are broken on purpose, each one a fault I would expect to actually find:

| Asset | Fault |
|---|---|
| `AST-1010` | access point in reception with no owner |
| `AST-1011` | laptop with no warranty end date |
| `AST-1012` | access switch recorded as `10.0.10.300`, not a valid address |
| `AST-1013` | laptop on VLAN 25, which is not in the plan |
| `AST-1014` | printer with no cost center |
| `AST-1015` | access point with no VLAN at all |

**Three checks a spreadsheet validator would miss.** IPv4 is parsed octet by octet rather than pattern matched, so `10.0.10.300` is caught as out of range instead of slipping past a loose regex. VLAN is checked against the actual plan, so VLAN 25 is a finding even though 25 is a legal VLAN number in general. MAC is optional, but a malformed one still fails, because a half-typed MAC is worse than an empty field.

**Reconciliation writes a new file.** [`11-remediate-hardware.ps1`](scripts/11-remediate-hardware.ps1) keys corrections by AssetID and writes a clean copy rather than editing the seed. The before state has to stay reproducible or nobody can re-measure the 60%, and a script that rewrites the source inventory every run is how one bad assumption becomes a permanently corrupted CMDB.

## 📡 The network lab

The hardware module would be a spreadsheet exercise if the devices were invented. They are not.

Design: [`docs/network-topology.md`](docs/network-topology.md). Build steps: [`docs/lab-build.md`](docs/lab-build.md). Exported configs: [`network/configs/`](network/configs/). Evidence index: [`network/README.md`](network/README.md).

| VLAN | Name | Use | Subnet | Gateway |
|------|------|-----|--------|---------|
| 10 | MGMT | switches, router, APs, controller | 10.0.10.0/24 | 10.0.10.1 |
| 20 | CLIENTS | laptops, printers | 10.0.20.0/24 | 10.0.20.1 |
| 30 | SERVERS | file and app servers | 10.0.30.0/24 | 10.0.30.1 |
| 40 | WIFI | wireless clients | 10.0.40.0/24 | 10.0.40.1 |
| 99 | NATIVE | trunk native and parking | not routed | none |

Switch-to-switch and switch-to-router links are 802.1Q trunks with an explicit allowed VLAN list and 99 as native. Client ports are untagged access ports in VLAN 20, configured as a whole block per floor so anyone can plug in anywhere.

<p align="center">
  <img src="network/screenshots/07-core-show-interfaces-trunk.png" alt="show interfaces trunk on the core switch" width="700">
</p>

### 🎯 How I know it actually routes

<p align="center">
  <img src="network/screenshots/03-ping-server-cross-vlan.png" alt="Cross-VLAN ping returning TTL 127" width="560">
</p>

Look at the TTL.

| Ping from `nb-1123` | TTL | Meaning |
|---|---|---|
| `10.0.20.1` gateway | 255 | the router answered directly |
| `10.0.20.52` other laptop | 128 | same VLAN, never routed |
| `10.0.20.80` printer | 128 | same VLAN |
| `10.0.30.10` file server | **127** | **routed exactly once** |

Replies start at TTL 128 and every router that forwards one subtracts 1. A reply at 127 is the packet itself reporting that exactly one router handled it.

A diagram asks to be believed. A TTL of 127 does not.

<details>
<summary>📸 All ten verification captures</summary>

<br>

| Capture | Proves |
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
  <img src="network/screenshots/09-router-show-ip-dhcp-binding.png" alt="DHCP bindings on the router" width="620">
</p>

The DHCP binding is the router's own record of what it leased. `10.0.20.51` and `10.0.20.52` went to the two laptops, matching `AST-1011` and `AST-1013` without my having touched anything.

</details>

### 🔍 What building it changed

The lab was not a formality. It found two faults in configs that read correctly on paper.

**The printer was on the wrong floor.** Cabled to the first-floor switch when the CMDB puts it in `OG2-Flur`. No field-level audit could catch this, because which switch a device hangs off is not a checked field.

**DHCP could hand out the printer's static address.** The pool covered all of `10.0.20.0/24` while excluding only `.1` to `.50`, and the printer sits on `.80`. It would have worked perfectly until the day a new device joined, which is the worst failure profile there is.

Both are in the exported configs and both are written up as corrections in [`docs/lab-build.md`](docs/lab-build.md) rather than quietly folded in.

## 🧾 Evidence

Every number above is backed by a generated file.

| File | What it holds |
|---|---|
| [`reports/accuracy-log.csv`](reports/accuracy-log.csv) | Every audit run, both modules, timestamped |
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

The detail reports are the more useful artifact. They do not just say five resources failed, they say which check each one failed and why:

```
"vnet-dmz-test","Microsoft.Network/virtualNetworks","False","invalid:Environment=Production"
"rt-internal","Microsoft.Network/routeTables","False","missing:Owner; missing:CostCenter; missing:Environment; missing:DataClassification; missing:AssetID; missing:Lifecycle"
```

## 📁 Repository layout

| Path | What is in it |
|---|---|
| [`config/tagging-standard.md`](config/tagging-standard.md) | Cloud asset policy: required tags, allowed values, cadence |
| [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md) | Hardware CMDB policy: required fields, valid values |
| [`data/hardware-inventory.csv`](data/hardware-inventory.csv) | The CMDB, 15 devices, 6 broken on purpose |
| [`scripts/00-setup-demo-assets.ps1`](scripts/00-setup-demo-assets.ps1) | Creates demo Azure resources with messy tags |
| [`scripts/01-collect-inventory.ps1`](scripts/01-collect-inventory.ps1) | Cloud inventory as CSV |
| [`scripts/02-audit-compliance.ps1`](scripts/02-audit-compliance.ps1) | Cloud audit, accuracy, log |
| [`scripts/03-remediate-tags.ps1`](scripts/03-remediate-tags.ps1) | Fix the cloud tags |
| [`scripts/04-teardown.ps1`](scripts/04-teardown.ps1) | Delete the resource group |
| [`scripts/05-assign-policy.ps1`](scripts/05-assign-policy.ps1) | Assign the Azure Policy, read compliance |
| [`scripts/10-audit-hardware.ps1`](scripts/10-audit-hardware.ps1) | Hardware audit, accuracy, log |
| [`scripts/11-remediate-hardware.ps1`](scripts/11-remediate-hardware.ps1) | Reconcile the CMDB, write clean copy |
| [`policies/`](policies/) | Azure Policy definition, audit effect |
| [`docs/network-topology.md`](docs/network-topology.md) | LAN, VLAN plan, IP scheme, Wi-Fi, diagram |
| [`docs/lab-build.md`](docs/lab-build.md) | Step by step build with real IOS, corrections marked |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Every problem actually hit |
| [`network/README.md`](network/README.md) | Index of the network evidence |
| [`network/koeln-hq-lan.pkt`](network/koeln-hq-lan.pkt) | The Packet Tracer lab itself |
| [`network/configs/`](network/configs/) | Running-configs exported from the lab |
| [`network/screenshots/`](network/screenshots/) | Ten verification captures |
| [`reports/`](reports/) | Generated audit reports and the accuracy log |
| [`images/`](images/) | Terminal captures from the cloud run |

## 🔒 Security approach

**Policy effect is `audit`, not `deny`.** Deny is the correct end state and the wrong first move. Turning it on before you know the real violation rate blocks deployments on day one and gets the policy switched off entirely.

**Native VLAN 99 carries nothing.** A native VLAN mismatch is the basis of VLAN hopping, where a frame reaches a VLAN it was never meant to. Parking the native VLAN somewhere empty means untagged frames land harmlessly. When the two ends of a trunk disagreed during the build, spanning tree blocked the VLAN rather than carry it, which is the behaviour you want.

**Trunks use an explicit allowed VLAN list.** Without one, a trunk carries every VLAN that exists, now and in future, so a VLAN created by accident next year would silently start crossing links it was never meant to.

**Management VLAN is separated.** VLAN 10 holds switch and router management addresses and is reachable only from admin subnets.

**`DataClassification` is a required field.** `PersonalData` marks resources under DSGVO obligations, and the estate sits in Germany West Central so residency stays inside Germany.

**Nothing secret is committed.** No credentials, keys or subscription identifiers. The Azure module authenticates interactively.

## 🚫 Things I considered and chose not to do

**A real CMDB product** such as ServiceNow or GLPI. The point here is the audit method and the metric, and a CSV keeps the data readable, diffable and greppable in the repo. A product would hide the logic behind a UI.

**`deny` on the Azure Policy.** Correct destination, wrong starting point. See the security note above.

**Multi-argument `Join-Path`.** Reads better than the nested form, but requires PowerShell 6+. These scripts should run on a plain corporate Windows desktop with nothing installed, so the constraint won over the syntax.

**Azure Resource Graph for the inventory.** The right tool once this crosses subscription boundaries, and overkill for one resource group. Noted in [`01-collect-inventory.ps1`](scripts/01-collect-inventory.ps1) as the scaling path rather than built prematurely.

**GNS3 or containerlab instead of Packet Tracer.** Both are more realistic. Neither does Wi-Fi, and the Wi-Fi design with a WLAN controller and SSID-to-VLAN mapping is part of what this project is meant to show.

**Squashing the pull requests.** Squash gives a tidier history and throws away how the work was built. For a portfolio repo, that record is the point.

**Claiming the firewall and Wi-Fi are built.** They are designed, documented and in the CMDB, but not constructed in the lab. [`docs/network-topology.md`](docs/network-topology.md) marks each one, because implying otherwise would undermine every claim that is true.

## 🤖 How I built this

In chunks, each one an issue, a branch, small commits, a pull request and a merge.

| Chunk | Issue | PR | What landed |
|---|---|---|---|
| Skeleton | | | README, LICENSE, .gitignore |
| Cloud module | [#1](../../issues/1) | [#2](../../pull/2) | Tagging standard, six scripts, Azure Policy |
| Path fix | [#3](../../issues/3) | [#4](../../pull/4) | Backslash paths broke on Linux |
| Hardware CMDB | [#5](../../issues/5) | [#6](../../pull/6) | Standard, seed data, audit, reconciliation |
| Evidence | [#7](../../issues/7) | [#8](../../pull/8) | Reports from both live runs |
| Network lab | | [#9](../../pull/9) | The LAN, configs, screenshots, docs |
| Troubleshooting | | [#10](../../pull/10) | Every problem hit |

Pull requests carry the reasoning. Code shows what was done; the PR shows why, including the decisions that could reasonably have gone the other way.

The commits are deliberately small. The history is meant to read as a sequence of decisions rather than one large drop.

## 🤝 Contributing

Issues and pull requests are welcome, particularly on the network side.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for how to run the modules, what a useful change looks like, and the conventions used here.

The most helpful contributions would be a Wi-Fi build in the lab, additional audit checks with a stated reason for each, or a second network topology the CMDB could describe.

---

## License

Licensed under the [MIT License](LICENSE).

---
