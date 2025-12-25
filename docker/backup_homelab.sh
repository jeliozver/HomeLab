#!/bin/bash

set -e

ARCHIVE_NAME="homelab_backup_$(date +%Y-%m-%d).zip"

STACKS=(
  "authentik"
  "vaultwarden"
  "homelab"
)

EXCLUDE_PATTERNS=(
  "homelab/data/*"
)

cleanup() {
  echo "Starting Docker Compose stacks..."
  for stack in "${STACKS[@]}"; do
    if [ -d "$stack" ]; then
      echo "Starting $stack"
      (cd "$stack" && docker compose up -d)
    fi
  done
}
trap cleanup EXIT

echo "Stopping Docker Compose stacks..."
for stack in "${STACKS[@]}"; do
  if [ -d "$stack" ]; then
    echo "Stopping $stack"
    (cd "$stack" && docker compose down)
  fi
done

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_ARGS+=("-x" "$pattern")
done

echo "Creating backup archive..."
zip -r "$ARCHIVE_NAME" "${STACKS[@]}" "${EXCLUDE_ARGS[@]}"

echo "Backup completed: $ARCHIVE_NAME"