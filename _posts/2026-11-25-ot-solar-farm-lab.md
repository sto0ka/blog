---
title: "Building an OT Security Lab — A Solar Farm Behind a Purdue-Model Firewall"
date: 2026-11-25 12:00:00 +0800
categories: [Security, Homelab]
tags: [OT, ICS, Purdue, Modbus, DNP3, Suricata, Proxmox, Segmentation, Detection]
comments: true
media_subpath: /assets/img/ot-lab
image:
  path: hmi-before.png
  alt: HMI single-line diagram of the simulated solar farm
---

For most of November I ran a small power plant on a mini PC under my desk.

The plant wasn’t real, but the software around it was: a PLC runtime, a SCADA HMI, a DNP3 master standing in for the grid operator, a historian, and a next-gen firewall between every level of the Purdue model. I wanted a lab where I could show segmentation, an attack and its detection end to end, with every demo starting from one command.

This post covers what I built, what the demos showed and what I learned. The lab is switched off now. The VMs are backed up and the same host has moved on to the next project.

## The plant

The lab simulates **SF-01**, a utility-scale solar farm:

- 10 MW of PV across four central inverters
- a 5 MW / 10 MWh battery
- a 33 kV switchboard with four breakers, a protection relay and a revenue meter at the grid connection
- a weather station, inverter faults, battery alarms and grid frequency events

The physics is a Python simulator. Everything above it is real industrial software. To keep demos short, one plant day lasts 30 real minutes, so you can watch a sunrise, a cloud front and an export-limit curtailment in one coffee break.

## The HMI

The operator screens are built in FUXA, an open-source web SCADA/HMI. I didn’t draw them by hand: a Python script generates the whole FUXA project (six pages plus faceplates) from the same point map as the PLC program, so tags, alarms and screens always agree.

![FUXA overview](fuxa-overview.png)
_The overview page: plant KPIs across the top, the 33 kV single-line diagram, plant status, active alarms and a 10-minute power trend. Here inverter INV-3 has tripped on a fault and the battery feeder breaker is open._

Clicking any piece of equipment opens a faceplate. Breakers use select-before-operate, just like real switchgear. The grid page shows the revenue meter, the protection relay (under/over-frequency and voltage) and the plant controller’s export limit, which the grid operator sets remotely over DNP3.

![FUXA grid connection and protection](fuxa-grid-protection.png)
_Grid connection and protection: meter, relay status with lockout reset, and plant control in REMOTE, where the grid operator sets the export limit._

I could also reach the HMI from my phone over Tailscale. It works, though FUXA’s auto-resize stretches pages unevenly on a small screen, so the phone view is for glancing rather than operating.

![FUXA on a phone](fuxa-phone.png){: width="320" }
_The overview on a phone._

Behind the HMI, Telegraf copies every point into the historian:

![Historian dashboard](grafana.png)
_The historian (InfluxDB and Grafana): power at the grid connection, curtailment, inverter state, battery cells, grid frequency and an alarm timeline._

## The setup

Everything runs as Debian VMs on one Proxmox host, a Ryzen mini PC with 26 GB of RAM. Each Purdue level is its own network:

| Level | Zone | Host | Software | Role |
|---|---|---|---|---|
| L0 | PROC | field-io | Python, pymodbus | Plant simulator (Modbus TCP) |
| L1 | CTRL | plc1 | OpenPLC v3 | Plant controller; Modbus server and DNP3 outstation |
| L2 | SUP | scada | FUXA, a DNP3 master, Telegraf | Operator HMI and the grid operator’s control centre |
| L3 | OPS | historian, ews | InfluxDB, Grafana; a desktop with mbpoll | History and the engineering workstation |
| L3.5 | DMZ | dmz01 | nginx, an Influx replica, Grafana, apt-cacher-ng | TLS proxy to the HMI, a read-only data copy, package proxy |
| L4 | ENT | mgmt | scripts | The "IT" host that drives the demos |

In the middle sits a virtual **Crystal Eye** appliance (CE 6.0) acting as firewall, IDS and VPN. It has one virtual NIC per level and is the `.1` gateway in every zone, so every packet between levels has to cross it.

