#!/bin/bash

set -e

BACKUP_DIR="/backups"
STACKS_DIR="stacks"
DATE=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="homelab_backup_$(date +%Y-%m-%d).zip"
SQL_BACKUP_FILE="${STACKS_DIR}/authentik/authentik_db_backup_dump.sql"
VOLUME_BACKUP_DIR="${BACKUP_DIR}/volumes/${DATE}"
VOLUMES=$(docker volume ls -q)
STACKS=(
  "authentik"
  "vaultwarden"
  "homelab"
  "reverse-proxy"
)
EXCLUDE_PATTERNS=(
  "stacks/homelab/data/*"
)

mkdir -p "$VOLUME_BACKUP_DIR"

cleanup() {
  echo "Starting Docker Compose stacks..."
  for stack in "${STACKS[@]}"; do
    STACK_PATH="${STACKS_DIR}/${stack}"
    if [ -d "$STACK_PATH" ]; then
      echo "Starting $stack"
      (cd "$STACK_PATH" && docker compose up -d)
    fi
  done
}
trap cleanup EXIT

echo "Backing up authentik database..."
echo "Creating pg_dump of authentik database..."

(
  cd "${STACKS_DIR}/authentik" && \
  docker compose exec -T postgresql \
    pg_dump -U authentik -d authentik -cC \
    > authentik_db_backup_dump.sql
)

echo "Stopping Docker Compose stacks..."
for stack in "${STACKS[@]}"; do
  STACK_PATH="${STACKS_DIR}/${stack}"
  if [ -d "$STACK_PATH" ]; then
    echo "Stopping $stack"
    (cd "$STACK_PATH" && docker compose down)
  fi
done

echo "Backing up docker volumes..."

for volume in $VOLUMES; do
  echo "Backing up volume: $volume"

  docker run --rm \
    -v "$volume:/data:ro" \
    -v "$VOLUME_BACKUP_DIR:/backup" \
    alpine \
    tar czf "/backup/${volume}.tar.gz" -C /data .

  if [ -f "${VOLUME_BACKUP_DIR}/${volume}.tar.gz" ]; then
    echo "✓ Successfully backed up: $volume"
  else
    echo "✗ Failed to backup: $volume"
  fi
done

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_ARGS+=("-x" "$pattern")
done

echo "Backing up mounted volumes..."
zip -r "$ARCHIVE_NAME" "$STACKS_DIR" "${EXCLUDE_ARGS[@]}"

if [ -f "$SQL_BACKUP_FILE" ]; then
  echo "Cleaning up SQL backup file..."
  rm "$SQL_BACKUP_FILE"
  echo "SQL backup file removed: $SQL_BACKUP_FILE"
else
  echo "Note: SQL backup file not found at $SQL_BACKUP_FILE"
fi

echo "Backup completed: $ARCHIVE_NAME"