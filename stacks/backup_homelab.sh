#!/bin/bash

set -e

ARCHIVE_NAME="homelab_backup_$(date +%Y-%m-%d).zip"
SQL_BACKUP_FILE="authentik/authentik_db_backup_dump.sql"

STACKS=(
  "authentik"
  "vaultwarden"
  "homelab"
  "reverse-proxy"
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

echo "Backing up authentik database..."
echo "Creating pg_dump of authentik database..."

(cd "authentik" && docker compose exec -T postgresql pg_dump -U authentik -d authentik -cC > authentik_db_backup_dump.sql)

echo "Stopping Docker Compose stacks..."
for stack in "${STACKS[@]}"; do
  if [ -d "$stack" ]; then
    echo "Stopping $stack"
    (cd "$stack" && docker compose down)
  fi
done

echo "Backing up authentik database volume..."

if docker volume inspect authentik_database > /dev/null 2>&1; then
    # Remove existing backup volume if it exists
    if docker volume inspect authentik_database_backup > /dev/null 2>&1; then
        echo "Removing existing authentik_database_backup volume..."
        docker volume rm authentik_database_backup
    fi

    # Create new backup volume and copy data
    echo "Creating fresh backup of authentik database volume..."
    docker volume create authentik_database_backup
    docker run --rm -v authentik_database:/from -v authentik_database_backup:/to alpine sh -c 'cd /from && cp -a . /to'
    echo "Authentik database volume backed up successfully"
else
    echo "Warning: authentik_database volume not found, skipping volume backup"
fi

EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_ARGS+=("-x" "$pattern")
done

echo "Creating backup archive..."
zip -r "$ARCHIVE_NAME" "${STACKS[@]}" "${EXCLUDE_ARGS[@]}"

if [ -f "$SQL_BACKUP_FILE" ]; then
    echo "Cleaning up SQL backup file..."
    rm "$SQL_BACKUP_FILE"
    echo "SQL backup file removed: $SQL_BACKUP_FILE"
else
    echo "Note: SQL backup file not found at $SQL_BACKUP_FILE"
fi

echo "Backup completed: $ARCHIVE_NAME"