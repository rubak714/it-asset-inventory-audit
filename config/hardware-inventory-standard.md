# 🖥️ Hardware and Network Inventory Standard

Version 1.0. Applies to every physical device in the CMDB (`data/hardware-inventory.csv`): switches, routers, firewalls, access points, WLAN controllers, servers, laptops, printers.

## 🎯 Purpose

Every device must be owned, located, addressed, and traceable through its lifecycle. Those fields are the basis for inventory control and audit.

I run the same audit engine over this as I run over the cloud estate, so the two domains report the same accuracy metric instead of two numbers nobody can compare. Six of the fields below are deliberately identical to the cloud tags in `config/tagging-standard.md`.

## 📋 Required fields

| Field | Meaning | Rule |
|-------|---------|------|
| `AssetID` | Inventory number | must be set, format `AST-####` |
| `DeviceType` | Class of device | one of the allowed types below |
| `Hostname` | Device name | must be set |
| `Site` | Location code | must be set, e.g. `DE-KOELN-HQ` |
| `Owner` | Responsible person | must be set |
| `CostCenter` | Cost center | must be set, format `KST-####` |
| `Lifecycle` | Lifecycle stage | one of `Active`, `DecommissionPlanned`, `Retired` |
| `IPAddress` | Management IP | must be a valid IPv4 address |
| `VLAN` | Assigned VLAN | one of `10`, `20`, `30`, `40`, `99` |
| `WarrantyEnd` | Warranty end date | must be set, format `YYYY-MM-DD` |

Optional but validated: `MACAddress`. If it is present it must match `xx:xx:xx:xx:xx:xx`, because a half-typed MAC is worse than an empty one. Free fields, not checked: `Room`, `DataClassification`, `Firmware`, `PurchaseDate`.

## ✅ Allowed values

- `DeviceType`: `CoreSwitch`, `AccessSwitch`, `Router`, `Firewall`, `AccessPoint`, `WLANController`, `Server`, `Laptop`, `Printer`
- `Lifecycle`: `Active`, `DecommissionPlanned`, `Retired`
- `VLAN`: `10` (management), `20` (clients), `30` (servers), `40` (Wi-Fi), `99` (native and parking)

A device is **compliant** when all required fields are set, the constrained values are valid, the IP parses as IPv4, and the MAC (if present) is well formed. Otherwise it is **non-compliant**.

## 🔍 Why these checks

I picked these because each one catches a failure I would otherwise only find out about at the worst moment.

- Missing `Owner` or `CostCenter` means a device nobody is accountable for and nobody is billing. That is the classic form of inventory drift, and it usually shows up when someone leaves and their kit quietly becomes nobody's problem.
- An invalid IP or an out-of-plan VLAN means the network documentation and the real configuration have diverged. `10.0.10.300` is not an address that exists, so either the record is wrong or someone typed it into a device and it never worked.
- Missing `WarrantyEnd` means no way to plan replacement before support runs out. Finding that out during an outage is the expensive version.

The audit reports a typed reason per finding, `missing:Owner` or `invalid:VLAN=25`, rather than a bare pass or fail. A list of failures nobody can act on is not much better than no list.

## 🔗 Related

- `docs/network-topology.md` has the LAN layout, VLAN plan, IP scheme, and Wi-Fi that this standard validates against.
- `config/tagging-standard.md` is the same policy applied to cloud resources.
