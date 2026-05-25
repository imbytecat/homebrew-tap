# AGENTS.md

Operational notes for AI coding agents working in `imbytecat/homebrew-tap`.

`README.md` is the human-facing front page. Anything dev-only belongs here.

## Architecture in one paragraph

This tap distributes Chinese NAS clients whose vendor download endpoints sit
behind sticky per-IP CAPTCHAs. To make `brew install` work from any user's
home network, every cask points its `url` at a Cloudflare Worker
(`worker/`, name `homebrew-proxy`). The Worker hits the vendor API from
Cloudflare edge IPs and 302-redirects to the freshly-signed CDN URL. The
cask still pins `sha256` of the published build; a bump script refreshes
version + sha when upstream cuts a release. **Do not write a cask whose URL
points directly at the vendor API — that route has been tried and it fails
in production due to CAPTCHA.**

## Layout

| Path | Owns |
| --- | --- |
| `Casks/ugreen-nas.rb` | The cask. Pure declarative DSL. No `require`, no custom class, URL must include `#{version}` interpolation. |
| `worker/` | Cloudflare Worker. TS + Hono. Each new vendor = a Hono sub-app under `worker/src/vendors/`, mounted in `worker/src/index.ts`. The generic `redirectProxy(c, { resolve, cacheKey, ttl })` helper in `worker/src/lib/proxy.ts` handles `caches.default` + 302; vendor modules just supply `resolve()`. |
| `scripts/bump-ugreen-nas.rb` | Detects upstream version via the **LIST endpoint** (`api.ugnas.com/api/system/v3/sa/apk`, no CAPTCHA), exits if unchanged, downloads via the Worker, verifies upstream MD5, rewrites the cask. |
| `.github/workflows/ci.yml` | `brew style` + `brew audit --cask --online` on macOS. |
| `.github/workflows/deploy-worker.yml` | `npm ci` → `tsc --noEmit` → `wrangler deploy` when `worker/**` changes. |
| `.github/workflows/bump-ugreen-nas.yml` | Weekly + manual. Runs the bump script, opens a PR via `peter-evans/create-pull-request@v8`. |
| `flake.nix` | Dev shell: ruby_3_3 + rubocop, nodejs_22, just, curl, p7zip, libplist, jq. |
| `Justfile` | `just bump-ugreen-nas` / `worker-dev` / `worker-deploy` / `worker-typecheck` / `style`. |

## Cask invariants (the cop will catch you)

- **`url` must contain `#{version}` literally in source**. Audit's
  `unversioned?` check (`brew/Library/Homebrew/cask/url.rb`) grep's the
  source line for `#{` — if absent it forces `sha256 :no_check`.
- **`verified:` is forbidden when the URL host's eTLD+1 matches the
  homepage's eTLD+1**. `audit_unnecessary_verified` errors. Our Worker host
  (`*.workers.dev`) does NOT match `www.ugnas.com`, so we keep `verified:`.
- **`zap trash:` array is sorted case-insensitively** by the
  `Cask/ArrayAlphabetization` cop (`a.downcase <=> b.downcase`). ASCII
  sort (`U` < `c`) is wrong; `downcase` (`u` > `c`) is right.
- **`depends_on macos:` uses the symbol form**, not a comparison string.
  `Homebrew/OSDependsOn` cop rejects `">= :big_sur"`; use `:big_sur`.
- **Don't write Ruby logic in the cask**. Custom `using:` classes and
  inline `require` statements have zero precedent in `homebrew/homebrew-cask`
  and we ripped them out. Keep it declarative.

## Comments

The cask currently has none. Bump script has only `# frozen_string_literal: true`
(mandatory pragma). When adding any new comment, justify it as documenting
non-obvious *external* behavior, never restating code. The session hook
will object otherwise.

## Bump script invariants

- Reads LIST endpoint (no CAPTCHA) first, compares to current cask version,
  exits 0 if unchanged. **Never download speculatively** — every wasteful
  fetch nudges the IP toward CAPTCHA on the download endpoint.
- Downloads through the Worker, not direct from the vendor API. GH Actions
  runner IPs can also get CAPTCHA'd; the Worker absorbs that.
