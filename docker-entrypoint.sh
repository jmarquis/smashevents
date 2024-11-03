#!/bin/sh

bundle install
rails db:seed

exec "$@"
