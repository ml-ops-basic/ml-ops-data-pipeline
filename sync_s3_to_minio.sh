#!/usr/bin/env bash
set -euo pipefail

# --------- CONFIGURE THESE -------------
SRC_URL="s3://jmktm-test-bucket-s3/data/data.xml"   # S3 object or prefix
IMPORT_PATH="data/data.xml"                          # local tracked path
SRC_REMOTE="rh-demo-s3"                              # S3 DVC remote name
DST_REMOTE="minio"                                   # MinIO DVC remote name
# ---------------------------------------

echo "==> Ensuring ${IMPORT_PATH} is tracked as an import from ${SRC_URL}"
if [[ ! -f "${IMPORT_PATH}.dvc" ]]; then
  if [[ -f "${IMPORT_PATH}" && ! -L "${IMPORT_PATH}" ]]; then
    echo "Found existing local file at ${IMPORT_PATH}; backing it up to ${IMPORT_PATH}.backup"
    mv "${IMPORT_PATH}" "${IMPORT_PATH}.backup"
  fi
  dvc import-url --to-remote "${SRC_URL}" "${IMPORT_PATH}" -r "${SRC_REMOTE}" --force
  git add "${IMPORT_PATH}.dvc" .gitignore || true
  git commit -m "Import ${IMPORT_PATH} from ${SRC_URL} (to-remote via ${SRC_REMOTE})" || true
fi

echo "==> Checking for updates in S3 (dvc update)"
# If nothing changed, dvc prints it's up to date; exit code stays 0.
dvc update "${IMPORT_PATH}.dvc" || true

# If the .dvc pointer changed, commit it so history shows when S3 changed
if ! git diff --quiet -- "${IMPORT_PATH}.dvc"; then
  echo "==> Import updated; committing pointer change"
  git add "${IMPORT_PATH}.dvc"
  git commit -m "Update import snapshot for ${IMPORT_PATH}"
else
  echo "==> No pointer change detected (already up to date)"
fi

echo "==> Fetching objects from S3 remote '${SRC_REMOTE}' into cache"
dvc fetch -r "${SRC_REMOTE}" -v

echo "==> Pushing objects to MinIO remote '${DST_REMOTE}'"
dvc push  -r "${DST_REMOTE}" -v

echo "==> Done. MinIO is in sync with the latest S3 snapshot for ${IMPORT_PATH}."