- Verifies upstream `md5` from LIST against the downloaded file before
  computing SHA256. The vendor API publishes md5; we use it as a tamper
  check.
- Rewrites with `^\s*version\s+"…"` and `^\s*sha256\s+"…"` line-anchored
  regexes. The URL line contains `#{version}` literally; the regex won't
  match it. If you ever add a `version "…"` or `sha256 "…"`-shaped string
  inside a comment / multiline / URL, that regex will misfire.

## Worker

- Pinned versions live in `worker/package.json` and the lockfile.
  `cloudflare/wrangler-action@v4` honors the package-local wrangler instead
  of pulling its default. Do not drop the lockfile; CI runs `npm ci`.
- `caches.default` (Cloudflare Cache API) is used instead of KV — no
  bindings to manage. 5-minute TTL is below UGREEN's ~8-minute signature
  lifetime.
- The Worker URL hostname (`homebrew-proxy.imbytecat.workers.dev`) is
  hardcoded in **two** places: the cask `url`/`verified:` and the bump
  script `WORKER_DL`. Keep them in sync.
- TypeScript strict + `@cloudflare/workers-types`. `npm run typecheck`
  must pass. `npx wrangler deploy --dry-run` works offline as a smoke test.

## CI workflow gotchas

- **`Homebrew/actions/setup-homebrew@main` auto-symlinks the tap** when
  `$GITHUB_REPOSITORY` matches `^.+/homebrew-.+$`. Don't checkout to a
  subdir, don't manually `ln -s` into `Library/Taps/`. Use plain
  `actions/checkout@v6` and let setup-homebrew handle it.
  ([main.sh](https://github.com/Homebrew/actions/blob/master/setup-homebrew/main.sh#L104-L106))
- `brew audit` runs without `--new` here. `--new` is for casks being
  submitted to `homebrew/homebrew-cask` and applies strict rules
  irrelevant to a personal tap.
- `brew audit --online` actually downloads the DMG to verify SHA256.
  Each run consumes one Worker call.
- The deploy workflow explicitly fails with a clear error when
  `CLOUDFLARE_API_TOKEN` is missing — don't remove that check, the
  underlying `wrangler` failure is unreadable.

## Action versions (current, all node24)

`actions/checkout@v6`, `actions/setup-node@v5`, `ruby/setup-ruby@v1`,
`peter-evans/create-pull-request@v8`, `cloudflare/wrangler-action@v4`,
`Homebrew/actions/setup-homebrew@main` (upstream never tags).

When bumping any, check `runs.using:` in the action's `action.yml`; refuse
anything still on `node20`.

## Adding a new cask for a vendor with signed URLs

1. Probe vendor API: confirm there's a list endpoint (for `livecheck`) and
   a download endpoint. Document if the download endpoint requires a
   session / captcha / signature.
2. Extract the DMG with `7z x <file>.dmg` (provided by `flake.nix`),
   enumerate all `Info.plist` bundle IDs (main + helpers + embedded apps)
   — these drive the `zap` stanza. Don't guess.
3. Add `worker/src/vendors/<vendor>.ts` exporting a Hono sub-app, mount
   it under a vendor-named path in `worker/src/index.ts`. Use
   `redirectProxy` from `worker/src/lib/proxy.ts`.
4. Add the cask, point `url` at the new Worker path, include `#{version}`
   interpolation.
5. Add a bump script for the cask (or generalize `scripts/bump-*.rb` if
   you're feeling brave). Same invariants: LIST endpoint version check
   before download.
6. Add a corresponding workflow file mirroring `bump-ugreen-nas.yml`.

## Commit style

Conventional commits, **Chinese commit messages** (see `git log`). Type +
short Chinese subject, optional body with explanation of the *why*, not
the *what*.

## Things deliberately not done

- **No Intel x86 cask.** Homebrew is winding down Intel.
- **No `auto_updates true` removed** — UGREEN ships its own updater inside
  the app, brew won't fight it.
- **No `pkgutil:` / `launchctl:` / `signal:` in `uninstall`/`zap`** — this
  is a plain `.app` bundle, no pkg receipt, no launchd agents observed.
  Don't cargo-cult these.
- **No `--new` flag on `brew audit`** in CI. See above.
