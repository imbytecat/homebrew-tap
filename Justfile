set shell := ["bash", "-cu"]

default:
    @just --list

bump CASK:
    ruby scripts/bump-{{CASK}}.rb

style:
    rubocop scripts

worker-dev:
    cd worker && npm install && npm run dev

worker-deploy:
    cd worker && npm install && npm run typecheck && npm test && npx wrangler deploy

worker-typecheck:
    cd worker && npm install && npm run typecheck

worker-test:
    cd worker && npm install && npm test
