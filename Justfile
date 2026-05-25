set shell := ["bash", "-ceuo", "pipefail"]

default:
    @just --list

bump CASK:
    ruby scripts/bump-{{CASK}}.rb

style:
    rubocop scripts
    actionlint .github/workflows/*.yml

worker-test:
    cd worker && npm run typecheck && npm test

worker-dev:
    cd worker && npm run dev

worker-deploy:
    cd worker && npx wrangler deploy
