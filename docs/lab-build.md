# 🧪 Lab Build (Cisco Packet Tracer)

This builds the network in `docs/network-topology.md` as a real, configurable lab. You write real IOS, verify it, and save the evidence. The CMDB in `data/hardware-inventory.csv` then describes the network you actually built.

No physical hardware needed. Packet Tracer is free through the Cisco Networking Academy. I built this on version 9.0.0.

Everything below is what I did, including the parts that went wrong. The corrections are marked, because a guide that pretends the first attempt worked is not much use to the next person.

## ⏱️ Honest time estimate

| Stage | Time |
|---|---|
| Place and cable 8 devices | 25 min |
| Configure the router | 20 min |
| Configure three switches | 30 min |
| End devices | 15 min |
| Verify and capture | 20 min |
| Wi-Fi (optional, separate session) | 45 min |

Two sittings, not one.

---

## 🖥️ Stage 1: Place the devices

| Category | Model | Rename to | CMDB row | Location |
|---|---|---|---|---|
| Routers | 2911 | `rtr-edge-01` | AST-1004 | DC-Rack-1 |
| Switches | 2960 | `sw-core-01` | AST-1001 | DC-Rack-1 |
| Switches | 2960 | `sw-acc-01` | AST-1002 | OG1-IDF |
| Switches | 2960 | `sw-acc-02` | AST-1003 | OG2-IDF |
| End Devices | Server | `srv-file-01` | AST-1009 | DC-Rack-3 |
| End Devices | PC | `nb-1123` | AST-1011 | OG1-Buero |
| End Devices | PC | `nb-1147` | AST-1013 | OG2-Buero |
| End Devices | Printer | `prn-2f-01` | AST-1014 | OG2-Flur |

Rename by clicking the label under the device, or through `Config` → `Display Name`. Rename everything before cabling. A workspace of `Switch0`, `Switch1`, `Switch2` is how you end up plugging the wrong port.

Save into the repo straight away: `File` → `Save As` → `network/koeln-hq-lan.pkt`. Then `Ctrl+S` often, Packet Tracer does crash.

---

## 🔌 Stage 2: Cable them

Use **Connections** → the first item, "Automatically Choose Connection Type".

Switch-to-switch links need a **crossover** cable while router-to-switch and PC-to-switch need **straight-through**. Pick wrong and the link goes red with nothing explaining why. The automatic option gets it right every time.

| From | Port | To | Port | Carries |
|---|---|---|---|---|
| `rtr-edge-01` | `Gi0/0` | `sw-core-01` | `Gi0/1` | trunk |
| `sw-core-01` | `Fa0/1` | `sw-acc-01` | `Gi0/1` | trunk |
| `sw-core-01` | `Fa0/2` | `sw-acc-02` | `Gi0/1` | trunk |
| `sw-core-01` | `Gi0/2` | `srv-file-01` | `Fa0` | access VLAN 30 |
| `sw-acc-01` | `Fa0/1` | `nb-1123` | `Fa0` | access VLAN 20 |
| `sw-acc-02` | `Fa0/1` | `nb-1147` | `Fa0` | access VLAN 20 |
| `sw-acc-02` | `Fa0/2` | `prn-2f-01` | `Fa0` | access VLAN 20 |

> ⚠️ **Correction from the first attempt.** I originally cabled `prn-2f-01` to `sw-acc-01`. The CMDB puts it in `OG2-Flur`, second floor, so it belongs on `sw-acc-02`. The device name even says `2f`. Worth catching, because a wrong-floor cable makes the inventory wrong in a way no field-level audit can detect: which switch a device hangs off is not one of the checked fields.

### Reading the link lights

- **Green**: up
- **Amber**: normal for 30 seconds on switch ports while spanning tree settles
- **Red**: down, usually a wrong cable type or a port that does not exist

> ℹ️ **The router link starts red and that is correct.** Every Cisco router interface ships administratively shut down. Switch ports are the opposite, live out of the box, which is why the six switch links come up green on their own. The router link turns green after `no shutdown` in stage 3.

---

## 🧠 Stage 3: Router (`rtr-edge-01`)

Router-on-a-stick. One physical link to the core, one subinterface per VLAN. The router is also the DHCP server.

Open the device, click the `CLI` tab. If it asks about the configuration dialog, answer `no`.

### Wake the interface

```
enable
configure terminal
hostname rtr-edge-01
interface GigabitEthernet0/0
 no shutdown
 exit
```

Watch the workspace. The red link turns green within a few seconds.

### Subinterfaces, one per VLAN

```
interface GigabitEthernet0/0.10
 encapsulation dot1Q 10
 ip address 10.0.10.1 255.255.255.0
interface GigabitEthernet0/0.20
 encapsulation dot1Q 20
 ip address 10.0.20.1 255.255.255.0
interface GigabitEthernet0/0.30
 encapsulation dot1Q 30
 ip address 10.0.30.1 255.255.255.0
interface GigabitEthernet0/0.40
 encapsulation dot1Q 40
 ip address 10.0.40.1 255.255.255.0
interface GigabitEthernet0/0.99
 encapsulation dot1Q 99 native
 exit
```

