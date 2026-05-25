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
| `Casks/<name>.rb` | The cask. Pure declarative DSL. No `require`, no custom class, URL must include `#{version}` interpolation. |
| `worker/` | Cloudflare Worker. TS + Hono. Each new vendor = a Hono sub-app under `worker/src/vendors/<vendor>.ts`, mounted in `worker/src/index.ts`. The generic `redirectProxy(c, { resolve, cacheKey, ttl })` helper in `worker/src/lib/proxy.ts` handles `caches.default` + 302; vendor modules just export a `resolveDownloadUrl(id)` and a `Hono` sub-app. `USER_AGENT` is the one shared constant. |
| `worker/src/vendors/*.test.ts` | Vitest tests for each vendor's resolver. Plain node env, `fetch` mocked via `vi.spyOn`. Pool-Workers is not used — we only test pure resolve logic, not `caches.default`. |
| `scripts/lib/cask_bumper.rb` | `CaskBumper::Bumper` base class. Subclasses override `#worker_path` and `#upstream` (returns `{ version:, md5: }`). Base handles HTTP, MD5 check, SHA256, cask file rewrite, `WORKER_BASE` constant. |
| `scripts/bump-<name>.rb` | Thin subclass per cask. Detects upstream version via the cask's LIST endpoint (no CAPTCHA), exits if unchanged, downloads via the Worker, verifies upstream MD5, rewrites the cask. |
| `.github/workflows/ci.yml` | macOS: `brew style --tap` + `brew audit --cask --online --tap`. Ubuntu: `rubocop scripts/` and worker `npm ci` + `typecheck` + `test`. Runs on push + PR. |
| `.github/workflows/deploy-worker.yml` | `npm ci` → `typecheck` → `test` → `wrangler deploy` when `worker/**` changes on main. |
| `.github/workflows/bump.yml` | Weekly + manual. `discover` job globs `scripts/bump-*.rb` into a matrix; `bump` job runs each in parallel, opens one PR per outdated cask. `workflow_dispatch` accepts an optional `cask` input to bump just one. |
| `.github/dependabot.yml` | Weekly grouped updates for `github-actions` + worker `npm`. |
| `flake.nix` | Dev shell: ruby_3_3 + rubocop, nodejs_22, just, curl, p7zip, libplist, jq. |
| `Justfile` | `just bump <name>` / `worker-dev` / `worker-deploy` / `worker-typecheck` / `worker-test` / `style`. |

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

- Cask files: none.
- Bump scripts and `scripts/lib/cask_bumper.rb`: only `# frozen_string_literal: true`
  (mandatory pragma) and a single class-level doc on `CaskBumper::Bumper`
  that defines the subclass contract (`#worker_path`, `#upstream`).
- TypeScript: none beyond what's needed to disambiguate non-obvious behavior.

When adding any new comment, justify it as documenting non-obvious
*external* behavior or a public-API contract — never restating code. The
session hook will object otherwise.

## Bump script invariants

- Reads LIST endpoint (no CAPTCHA) first, compares to current cask version,
  returns early if unchanged. **Never download speculatively** — every
  wasteful fetch nudges the IP toward CAPTCHA on the download endpoint.
- Downloads through the Worker, not direct from the vendor API. GH Actions
  runner IPs can also get CAPTCHA'd; the Worker absorbs that.
- Verifies upstream `md5` from LIST against the downloaded file before
  computing SHA256, *only if* the LIST endpoint exposes one. Subclass's
  `#upstream` returns `{ version:, md5: nil }` if no md5 is available.
- Rewrites with `^\s*version\s+"…"` and `^\s*sha256\s+"…"` line-anchored
  regexes (in `CaskBumper::Bumper#rewrite_cask`). The URL line contains
  `#{version}` literally; the regex won't match it. If you ever add a
  `version "…"` or `sha256 "…"`-shaped string inside a comment / multiline /
  URL, that regex will misfire.
- Subclass MUST stay thin: only `worker_path` + `upstream` + per-vendor
  constants. If you reach for a shared HTTP helper, add it to the base.

## Worker

- Pinned versions live in `worker/package.json` and the lockfile.
  `cloudflare/wrangler-action@v4` honors the package-local wrangler instead
  of pulling its default. Do not drop the lockfile; CI runs `npm ci`.
