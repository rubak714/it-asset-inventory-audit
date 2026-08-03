# 🔌 network

Evidence for the LAN. The network follows `docs/network-topology.md` and was built with `docs/lab-build.md`. The devices, IPs and VLANs match the CMDB in `data/hardware-inventory.csv`.

## 📁 What is here

| Path | What it is |
|---|---|
| `koeln-hq-lan.pkt` | The Packet Tracer lab. Open it and the network is there |
| `configs/` | Running-configs exported from the four network devices |
| `screenshots/` | Verification captures from the build |

## 💾 The lab file

`koeln-hq-lan.pkt` holds the built network: eight devices, seven links, five VLANs, router-on-a-stick with DHCP. Built on Packet Tracer 9.0.0.

It is in the repo so nobody has to take the diagram on trust. Open the file, click any device, read its config, run the pings yourself.

## ⚙️ The configs

These are **exports from the working lab**, not drafts.

| File | Device | Asset | Role |
|---|---|---|---|
| `rtr-edge-01.txt` | Router 2911 | AST-1004 | inter-VLAN routing, DHCP |
| `sw-core-01.txt` | Switch 2960 | AST-1001 | core trunk hub, server access port |
| `sw-acc-01.txt` | Switch 2960 | AST-1002 | access switch, first floor |
| `sw-acc-02.txt` | Switch 2960 | AST-1003 | access switch, second floor |

Each carries a header recording the asset ID, site, management IP, and which devices sit on which ports, so a config traces back to a CMDB row without opening the topology doc.

### ⚠️ Create the VLANs before pasting a switch config

Cisco keeps the VLAN database in `vlan.dat`, separate from the running config. So these files show ports *assigned* to VLAN 30 but never show VLAN 30 being *created*.

Paste a config into a fresh switch without creating the VLANs first and every port assignment fails silently. The block to paste first is in each file's header:

```
vlan 10
 name MGMT
vlan 20
 name CLIENTS
vlan 30
 name SERVERS
vlan 40
 name WIFI
vlan 99
 name NATIVE
```

### To load one

Open the device CLI in your simulator, `enable`, then `configure terminal`, paste the VLAN block, then paste the file contents. Lines beginning `!` are comments and are safe to include. Finish with `end` and `write memory`.

## 📸 The screenshots

Numbered in run order, named after what they prove.

| File | Proves |
|---|---|
| `00-final-pkt-screenshot.png` | Topology, every link green |
| `01-ipconfig-nb-1123.png` | DHCP handed out `10.0.20.51`, matching AST-1011 |
| `02-ping-gateway.png` | Gateway reachable, TTL 255 |
| `03-ping-server-cross-vlan.png` | 🎯 Inter-VLAN routing, TTL 127 |
| `04-ping-across-access-switches.png` | Across the core to the other floor, TTL 128 |
| `05-ping-printer.png` | Printer at its static address, TTL 128 |
| `06-core-show-vlan-brief.png` | Five VLANs, server port in VLAN 30 |
| `07-core-show-interfaces-trunk.png` | Three trunks, native 99, full allowed list |
| `08-router-show-ip-interface-brief.png` | Five subinterfaces up with the right gateways |
| `09-router-show-ip-dhcp-binding.png` | Which MAC received which address |

### 🎯 Why `03` is the important one

Replies start at TTL 128 and every router that forwards one subtracts 1.

Everything inside VLAN 20 comes back at **128**. The file server in VLAN 30 comes back at **127**.

That single digit is the packet reporting that exactly one router handled it. It proves inter-VLAN routing without anyone needing to trust the config or the diagram.

## 📐 Not built yet

The CMDB and topology also describe a perimeter firewall (`AST-1005`), a WLAN controller (`AST-1006`) and three access points (`AST-1007`, `AST-1008`, `AST-1010`, `AST-1015`). Those are designed but not built in the lab, and `docs/network-topology.md` marks them as such.

They stay in the inventory because they belong to the design. Marking them beats quietly implying they exist.

## 🎓 Which simulator

Packet Tracer is free with a free Cisco Networking Academy account, no school or education ID needed. These IOS configs also load in GNS3. For a fully open Docker-based option there is containerlab with a free network OS, though the syntax differs from IOS.
