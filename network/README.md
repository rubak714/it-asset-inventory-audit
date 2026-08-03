# 🔌 network

This is my evidence for the LAN. I designed it in [`docs/network-topology.md`](../docs/network-topology.md) and built it following [`docs/lab-build.md`](../docs/lab-build.md). The devices, IPs and VLANs all match my CMDB in [`data/hardware-inventory.csv`](../data/hardware-inventory.csv).

## 📁 What is here

| Path | What it is |
|---|---|
| [`koeln-hq-lan.pkt`](koeln-hq-lan.pkt) | My Packet Tracer lab. Open it and the network is there |
| [`configs/`](configs/) | Running-configs I exported from the four network devices |
| [`screenshots/`](screenshots/) | My verification captures from the build |

## 💾 The lab file

`koeln-hq-lan.pkt` holds what I built: eight devices, seven links, five VLANs, router-on-a-stick with DHCP. I used Packet Tracer 9.0.0.

I committed it so nobody has to take my diagram on trust. Open the file, click any device, read its config, run the pings yourself.

## ⚙️ The configs

These are **exports from my working lab**, not drafts I wrote and never ran.

| File | Device | Asset | Role |
|---|---|---|---|
| [`rtr-edge-01.txt`](configs/rtr-edge-01.txt) | Router 2911 | AST-1004 | inter-VLAN routing, DHCP |
| [`sw-core-01.txt`](configs/sw-core-01.txt) | Switch 2960 | AST-1001 | core trunk hub, server access port |
| [`sw-acc-01.txt`](configs/sw-acc-01.txt) | Switch 2960 | AST-1002 | access switch, first floor |
| [`sw-acc-02.txt`](configs/sw-acc-02.txt) | Switch 2960 | AST-1003 | access switch, second floor |

I put a header on each one recording:

- The asset ID it belongs to
- Its site and rack
- Its management IP
- Which devices sit on which ports

That way you can trace a config back to a CMDB row without opening the topology doc.

### ⚠️ Create the VLANs before you paste a switch config

> [!IMPORTANT]
> Cisco keeps the VLAN database in `vlan.dat`, separate from the running config. So my files show ports *assigned* to VLAN 30 but never show VLAN 30 being *created*.

Paste one of these into a fresh switch without creating the VLANs first and **every port assignment fails silently**. No error, nothing. This one took me a while to work out.

Paste this block first:

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

It is also in the header of every config file for the same reason.

### To load one

1. Open the device CLI in your simulator
2. `enable`, then `configure terminal`
3. Paste the VLAN block above
4. Paste the file contents. Lines starting `!` are comments and safe to include
5. Finish with `end` and `write memory`

## 📸 The screenshots

I numbered them in run order and named them after what they prove, not by timestamp.

| File | What I am proving |
|---|---|
| [`00-final-pkt-screenshot.png`](screenshots/00-final-pkt-screenshot.png) | My topology, every link green |
| [`01-ipconfig-nb-1123.png`](screenshots/01-ipconfig-nb-1123.png) | DHCP handed out `10.0.20.51`, matching AST-1011 |
| [`02-ping-gateway.png`](screenshots/02-ping-gateway.png) | Gateway reachable, TTL 255 |
| [`03-ping-server-cross-vlan.png`](screenshots/03-ping-server-cross-vlan.png) | 🎯 Inter-VLAN routing, TTL 127 |
| [`04-ping-across-access-switches.png`](screenshots/04-ping-across-access-switches.png) | Across the core to the other floor |
| [`05-ping-printer.png`](screenshots/05-ping-printer.png) | Printer at its static address |
| [`06-core-show-vlan-brief.png`](screenshots/06-core-show-vlan-brief.png) | Five VLANs, server port in VLAN 30 |
| [`07-core-show-interfaces-trunk.png`](screenshots/07-core-show-interfaces-trunk.png) | Three trunks, native 99, full allowed list |
| [`08-router-show-ip-interface-brief.png`](screenshots/08-router-show-ip-interface-brief.png) | Five subinterfaces up with the right gateways |
| [`09-router-show-ip-dhcp-binding.png`](screenshots/09-router-show-ip-dhcp-binding.png) | Which MAC received which address |

### 🎯 Why 03 is the one I would point at

Replies start at TTL 128, and every router that forwards one subtracts 1.

- Everything inside VLAN 20 came back at **128**
- My file server in VLAN 30 came back at **127**

That single digit is the packet telling me exactly one router handled it. It proves my inter-VLAN routing works without anyone needing to trust my config or my diagram.

## 📐 What I have not built yet

My CMDB and topology also describe:

- A perimeter firewall (`AST-1005`)
- A WLAN controller (`AST-1006`)
- Four access points (`AST-1007`, `AST-1008`, `AST-1010`, `AST-1015`)

I designed those but have not constructed them in the lab, and I mark each one in [`docs/network-topology.md`](../docs/network-topology.md).

They stay in my inventory because they belong to the design. I would rather mark them than quietly imply I built the whole diagram.

## 🎓 Which simulator

I used Packet Tracer, which is free with a free Cisco Networking Academy account, no school or education ID needed.

- My IOS configs also load in **GNS3**
- For a fully open Docker-based option there is **containerlab** with a free network OS, though the syntax differs from IOS

I chose Packet Tracer because it is the only free option that does Wi-Fi, and Wi-Fi is part of what I want to show.
