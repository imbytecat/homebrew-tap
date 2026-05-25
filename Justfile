set shell := ["bash", "-ceuo", "pipefail"]

[private]
default:
    @just --list

# Refresh one cask's version + sha256 from upstream. Example: `just bump ugreen-nas`.
bump CASK:
    ruby scripts/bump-{{CASK}}.rb

# Lint Ruby scripts (rubocop) + GitHub workflows (actionlint+shellcheck).
style:
    rubocop scripts
    actionlint .github/workflows/*.yml

# Worker: tsc typecheck + vitest. Requires `cd worker && npm install` first.
worker-test:
    cd worker && npm run typecheck && npm test

# Worker: live dev server at http://localhost:8787.
worker-dev:
    cd worker && npm run dev

# Worker: deploy to Cloudflare (CI handles main; use this for ad-hoc deploys).
worker-deploy:
    cd worker && npx wrangler deploy
