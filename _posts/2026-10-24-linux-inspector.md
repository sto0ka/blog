---
title: "linux-inspector: Working Out What a Linux Server Actually Does"
date: 2026-10-24 12:00:00 +0800
last_modified_at: 2026-10-25 00:00:00 +0800
categories: [Linux, Projects]
tags: [Linux, Python, SystemAdministration, Discovery, Documentation, Kubernetes]
---

A server can be healthy and still be a mystery.

You can see that nginx is running. There is a Java process, a database, a few containers and several custom systemd units. Nobody is quite sure which application owns a port, whether a scheduled job still matters, or where a configuration change needs to go so it survives the next deployment.

I’m building **linux-inspector** to make that investigation easier. It collects evidence from a Linux machine and builds a report about what the machine does, how its services connect, where its data lives and how it is managed. It can then join several host reports into a fleet map.

I wanted a tool that could help me answer "what does this box do?" without spending the first hour stitching together command output by hand.

The project is at **0.1.0**. This post walks through what I’ve built so far, how I use it and where I want to take it next. All examples use synthetic test machines, with fictional hostnames, domains and application details.

## Following a request through the machine

A package list might tell me that nginx, Python and PostgreSQL are installed. It does not explain how they fit together.

linux-inspector tries to reconstruct a path like this:

```text
api.example.com
  -> nginx on port 443
  -> application listener on 127.0.0.1:8000
  -> gunicorn process
  -> billing-api.service
  -> FastAPI application in /opt/billing-api
  -> PostgreSQL on port 5432
```

The collector reads the proxy configuration, checks the listener and its owning process, follows that process to its service or container, and inspects relevant application files. Established connections can supply evidence for the database relationship.

This helps answer practical questions: which unit would I inspect for a failed API, which logs belong to it, and would editing a local configuration file actually stick?

On a GitOps-managed host, I also want the report to point me to the Flux or Argo CD source. That gives me a place to make a lasting change.

## Evidence, then interpretation

The code separates collection from analysis and reporting:

```text
Local / SSH / recorded evidence / synthetic fixture
                      |
                 Collectors
                      |
                  facts.json
                      |
              Correlation and findings
                      |
        graph.json + analysis.json + report.md
```

Collectors cover the host, processes, systemd, scheduled jobs, network rules, web servers, certificates, databases, applications, containers and Kubernetes. The analysis joins facts into relationships; the Markdown report puts the operational summary before the detailed inventory.

Relationships carry a confidence label:

| Label | How I read it |
|---|---|
| Confirmed | A relationship has direct supporting evidence, such as a listener with an owning process. |
| Inferred | Configuration or naming suggests the relationship, but it was not directly observed. |
| Unknown | Something is referenced, but the scan could not establish the next step. |

I keep those labels attached to the relationships so I can follow up on an inferred dependency or a missing part of the chain. Listener discovery, network reachability and service health each answer a different question.

I’ve built the current summaries with Python parsers and correlation rules, so collection and reporting run locally without a model API.

## Trying it without touching a server

From a project checkout, I set up the development environment like this. The regular package needs **Python 3.10 or newer**.

```bash
cd linux-inspector
python3 -m venv .venv
.venv/bin/python -m pip install -e .
```

The repository includes fake filesystems and canned command output, so the collection and reporting pipeline can run against a fixture:

```bash
.venv/bin/linux-inspector scan \
  --fixture tests/fixtures/web-compose-host \
  --sudo \
  --sample-window 0 \
  -o /tmp/inspector-demo
```

Here `--sudo` enables the fixture's privileged view. It does not run a privileged scan of the workstation. `--sample-window 0` avoids waiting for the usual connection-sampling window.

That fixture represents nginx in front of a systemd-managed FastAPI application, a local PostgreSQL instance and a Compose stack. In my example run it produced **68 entities, 87 relationships and 341 recorded operations**. The fixture gives me a repeatable way to check how changes affect the report.

The report is written to:

```text
/tmp/inspector-demo/report.md
```

I can also ask a narrower question:

