#!/usr/bin/env bash
# =============================================================================
# publish.sh — Publish compiled wiki/ to the `dist` branch as a tagged release.
#
# Usage:
#   ./scripts/publish.sh patch          # bump patch version
#   ./scripts/publish.sh minor          # bump minor version
#   ./scripts/publish.sh major          # bump major version
#   ./scripts/publish.sh 1.2.3          # set explicit version
#   ./scripts/publish.sh patch --push   # bump + push branch & tag to origin
#
# Design: ADR-002. Consumers embed this repo's `dist` branch as a git submodule
# and pin to a `wiki-vX.Y.Z` tag. The `dist` branch contains only `wiki/` and
# `manifest.json` — no raw/, scripts/, or workspace metadata.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ---------- args ----------
if [[ $# -lt 1 ]]; then
  echo "usage: $0 <patch|minor|major|X.Y.Z> [--push]" >&2
  exit 64
fi
BUMP="$1"
PUSH="${2:-}"

# ---------- preflight ----------
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$SOURCE_BRANCH" != "main" && "$SOURCE_BRANCH" != "master" ]]; then
  if [[ -n "${CI:-}" || "${NO_PROMPT:-0}" == "1" ]]; then
    echo "note: publishing from '$SOURCE_BRANCH' (non-interactive, proceeding)."
  else
    echo "warn: publishing from '$SOURCE_BRANCH' (expected main/master). Continue? [y/N]"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
  fi
fi

if [[ -x ./scripts/lint.sh && "${SKIP_LINT:-0}" != "1" ]]; then
  echo "→ running lint..."
  ./scripts/lint.sh || { echo "error: lint failed. Fix before publishing." >&2; exit 1; }
fi

# ---------- compute next version ----------
LAST_TAG="$(git tag --list 'wiki-v*' --sort=-v:refname | head -n1 || true)"
if [[ -z "$LAST_TAG" ]]; then
  CUR="0.0.0"
else
  CUR="${LAST_TAG#wiki-v}"
fi
IFS='.' read -r MA MI PA <<<"$CUR"

case "$BUMP" in
  major) NEW="$((MA+1)).0.0" ;;
  minor) NEW="${MA}.$((MI+1)).0" ;;
  patch) NEW="${MA}.${MI}.$((PA+1))" ;;
  [0-9]*.[0-9]*.[0-9]*) NEW="$BUMP" ;;
  *) echo "error: invalid bump '$BUMP'" >&2; exit 64 ;;
esac
TAG="wiki-v${NEW}"

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "error: tag ${TAG} already exists." >&2
  exit 1
fi

SOURCE_COMMIT="$(git rev-parse HEAD)"
SOURCE_SHORT="$(git rev-parse --short HEAD)"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PAGE_COUNT="$(find wiki -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"

echo "→ publishing ${TAG}"
echo "  source: ${SOURCE_BRANCH}@${SOURCE_SHORT}"
echo "  pages:  ${PAGE_COUNT}"

# ---------- prepare dist worktree ----------
WORKTREE_DIR="$(mktemp -d -t llm-wiki-dist-XXXXXX)"
cleanup() { git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || rm -rf "$WORKTREE_DIR"; }
trap cleanup EXIT

if git show-ref --verify --quiet refs/heads/dist; then
  git worktree add "$WORKTREE_DIR" dist
else
  # First-ever publish: create orphan dist branch.
  git worktree add --detach "$WORKTREE_DIR" "$SOURCE_COMMIT"
  git -C "$WORKTREE_DIR" checkout --orphan dist
  git -C "$WORKTREE_DIR" rm -rf . >/dev/null 2>&1 || true
fi

# ---------- sync wiki/ into worktree ----------
# Clear previous contents (preserve .git pointer).
find "$WORKTREE_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

mkdir -p "$WORKTREE_DIR/wiki"
# Use rsync if available, else cp.
if command -v rsync >/dev/null; then
  rsync -a --delete wiki/ "$WORKTREE_DIR/wiki/"
else
  cp -R wiki/. "$WORKTREE_DIR/wiki/"
fi

# ---------- manifest ----------
cat >"$WORKTREE_DIR/manifest.json" <<EOF
{
  "version": "${NEW}",
  "tag": "${TAG}",
  "source_commit": "${SOURCE_COMMIT}",
  "source_branch": "${SOURCE_BRANCH}",
  "generated_at": "${GENERATED_AT}",
  "page_count": ${PAGE_COUNT}
}
EOF

# ---------- readme stub for consumers ----------
cat >"$WORKTREE_DIR/README.md" <<EOF
# LLM Wiki — Distribution Branch

This branch is the **read-only distribution channel** for the LLM Wiki.
Consumers embed it as a git submodule and pin to a \`wiki-vX.Y.Z\` tag.

Do not edit files on this branch directly — changes are overwritten by
\`scripts/publish.sh\` on the source branch. See ADR-002 for details.

- Version: \`${NEW}\`
- Source: \`${SOURCE_SHORT}\`
- Generated: \`${GENERATED_AT}\`
EOF

# ---------- commit & tag ----------
git -C "$WORKTREE_DIR" add -A
if git -C "$WORKTREE_DIR" diff --cached --quiet; then
  echo "note: no wiki changes since last publish; tagging current dist HEAD."
else
  git -C "$WORKTREE_DIR" commit -m "publish: ${TAG} (source ${SOURCE_SHORT})"
fi
git -C "$WORKTREE_DIR" tag -a "$TAG" -m "LLM Wiki ${NEW}"

DIST_SHA="$(git -C "$WORKTREE_DIR" rev-parse HEAD)"
echo "✓ dist@${DIST_SHA:0:7} tagged as ${TAG}"

# ---------- push (optional) ----------
if [[ "$PUSH" == "--push" ]]; then
  echo "→ pushing dist branch and tag to origin..."
  git push origin dist
  git push origin "$TAG"
  echo "✓ pushed"
else
  echo "  (skip push; rerun with --push or: git push origin dist && git push origin ${TAG})"
fi