![One zone per Purdue level](network.png)

On the appliance, each level is a security zone bound to its own interface, and every zone’s default policy is **Blocked**. None of my zones use the "Allowed Zones" shortcut, so nothing crosses between them without a named rule.

![Security zones on the firewall](ce-zones.png)
_Security zones: one per Purdue level plus one per VPN, all with default policy Blocked._

Each host is also named in the appliance’s network map. Those names then appear on every event, so an analyst sees `SF01-PPC-01` rather than a bare IP. An unnamed device on an OT interface is worth a look in its own right, which matters later.

![Network map by interface](ce-network-map.png)
_Devices by interface: one named asset per zone (two in operations)._

The build is all code. One script creates the VMs and another provisions them. Generators turn a single point map into the PLC program (Structured Text), the HMI project and the Grafana dashboard, so a point changes in one place and all three follow.

## Default block, named conduits

Traffic between zones is blocked by default. Anything that has to pass gets a named conduit with one source zone, one destination zone and only the ports it needs:

| Conduit | From → To | Port | Why |
|---|---|---|---|
| C1 | PLC → field I/O | 502 | The PLC drives the plant |
| C2 | SCADA → PLC | 502, 20000 | HMI (Modbus) and control centre (DNP3), from the SCADA server’s IP only |
| C4 | SCADA → historian | 8086 | Telemetry |
| C7 | historian → DMZ | 8086 | Data is pushed up to a replica; the DMZ can’t pull |
| C8 | enterprise → DMZ | 3000 | Business users read Grafana in the DMZ, not in the plant |
| C9/C10 | operator VPN → DMZ proxy → HMI | 443 → 8080 | Remote operators only ever see the proxy |

Remote access is two WireGuard tunnels, each in its own zone. Operators reach the HMI proxy and nothing else. Engineers land on a DMZ jump host. No VPN zone has a rule into levels 0 to 2.

A small script tests all 39 designed flows, allowed and blocked, after every rule change. It turned out to be the most useful thing in the project.

## One command per demo

Every demo runs from the enterprise host with `demo.sh` and prints readable output, so I can talk while it runs and switch to the firewall for the evidence.

| Command | What it shows |
|---|---|
| `demo.sh check` | Pre-flight: every conduit, the HMI through the proxy, and live DNP3 data with the plant’s current state |
| `demo.sh 1` | Conduits: three flows the plant needs are allowed, three that it never should are blocked |
| `demo.sh 2` | An IT host probes the PLC and HMI web interfaces, and the IDS rules fire |
| `demo.sh 3` / `3r` | A breaker trip over the allowed DNP3 path, then a reclose |
| `demo.sh 4` | A recon sweep from IT into the plant |
| `demo.sh 5` | Can the PLC reach the internet? |
| `demo.sh 6` | Who can reach the firewall’s own admin interfaces? |
| `demo.sh 7` / `8` | A shadow device on the SCADA network, with protection off and then on |
| `demo.sh reset` | Clears trips and faults and closes the grid breaker |
| `demo.sh fix-plc` | Recovers the PLC if its DNP3 server wedges |

Under the hood it’s plain Bash: SSH to the source VM and try a TCP connect with `/dev/tcp`. The plant line comes from a small status API on the SCADA host:

```bash
# reach <from host|mgmt> <to ip> <port> <label>: TCP connect test
reach() {
  local t="timeout 4 bash -c '</dev/tcp/$2/$3' 2>/dev/null"
  if [[ $1 == mgmt ]]; then bash -c "$t"; else on "$1" "$t"; fi && ok "$4" || no "$4"
}
```

Demo 1 proves the picture:

![Demo 1: conduits](demo1-conduits.png)
_The engineering workstation has mbpoll, the PLC’s address and the know-how, and still can’t read the PLC: there’s no conduit from L3 to L1._

## Recon from the IT side

A port sweep from the enterprise host into the plant gets no answer on any industrial port: Modbus 502, DNP3 20000, S7 102, EtherNet/IP 44818. Everything that does answer goes through one exception I created on purpose so the lab could be automated.

