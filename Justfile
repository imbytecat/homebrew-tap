set shell := ["bash", "-cu"]

default:
    @just --list

bump-ugreen-nas:
    ruby scripts/bump-ugreen-nas.rb

style:
    rubocop scripts

worker-dev:
    cd worker && npm install && npm run dev

worker-deploy:
    cd worker && npm install && npm run typecheck && npx wrangler deploy

worker-typecheck:
    cd worker && npm install && npm run typecheck
