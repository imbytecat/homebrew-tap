# AGENTS.md

Operational notes for AI coding agents working in `imbytecat/homebrew-tap`.

`README.md` is the human-facing front page. Anything dev-only belongs here.

## Architecture in one paragraph

This tap distributes Chinese NAS clients and similar desktop software whose
vendor download endpoints sometimes sit behind sticky per-IP CAPTCHAs. To
make `brew install` work from any user's home network, **CAPTCHA-gated**
casks point their `url` at a Cloudflare Worker (`worker/`, name
`homebrew-proxy`); the Worker hits the vendor API from Cloudflare edge IPs
and 302-redirects to the freshly-signed CDN URL. Casks with **publicly
reachable CDN URLs** (e.g. `doubao-ime`) skip the Worker entirely and
point `url` at the vendor CDN directly. The cask always pins `sha256` of
the published build; a bump script refreshes version + sha when upstream
cuts a release. **Do not write a CAPTCHA-gated cask whose URL points
directly at the vendor API — that route has been tried and it fails in
production due to CAPTCHA.**

## Layout

| Path | Owns |
| --- | --- |
| `Casks/<name>.rb` | The cask. Pure declarative DSL. No `require`, no custom class, URL must include `#{version}` interpolation. |
| `worker/` | Cloudflare Worker. TS + Hono. Each new vendor = a Hono sub-app under `worker/src/vendors/<vendor>.ts`, mounted in `worker/src/index.ts`. The generic `redirectProxy(c, { resolve, cacheKey, ttl })` helper in `worker/src/lib/proxy.ts` handles `caches.default` + 302; vendor modules just export a version-based `resolveDownloadUrl(...)` and a `Hono` sub-app. `USER_AGENT` is the one shared constant. |
| `worker/src/vendors/*.test.ts` | Vitest tests for each vendor's resolver. Plain node env, `fetch` mocked via `vi.spyOn`. Pool-Workers is not used — we only test pure resolve logic, not `caches.default`. |
| `scripts/lib/cask_bumper.rb` | `CaskBumper::Bumper` base class. Subclasses override `#upstream` (returns `{ version: }` plus optional `md5:`/`url:`/`id:`/per-vendor keys) and either `#worker_path` (CAPTCHA-gated → proxied via Worker) or `#download_url` (public CDN → direct). Optional hooks: `#validate_download(path)` for post-download archive/pkg checks, `#cask_url_after_bump` to rewrite non-version placeholders in the cask `url` line (e.g. UGREEN's pinned vendor `id=`). Base enforces three invariants automatically: cask `url` must contain literal `\#{version}`; proxied cask `url` must start with `WORKER_BASE`; URL line is rewritten by `#rewrite_cask` from `#cask_url_after_bump` on every bump. Base provides `#cask_url_template`, `#fetch_json`, and `#fetch_redirect_location` helpers. |
| `scripts/bump-<name>.rb` | Thin subclass per cask. Detects upstream version via the cask's LIST endpoint (no CAPTCHA), exits if unchanged, downloads (through the Worker for CAPTCHA-gated vendors, directly otherwise), verifies upstream MD5 when available, rewrites the cask. |
| `.github/workflows/ci.yml` | macOS: `brew style --cask imbytecat/tap` + `brew audit --cask --online --tap imbytecat/tap`. Ubuntu: `rubocop scripts/` and worker `npm ci` + `typecheck` + `test`. Runs on push + PR. |
| `.github/workflows/deploy-worker.yml` | `npm ci` → `typecheck` → `test` → `wrangler deploy`. Triggers on push to `main` touching `worker/**` or the workflow file itself. |
| `.github/workflows/bump.yml` | Weekly + manual. `discover` job uses `find scripts -name 'bump-*.rb' -printf '%f\n'` to build a matrix; `bump` job runs each in parallel, opens one PR per outdated cask. `workflow_dispatch` accepts an optional `cask` input to bump just one. |
| `.github/dependabot.yml` | Weekly grouped updates for `github-actions` + worker `npm`. |
| `flake.nix` | Dev shell: ruby_3_3 + rubocop, nodejs_22, just, curl, p7zip, libplist, jq, actionlint, shellcheck. |
| `Justfile` | `set shell := ["bash", "-ceuo", "pipefail"]`. Recipes: `bump <name>` / `style` (rubocop + actionlint) / `worker-test` (typecheck + vitest) / `worker-dev` / `worker-deploy`. Worker recipes assume `npm install` was run once. |
| `worker/wrangler.toml` | Pins `name = "homebrew-proxy"`, `main = "src/index.ts"`, `compatibility_date = "<recent>"`. Bump `compatibility_date` rather than dropping it. |
| `.rubocop.yml` | `TargetRubyVersion: 3.3`, double-quote strings, `Layout/LineLength: 118`, `Style/Documentation: Enabled: false`, `Casks/**/*` excluded entirely (cask DSL is checked by `brew style`'s Homebrew-aware rubocop), `scripts/**/*.rb` excluded from `Metrics/*` cops. |

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
- **`uninstall` keys follow a fixed order** enforced by
  `Cask/UninstallMethodsOrder`: `quit` before `pkgutil` before
  `delete`/`trash`. Alphabetical or "convenient" ordering fails.
- **`depends_on macos:` uses the symbol form**, not a comparison string.
  `Homebrew/OSDependsOn` cop rejects `">= :big_sur"`; use `:big_sur`.
- **Don't write Ruby logic in the cask**. Custom `using:` classes and
  inline `require` statements have zero precedent in `homebrew/homebrew-cask`
  and we ripped them out. Keep it declarative.

## Comments

- Cask files: none.
- Bump scripts and `scripts/lib/cask_bumper.rb`: only `# frozen_string_literal: true`
  (mandatory pragma) and a single class-level doc on `CaskBumper::Bumper`
  that defines the subclass contract (`#upstream` + one of `#worker_path`
  / `#download_url`).
- TypeScript: none beyond what's needed to disambiguate non-obvious behavior.

When adding any new comment, justify it as documenting non-obvious
*external* behavior or a public-API contract — never restating code. The
session hook will object otherwise.

## Bump script invariants

- Reads upstream (LIST endpoint, version JSON, or HEAD redirect — anything
  that's not the binary download) first, compares to current cask version
  **and** current cask `url`, returns early if both are unchanged. **Never
  download the binary speculatively** — every wasteful fetch nudges the IP
  toward CAPTCHA on the download endpoint.
- `Bumper#run` first line calls `#download_url` and discards the result —
  this is a deliberate fail-fast contract check that raises
  `NotImplementedError` if a subclass overrides neither `#worker_path` nor
  `#download_url`. It is cheap (string interpolation or a memoized
  `#upstream` call that would happen anyway) and protects against
  no-op-when-already-up-to-date masking a broken subclass.
- CAPTCHA-gated vendors download through the Worker, not direct from the
  vendor API; GH Actions runner IPs can also get CAPTCHA'd. Public-CDN
  vendors download directly (the Worker would add latency for no benefit).
- Verifies upstream `md5` from LIST against the downloaded file before
  computing SHA256, when available. Subclass's `#upstream` returns at
  least `{ version: }`; include `md5:` only if the LIST endpoint exposes
  one. Hash is duck-typed — base class reads `info[:md5]` and skips the
  check when absent.
- For casks with non-trivial container shapes (e.g. `container nested:`),
  or `.pkg` casks where the postinstall script makes network calls, the
  subclass overrides `#validate_download(path)` to spot-check the
  downloaded archive. Examples: `bump-doubao-ime.rb` uses `7z l -slt`
  against a nested-zip path template; `bump-roxy-browser.rb` does
  `pkgutil --expand-full` then scans `**/Scripts/*` for unknown HTTP
  hosts against a per-vendor whitelist (catches vendor adding new
  install-time telemetry endpoints between SHA-rounds).
- For direct-CDN vendors, the subclass compares the API-supplied URL
  against the cask's `url` line via `#cask_url_template` + `String#sub` on
  the literal `"\#{version}"` placeholder. Single source of truth —
  changing the cask `url` automatically tightens the drift check.
- If a vendor exposes only a `-latest` redirect endpoint (no JSON URL
  field), the bumper does HEAD via `#fetch_redirect_location` (base
  helper), parses the version out of the `Location:` URL with a regex,
  and drift-checks against `#cask_url_template` using `String#gsub` —
  needed when the cask `url` has multiple `#{version}` interpolations
  (see `bump-roxy-browser.rb`). When both a JSON version endpoint and a
  HEAD redirect exist, the bumper reads the JSON first and asserts the
  two agree (catches livecheck-vs-download divergence).
- Worker-proxied casks pin **vendor artifact id** in the cask URL when
  the upstream LIST API only exposes the current version. Bumper's
  `#upstream` returns `id:`, `#worker_path` includes `&id=<id>`, and
  `#cask_url_after_bump` rewrites the `id=\d+` placeholder. This keeps
  old casks installable even after upstream cuts a newer release: the
  Worker hits the vendor's by-id endpoint and skips LIST entirely. See
  `bump-ugreen-nas.rb` + `Casks/ugreen-nas.rb`'s `?v=#{version}&id=536`.
- `CaskBumper::Bumper#rewrite_cask` uses line-anchored regexes
  (`^\s*url\s+"…"` / `^\s*version\s+"…"` / `^\s*sha256\s+"…"`). The URL
  line is rewritten from `#cask_url_after_bump` on every bump; default
  `#cask_url_after_bump` returns `#cask_url_template` so the URL only
  changes when the subclass overrides.
- Subclass MUST stay thin: only `#upstream` + one of (`#worker_path` /
  `#download_url`) + optional `#validate_download` + optional
  `#cask_url_after_bump` + per-vendor constants. If you reach for a
  shared HTTP helper, add it to the base.

## Worker

- Pinned versions live in `worker/package.json` and the lockfile.
  `cloudflare/wrangler-action@v4` honors the package-local wrangler instead
  of pulling its default. Do not drop the lockfile; CI runs `npm ci`.
  **`nix develop` does NOT install wrangler / vitest** — they live in
  `worker/node_modules/`; run `cd worker && npm install` once after entering
  the dev shell, otherwise `just worker-*` recipes fail.
- `caches.default` (Cloudflare Cache API) is used instead of KV — no
  bindings to manage. TTL is 120 s for UGREEN — well under the observed
  ~8 min signature lifetime, so a cached signed URL is unlikely to expire
  mid-install. Tighter than the previous 5 min to leave more headroom for
  retries and slow connections.
- Public Worker has no auth — cask URLs need to be hit by any user's brew.
  Abuse model: external attacker can fan-out vendor LIST/SIGN calls from
  CF edge. Mitigation lives in the Cloudflare dashboard, not in code:
  enable per-IP rate limiting on `/ugnas/*` (and any future vendor route)
  via WAF if traffic spikes. Don't add request auth.
- The Worker URL hostname (`homebrew-proxy.imbytecat.workers.dev`) lives in
  one constant: `CaskBumper::WORKER_BASE` in `scripts/lib/cask_bumper.rb`.
  Each proxied cask DSL file also hardcodes it in `url` / `verified:` (cask
  DSL can't reference Ruby constants). Keep these in sync.
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
- `brew style` does **not** accept `--tap`; pass the tap name as a
  positional (`brew style --cask imbytecat/tap`). Only `brew audit` has
  `--tap`. (One of those gotchas you only find by failing CI.)
- `brew audit` runs without `--new` here. `--new` is for casks being
  submitted to `homebrew/homebrew-cask` and applies strict rules
  irrelevant to a personal tap.
- `brew audit --online` actually downloads the DMG to verify SHA256.
  Each run consumes one Worker call per proxied cask.
- `bump.yml` discovers casks dynamically via `find scripts -name 'bump-*.rb' -printf '%f\n'`.
  Adding a cask = create `Casks/<name>.rb` + `scripts/bump-<name>.rb`; no
  workflow edit needed. **Don't use `ls glob` here** — shellcheck SC2012
  fires (see "brew style internals" below).
- `bump.yml` sets `concurrency: group: bump-${{ matrix.cask }}` with
  `cancel-in-progress: false` so a simultaneous schedule + manual dispatch
  on the same cask serialize on the fixed `bot/bump-<cask>` branch
  (`create-pull-request` action would otherwise push to the same ref and
  corrupt the PR). GitHub keeps at most 1 running + 1 pending per group;
  a third concurrent run replaces the pending one — latest-pending-wins,
  not infinite queue.
- `bump.yml` job runs on `macos-latest`, not `ubuntu-latest`. Required
  for `.pkg` cask audits that shell out to `pkgutil --expand-full`
  (macOS only). Ubuntu would work for `doubao-ime` and `ugreen-nas`
  alone but the matrix shares a single `runs-on`, and macOS has every
  tool the bumpers need including `curl`, `7z`, and `pkgutil`.
- The deploy workflow explicitly fails with a clear error when
  `CLOUDFLARE_API_TOKEN` is missing — don't remove that check, the
  underlying `wrangler` failure is unreadable.

## `brew style` internals (the part nobody tells you)

`brew style` is **four linters orchestrated by one command**, not just rubocop:

| Tool | Targets | Installed by `brew style` |
| --- | --- | --- |
| `rubocop` | `*.rb` (cask + scripts) | via `Library/Homebrew/style.rb` |
| `shellcheck` | `*.sh` (we have none) and **embedded in actionlint** | brew formula |
| `shfmt` | `*.sh` | brew formula |
| `actionlint` | `.github/workflows/*.yml` | brew formula |

Key implications:

- **`brew style` has no flag to disable actionlint** (only `--only-cops` /
  `--except-cops` exist, and those are rubocop-only). If you ever need to
  suppress an actionlint check, use `.github/actionlint.yaml`'s
  `paths.ignore` or inline `# actionlint-disable` directives.
- **Local `actionlint` ≠ `brew style`'s actionlint.** Standalone `actionlint`
  calls `exec.LookPath("shellcheck")`; if shellcheck isn't on PATH it
  **silently disables** shellcheck rules (verbose-only log). `brew style`
  passes the absolute shellcheck path explicitly so it always runs.
  ⇒ Local repro requires **both** in PATH: dev shell has both via flake.
- actionlint's shellcheck integration **always disables** these SC rules
  inside `${{ … }}` substitution blocks because of false positives:
  SC1091, SC2050, SC2154, SC2157, SC2043, SC2194. Don't expect them to fire.
- Use `shell: bash` not `shell: /bin/bash` in workflow `run:` steps; the
  latter can confuse actionlint's shell detection.

## Action versions (current, all node24)

`actions/checkout@v6`, `actions/setup-node@v6`, `ruby/setup-ruby@v1`,
`peter-evans/create-pull-request@v8`, `cloudflare/wrangler-action@v4`,
`Homebrew/actions/setup-homebrew@main` (upstream never tags).

When bumping any, check `runs.using:` in the action's `action.yml`; refuse
anything still on `node20`.

## Adding a new cask

1. **Probe vendor API**: confirm there's a list endpoint (for `livecheck`
   and version detection) and a download endpoint. Document whether the
   download endpoint requires a session / captcha / signature.
2. **Inventory bundle IDs**: extract the DMG with `7z x <file>.dmg`
   (provided by `flake.nix`), enumerate all `Info.plist` bundle IDs (main +
   helpers + embedded apps) — these drive the `zap` stanza. Don't guess.
3. **Decide route**:
   - **Public CDN, no CAPTCHA** → cask `url` points at the vendor CDN
     directly. Skip steps 4–5. Bumper subclass overrides `#download_url`.
   - **CAPTCHA-gated** → continue with steps 4–5.
4. **Worker vendor module**: add `worker/src/vendors/<vendor>.ts` that
   exports `resolveDownloadUrl(...)` and a `Hono` sub-app, mount it under a
   vendor-named path in `worker/src/index.ts`. Use `redirectProxy` from
   `worker/src/lib/proxy.ts` and the shared `USER_AGENT` constant.
5. **Worker tests**: drop a `worker/src/vendors/<vendor>.test.ts` mirroring
   `ugnas.test.ts` — mock `globalThis.fetch`, assert success + non-2xx +
   missing-field cases.
6. **Cask**: add `Casks/<name>.rb` with `#{version}` interpolation in `url`.
7. **Bump subclass**: add `scripts/bump-<name>.rb` extending
   `CaskBumper::Bumper`. Implement `#upstream` + one of `#worker_path` /
   `#download_url`.
8. **Done with workflows**: `bump.yml` auto-discovers `scripts/bump-*.rb`;
   `ci.yml` and `deploy-worker.yml` are tap-wide. No workflow edits needed.

## Commit style

Conventional commits, **Chinese commit messages** (see `git log`). Type +
short Chinese subject, optional body with explanation of the *why*, not
the *what*.

## Things deliberately not done

- **`auto_updates true` kept** — UGREEN ships its own updater inside the
  app, brew won't fight it.
- **No `pkgutil:` / `launchctl:` / `signal:` in `.app` casks** —
  `ugreen-nas` and `doubao-ime` ship plain `.app` bundles (DMG / nested
  zip), so there's no pkg receipt to drop and no launchd agents observed.
  Don't cargo-cult these onto `.app` casks. Real `.pkg` casks
  (`roxy-browser`) DO require `pkgutil:` to clear the install receipt
  on uninstall.
- **No `--new` flag on `brew audit`** in CI. See above.
- **No `@cloudflare/vitest-pool-workers`** — tests don't need the Workers
  runtime to validate the pure resolver logic. If you ever want to test
  `redirectProxy` cache behavior end-to-end, add it then; not before.
- **No per-cask bump workflow.** `bump.yml` is the only one.
- **No `Gemfile` / `Gemfile.lock`.** Bumpers use Ruby stdlib only
  (`net/http`, `json`, `digest`). RuboCop comes from the flake's
  `ruby_3_3.withPackages`. If a future bumper needs a real gem, add
  Gemfile + Gemfile.lock + update CI to `bundle install` first.
- **No `opencode.json` / `.cursor*` / `CLAUDE.md` / `.github/copilot-instructions.md`.**
  This file is the single source of agent context.
- **No pre-commit / husky / lefthook.** CI is the only enforcement layer;
  `.git/hooks/*.sample` are git's default templates, not installed.
