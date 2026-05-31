# homebrew-proxy

Cloudflare Worker that resolves vendor signed-URL APIs and 302-redirects to
the real download. Used by CAPTCHA-gated casks in
[`imbytecat/homebrew-tap`](..) so end-user installs don't hit per-IP
CAPTCHAs on vendor APIs.

## Stack

- TypeScript on Workers runtime, [Hono](https://hono.dev) for routing
- Wrangler + vitest pinned in `package.json` (lockfile required for `npm ci`)
- [`redirectProxy`](src/lib/proxy.ts) — vendor modules supply `resolveDownloadUrl(version)` + cache key + TTL

## Routes

| Route | Vendor | Notes |
| --- | --- | --- |
| `GET /ugnas/dl?v=<version>&id=<id>` | UGREEN | When `id` is supplied (current `Casks/ugreen-nas.rb`), Worker calls the vendor's by-id TEMP_LINK endpoint directly — no LIST round-trip. When `id` is missing (legacy / not-yet-rebumped caller), Worker falls back to LIST + version match for backward compat. Signed URL cached 120 s per `id` (or per `v` on the fallback path). |

## Local dev

```sh
nix develop                        # from repo root: ruby + node + just + wrangler deps
cd worker && npm install           # once
just worker-dev                    # wrangler dev at http://localhost:8787
just worker-test                   # tsc --noEmit + vitest
```

## First-time deploy

```sh
cd worker
npm install
npx wrangler login                 # browser-based OAuth
npx wrangler deploy
```

Wrangler assigns `https://homebrew-proxy.<your-subdomain>.workers.dev`. If
your CF subdomain isn't `imbytecat`, update `CaskBumper::WORKER_BASE` in
`scripts/lib/cask_bumper.rb` and each cask's `url` / `verified:`.

## Auto-deploy from CI

```sh
gh secret set CLOUDFLARE_API_TOKEN
```

Token from Cloudflare Dashboard → My Profile → API Tokens → *Edit Cloudflare
Workers* template. `.github/workflows/deploy-worker.yml` runs `npm ci`,
typecheck, vitest, then `wrangler deploy` on every push to `main` touching
`worker/**` or the workflow itself.

## Cache

Each signed URL is cached 120 s in `caches.default` (UGREEN signatures live
~8 min, so even slow installs finish before expiry). Hot keys share one
upstream call so end users almost never trigger upstream CAPTCHA even at
Worker level.
