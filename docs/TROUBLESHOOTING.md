# 🔧 Troubleshooting

Everything below is something I actually hit while building this. I did not anticipate any of it and I did not pad the list to look thorough.

I have grouped them into cloud, network lab, and general. The ones I would most want you to read are the silent failures, where nothing errors and the wrong outcome looks like the right one.

---

## ☁️ Cloud module

### Az module missing or old

`Install-Module Az -Scope CurrentUser`. If it clashes with the old AzureRM module, restart the session. Check with `Get-Module Az -ListAvailable`.

Not needed at all in Azure Cloud Shell, where Az is preinstalled.

### No context or wrong subscription

After `Connect-AzAccount`, set the right subscription with `Set-AzContext -Subscription "<id>"`. Otherwise resources land in the default one. Check with `Get-AzContext`.

In Cloud Shell you are already authenticated, so `Get-AzContext` should print a subscription immediately. If it prints nothing, stop and fix that before running anything else.

### 🐚 Bash vs PowerShell in Cloud Shell

Cloud Shell offers both. My scripts are `.ps1`, so **Bash cannot run them at all**. It prints nothing useful either, which made this hard for me to diagnose because I did not suspect the shell.

Use the dropdown at the top left of the Cloud Shell window to switch to **PowerShell**.

- ✅ Right shell: prompt reads `PS /home/<you>>`
- ❌ Wrong shell: prompt reads `<you>@Azure:~$`

I lost a run to switching back and forth between the two mid-session. Pick one and stay in it.

### 📁 Forward slashes in Cloud Shell

Cloud Shell PowerShell runs on **Linux**. Invoke scripts as `./scripts/00-setup-demo-assets.ps1`, not `.\scripts\00-setup-demo-assets.ps1`.

The README shows the Windows form because that is where the scripts were written. See the next entry for what that assumption cost.

### 🪤 Backslashes in script paths (fixed, worth knowing)

My scripts originally built paths like this:

```powershell
Join-Path $PSScriptRoot '..\reports'
```

That works on Windows. On Linux a backslash is a **legal filename character**, not a separator, so the same line resolved to a directory literally named `..\reports` inside `scripts/`.

Here is what made it nasty:

- Nothing errored
- The directory was created
- The CSV was written into it
- The script printed a success message with a plausible-looking path

So the reports were simply not where my repo said they were, and `accuracy-log.csv` never accumulated across runs.

I fixed it everywhere with:

```powershell
Join-Path (Split-Path $PSScriptRoot -Parent) 'reports'
```

I avoided the multi-argument form of `Join-Path`. It reads better, but it needs PowerShell 6 or later, and I want these running in Windows PowerShell 5.1 on a plain desktop.

A script that fails loudly is fine. A script that lies quietly is the one I worry about.

### Region not available

Some resource types or SKUs are limited per region. NSG, VNet and route table are all available in Germany West Central. For anything else, check with `Get-AzLocation`.

### Resource provider not registered

A brand new subscription may not have `Microsoft.Network` registered. If resource creation fails complaining about the provider:

```powershell
Register-AzResourceProvider -ProviderNamespace Microsoft.Network
```

Wait a couple of minutes, then retry.

### Tags come back empty

`Get-AzResource` returns `Tags` as a hashtable or `$null`. Reading immediately after creating can catch the tag state before it has propagated. Wait a moment and run the inventory again.

### Tag key casing

Azure treats tag **names** as case-insensitive but **values** as case-sensitive. `Environment='Production'` fails the audit because only `Prod`, `Test`, `Dev` are allowed. That is deliberate. It is the whole argument for validating values rather than counting populated fields.

### Policy compliance shows nothing

The scan is asynchronous. After `Start-AzPolicyComplianceScan` it can take a few minutes before `Get-AzPolicyState` returns results. For the reliable number use `02-audit-compliance.ps1`, which is available immediately.

### Do not forget to clean up

NSG, VNet and route table cost nothing, but they pile up. `04-teardown.ps1` removes everything cleanly. It asks for a typed `yes` first, which is intentional: a script whose whole job is deleting things should not run off a stray keypress.

---

## 🌐 Network lab

### 🔴 The router link starts red, and that is correct

Every Cisco router interface ships **administratively shut down**. Switch ports are the opposite, live out of the box, which is why switch-to-switch links come up green on their own while the router link does not.

It turns green after:

```
interface GigabitEthernet0/0
 no shutdown
```

Not a cabling fault. Packet Tracer accurately simulating a router out of the box.

### 🔌 Wrong cable type

Switch-to-switch normally needs a **crossover** cable, while router-to-switch and PC-to-switch need **straight-through**. Pick wrong and the link goes red with nothing explaining why.

Use **Connections → Automatically Choose Connection Type** (the lightning bolt). It picks correctly every time and removes a whole category of wasted debugging.

### 🚨 Native VLAN mismatch while half-configured

