#!/bin/sh
# Installs the repository hooks by setting git's core.hooksPath to .githooks
# Usage: sh scripts/install-hooks.sh

set -e

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository. Run this from the repo root." >&2
  exit 1
fi

echo "Setting git core.hooksPath to .githooks"
git config core.hooksPath .githooks

if [ -f .githooks/pre-commit ]; then
  chmod +x .githooks/pre-commit || true
  echo "Hook .githooks/pre-commit made executable."
else
  echo "No .githooks/pre-commit found to install." >&2
fi

echo "Done. Local git will now use hooks from .githooks/. To undo: git config --unset core.hooksPath" 