![Demo 4: recon sweep](demo4-recon.png)

With segmentation in place, the attack surface from IT is exactly your exception list. That’s a useful sentence to put in front of a plant manager.

On the firewall, each probe is a flow record. A flow with zero packets back to the client is a dropped SYN:

![Flow events from the sweep](threathunt-sweep.png)

## OT is boring on purpose

Before any attack, I show a normal day. Group 24 hours of events by source, destination and type, and the whole plant comes down to about five conversations: SCADA reads the PLC, the control centre polls the PLC over DNP3, the PLC drives the field I/O, SCADA writes to the historian, and the historian pushes a copy to the DMZ.

Inside the DNP3 conversation the pattern is even clearer. Reads (function code 1) and responses (129) number in the thousands per hour. Direct operates (function code 5) run to a few dozen, and those are the control centre changing the export limit. Reads are routine; writes are rare and meaningful.

That gives an analyst three questions to ask of every event:

1. Is this a relationship we’ve seen before?
2. Is it a read or a write?
3. Is it happening at a time that makes sense?

## Writes, approved and otherwise

First, a few approved writes. The grid operator lowers the export limit over DNP3, and the HMI follows it down. Then the operator opens and recloses a feeder breaker from the HMI using select-before-operate: one click to select, which starts a 10-second window, and a second click to operate. Real switchgear works this way so that one stray packet can’t flip a breaker.

Both writes come from the one approved source over the one approved conduit. Nothing alerts, and that’s correct.

### Tripping the grid breaker over an allowed path

Next, the SCADA host is compromised. The attacker uses the control centre’s own DNP3 master to send a direct-operate command that opens the main grid breaker.

| Before | After |
|---|---|
| ![HMI before](hmi-before.png) | ![HMI after](hmi-after.png) |

Export falls from about 6 MW to zero and every inverter goes offline. The firewall allows all of it, correctly, because the plant can’t run without SCADA → PLC on DNP3. Segmentation can’t help here. This is the detection layer’s job.

The IDS parses DNP3, so you can filter on the function code:

![DNP3 direct operates from SCADA](threathunt-dnp3.png)

The honest reading is 72 direct operates in three hours, and almost all of them are legitimate dispatch. Function code 5 from SCADA on its own isn’t an alarm. Catching the attack needs either the object index (which point was operated: the grid breaker, not a setpoint) or behaviour (an off-schedule burst, a new source, an operate outside a dispatch window). Both need custom rules or correlation in the SOC.

### A shadow device on the SCADA network

The demo I liked most: a small device turns up on the SCADA subnet. It could be a contractor’s laptop or a Raspberry Pi behind a cabinet. On its own it can’t reach the PLC, because conduit C2 is pinned to the SCADA server’s IP rather than the subnet.

So I make the most common real-world mistake on purpose: one extra rule that trusts the whole SCADA network.

With that rule on, the device reads the PLC over Modbus (no password and no handshake, because Modbus has neither), finds the coil for the main grid breaker, then does exactly what the operator did a minute earlier: select, then operate. The plant disconnects from the grid, and the historian shows export falling to zero at the same minute.

Nothing in the protocol stopped it. What the firewall did see was an unnamed device talking to the controller, a relationship that had never existed in the baseline, at a time nobody had planned. That detection doesn’t need a signature.

Then I restore the plant, switch the bad rule off and run the same attack again. Every connection attempt gets silence back, and the plant doesn’t notice. On the firewall you can watch the device keep trying, with zero packets returned. Modbus stays open; only the path from the one device that had no business using it is gone.

### Probing the PLC’s web interface

OpenPLC has a web interface for uploading programs and starting or stopping the runtime. I wrote local Suricata rules for those URIs (`/upload-program`, `/start_plc`, `/stop_plc`, `/hardware`) and for the HMI’s project export and login endpoints. Demo 2 hits each of them from the IT host:

![Demo 2: web probe](demo2-web-probe.png)

They produced the clearest alerts in the lab: rare, meaningful events, labelled with asset names from the network map.

