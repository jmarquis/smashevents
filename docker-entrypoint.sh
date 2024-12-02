#!/bin/sh

bundle install
rails db:seed
yarn install

exec "$@"
