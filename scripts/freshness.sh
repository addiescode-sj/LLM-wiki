#!/usr/bin/env bash
# =============================================================================
# freshness.sh — LLM Wiki Freshness Checker
# 소스 SHA 기반 위키 페이지 최신성 검증 + 만료 표시
#
# 사용법:
#   ./scripts/freshness.sh           # 전체 freshness 체크
#   ./scripts/freshness.sh --stale   # 만료 페이지만 출력
#   ./scripts/freshness.sh --update  # 만료 페이지 재컴파일 (Claude Code)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(dirname "$SCRIPT_DIR")"
WIKI_DIR="$WIKI_ROOT/wiki"
RAW_DIR="$WIKI_ROOT/raw"
LOG_FILE="$WIKI_DIR/log.md"

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[FRESH]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_stale() { echo -e "${YELLOW}[STALE]${NC} $1"; }
log_miss()  { echo -e "${RED}[MISS]${NC}  $1"; }

timestamp() { date '+%Y-%m-%d %H:%M'; }

STALE_FILES=()
FRESH_COUNT=0

# ── 단일 파일 freshness 검사 ──────────────────────────────────────────────
check_file() {
  local wiki_file="$1"
  local slug
  slug="$(basename "$wiki_file" .md)"

  # YAML에서 sources 정보 추출
  local src_path sha_recorded
  src_path="$(awk '/^sources:/,/^[a-z]/' "$wiki_file" 2>/dev/null | \
    grep '^\s*- path:' | head -1 | sed 's/.*path: *"*//; s/"*//' || true)"
  sha_recorded="$(awk '/^sources:/,/^[a-z]/' "$wiki_file" 2>/dev/null | \
    grep '^\s*sha:' | head -1 | sed 's/.*sha: *"*//; s/"*//' || true)"

  # sources 없는 파일 (index, log 등) 스킵
  [[ -z "$src_path" ]] && return

  # Google Docs ID 스킵 (로컬 파일 아님)
  if [[ "$sha_recorded" == gdoc-* ]]; then
    log_ok "$slug — Google Docs (SHA 검증 스킵)"
    ((FRESH_COUNT++))
    return
  fi

  local full_path="$WIKI_ROOT/$src_path"
  if [[ ! -f "$full_path" ]]; then
    log_miss "$slug — 소스 파일 없음: $src_path"
    STALE_FILES+=("$wiki_file:missing")
    return
  fi

  # 실제 SHA 계산
  local sha_actual
  sha_actual="$(shasum -a 256 "$full_path" | cut -c1-16)"

  if [[ "$sha_actual" == "$sha_recorded" ]]; then
    log_ok "$slug — 최신 (sha: $sha_actual)"
    ((FRESH_COUNT++))
  else
    log_stale "$slug — 만료됨 (기록: $sha_recorded → 실제: $sha_actual)"
    STALE_FILES+=("$wiki_file:$full_path")

    # 위키 파일에 stale 상태 표시 (status 필드 업데이트)
    sed -i '' 's/^status: .*/status: stale/' "$wiki_file" 2>/dev/null || true
  fi
}

# ── 전체 검사 ──────────────────────────────────────────────────────────────
cmd_check() {
  log_info "Freshness 검사 시작: $(timestamp)"
  echo ""

  while IFS= read -r -d '' f; do
    slug="$(basename "$f" .md)"
    [[ "$slug" == "index" || "$slug" == "log" || "$slug" == "lint-report" ]] && continue
    check_file "$f"
  done < <(find "$WIKI_DIR" -name "*.md" -print0 2>/dev/null)

  echo ""
  echo "======================================"
  echo "  최신: ${FRESH_COUNT} | 만료: ${#STALE_FILES[@]}"
  echo "======================================"

  if [[ ${#STALE_FILES[@]} -gt 0 && "${1:-}" != "--stale" ]]; then
    echo ""
    echo "만료된 페이지:"
    for entry in "${STALE_FILES[@]}"; do
      echo "  → $(basename "${entry%%:*}" .md)"
    done
    echo ""
    echo "재컴파일하려면: ./scripts/freshness.sh --update"
  fi
}

# ── 만료 페이지만 출력 ─────────────────────────────────────────────────────
cmd_stale() {
  FRESH_COUNT=0
  cmd_check --stale

  if [[ ${#STALE_FILES[@]} -eq 0 ]]; then
    echo "만료된 페이지 없음."
    exit 0
  fi

  echo "만료된 페이지 목록:"
  for entry in "${STALE_FILES[@]}"; do
    local wiki_f src_f
    wiki_f="${entry%%:*}"
    src_f="${entry##*:}"
    echo "  위키: $(basename "$wiki_f") ← 소스: $src_f"
  done
}

# ── 만료 페이지 재컴파일 ───────────────────────────────────────────────────
cmd_update() {
  FRESH_COUNT=0
  cmd_check --stale

  if [[ ${#STALE_FILES[@]} -eq 0 ]]; then
    log_ok "모든 페이지가 최신 상태입니다."
    exit 0
  fi

  log_info "만료된 ${#STALE_FILES[@]}개 페이지 재컴파일 시작..."

  for entry in "${STALE_FILES[@]}"; do
    local wiki_f src_f
    wiki_f="${entry%%:*}"
    src_f="${entry##*:}"

    [[ "$src_f" == "missing" ]] && {
      log_miss "소스 없음, 스킵: $(basename "$wiki_f")"
      continue
    }

    local sha
    sha="$(shasum -a 256 "$src_f" | cut -c1-16)"

    log_info "재컴파일: $(basename "$wiki_f") ← $src_f"

    claude "CLAUDE.md 규칙에 따라 소스 파일의 변경 사항을 기존 위키 페이지에 반영해줘.

소스 파일: $src_f
위키 페이지: $wiki_f
새 SHA: $sha

처리:
1. 소스와 위키 페이지를 모두 읽어 변경된 내용 파악
2. 위키 페이지에 새 정보 Synthesize (기존 내용 보존)
3. YAML의 last_updated와 sources.sha를 '$sha'로 갱신
4. status를 'draft'로 복원
5. log.md에 REFRESH 트랜잭션 기록" || {
      log_warn "재컴파일 실패: $(basename "$wiki_f")"
      continue
    }

    log_ok "재컴파일 완료: $(basename "$wiki_f")"
    sleep 1
  done
}

# ── 메인 ──────────────────────────────────────────────────────────────────
main() {
  if [[ ! -d "$WIKI_DIR" ]]; then
    echo "wiki/ 디렉터리가 없습니다. ./scripts/ingest.sh --init 을 먼저 실행하세요."
    exit 1
  fi

  case "${1:-}" in
    --stale)  cmd_stale ;;
    --update) cmd_update ;;
    *)        cmd_check ;;
  esac
}

main "$@"