The number after the dot is just a label. `encapsulation dot1Q 10` is what actually binds the subinterface to VLAN 10.

`.99` gets `native` and **no IP address**. Native VLAN traffic crosses a trunk untagged and nothing routes on it, so it needs none.

### DHCP

```
ip dhcp excluded-address 10.0.20.1 10.0.20.50
ip dhcp excluded-address 10.0.40.1 10.0.40.20
ip dhcp excluded-address 10.0.20.80
ip dhcp pool CLIENTS
 network 10.0.20.0 255.255.255.0
 default-router 10.0.20.1
 dns-server 10.0.30.10
 exit
ip dhcp pool WIFI
 network 10.0.40.0 255.255.255.0
 default-router 10.0.40.1
 dns-server 10.0.30.10
 exit
end
write memory
```

> ⚠️ **Correction from the first attempt.** The third exclusion line was missing. `prn-2f-01` holds `10.0.20.80` statically, but the CLIENTS pool leases the whole of `10.0.20.0/24`, so DHCP could hand that address to a laptop. It would have worked fine until the day a new device joined, which is the kind of fault worth finding in a lab. The written config looked correct on paper and only building it exposed this.

The exclusion range also decides the first offered address. Excluding `.1` to `.50` makes the first laptop land on `.51`, matching `AST-1011`.

### Check

```
show ip interface brief
```

All five subinterfaces `up up`. The parent `Gi0/0` shows `unassigned`, which is right: the addresses live on the subinterfaces.

> ⚠️ **Watch for a stray `router rip`.** Mine picked one up somewhere, a RIP process with no networks under it, doing nothing. Remove it with `no router rip`. An unexplained routing protocol sitting in a config is exactly what gets asked about.

---

## 🔀 Stage 4: Switches

Same block on all three, with two values changing per device.

### VLANs

```
enable
configure terminal
hostname sw-core-01
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
exit
```

Define all five on every switch, even the ones a given switch does not use today. A trunk drops traffic for VLANs the local switch has never heard of, so this keeps the two access switches interchangeable.

### `sw-core-01`

```
interface GigabitEthernet0/1
 description uplink to rtr-edge-01
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,30,40,99
 exit
interface range FastEthernet0/1 - 2
 description down to access switches
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,30,40,99
 exit
interface GigabitEthernet0/2
 description srv-file-01
 switchport mode access
 switchport access vlan 30
 exit
interface vlan 10
 ip address 10.0.10.2 255.255.255.0
 no shutdown
 exit
ip default-gateway 10.0.10.1
end
write memory
```

`interface range` needs the spaces around the hyphen.

The `allowed vlan` list is a whitelist. Without it a trunk carries every VLAN that exists, now and in future.

`interface vlan 10` does not route anything. A 2960 is layer 2. That address exists purely so the switch can be managed, and it is `10.0.10.2` because that is what `AST-1001` says.

### `sw-acc-01` and `sw-acc-02`

Same VLAN block, then:

```
interface GigabitEthernet0/1
 description uplink to sw-core-01
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,30,40,99
 exit
interface range FastEthernet0/1 - 10
 switchport mode access
 switchport access vlan 20
 exit
interface vlan 10
 ip address 10.0.10.11 255.255.255.0
 no shutdown
 exit
ip default-gateway 10.0.10.1
end
write memory
```

For `sw-acc-02`: `hostname sw-acc-02` and `10.0.10.12`.

Configure `Fa0/1` to `Fa0/10` as a block rather than only the ports in use, so anyone can plug in anywhere on that floor.

### 🚨 Errors you will see, and should

Configuring one switch at a time means the two ends of a trunk disagree for a while. Expect this:

```
%CDP-4-NATIVE_VLAN_MISMATCH: Native VLAN mismatch discovered on FastEthernet0/2 (99), with Switch GigabitEthernet0/1 (1)
%SPANTREE-2-BLOCK_PVID_LOCAL: Blocking FastEthernet0/1 on VLAN0099. Inconsistent local vlan.
```

`(99)` is your side, `(1)` is the far side still on factory default. Spanning tree blocks VLAN 99 rather than carry traffic when the ends cannot agree, because a native VLAN mismatch is the basis of VLAN hopping attacks.

**This is not a fault.** It clears as soon as you configure the other switch. Anyone changing a trunk on a live network sees the same window.

---

## ✅ Stage 5: Verify

`show interfaces trunk` on `sw-core-01`. The last block is the useful one:

```
Port        Vlans in spanning tree forwarding state and not pruned
Fa0/1       10,20,30,40,99
Fa0/2       10,20,30,40,99
Gig0/1      10,20,30,40,99
```