- `caches.default` (Cloudflare Cache API) is used instead of KV — no
  bindings to manage. 5-minute TTL is below typical signature lifetimes
  (UGREEN's is ~8 min).
- The Worker URL hostname (`homebrew-proxy.imbytecat.workers.dev`) lives in
  one constant: `CaskBumper::WORKER_BASE` in `scripts/lib/cask_bumper.rb`.
  Each cask DSL file also hardcodes it in `url` / `verified:` (cask DSL
  can't reference Ruby constants). Keep these in sync.
- TypeScript strict + `@cloudflare/workers-types`. `npm run typecheck`
  must pass. `npx wrangler deploy --dry-run` works offline as a smoke test.
- `npm test` runs vitest in plain node env, mocking `globalThis.fetch`.
  Tests only cover vendor `resolveDownloadUrl()`; the `redirectProxy`
  cache layer is Cloudflare-runtime-only and not exercised in tests.

## CI workflow gotchas

- **`Homebrew/actions/setup-homebrew@main` auto-symlinks the tap** when
  `$GITHUB_REPOSITORY` matches `^.+/homebrew-.+$`. Don't checkout to a
  subdir, don't manually `ln -s` into `Library/Taps/`. Use plain
  `actions/checkout@v6` and let setup-homebrew handle it.
  ([main.sh](https://github.com/Homebrew/actions/blob/master/setup-homebrew/main.sh#L104-L106))
- `brew audit --tap imbytecat/tap` is the canonical tap-wide form used by
  `homebrew/homebrew-cask` itself. Don't enumerate casks manually.
- `brew audit` runs without `--new` here. `--new` is for casks being
  submitted to `homebrew/homebrew-cask` and applies strict rules
  irrelevant to a personal tap.
- `brew audit --online` actually downloads the DMG to verify SHA256.
  Each run consumes one Worker call per cask.
- `bump.yml` discovers casks dynamically (`ls scripts/bump-*.rb | jq -R -s …`).
  Adding a cask = create `Casks/<name>.rb` + `scripts/bump-<name>.rb`; no
  workflow edit needed.
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

1. **Probe vendor API**: confirm there's a list endpoint (for `livecheck`
   and version detection) and a download endpoint. Document whether the
   download endpoint requires a session / captcha / signature.
2. **Inventory bundle IDs**: extract the DMG with `7z x <file>.dmg`
   (provided by `flake.nix`), enumerate all `Info.plist` bundle IDs (main +
   helpers + embedded apps) — these drive the `zap` stanza. Don't guess.
3. **Worker vendor module**: add `worker/src/vendors/<vendor>.ts` that
   exports `resolveDownloadUrl(id)` and a `Hono` sub-app, mount it under a
   vendor-named path in `worker/src/index.ts`. Use `redirectProxy` from
   `worker/src/lib/proxy.ts` and the shared `USER_AGENT` constant.
4. **Worker tests**: drop a `worker/src/vendors/<vendor>.test.ts` mirroring
   `ugnas.test.ts` — mock `globalThis.fetch`, assert success + non-2xx +
   missing-field cases.
5. **Cask**: add `Casks/<name>.rb`, point `url` at the new Worker path,
   include `#{version}` interpolation.
6. **Bump subclass**: add `scripts/bump-<name>.rb` extending
   `CaskBumper::Bumper`. Implement `#worker_path` and `#upstream` only.
7. **Done with workflows**: `bump.yml` auto-discovers `scripts/bump-*.rb`;
   `ci.yml` and `deploy-worker.yml` are tap-wide. No workflow edits needed.

## Commit style

Conventional commits, **Chinese commit messages** (see `git log`). Type +
short Chinese subject, optional body with explanation of the *why*, not
the *what*.

## Things deliberately not done

- **No Intel x86 cask.** Homebrew is winding down Intel.
- **`auto_updates true` kept** — UGREEN ships its own updater inside the
  app, brew won't fight it.
- **No `pkgutil:` / `launchctl:` / `signal:` in `uninstall`/`zap`** — this
  is a plain `.app` bundle, no pkg receipt, no launchd agents observed.
  Don't cargo-cult these.
- **No `--new` flag on `brew audit`** in CI. See above.
- **No `@cloudflare/vitest-pool-workers`** — tests don't need the Workers
  runtime to validate the pure resolver logic. If you ever want to test
  `redirectProxy` cache behavior end-to-end, add it then; not before.
- **No per-cask bump workflow.** `bump.yml` is the only one.
