# imbytecat/homebrew-tap

Personal Homebrew tap.

## Install

```sh
brew install --cask imbytecat/tap/ugreen-nas
```

## Casks

| Cask | Notes |
| --- | --- |
| [`ugreen-nas`](Casks/ugreen-nas.rb) | UGREEN NAS (绿联云) macOS client, Apple Silicon only. |

## Development

```sh
nix develop          # ruby_3_3 + rubocop + just + curl
just bump-ugreen-nas # refresh version + sha256 from upstream API
just style           # rubocop on scripts
```

## Why a Cloudflare Worker proxy

UGREEN's CDN only serves the macOS DMG via short-lived (~8 min) signed URLs
fetched from `api-zh.ugnas.com`. That endpoint enforces a sticky per-IP
CAPTCHA, so a normal `brew install` from a home network gets blocked after
a few requests.

[`worker/`](worker/) holds a tiny Cloudflare Worker (`homebrew-proxy`) that
sits in front of the API: end users hit a stable
`https://homebrew-proxy.<sub>.workers.dev/ugnas/dl?id=515` URL, Cloudflare's
edge IPs talk to UGREEN (and absorb the rate limit), and the Worker
302-redirects to the freshly-signed CDN URL. Signed URLs are cached for
5 min so multiple installs in a window share a single API call.

The cask points at the Worker URL with a pinned `sha256` of the published
build; `scripts/bump-ugreen-nas.rb` refreshes the version + sha when upstream
cuts a release.

See [`worker/README.md`](worker/README.md) for deploy steps.

Intel x86 is intentionally not packaged here — Homebrew is winding down Intel
support. Grab the Intel `.dmg` from <https://www.ugnas.com/download/> if you
need it.

## Repo setup (one-time)

The weekly bump workflow needs permission to open PRs. In repository
**Settings → Actions → General → Workflow permissions**, enable
*Allow GitHub Actions to create and approve pull requests*. Or via `gh`:

```sh
gh api -X PUT repos/imbytecat/homebrew-tap/actions/permissions/workflow \
  -F default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```
