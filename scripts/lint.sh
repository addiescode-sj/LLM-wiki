#!/usr/bin/env bash
# =============================================================================
# lint.sh — LLM Wiki Lint Agent
# wiki/ 품질 감사: 고아 링크, YAML 검증, SHA 불일치, 모순 감지
#
# 사용법:
#   ./scripts/lint.sh              # 전체 감사
#   ./scripts/lint.sh --fix        # 자동 수복 시도 (Claude Code 호출)
#   ./scripts/lint.sh --report     # 결과를 lint-report.md로 저장
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(dirname "$SCRIPT_DIR")"
WIKI_DIR="$WIKI_ROOT/wiki"
RAW_DIR="$WIKI_ROOT/raw"
INDEX_FILE="$WIKI_DIR/index.md"
LOG_FILE="$WIKI_DIR/log.md"
REPORT_FILE="$WIKI_DIR/lint-report.md"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[LINT]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

timestamp() { date '+%Y-%m-%d %H:%M'; }

ERRORS=0
WARNINGS=0
REPORT=""

record() {
  local level="$1" msg="$2"
  REPORT+="[$level] $msg\n"
  if [[ "$level" == "ERROR" ]]; then
    ((ERRORS++))
    log_error "$msg"
  else
    ((WARNINGS++))
    log_warn "$msg"
  fi
}

ok() {
  REPORT+="[OK] $1\n"
  log_ok "$1"
}

# ── 1. YAML 프론트매터 검증 ────────────────────────────────────────────────
check_yaml() {
  log_info "YAML 프론트매터 검증 중..."
  local required_fields=("title" "summary" "tags" "type" "created" "last_updated" "status")

  while IFS= read -r -d '' f; do
    local missing=()
    for field in "${required_fields[@]}"; do
      if ! grep -q "^${field}:" "$f" 2>/dev/null; then
        missing+=("$field")
      fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      record "WARN" "YAML 필드 누락 in $(basename "$f"): ${missing[*]}"
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" -not -name "lint-report.md" -print0 2>/dev/null)

  [[ $WARNINGS -eq 0 ]] && ok "YAML 프론트매터 이상 없음"
}

# ── 2. 고아 wikilink 추적 ─────────────────────────────────────────────────
check_orphan_links() {
  log_info "고아 wikilink 검사 중..."
  local all_slugs=()

  # 모든 위키 파일 슬러그 수집
  while IFS= read -r -d '' f; do
    slug="$(basename "$f" .md)"
    all_slugs+=("$slug")
  done < <(find "$WIKI_DIR" -name "*.md" -print0 2>/dev/null)

  # 각 파일의 [[link]] 검사
  while IFS= read -r -d '' f; do
    while IFS= read -r link; do
      # [[slug]] 또는 [[slug|표시명]] 에서 slug 추출
      slug="$(echo "$link" | sed 's/\[\[//; s/\]\].*//; s/|.*//')"
      local found=false
      for s in "${all_slugs[@]}"; do
        [[ "$s" == "$slug" ]] && found=true && break
      done
      if [[ "$found" == "false" ]]; then
        record "WARN" "고아 링크 [[${slug}]] in $(basename "$f")"
      fi
    done < <(grep -oE '\[\[[^\]]+\]\]' "$f" 2>/dev/null || true)
  done < <(find "$WIKI_DIR" -name "*.md" -print0 2>/dev/null)

  ok "wikilink 검사 완료"
}

# ── 3. 소스 SHA 정합성 검증 ───────────────────────────────────────────────
check_sha() {
  log_info "소스 SHA 정합성 검증 중..."

  while IFS= read -r -d '' f; do
    # YAML에서 sources.path 추출
    local src_path sha_in_yaml
    src_path="$(grep -A1 '^\s*- path:' "$f" 2>/dev/null | grep 'path:' | sed 's/.*path: *"*//; s/"*//' | head -1 || true)"
    sha_in_yaml="$(grep '^\s*sha:' "$f" 2>/dev/null | head -1 | sed 's/.*sha: *"*//; s/"*//' || true)"

    [[ -z "$src_path" || -z "$sha_in_yaml" ]] && continue

    local full_path="$WIKI_ROOT/$src_path"
    if [[ ! -f "$full_path" ]]; then
      record "WARN" "소스 파일 없음: $src_path (referenced from $(basename "$f"))"
      continue
    fi

    # SHA가 gdoc- 접두사면 스킵 (Google Docs ID)
    [[ "$sha_in_yaml" == gdoc-* ]] && continue

    local actual_sha
    actual_sha="$(shasum -a 256 "$full_path" | cut -c1-16)"
    if [[ "$actual_sha" != "$sha_in_yaml" ]]; then
      record "WARN" "SHA 불일치 in $(basename "$f"): 기록=${sha_in_yaml}, 실제=${actual_sha}"
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -not -name "index.md" -not -name "log.md" -print0 2>/dev/null)

  ok "SHA 정합성 검사 완료"
}

