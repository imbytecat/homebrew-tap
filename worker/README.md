# homebrew-proxy

Cloudflare Worker that resolves vendor signed-URL APIs and 302-redirects to
the real download. Used by [`imbytecat/homebrew-tap`](..) casks so end-user
installs don't hit per-IP CAPTCHAs on vendor APIs.

## Stack

- TypeScript on Workers runtime, [Hono](https://hono.dev) for routing
- Wrangler + vitest pinned in `package.json` (lockfile required for `npm ci`)
- [`redirectProxy`](src/lib/proxy.ts) — vendor modules supply `resolveDownloadUrl(id)` + cache key + TTL

## Routes

| Route | Vendor | Notes |
| --- | --- | --- |
| `GET /ugnas/dl?id=<appId>` | UGREEN | Allowed ids: `515` (mac arm64), `516` (mac x64), `514` (win64), `517` (android), `502` (android-tv) |

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

Each signed URL is cached 5 min in `caches.default` (UGREEN signatures live
~8 min). Hot keys share one upstream call so end users almost never trigger
upstream CAPTCHA even at Worker level.
