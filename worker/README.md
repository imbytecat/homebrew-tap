# homebrew-proxy

Cloudflare Worker that resolves vendor signed-URL APIs and 302-redirects to
the real download. Used by [`imbytecat/homebrew-tap`](..) casks so end-user
installs don't hit per-IP CAPTCHAs on vendor APIs.

## Stack

- TypeScript on Workers runtime
- [Hono](https://hono.dev) for routing
- Wrangler pinned in `package.json` (auto-picked by `wrangler-action`)
- Generic [`redirectProxy`](src/lib/proxy.ts) helper — vendor modules just
  supply `resolve()` + cache key + TTL

## Routes

| Route | Vendor | Notes |
| --- | --- | --- |
| `GET /ugnas/dl?id=<appId>` | UGREEN | Allowed ids: `515` (mac arm64), `516` (mac x64), `514` (win64), `517` (android), `502` (android-tv) |

Add a new vendor:

1. Drop `src/vendors/<vendor>.ts` exporting a `Hono` sub-app
2. `app.route("/<vendor>", <vendor>)` in `src/index.ts`

## Local dev

```sh
nix develop                        # gives you node + ruby + just + curl
cd worker
npm install
npm run typecheck
npm run dev                        # wrangler dev at http://localhost:8787
```

## First-time deploy

```sh
cd worker
npm install
npx wrangler login                 # browser-based OAuth
npx wrangler deploy
```

Wrangler assigns `https://homebrew-proxy.<your-subdomain>.workers.dev`. If
your CF subdomain isn't `imbytecat`, update `Casks/ugreen-nas.rb` and
`scripts/bump-ugreen-nas.rb` to match.

## Auto-deploy from CI

```sh
gh secret set CLOUDFLARE_API_TOKEN
```

Token from Cloudflare Dashboard → My Profile → API Tokens → *Edit Cloudflare
Workers* template. `.github/workflows/deploy-worker.yml` runs `npm ci`,
`tsc --noEmit`, then `wrangler deploy` on every push to `main` touching
`worker/`.

## Cache

Each cache key is held for 5 min (UGREEN signed URLs live ~8 min). Hot keys
share a single upstream call so end users almost never trigger the upstream
CAPTCHA gate even at the Worker level.