# ── 4. index.md 등록 누락 검사 ────────────────────────────────────────────
check_index_coverage() {
  log_info "index.md 등록 누락 검사 중..."

  while IFS= read -r -d '' f; do
    local slug
    slug="$(basename "$f" .md)"
    [[ "$slug" == "index" || "$slug" == "log" || "$slug" == "lint-report" ]] && continue

    if ! grep -q "$slug" "$INDEX_FILE" 2>/dev/null; then
      record "WARN" "index.md 미등록: $slug"
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -print0 2>/dev/null)

  ok "index.md 커버리지 검사 완료"
}

# ── 5. Claude Code로 심층 감사 (모순 감지) ────────────────────────────────
check_contradictions() {
  log_info "심층 모순 감지 시작 (Claude Code)..."

  claude "wiki/ 디렉터리의 모든 마크다운 파일을 읽고 아래 항목을 점검해줘:
1. 동일 개념에 대해 서로 다른 설명이 있는 페이지 쌍 (모순)
2. 정합성이 만료됐을 가능성 있는 내용 (날짜가 오래된 경우)
3. 개선이 필요한 [[wikilink]] 연결 (중요한 연결 누락)

결과는 심각도 [HIGH/MED/LOW]로 분류해서 보고해줘.
자동으로 수정하지 말고 보고만 해줘." 2>&1 | tee -a /tmp/lint_claude_out.txt || true

  ok "심층 감사 완료 → /tmp/lint_claude_out.txt 참조"
}

# ── 리포트 저장 ────────────────────────────────────────────────────────────
save_report() {
  local ts
  ts="$(timestamp)"
  cat > "$REPORT_FILE" <<EOF
---
title: "Lint Report"
type: reference
created: ${ts}
---

# Lint Report — $(date '+%Y-%m-%d')

총 오류: **${ERRORS}** | 경고: **${WARNINGS}**

\`\`\`
$(echo -e "$REPORT")
\`\`\`
EOF
  log_ok "리포트 저장: $REPORT_FILE"
}

# ── 자동 수복 모드 ─────────────────────────────────────────────────────────
cmd_fix() {
  log_info "자동 수복 모드 시작 (Claude Code)..."

  claude "CLAUDE.md와 AGENTS.md의 규칙을 따라 wiki/ 디렉터리를 점검하고:
1. 고아 wikilink가 있는 경우 해당 위키 페이지를 새로 생성하거나 링크를 수정해
2. YAML 프론트매터 필수 필드가 누락된 페이지는 채워줘
3. index.md에 누락된 페이지를 추가해
4. log.md에 LINT-FIX 트랜잭션을 기록해
수정한 내용을 요약해서 보고해줘." || true

  log_ok "자동 수복 완료"
}

# ── 메인 ──────────────────────────────────────────────────────────────────
main() {
  local fix_mode=false
  local report_mode=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)    fix_mode=true; shift ;;
      --report) report_mode=true; shift ;;
      *)        shift ;;
    esac
  done

  if [[ ! -d "$WIKI_DIR" ]]; then
    echo "wiki/ 디렉터리가 없습니다. ./scripts/ingest.sh --init 을 먼저 실행하세요."
    exit 1
  fi

  echo ""
  echo "======================================"
  echo "  LLM Wiki Lint — $(timestamp)"
  echo "======================================"
  echo ""

  check_yaml
  check_orphan_links
  check_sha
  check_index_coverage

  echo ""
  echo "--------------------------------------"
  echo "  총 오류: ${ERRORS} | 경고: ${WARNINGS}"
  echo "--------------------------------------"

  [[ "$report_mode" == "true" ]] && save_report

  if [[ "$fix_mode" == "true" && ($ERRORS -gt 0 || $WARNINGS -gt 0) ]]; then
    echo ""
    cmd_fix
  fi

  if [[ $ERRORS -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
