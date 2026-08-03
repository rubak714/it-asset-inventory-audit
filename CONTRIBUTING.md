# 🤝 Contributing

Thanks for looking. This is a portfolio project, but it is a working one, and issues or pull requests are welcome.

## 🚀 Running it locally

### 🌐 Hardware module, no account needed

The fastest way to see the whole method working. No cloud login, no Az module, nothing to install.

```powershell
git clone https://github.com/rubak714/it-asset-inventory-audit.git
cd it-asset-inventory-audit

.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"
.\scripts\11-remediate-hardware.ps1
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"

Get-Content reports\accuracy-log.csv
```

You should see 9 of 15, then 15 of 15.

### ☁️ Cloud module, needs an Azure subscription

Everything it creates (NSG, VNet, route table) is free, and [`04-teardown.ps1`](scripts/04-teardown.ps1) removes it all.

```powershell
Connect-AzAccount
Set-AzContext -Subscription "<your-subscription-id>"

.\scripts\00-setup-demo-assets.ps1
.\scripts\02-audit-compliance.ps1 -Label "before"
.\scripts\03-remediate-tags.ps1
.\scripts\02-audit-compliance.ps1 -Label "after"
.\scripts\04-teardown.ps1
```

> [!WARNING]
> In Azure Cloud Shell, pick **PowerShell** from the dropdown, not Bash, and use forward slashes: `./scripts/00-setup-demo-assets.ps1`. Bash cannot run `.ps1` files and fails without a useful message.

### 🔌 The network lab

Open [`network/koeln-hq-lan.pkt`](network/koeln-hq-lan.pkt) in Cisco Packet Tracer 9.0.0 or later. Everything is configured, so you can run the verification commands straight away.

To build it yourself, [`docs/lab-build.md`](docs/lab-build.md) walks through it stage by stage with the real IOS.

## 💡 What would actually help

| Area | What |
|---|---|
| 📶 Wi-Fi | Build the WLC and access points in the lab. The design is in [`docs/network-topology.md`](docs/network-topology.md), SSIDs `KOELN-CORP` and `KOELN-GUEST` on VLAN 40 |
| 🔍 Audit checks | New checks are welcome, with a stated reason for each. A check nobody can act on is not worth the runtime |
| 🌍 A second topology | Another site the CMDB could describe, so the audit runs against more than one network |
| 🐛 Bugs | Especially cross-platform ones. The scripts run on Windows PowerShell 5.1, PowerShell 7, and Cloud Shell on Linux |
| 📝 Documentation | If something in the build guide does not match what your Packet Tracer does, that is worth an issue |

## 📐 Conventions

### Commits

[Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | For |
|---|---|
| `feat:` | new capability |
| `fix:` | bug fix |
| `docs:` | documentation only |
| `chore:` | housekeeping, config, tooling |

Write the body as full-width paragraphs, not hard-wrapped at 72 characters. Explain **why**, not what. The diff already shows what.

### Pull requests

Say what you changed and what you decided against. A PR that records a decision which could reasonably have gone the other way is worth more than one that only lists files.

Reference the issue with `Closes #N` so it closes on merge.

### PowerShell

**Build paths portably.** Never embed a separator:

```powershell
# no, breaks on Linux where \ is a legal filename character
Join-Path $PSScriptRoot '..\reports'

# yes
Join-Path (Split-Path $PSScriptRoot -Parent) 'reports'
```

Avoid the multi-argument `Join-Path`. It reads better but needs PowerShell 6+, and these scripts should keep running in Windows PowerShell 5.1.

**Findings must be actionable.** Report `missing:Owner` or `invalid:VLAN=25`, never a bare `False`. Whoever reads the output has to know what to fix.

**Never rewrite source data in place.** Remediation writes a clean copy. The before state has to stay reproducible or the measurement cannot be checked.

### New audit checks

A check needs three things:

1. A rule written down in the relevant file under [`config/`](config/) first
2. A typed failure reason, so the report says what broke
3. A sentence on why it exists, in the standard

The third one matters most. Every check in [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md) says what failure it catches. A rule nobody can justify gets ignored, then removed.

### Network configs

Files in [`network/configs/`](network/configs/) are **exports from the working lab**, not drafts. If you change a device, rebuild the lab, verify it, and re-export with `show running-config`.

> [!IMPORTANT]
> Cisco keeps the VLAN database in `vlan.dat`, separate from the running config, so an exported config never contains its own `vlan` definitions. Paste one into a fresh switch without creating the VLANs first and every port assignment fails silently. Each config file carries the block to paste first in its header.

## 🧪 Before opening a PR

- [ ] Run the hardware module end to end and confirm 60% then 100%
- [ ] If you touched a script, run it on Windows PowerShell and in Cloud Shell
- [ ] If you touched the lab, re-export the configs and update the screenshots
- [ ] If you added a check, document the rule and the reason in `config/`
- [ ] No credentials, keys or subscription identifiers anywhere in the diff

## 🐞 Reporting a problem

Useful issues include what you ran, what you expected, what happened, and where you ran it (Windows PowerShell 5.1, PowerShell 7, or Cloud Shell). The platform matters more than usual here, since one bug in this repo's history existed only on Linux.

[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) covers the problems already hit. If yours is there but the fix did not work, say so, that is worth knowing.

## 📄 License

Contributions are accepted under the [MIT License](LICENSE).
