---
title: "linux-inspector: Working Out What a Linux Server Actually Does"
date: 2026-10-24 12:00:00 +0800
categories: [Linux, Projects]
tags: [Linux, Python, SystemAdministration, Discovery, Documentation, Kubernetes]
---

A server can be healthy and still be a mystery.

You can see that nginx is running. There is a Java process, a database, a few containers and several custom systemd units. Nobody is quite sure which application owns a port, whether a scheduled job still matters, or where a configuration change needs to go so it survives the next deployment.

That is the problem I started **linux-inspector** to investigate. It collects evidence from a Linux machine and builds a report about what the machine does, how its services connect, where its data lives and how it is managed. It can then join several host reports into a fleet map.

The useful question is less "what packages are installed?" and more "what would I need to understand before taking responsibility for this box?"

The examples below use synthetic test machines. Hostnames, domains, application names and topology are illustrative; they are not a map of a live environment. The project is currently at version **0.1.0**, so this is a look at the working tool and its limits, not a claim that discovery is solved.

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

That last question matters on a GitOps-managed host. Finding Flux or Argo CD sources is more useful than handing someone a list of Kubernetes objects they could edit and have immediately reconciled back.

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

A confirmed local listener does not prove that an Internet client can reach it. A configured database hostname does not prove that the database is healthy. Those are different claims, and the report needs to keep them separate.

The current summaries come from Python parsers and correlation rules. Running the tool does not require an LLM or a hosted model API. An optional model-assisted narrative layer is on the roadmap, not part of the current scan path.

## Trying it without touching a server

These commands assume access to a project checkout. The regular package needs **Python 3.10 or newer**.

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

That fixture represents nginx in front of a systemd-managed FastAPI application, a local PostgreSQL instance and a Compose stack. In my example run it produced **68 entities, 87 relationships and 341 recorded operations**. Those numbers describe this test fixture, not a typical production server.

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

The standard connection-sampling window is **60 seconds**. That is an observation window, not the promised duration of the entire scan. A quiet listener during one minute may still be important overnight or at month end.

## Taking the bundle to an offline machine

SSH is not always available. The project can build a single Python zip application:

```bash
.venv/bin/python tools/build_bundle.py
```

The result is `dist/linux-inspector.pyz`. Building it needs dependencies on the build machine and may download its pinned vendored wheels; a prepared wheel directory can be supplied for an offline build. The finished bundle runs on **Python 3.6 or newer** without installing Python packages on the target.

Once the bundle is on an approved machine, collection can be kept separate from analysis:

```bash
sudo python3 /path/to/linux-inspector.pyz scan \
  --local --no-analyze \
  -o /mnt/review/host-01
```

The output location is explicit. This mode writes evidence where requested; it is not a zero-footprint execution mode. The regular package's Python requirement and the bundle's runtime requirement are different.

Back on the analysis machine:

```bash
.venv/bin/linux-inspector import /mnt/review --check-only
.venv/bin/linux-inspector import /mnt/review --fleet
```

Import checks the recorded structure and output hashes, checks for known secret material and rejects symlinks before accepting evidence. Hashes help detect changes to recorded outputs; they are not a signed attestation that the source machine was trustworthy.

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

The result includes a Markdown fleet report and Mermaid dependency diagrams. Its value depends on the evidence available from each machine; an inferred link does not become confirmed just because it appears in a diagram.

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

The operation IDs connect findings to the outputs behind them. If an application relationship looks wrong, there is a way to investigate the source rather than taking the prose on trust.

For repeated work, I can reanalyze or replay saved evidence without reconnecting to the server:

```bash
.venv/bin/linux-inspector report \
  ./evidence/web-01-review --reanalyze

.venv/bin/linux-inspector scan \
  --replay ./evidence/web-01-review \
  -o ./evidence/web-01-replay
```

Neither command refreshes the facts from the live machine. Replay answers collection requests from previously recorded output; it cannot invent evidence that the original scan never collected.

## Read-only deserves an explanation

The collection path has a fixed command allowlist and checks for dangerous flags. It reads application code and scheduled scripts rather than executing them. Container files are inspected through the host's process filesystem rather than by running commands inside containers. Private-key material and several credential/data locations are excluded, and stored output passes through redaction.

There is no remediation mode. The operating guide may show a restart command for a human to use, but the scanner does not run that recommendation.

That still needs sensible boundaries. SSH and sudo can create audit records. Local collection writes evidence. Some otherwise observational system tools can create caches or first-run files; the roadmap records those side effects as work to resolve. Root access gives a much fuller picture, but it also makes reviewing the collection plan worthwhile.

```bash
.venv/bin/linux-inspector plan \
  --sudo --sample-window 0 \
  -o scan-plan.md

.venv/bin/linux-inspector plan \
  --sudo --sample-window 0 \
  --check /tmp/inspector-demo
```

The first command describes what that configuration may inspect. The second checks the recorded operations against those rules. My fixture run classified all 341 recorded operations without an unplanned operation. That is a check of the operation policy, not a general security certification.

The current redaction also has coverage gaps, so it is not a guarantee that every credential has been removed. Redaction is not the same as anonymization either. A report can still contain hostnames, addresses, repository URLs, usernames and enough topology to identify an environment. I would treat the whole evidence directory as sensitive, review any excerpt before sharing it and use synthetic examples for a public article like this one.

## Where it has helped, and where it stops

The immediate benefit is a better starting point for a takeover, migration or cleanup. I can find custom units among vendor services, follow a domain to its application, identify persistent data and see whether changes belong in Git, Compose or a hand-maintained unit.

It has also been useful during a before-and-after review. A rescan found a new backup timer and upload script, while the managed Kubernetes workloads largely stayed the same. That distinction was useful: a clean GitOps reconciliation did not describe every host-level change.

The same review showed why the output needs interpretation:

- A TCP connection to SSH is not a successful login. The current code uses visible process/session evidence to separate attempts from logged-in clients when privileges allow it. Without process ownership, login state is less certain; authentication records remain an important cross-check.
- Journal counts can include old setup failures after a service has been fixed. They need to be read alongside timestamps and current service state.
- A backup destination stored in a shell variable can remain unresolved. A detected timer and script do not prove that a usable off-site backup exists.
- Firewall analysis describes the host rules it could read. Cloud security lists, NSGs, upstream devices and some forwarding paths are outside that conclusion. Unprivileged scans also have a documented case where unreadable rules can look too permissive.
- Support dates come from a built-in table. This is not a live vulnerability scan or proof that vendor-backported packages are unpatched.

There is no dedicated `linux-inspector diff` command yet. Comparing two scans currently means reviewing their reports or structured files; the first-class diff command is roadmap work. The same applies to the optional model-based narrative layer and broader destination resolution.

For me, the useful outcome is a report I can question: what was observed, what was inferred, and what still needs checking before I change the machine. That is a better handover than a list of running processes and somebody saying, "I think that box does the billing."