```bash
.venv/bin/linux-inspector trace \
  --domain api.example.com \
  --evidence /tmp/inspector-demo

.venv/bin/linux-inspector explain \
  --application billing-api \
  --evidence /tmp/inspector-demo
```

`trace` follows the request path. `explain` describes the application: its runtime, startup units, routes, configuration paths and dependencies. Both use the saved evidence, so I do not have to reconnect to a host for every follow-up question.

## What a report looks like

Here is an abridged example from the repository’s synthetic three-host fixture. I’ve shortened the headings and selected a few columns to fit the post. The generated report goes on to include the detailed inventory and evidence references.

### At a glance

**edge-01** is a virtual machine running Ubuntu 22.04.4 LTS. It serves three domains through nginx, with Ansible management markers in two configuration files.

| Item | Result |
|---|---|
| Role | Reverse proxy / web front end |
| Domains | api.example.com, blog.example.com, shop.example.com |
| Web server | nginx 1.18.0 |
| Monitoring | Zabbix agent 2 |
| Management | Ansible markers in nginx configuration |

### Web endpoints

| Domain | Ports | Backend | Confidence |
|---|---|---|---|
| api.example.com | 80, 443 | 10.0.0.20:3000 | Inferred |
| blog.example.com | 80, 443 | app-01.corp.example:8081 | Inferred |
| shop.example.com | 80, 443 | 10.0.0.20:8080 | Inferred |

### Operating guide: nginx

- **Runs as:** `nginx.service`, active and enabled.
- **Logs:** `journalctl -u nginx.service --since today` and `/var/log/nginx/access.log`.
- **Configuration:** `/etc/nginx/nginx.conf` and `/etc/nginx/sites-enabled/`.
- **Change via:** Ansible; the configuration files carry management markers.

Commands in the operating guide are there for me to use when needed; the scan doesn’t run them.

When I join all three fixture hosts, the fleet report follows the application through to its database:

```text
api.example.com
  -> edge-01: nginx on 443
  -> app-01: orders-api on 3000, managed by PM2
  -> db-01: PostgreSQL on 5432
```

The host endpoint table records configuration-derived links as inferred. The fleet view adds the connections observed across the scanned hosts. That is the part I wanted to bring together: the service, its configuration, the way it is managed and the next system in the chain.

[Download this sample report as Markdown]({{ '/assets/examples/linux-inspector-report-excerpt.md' | relative_url }}).

## Running a real collection

For a host reachable over SSH:

```bash
.venv/bin/linux-inspector scan \
  --ssh admin@web-01 \
  --sudo \
  -o ./evidence/web-01-review
```

SSH uses key or agent authentication in BatchMode. `--sudo` expects non-interactive `sudo -n`; if that check fails, the scan continues without elevated access and records limitations. The SSH mode does not install an agent on the target.

There are three collection depths:

| Depth | Useful for |
|---|---|
| `quick` | Initial host, process, service, listener and configuration inventory. |
| `standard` | Adds deeper application and Kubernetes discovery, journal sampling and usage observations. |
| `deep` | Wider source searches and additional environment/container-log inspection, with more material to review. |

The standard connection-sampling window is **60 seconds**, in addition to the other collection work. I use it to add a picture of activity during the scan, alongside the configured services and listeners.

## Taking the bundle to an offline machine

SSH is not always available. The project can build a single Python zip application:

```bash
.venv/bin/python tools/build_bundle.py
```

The result is `dist/linux-inspector.pyz`. Building it needs dependencies on the build machine and may download its pinned vendored wheels; a prepared wheel directory can be supplied for an offline build. The finished bundle runs on **Python 3.6 or newer** without installing Python packages on the target.

On a machine I’m inspecting, I can collect first and analyze the saved evidence later:

```bash
sudo python3 /path/to/linux-inspector.pyz scan \
  --local --no-analyze \
  -o /mnt/review/host-01
```

I choose the evidence destination explicitly so I can carry the results back to my analysis machine. The bundle’s older Python support is useful for inspecting systems where I don’t want to install another runtime.

Back on the analysis machine:

