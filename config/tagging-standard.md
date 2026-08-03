# 📋 Asset Management Policy (Tagging Standard)

Version 1.0. Applies to all resources in the resource group `rg-itam-audit-demo`, region Germany West Central.

## 🎯 Purpose

Every IT asset must be clearly owned, classified, and traceable through its lifecycle. I keep those facts as tags on the resource itself, so the record travels with the asset instead of living in a spreadsheet that drifts. These tags are the basis for inventory and audit.

I use the same six fields here that I use as columns in the hardware CMDB. That is deliberate. One policy, two estates, one accuracy metric.

## 🏷️ Required tags

| Tag | Meaning | Rule |
|-----|---------|------|
| `Owner` | Responsible person (short name) | must be set and not empty |
| `CostCenter` | Cost center | must be set, format `KST-####` |
| `Environment` | Environment | one of `Prod`, `Test`, `Dev` |
| `DataClassification` | Data classification (DSGVO) | one of `Public`, `Internal`, `Confidential`, `PersonalData` |
| `AssetID` | Inventory number (CMDB reference) | must be set, format `AST-####` |
| `Lifecycle` | Lifecycle stage | one of `Active`, `DecommissionPlanned`, `Retired` |

An asset counts as **compliant** when all six tags are present and the constrained values are valid. If a tag is missing or a value is not allowed, the asset counts as **non-compliant**.

I check both conditions on purpose. Presence alone is not enough. A resource tagged `Environment=Production` looks filled in to a human but breaks every filter and cost report that expects `Prod`, so I treat it as a finding.

## 🔐 Data classification and DSGVO

`PersonalData` marks resources that process or store personal data. Those assets carry a stronger evidence requirement. I keep the estate in Germany West Central so data residency stays inside Germany.

## 🔁 Audit cadence

- Full audit: monthly
- Ad-hoc audit: after any larger change to the infrastructure
- Result of every audit is logged to `reports/accuracy-log.csv`

The log is append-only. Each run adds a timestamped line, so the trend over time is visible and no single run can be quietly overwritten.

## 👥 Responsibilities

- The person named in the `Owner` tag maintains the tags for their asset.
- Non-compliant assets are fixed in the next maintenance window.
- Assets without an `Owner` are escalated and handled first, because an unowned asset has nobody to assign the fix to.

## 🔗 Related

- `config/hardware-inventory-standard.md` is the same policy applied to physical devices.
- `policies/require-tracking-tags.policy.json` is this standard expressed as Azure Policy, so the platform flags violations continuously instead of only at audit time.
