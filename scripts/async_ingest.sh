#!/usr/bin/env bash
# =============================================================================
# async_ingest.sh — Git post-commit hook용 비동기 인입 에이전트
# 커밋된 raw/ 파일을 백그라운드에서 자동으로 wiki/에 컴파일합니다.
#
# 직접 호출하지 마세요. .git/hooks/post-commit 에서 자동 실행됩니다.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$WIKI_ROOT/raw"
LOCK_FILE="/tmp/llm-wiki-ingest.lock"
INGEST_LOG="/tmp/llm-wiki-async-ingest.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() { echo "[$(timestamp)] $1" >> "$INGEST_LOG"; }

# ── flock으로 동시 실행 방지 ──────────────────────────────────────────────
# 이미 인입 중이면 조용히 종료
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "SKIP: 이미 인입 진행 중 (lock: $LOCK_FILE)"
  exit 0
fi

log "START: 비동기 인입 시작"

# ── 마지막 커밋에서 raw/ 파일 추출 ────────────────────────────────────────
cd "$WIKI_ROOT"

# git diff로 이번 커밋에서 추가/수정된 raw/ 파일 목록
CHANGED_FILES="$(git diff-tree --no-commit-id -r --name-only HEAD 2>/dev/null | \
  grep '^raw/' | \
  grep -v '__pycache__' || true)"

if [[ -z "$CHANGED_FILES" ]]; then
  log "SKIP: 이번 커밋에 raw/ 변경 없음"
  exit 0
fi

log "감지된 raw/ 파일:"
echo "$CHANGED_FILES" | while IFS= read -r f; do
  log "  → $f"
done

# ── 각 파일 인입 ──────────────────────────────────────────────────────────
INGEST_COUNT=0
FAIL_COUNT=0

while IFS= read -r raw_file; do
  [[ -z "$raw_file" ]] && continue
  full_path="$WIKI_ROOT/$raw_file"

  if [[ ! -f "$full_path" ]]; then
    log "WARN: 파일 없음 — $raw_file (삭제된 파일?)"
    continue
  fi

  log "INGEST: $raw_file"

  if "$SCRIPT_DIR/ingest.sh" "$full_path" >> "$INGEST_LOG" 2>&1; then
    log "OK: $raw_file 인입 완료"
    ((INGEST_COUNT++))
  else
    log "FAIL: $raw_file 인입 실패"
    ((FAIL_COUNT++))
  fi

  sleep 1  # API rate limit 방지

done <<< "$CHANGED_FILES"

log "END: 완료 $INGEST_COUNT 성공, $FAIL_COUNT 실패"
log "로그 전체: $INGEST_LOG"

# ── 결과 알림 (터미널에 출력 — hook이 bg로 실행되므로 선택적) ──────────────
if [[ $INGEST_COUNT -gt 0 ]]; then
  # macOS 알림 (선택사항)
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"${INGEST_COUNT}개 파일 위키 컴파일 완료\" with title \"LLM Wiki\"" 2>/dev/null || true
  fi
fi