```
%CDP-4-NATIVE_VLAN_MISMATCH: Native VLAN mismatch discovered on FastEthernet0/2 (99), with Switch GigabitEthernet0/1 (1)
%SPANTREE-2-RECV_PVID_ERR: Received BPDU with inconsistent peer vlan id 1 on FastEthernet0/2 VLAN99
%SPANTREE-2-BLOCK_PVID_LOCAL: Blocking FastEthernet0/1 on VLAN0099. Inconsistent local vlan
```

`(99)` is your side, `(1)` is the far end still on factory default. Configuring one switch at a time guarantees a window where the two ends of a trunk disagree.

Spanning tree blocks the affected VLAN rather than carry traffic when the ends cannot agree, because a native VLAN mismatch is the basis of VLAN hopping attacks. IOS refuses to quietly carry traffic it cannot reason about.

**Not a fault.** It clears as soon as both ends match. Anyone changing a trunk on a live network sees the same thing.

### 🔁 A PVID block that will not clear

After both my ends agreed, one trunk still showed VLAN 99 missing from the forwarding list. Packet Tracer's spanning tree is simplified and the block can stick.

I bounced the port to force a re-evaluation:

```
interface FastEthernet0/1
 shutdown
 no shutdown
```

Wait 30 to 50 seconds, then re-check. That cleared it for me.

If it persists, **check which VLAN is actually affected before chasing it.** In my design only VLAN 99 was blocked, and 99 is the native parking VLAN carrying no user traffic, so my connectivity was fine either way.

Knowing which alarms to act on and which to note and walk past is most of what troubleshooting actually is.

### 🔍 Reading `show interfaces trunk` to find the unconfigured end

The last block is the useful one:

```
Port        Vlans in spanning tree forwarding state and not pruned
Fa0/1       10,20,30,40
Fa0/2       10,20,30,40,99
Gig0/1      10,20,30,40,99
```

`Fa0/1` is missing 99 while the others have it. That means the device at the far end of `Fa0/1` has not been configured to match yet.

This lets you tell which end of a link is unconfigured **without logging into the other device**.

### 🪤 Your VLANs are not in the exported config

My exported switch configs contain `switchport access vlan 30` but never contain `vlan 30`. I thought my export had failed.

It had not. Cisco stores the VLAN database in **`vlan.dat`**, a separate file from the running config. So `show running-config` shows ports *assigned* to a VLAN but never shows the VLAN being *created*.

Paste an exported config into a fresh switch without creating the VLANs first and **every port assignment fails silently**. Create them first:

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

Every config file in `network/configs/` carries this block in its header for that reason.

### 🖨️ DHCP handing out a static address

My `CLIENTS` pool leases from all of `10.0.20.0/24` and originally excluded only `.1` to `.50`. My printer holds `10.0.20.80` statically, inside the lease range.

Nothing broke on the day I built it. It would have broken the first time a new device joined and got offered `.80`.

```
ip dhcp excluded-address 10.0.20.80
```

**Anything statically assigned inside a DHCP range has to be excluded from that range.** I would internalise this one, because the symptom shows up months after the mistake.

Two things I took from it:

- I only found this because I built the lab. The config read perfectly on paper
- The exclusion range also decides the first offered address. Excluding `.1` to `.50` is what makes my first laptop land on `.51`, matching `AST-1011` in the CMDB

### 🧹 A stray `router rip`

The exported router config contained a RIP process with no `network` statements under it. It advertised nothing and did nothing.

```
no router rip
```

Harmless, but an unexplained routing protocol sitting in a config is exactly what gets asked about, and "I do not know, it was just there" is not an answer.

### 📏 DHCP order decides which laptop gets which address

DHCP allocates in request order. If the CMDB says `nb-1123` holds `.51`, request from `nb-1123` **before** `nb-1147`, or they come back swapped and the inventory no longer matches.

If a client says `DHCP request failed`, switch it to Static and back to DHCP to retry. First attempts sometimes time out while spanning tree is still settling on the access port.

### 🎯 TTL tells you whether traffic was routed

Replies start at TTL 128 and every router that forwards one subtracts 1.

| Reply TTL | Meaning |
|---|---|
| 255 | a router answered directly, it was the destination |
| 128 | same VLAN, never routed |
| 127 | routed exactly once |

This is the cheapest way to confirm inter-VLAN routing genuinely works rather than assuming it from the config. It also catches the opposite case: if a cross-VLAN ping returns 128, the two devices are not in the VLANs you think they are.

### 🖨️ The printer keeps its gateway on a different screen

In Packet Tracer, a printer's IP address is under `Config` → `FastEthernet0`, but its **default gateway is under `Config` → `Settings`**. Set the IP, assume you are done, and it will not reach anything off its own subnet.

---

## 🪟 General

### Git Bash vs PowerShell on Windows

Some Az commands with path arguments break under Git Bash, because Git Bash rewrites paths. Run these scripts in PowerShell.

### Packet Tracer crashes

It does. Save into the repo early with `File` → `Save As` → `network/koeln-hq-lan.pkt`, then `Ctrl+S` every few minutes. Saving directly into the repo folder also means the lab file is already where it needs to be when you commit.
