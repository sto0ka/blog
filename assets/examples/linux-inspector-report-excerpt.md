# linux-inspector sample report

Abridged from the synthetic three-host fixture's edge-01 report. Headings and columns are shortened for this example. All names, addresses and configuration paths below belong to the test fixture, not a live environment.

## At a glance

**edge-01** is a virtual machine running Ubuntu 22.04.4 LTS. It serves three domains through nginx. Ansible management markers were found in two configuration files.

| Item | Result |
| --- | --- |
| Role | Reverse proxy / web front end |
| Domains | api.example.com, blog.example.com, shop.example.com |
| Web server | nginx 1.18.0 |
| Monitoring | Zabbix agent 2 |
| Management | Ansible markers in nginx configuration |

## Web endpoints

| Domain | Ports | Backend | Confidence |
| --- | --- | --- | --- |
| api.example.com | 80, 443 | 10.0.0.20:3000 | Inferred |
| blog.example.com | 80, 443 | app-01.corp.example:8081 | Inferred |
| shop.example.com | 80, 443 | 10.0.0.20:8080 | Inferred |

## Operating guide: nginx

- Runs as: `nginx.service`, active and enabled
- Logs: `journalctl -u nginx.service --since today` and `/var/log/nginx/access.log`
- Configuration: `/etc/nginx/nginx.conf` and `/etc/nginx/sites-enabled/`
- Change via: Ansible; configuration files carry management markers

Commands in the operating guide are suggestions for the reader. The scan did not run them.

## Fleet request chain

The fleet report joins the proxy with the scanned application and database hosts:

```text
api.example.com
  -> edge-01: nginx on 443
  -> app-01: orders-api on 3000, managed by PM2
  -> db-01: PostgreSQL on 5432
```

The host endpoint table records configuration-derived links as inferred. The separate fleet analysis also joins observed connections across the three fixture hosts.