```bash
.venv/bin/linux-inspector import /mnt/review --check-only
.venv/bin/linux-inspector import /mnt/review --fleet
```

The import workflow checks recorded output hashes and runs validation before rebuilding the analysis from the collected facts.

## From one box to a service map

For several SSH targets, a text file can hold one host per line:

```text
admin@edge-01
admin@app-01
admin@db-01
```

```bash
.venv/bin/linux-inspector scan \
  --targets hosts.txt --sudo --parallel 3
```

The fleet stage joins machines by observed addresses and names. A service path can then continue from a proxy on one host to an application and database on others.

The repository's three-host fixture demonstrates this with nginx, a Tomcat application and database servers. It also lists dependencies outside the scanned set. That is a useful handover list: "these systems are referenced, but we have not inspected them yet."

Existing scans can be joined again without recollection:

```bash
.venv/bin/linux-inspector fleet ./evidence
```

The result includes a Markdown fleet report and Mermaid dependency diagrams, with the evidence and confidence labels carried through from the host reports.

## What gets saved

A host's evidence directory contains more than the final report:

```text
report.md          Human-readable assessment
manifest.json      Scan metadata and limitations
operations.jsonl   Recorded collection operations and hashes
raw/               Redacted operation outputs
facts.json         Normalized collector results
graph.json         Entities, relationships and evidence references
findings.json      Issues with classifications and evidence
analysis.json      Summaries, traces and application profiles
```

I keep operation IDs with the findings so I can trace a relationship back to the output that produced it. That has been useful while developing parsers and checking a report against the fixture.

For repeated work, I can reanalyze or replay saved evidence without reconnecting to the server:

```bash
.venv/bin/linux-inspector report \
  ./evidence/web-01-review --reanalyze

.venv/bin/linux-inspector scan \
  --replay ./evidence/web-01-review \
  -o ./evidence/web-01-replay
```

I use reanalysis while improving the reporting rules, and replay while working on collectors. Both work with the saved scan; I run a new collection when I need a fresh view of the host.

## Keeping collection focused

I designed the collection path around observation. It has a fixed command allowlist and checks command arguments before running them. Application code and scheduled scripts are read for context, and container files are inspected through the host’s process filesystem.

The tool collects evidence and produces a report. I make any changes to the system separately, once I’ve worked out what belongs where.

I can review the collection plan before a scan and check the recorded operations afterwards:

```bash
.venv/bin/linux-inspector plan \
  --sudo --sample-window 0 \
  -o scan-plan.md

.venv/bin/linux-inspector plan \
  --sudo --sample-window 0 \
  --check /tmp/inspector-demo
```

The first command describes what that configuration may inspect. The second checks a saved scan against those rules. This is also part of my development workflow when I add a collector or expand an existing one.

Collection writes evidence to the chosen destination, and SSH, sudo and system tools can leave their usual logs or caches. I treat collected evidence as private operational data. Public examples in this post come from synthetic fixtures.

## What I find useful

The main benefit for me is getting the pieces into one place. I can follow a domain to its application, find the unit that starts it, locate persistent data and see whether configuration belongs in Git, Compose or a local file.

That makes several jobs easier:

- **Taking over a server:** start with a map of services and dependencies, then follow the evidence for the parts that need a closer look.
- **Planning a migration:** identify application roots, startup configuration, databases and storage before moving anything.
- **Investigating a problem:** use `trace` or `explain` to narrow the search to the application and its supporting services.
- **Writing documentation:** use the host and fleet reports as a starting point, with paths and relationships already collected.
- **Developing discovery rules:** replay saved fixtures and compare the results without repeatedly connecting to a server.

## What I’m working towards

I’m continuing to improve how the tool follows configuration references and explains missing visibility. I also want a dedicated scan comparison command, so I can ask what changed between two collections and get a useful summary of services, dependencies and configuration changes.

At the moment, I compare the saved reports and structured files. A built-in `diff` workflow is the next step I’d like to make easier.

That is the direction of linux-inspector: spend less time gathering the same clues by hand, and more time understanding the system I’m working on. I’m building it around the questions I ask when I sit down in front of an unfamiliar Linux machine.
