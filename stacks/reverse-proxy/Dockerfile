FROM caddy:2.11.7-builder AS builder

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    xcaddy build \
    --with github.com/caddy-dns/porkbun

FROM caddy:2.11.7

COPY --from=builder /usr/bin/caddy /usr/bin/caddy