![Alerts from the IT host](ce-alerts-it.png)
_Threat Hunt: program upload, start command, hardware recon and HMI project export, all from the enterprise host to the PLC and SCADA._

One detail is worth noticing: `/start_plc` still returned HTTP 302 even though its rule action is drop. More on that in the lessons.

All of this runs in one IDS profile across every zone, using the vendor’s OT base ruleset plus my local rules, in Detection & Protection mode. That’s detection first, deliberately.

![IDS profile](ce-idps-profile.png)
_The IDS profile: OT base ruleset, all plant zones, and dnp3, http and flow among the logged event types._

## Response in OT is a conversation

In IT, when in doubt, you pull the cable. In a power plant, pulling the wrong cable can be the outage. The playbook I used to close the demos:

- the SOC observes and alerts
- the plant operator, who owns safety, decides
- block the source at the conduit; isolate a whole zone only with the operator’s agreement
- recover with the plant’s normal procedure, not with a security tool

Containment in the shadow-device demo was surgical. Modbus and the SCADA network stayed up, because the real SCADA server needs both to run the plant.

## What I learned

**Write the conduit list first, then test it automatically.** A table of every flow, allowed and blocked, plus a script that checks them all made every rule change safe.

**One any-any rule silently undoes everything.** Early on, a temporary allow-all rule sat in the rule base and quietly turned every "blocked" result into "allowed". Nothing looked broken; only the flow test caught it. Temporary rules need an owner and an expiry date.

**Pin rules to hosts.** Multi-zone rules and subnet-wide sources are where the surprises come from. Pinning the control conduit to one IP is what made the shadow-device attack fail.

**Know whether the IDS is in the path or beside it.** "Blocked" in an alert log isn’t the same as the packet never arriving. In a detection-first mode the request can reach the PLC before a reset is sent. I tested enforcement with a server I controlled and captures on both ends before trusting any "drop". In OT I’d start passive, build a clean baseline, and go inline on specific conduits during a maintenance window.

**Protocol-aware isn’t intent-aware.** DNP3 parsing gives you function codes, but telling a dispatch from a breaker trip needs object-level rules or behavioural baselines. Modbus visibility varies a lot between products, so check what actually gets logged.

**Turn on inline features one conduit at a time.** One inline inspection feature I tried dropped established long-lived sessions mid-stream and cut connectivity for a while. Keep a rollback ready.

**Small labs have real failure modes.** A plain TCP probe against the PLC’s DNP3 port could wedge the outstation: Modbus and DNP3 stopped answering while the link stayed up, and the HMI showed stale values that looked healthy. The pre-demo check now confirms DNP3 data is moving, not just that the port is open. I also stopped running connectivity sweeps right before a demo.

**Wi-Fi power save on a hypervisor is a trap.** 100+ ms LAN latency, DNS timeouts and slow downloads all came down to the host’s Wi-Fi adapter going to sleep. Turn power save off, or better, use a cable.

## What came out of it

- a scripted Purdue-model OT lab of eight VMs plus the firewall, rebuildable from a Git repository
- a live process on real OT protocols, with an HMI and a historian with a DMZ replica
- 39 designed flows with an automated pass/fail test
- one-command demos with a health check and a reset
- custom IDS rules for PLC and HMI engineering actions, with saved threat-hunt queries for each demo
- separate WireGuard zones for operators and engineers
- a short webinar deck, a deep-dive deck, a findings report, presenter run sheets and a redeploy runbook

## Where I’m taking it next

The OT VMs are backed up and switched off, and the host now runs an AI security lab. The backups restore to the same addresses in a few minutes.

When the OT lab comes back, I want to close the gap the breaker-trip demo exposed: DNP3 object-level detection and a behavioural baseline for control commands.

Three things I’d take from it:

1. **Know your relationships.** In OT a handful of conversations is the whole plant, so a new one stands out.
2. **Know a read from a write.** Most traffic asks. Very little commands, and commands are what hurt.
3. **Enforce at the conduit.** The controller trusts anything that reaches it, so decide carefully what can.

That’s what I enjoyed about this lab: once the plant was running, every security idea had something real to protect.
