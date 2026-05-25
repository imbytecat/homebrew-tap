# imbytecat/homebrew-tap

Personal Homebrew tap for Chinese-vendor desktop / NAS clients whose
download endpoints sit behind sticky per-IP CAPTCHAs. A small Cloudflare
Worker in [`worker/`](worker/) resolves the vendor signed-URL APIs from
edge IPs so `brew install` works from any home network.

## Install

```sh
brew tap imbytecat/tap
brew install --cask imbytecat/tap/<cask>
```

## Casks

| Cask | Notes |
| --- | --- |
| [`ugreen-nas`](Casks/ugreen-nas.rb) | UGREEN NAS (绿联云). |

## How it works

Each cask's `url` points at the Worker, not the vendor:

```
brew install ──▶ Cask url (workers.dev/<vendor>/dl?…)
                   │
                   ▼
              Cloudflare Worker  ──▶  vendor LIST/SIGN API  ──▶  signed CDN URL
                   │                                                  │
                   └────────── 302 redirect ─────────────────────────┘
```

- Cask pins `version` + `sha256` of the published build.
- A per-cask bumper in [`scripts/`](scripts/) reads the vendor LIST endpoint
  (no CAPTCHA), exits if unchanged, downloads through the Worker, verifies
  upstream MD5, and rewrites the cask. A weekly GitHub Action runs every
  bumper in a matrix and opens one PR per outdated cask.
- The Worker caches each signed URL for 5 min (Cloudflare `caches.default`)
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

The weekly bump workflow needs permission to open PRs. In repository
**Settings → Actions → General → Workflow permissions**, enable
*Allow GitHub Actions to create and approve pull requests*. Or via `gh`:

```sh
gh api -X PUT repos/imbytecat/homebrew-tap/actions/permissions/workflow \
  -F default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```
