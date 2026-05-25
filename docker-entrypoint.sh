#!/bin/sh

bundle install
rails db:seed
npm ci

exec "$@"
