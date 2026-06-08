# imbytecat/homebrew-tap

Personal Homebrew tap for Chinese-vendor desktop apps. Some vendors gate
downloads behind sticky per-IP CAPTCHAs — a small Cloudflare Worker in
[`worker/`](worker/) resolves those from edge IPs so `brew install` works
from any home network. Other casks point at the vendor CDN directly.

## Install

```sh
brew tap imbytecat/tap
brew install --cask imbytecat/tap/<cask>
```

## Casks

| Cask | Notes |
| --- | --- |
| [`doubao-ime`](Casks/doubao-ime.rb) | Doubao Input Method (豆包输入法). Installs to `~/Library/Input Methods`. |
| [`roxy-browser`](Casks/roxy-browser.rb) | RoxyBrowser (Roxy浏览器). Apple Silicon only, `.pkg` installer with vendor postinstall script that POSTs an install-completion event to `*.gate.roxybrowser.cn/.net` (bumper audits the script for unknown hosts). |
| [`shandianshuo`](Casks/shandianshuo.rb) | Shandianshuo (闪电说). Voice-first AI assistant. Universal DMG hosted on the vendor's GitHub releases (`shandianshuo/shandianshuo-releases`); vendor CDN is Referer-locked, GitHub mirror is the install source. |
| [`ugreen-nas`](Casks/ugreen-nas.rb) | UGREEN NAS (绿联云). |

## How it works

CAPTCHA-gated casks (e.g. `ugreen-nas`) point `url` at the Worker:

```
brew install ──▶ Cask url (workers.dev/<vendor>/dl?…)
                   │
                   ▼
              Cloudflare Worker  ──▶  vendor LIST/SIGN API  ──▶  signed CDN URL
                   │                                                  │
                   └────────── 302 redirect ─────────────────────────┘
```

Casks whose vendor CDN is publicly reachable (e.g. `doubao-ime`) point
`url` straight at the CDN and skip the Worker.

- Cask pins `version` + `sha256` of the published build.
- A per-cask bumper in [`scripts/`](scripts/) reads the vendor's version
  source (LIST endpoint, version JSON, or `-latest` HEAD redirect — no
  CAPTCHA), exits if unchanged, downloads (through the Worker for
  CAPTCHA-gated vendors, directly otherwise), verifies upstream MD5 when
  available, and rewrites the cask. A daily GitHub Action runs every
  bumper in a matrix and opens one PR per outdated cask.
- The Worker caches each signed URL for 2 min (Cloudflare `caches.default`)
  so hot installs share a single upstream call.

See [`worker/README.md`](worker/README.md) for Worker deploy steps and
[`AGENTS.md`](AGENTS.md) for how to add a new cask.

## Development

```sh
nix develop                # ruby_3_3 + rubocop + node_22 + just + curl + jq + 7z + libplist + actionlint + shellcheck
just                       # list recipes
cd worker && npm install   # once
just bump ugreen-nas       # refresh one cask
just style                 # rubocop scripts + actionlint workflows
just worker-test           # typecheck + vitest
```

## Repo setup (one-time)

The daily bump workflow needs permission to open PRs. In repository
**Settings → Actions → General → Workflow permissions**, enable
*Allow GitHub Actions to create and approve pull requests*. Or via `gh`:

```sh
gh api -X PUT repos/imbytecat/homebrew-tap/actions/permissions/workflow \
  -F default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```
