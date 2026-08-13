#!/usr/bin/env bash
set -e

DOCKER_VOLUMES_DIR="/var/lib/docker/volumes"
STACKS_DIR="./stacks"
RESTIC_REPO_DIR="./restic-repo"
BACKUP_DIR="./backup"
RESTIC_TXT="./restic.txt"
SQL_BACKUP_FILE_AUTHENTIK="${STACKS_DIR}/authentik/authentik_db_backup_dump.sql"
SQL_BACKUP_FILE_DOCKHAND="${STACKS_DIR}/docker-management/dockhand_db_backup_dump.sql"
SQL_BACKUP_FILE_TRACEARR="${STACKS_DIR}/tracearr/tracearr_db_backup_dump.sql"
EXCLUDE_PATTERNS=(
  "$STACKS_DIR/homelab/data/*"
)
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab_backup_${DATE}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_ARGS+=("--exclude=${pattern}")
done

cleanup() {
  echo "Starting Docker Compose stacks..."
  for stack in "$STACKS_DIR"/*/; do
    [[ -d "$stack" ]] || continue
    stack="${stack%/}"
    stack_name=$(basename "$stack")
    echo "Starting $stack_name"
    (cd "$stack" && docker compose up -d)
  done
}
trap cleanup EXIT

echo "Creating dump of authentik database..."
(
  cd "${STACKS_DIR}/authentik" && \
  docker compose exec -T postgresql \
    pg_dump -U authentik -d authentik -cC \
    > authentik_db_backup_dump.sql
)

echo "Creating dump of dockhand database..."
(
  cd "${STACKS_DIR}/docker-management" && \
  docker compose exec -T dockhand-db \
   pg_dump -U dockhand -d dockhand -cC \
   > dockhand_db_backup_dump.sql
)

echo "Creating dump of tracearr database..."
(
  cd "${STACKS_DIR}/tracearr" && \
  docker compose exec -T timescale \
   pg_dump -U tracearr -d tracearr -cC \
   > tracearr_db_backup_dump.sql
)

echo "Stopping Docker Compose stacks..."
for stack in "$STACKS_DIR"/*/; do
  [[ -d "$stack" ]] || continue
  stack="${stack%/}"
  stack_name=$(basename "$stack")
  echo "Stopping $stack_name"
  (cd "$stack" && docker compose down)
done

echo "Migrating restic repo in case of update..."
sudo restic --repo=${RESTIC_REPO_DIR} --password-file=${RESTIC_TXT} --verbose migrate

echo "Creating backup for docker stacks...."
sudo restic --repo=${RESTIC_REPO_DIR} --password-file=${RESTIC_TXT} --verbose backup "$STACKS_DIR" "${EXCLUDE_ARGS[@]}"

echo "Creating backup for docker volumes...."
sudo restic --repo=${RESTIC_REPO_DIR} --password-file=${RESTIC_TXT} --verbose backup "$DOCKER_VOLUMES_DIR"

echo "Checking restic repo for errors..."
sudo restic --repo=${RESTIC_REPO_DIR} --password-file=${RESTIC_TXT} check

echo "Creating restic repo backup..."
sudo tar -czf "$BACKUP_PATH" "$RESTIC_REPO_DIR"

if [[ -f "$SQL_BACKUP_FILE_AUTHENTIK" ]]; then
  echo "Cleaning up authentik SQL dump..."
  rm "$SQL_BACKUP_FILE_AUTHENTIK"
  echo "SQL dump removed: $SQL_BACKUP_FILE_AUTHENTIK"
else
  echo "SQL backup dump not found at: $SQL_BACKUP_FILE_AUTHENTIK"
fi

if [[ -f "$SQL_BACKUP_FILE_DOCKHAND" ]]; then
  echo "Cleaning up dockhand SQL dump..."
  rm "$SQL_BACKUP_FILE_DOCKHAND"
  echo "SQL dump removed: $SQL_BACKUP_FILE_DOCKHAND"
else
  echo "SQL backup dump not found at: $SQL_BACKUP_FILE_DOCKHAND"
fi

if [[ -f "$SQL_BACKUP_FILE_TRACEARR" ]]; then
  echo "Cleaning up tracearr SQL dump..."
  rm "$SQL_BACKUP_FILE_TRACEARR"
  echo "SQL dump removed: $SQL_BACKUP_FILE_TRACEARR"
else
  echo "SQL backup dump not found at: $SQL_BACKUP_FILE_TRACEARR"
fi

echo "Backup completed!"