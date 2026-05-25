set shell := ["bash", "-cu"]

default:
    @just --list

bump-ugreen-nas:
    ruby scripts/bump-ugreen-nas.rb

style:
    rubocop scripts
