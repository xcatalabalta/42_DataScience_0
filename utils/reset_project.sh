#!/bin/sh
./reset_db.py
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # absolute path to present script
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"   # its parent = repo root
cd "${REPO_ROOT}"
echo "Working from repository root: ${REPO_ROOT}"
rm -rf data
ls -lR
