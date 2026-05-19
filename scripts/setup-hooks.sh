#!/usr/bin/env bash
# =============================================================================
# setup-hooks.sh — Install repo-local git hooks.
#
# Points git at .githooks/ so the commit-msg validator (and any future hooks)
# run automatically. Run this once after cloning.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "✓ core.hooksPath set to .githooks"
echo "✓ hook executables: $(ls .githooks 2>/dev/null | tr '\n' ' ')"
echo ""
echo "Try a dry-run:"
echo "  echo 'wiki: test message' | git commit-tree -m -F /dev/stdin HEAD^{tree} >/dev/null"
