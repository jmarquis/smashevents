#!/bin/sh

bundle install
rails db:seed
bun install

exec "$@"
