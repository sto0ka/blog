# Bree² Tech Blog 🧪💻

[![Build and Deploy](https://github.com/sto0ka/blog/actions/workflows/pages-deploy.yml/badge.svg)](https://github.com/sto0ka/blog/actions/workflows/pages-deploy.yml)
[![GitHub Pages](https://img.shields.io/badge/pages-live-brightgreen?logo=github)](https://breesquared.com)
[![Made with Jekyll](https://img.shields.io/badge/Made%20with-Jekyll-red?logo=jekyll)](https://jekyllrb.com/)

Welcome to the source for **[Bree² Tech](https://breesquared.com)** —  
a blog where Sr. Dan (aka *Modern-Day Alchemist*) shares insights on Linux, cloud, security, and everything tech.

This site is built with [Jekyll](https://jekyllrb.com/) and the [Chirpy theme](https://github.com/cotes2020/jekyll-theme-chirpy), and deployed automatically with GitHub Pages.

---

## Linux inspection project

[linux-inspector: Working Out What a Linux Server Actually Does](_posts/2026-10-24-linux-inspector.md) introduces the project with synthetic examples, local/SSH/offline usage, evidence-backed reports and current limitations.

## Homelab series

Current deployed services:

| Service | Site |
|---|---|
| **Paperless-ngx** | Home cluster; PostgreSQL, Valkey and encrypted backups |
| Homepage | Cloud cluster; service portal |
| Vikunja | Cloud cluster; task management |
| Zabbix | Cloud cluster; monitoring and alerts |
| Grafana | Cloud cluster; dashboards |


The [two-site K3s homelab post](_posts/2026-10-08-7.md) was updated on 25 October 2026 with Kubernetes monitoring, daily age-encrypted application backups, verified Cloudflare R2 copies, storage-usage alerts, SSH hardening at host and OCI network layers, and the remaining recovery tests. Paperless/Homepage deployments, application checks and the resource/probe/update baseline are now included; optional workload ideas remain proposals.

## ✨ Features
- ⚡️ Static site powered by **Jekyll 4**
- 🎨 Clean and modern **Chirpy theme**
- 💬 Comment system via **[Giscus](https://giscus.app/)**
- 🔍 SEO meta tags, sitemap, and analytics hooks
- 📱 Progressive Web App (PWA) support
- ✅ CI/CD with GitHub Actions (`pages-deploy.yml`)
- Dependency updates through Dependabot; GitHub secret scanning and push protection enabled

---

## 🚀 Local Development

Clone the repo and run it locally:

```bash
# Install the Ruby version in .ruby-version (currently 3.3.13) and Bundler
bundle install

# Build and serve locally
bundle exec jekyll serve
```

Then open [http://localhost:4000](http://localhost:4000) in your browser.

Before opening a pull request, run:

```bash
ruby tools/test-lastmod-hook.rb
bash tools/test.sh
```

Actions are pinned to commit SHAs and maintained by Dependabot. Builds have read-only repository access; only the deployment job receives Pages and OIDC permissions. Review dependency updates against the current main branch and require passing build checks before merging.

For diagrams, use Chirpy's built-in Mermaid support with `mermaid: true` in the post front matter. No separate Mermaid script loader is needed.

---

## 🛠️ Project Structure
- `_posts/` → blog posts (Markdown, with front matter)
- `_config.yml` → site configuration
- `Gemfile` / `Gemfile.lock` → Ruby gems
- `.github/workflows/` → GitHub Actions for CI/CD
- `.ruby-version` → pinned Ruby version for local + CI

---

## 🧑‍💻 Contributing
Pull requests are welcome!  
For major changes, please open an issue first to discuss what you’d like to change.

**Setup steps for contributors:**
1. Fork this repo
2. Clone your fork and run `bundle install`
3. Start the server: `bundle exec jekyll serve`
4. Commit your changes and open a PR 🚀

---

## 📜 License
This project is open source under the [MIT License](./LICENSE).