All three identical. This command also lets you see which end of a link has been configured without logging into the other device: a trunk missing VLAN 99 from that list has a far end that is not agreeing yet.

> ⚠️ **A stale block that will not clear.** After both my ends matched, `Fa0/1` still showed 99 missing. Packet Tracer's spanning tree is simplified and the block stuck. Bounce the port:
>
> ```
> interface FastEthernet0/1
>  shutdown
>  no shutdown
> ```
>
> Also worth checking *which* VLAN is affected before chasing it. Only 99 was blocked, and 99 carries no user traffic, so connectivity would have been fine either way.

### End devices

- `srv-file-01`: `Desktop` → `IP Configuration` → Static. `10.0.30.10 / 255.255.255.0`, gateway `10.0.30.1`
- `prn-2f-01`: `Config` → `FastEthernet0` → Static `10.0.20.80 / 255.255.255.0`, then `Settings` for the gateway `10.0.20.1`. The printer keeps its gateway on a different screen from its IP
- `nb-1123` then `nb-1147`: `Desktop` → `IP Configuration` → DHCP. In that order, DHCP allocates by request order and the CMDB says `nb-1123` holds `.51`

### The pings

From `nb-1123` → `Desktop` → `Command Prompt`:

```
ipconfig
ping 10.0.20.1        gateway
ping 10.0.30.10       server, crosses VLANs
ping 10.0.20.52       other laptop, through the core
ping 10.0.20.80       printer
```

### 🎯 TTL proves the routing

This is the best single piece of evidence in the lab.

| Ping | TTL | Meaning |
|---|---|---|
| `10.0.20.1` gateway | 255 | the router answered directly |
| `10.0.20.52` laptop | 128 | same VLAN, never routed |
| `10.0.20.80` printer | 128 | same VLAN |
| `10.0.30.10` server | **127** | **routed exactly once** |

Replies start at TTL 128 and every router that forwards one subtracts 1. A reply at 127 is the packet itself reporting that exactly one router handled it. That proves inter-VLAN routing without anyone having to trust the config or the diagram.

---

## 📸 Stage 6: Save the evidence

Capture these into `network/screenshots/`, numbered in run order and named after what they prove:

```
00-final-pkt-screenshot.png            topology, every link green
01-ipconfig-nb-1123.png                DHCP gave 10.0.20.51
02-ping-gateway.png                    TTL 255
03-ping-server-cross-vlan.png          TTL 127, the important one
04-ping-across-access-switches.png     TTL 128
05-ping-printer.png                    TTL 128
06-core-show-vlan-brief.png            five VLANs, server port in 30
07-core-show-interfaces-trunk.png      three trunks, native 99
08-router-show-ip-interface-brief.png  five subinterfaces up
09-router-show-ip-dhcp-binding.png     which MAC got which address
```

`Screenshot 2026-08-04 021533.png` tells a reader nothing. Run all the pings in one session and capture the scrollback: a continuous session is more convincing than five isolated images.

### Export the running configs

On each network device:

```
enable
terminal length 0
show running-config
```

Select, `Ctrl+C`, and save over the matching file in `network/configs/`.

> ⚠️ **The VLANs will not be in the export, and cannot be.** Cisco keeps the VLAN database in `vlan.dat`, separate from the running config. So `show running-config` shows ports *assigned* to VLAN 30 but never shows VLAN 30 being *created*. Paste an exported config into a fresh switch without creating the VLANs first and every port assignment fails silently. Each config file in this repo carries a header with the `vlan` block to paste first.

Save the lab file as `network/koeln-hq-lan.pkt` so anyone can open the network rather than take your word for the diagram.

---

## 📶 Stage 7: Wi-Fi (optional, strong)

1. Add a WLC 3504, connect it to the core on a VLAN 10 port
2. Add lightweight access points on access switch ports
3. On the WLC create a WLAN with SSID `KOELN-CORP` mapped to VLAN 40
4. Add wireless clients, associate them, confirm they get a `10.0.40.x` address from the WIFI pool

This is the fiddliest part of Packet Tracer. Do it as a second session. A simpler stand-in is a single access point on a VLAN 40 access port with an SSID and wireless clients pulling DHCP. That still demonstrates Wi-Fi, SSID to VLAN mapping and DHCP. If you use the stand-in, say so rather than implying the full controller setup.

---

## 🔁 Making a finding real

Two records in the seed CMDB are broken on purpose and both are reproducible here:

- `AST-1012` has IP `10.0.10.300`, which is not a valid address
- `AST-1013` sits on VLAN 25, which is not in the plan

Give a device a wrong address in the lab, or put a port in a VLAN that does not exist. The audit flags it, you fix it in Packet Tracer and in the CMDB, and the after report shows the number moving. That is inventory reconciliation against the real configuration, which is what the role actually involves.

The printer DHCP clash in stage 3 is the honest version of this: a fault I did not plant, found only because the lab was built.
