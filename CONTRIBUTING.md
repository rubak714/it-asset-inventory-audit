# 🤝 Contributing

Thanks for looking. This is a portfolio project, but it is a working one, and I welcome issues and pull requests.

## 🚀 Running it

### 🌐 The hardware module, no account needed

This is the fastest way to see my whole method working. No cloud login, no Az module, nothing to install.

```powershell
git clone https://github.com/rubak714/it-asset-inventory-audit.git
cd it-asset-inventory-audit

.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory.csv -Label "hardware-before"
.\scripts\11-remediate-hardware.ps1
.\scripts\10-audit-hardware.ps1 -CsvPath data\hardware-inventory-clean.csv -Label "hardware-after"

Get-Content reports\accuracy-log.csv
```

You should get 9 of 15, then 15 of 15. If you get something else, that is worth an issue.

### ☁️ The cloud module, needs an Azure subscription

Everything it creates (NSG, VNet, route table) is free, and [`04-teardown.ps1`](scripts/04-teardown.ps1) removes all of it.

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
> In Azure Cloud Shell, pick **PowerShell** from the dropdown, not Bash, and use forward slashes: `./scripts/00-setup-demo-assets.ps1`. I lost time to this myself. Bash cannot run `.ps1` files and fails without a useful message.

### 🔌 The network lab

Open [`network/koeln-hq-lan.pkt`](network/koeln-hq-lan.pkt) in Cisco Packet Tracer 9.0.0 or later. I left everything configured, so you can run the verification commands straight away.

To build it yourself, [`docs/lab-build.md`](docs/lab-build.md) walks through it stage by stage with the real IOS, including the mistakes I made.

## 💡 What would actually help me

| Area | What I am after |
|---|---|
| 📶 Wi-Fi | Build the WLC and access points in the lab. I designed them in [`docs/network-topology.md`](docs/network-topology.md), SSIDs `KOELN-CORP` and `KOELN-GUEST` on VLAN 40 |
| 🔍 Audit checks | New checks with a stated reason for each. A check nobody can act on is not worth the runtime |
| 🌍 A second topology | Another site my CMDB could describe, so the audit runs against more than one network |
| 🐛 Bugs | Cross-platform ones especially. These run on Windows PowerShell 5.1, PowerShell 7, and Cloud Shell on Linux |
| 📝 Docs | If something in my build guide does not match what your Packet Tracer does, tell me |

## 📐 Conventions I follow

### Commits

I use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | For |
|---|---|
| `feat:` | new capability |
| `fix:` | bug fix |
| `docs:` | documentation only |
| `chore:` | housekeeping, config, tooling |

Two things I care about in a commit body:

- Write full-width paragraphs, not hard-wrapped at 72 characters
- Explain **why**, not what. The diff already shows what

### Pull requests

Say what you changed and what you decided against. A PR that records a decision which could reasonably have gone the other way is worth more to me than one listing files.

Use `Closes #N` so the issue closes on merge.

### PowerShell

**Build paths portably.** Never embed a separator:

```powershell
# no. Breaks on Linux, where \ is a legal filename character
Join-Path $PSScriptRoot '..\reports'

# yes
Join-Path (Split-Path $PSScriptRoot -Parent) 'reports'
```

That exact bug was in this repo. It created a directory literally named `..\reports` in Cloud Shell and printed a success message the whole time.

Avoid the multi-argument `Join-Path` too. It reads better but needs PowerShell 6+, and I want these running on a plain 5.1 desktop.

**Make findings actionable.** Report `missing:Owner` or `invalid:VLAN=25`, never a bare `False`. Whoever reads the output has to know what to fix.

**Never rewrite source data in place.** Remediation writes a clean copy. I need the before state reproducible, or nobody can check my measurement.

### New audit checks

A check needs three things from me before I merge it:

1. A rule written down in the relevant file under [`config/`](config/) **first**
2. A typed failure reason, so the report says what broke
3. A sentence on why it exists, in the standard

The third matters most. Every check in [`config/hardware-inventory-standard.md`](config/hardware-inventory-standard.md) says which failure it catches. A rule nobody can justify gets ignored, then removed.

### Network configs

The files in [`network/configs/`](network/configs/) are **exports from my working lab**, not drafts. If you change a device, rebuild the lab, verify it, then re-export with `show running-config`.

> [!IMPORTANT]
> Cisco keeps the VLAN database in `vlan.dat`, separate from the running config, so an exported config never contains its own `vlan` definitions. Paste one into a fresh switch without creating the VLANs first and every port assignment fails silently. I put the block to paste first in each file's header.

## 🧪 Before you open a PR

- [ ] Run the hardware module end to end, confirm 60% then 100%
- [ ] If you touched a script, run it on Windows PowerShell **and** in Cloud Shell
- [ ] If you touched the lab, re-export the configs and update the screenshots
- [ ] If you added a check, document the rule and the reason in `config/`
- [ ] No credentials, keys or subscription identifiers anywhere in the diff

## 🐞 Reporting a problem

Tell me what you ran, what you expected, what happened, and **where** you ran it: Windows PowerShell 5.1, PowerShell 7, or Cloud Shell.

The platform matters more than usual here. One bug in this repo's history existed only on Linux and looked like success on Windows.

I wrote up everything I hit in [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md). If your problem is there but my fix did not work for you, say so. That is worth knowing.

## 📄 License

I accept contributions under the [MIT License](LICENSE).
