#!/usr/bin/env bash
set -e

CADDY_VERSION="v2.10.2"
PLUGIN="github.com/caddy-dns/porkbun"

echo "==> Using Go version: "
go version

echo "==> Building Caddy ${CADDY_VERSION} with ${PLUGIN}"
xcaddy build ${CADDY_VERSION} \
  --with ${PLUGIN}

echo
echo "==> Build complete: ./caddy"
echo "==> Listing version and modules"
./caddy version
./caddy list-modules