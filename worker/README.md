# ugnas-proxy

Cloudflare Worker that proxies UGreen's per-IP CAPTCHA-gated download endpoint
so Homebrew (and any HTTP client) gets a stable redirect-style URL.

## Endpoint

```
GET /dl?id=<appId> -> 302 to https://dl-cn.ugnas.com/.../<file>.dmg?signature=...
```

| id | platform |
| --- | --- |
| 515 | UGREEN NAS macOS Apple Silicon |
| 516 | UGREEN NAS macOS Intel |
| 514 | UGREEN NAS Windows 64-bit |
| 517 | UGREEN NAS Android |
| 502 | UGREEN NAS Android TV |

Add more ids in [`src/index.js`](src/index.js) `ALLOWED_IDS`.

## First-time deploy

```sh
cd worker
npx wrangler login
npx wrangler deploy
```

Wrangler will assign a URL like `https://ugnas-proxy.<your-subdomain>.workers.dev`.
Update [`Casks/ugreen-nas.rb`](../Casks/ugreen-nas.rb) `url` and `verified:`
to that hostname if it isn't `imbytecat.workers.dev`.

## Auto-deploy via GitHub Actions

```sh
gh secret set CLOUDFLARE_API_TOKEN
```

Token comes from Cloudflare Dashboard → My Profile → API Tokens → use the
*Edit Cloudflare Workers* template. Every push to `main` that touches
`worker/` will redeploy.

## Cache behavior

Each `id` is cached for 5 minutes. UGreen's signed URL is valid ~8 minutes,
so a cached redirect has 3+ minutes of validity left in the worst case.
Plenty for a 330 MB DMG over CDN.
