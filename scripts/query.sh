#!/usr/bin/env bash
# =============================================================================
# query.sh — LLM Wiki Query Agent
# wiki/ 지식 베이스를 검색하고 답변을 생성합니다.
#
# 사용법:
#   ./scripts/query.sh "질문"                    # 답변 출력
#   ./scripts/query.sh --save "질문"             # 답변을 새 위키 페이지로 저장
#   ./scripts/query.sh --tags <태그> "질문"      # 특정 태그 범위에서 검색
#   ./scripts/query.sh --list                    # 위키 인덱스 출력
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(dirname "$SCRIPT_DIR")"
WIKI_DIR="$WIKI_ROOT/wiki"
INDEX_FILE="$WIKI_DIR/index.md"
LOG_FILE="$WIKI_DIR/log.md"

# ── 색상 출력 ──────────────────────────────────────────────────────────────
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[QUERY]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

timestamp() { date '+%Y-%m-%d %H:%M'; }

# ── log.md 기록 ────────────────────────────────────────────────────────────
write_log() {
  local action="$1" source="$2" targets="$3" details="${4:-}"
  local ts entry
  ts="$(timestamp)"
  entry="[${ts}] [${action}] source: ${source} → targets: ${targets}"
  [[ -n "$details" ]] && entry+=" | ${details}"
  sed -i '' "/^\`\`\`$/i\\
${entry}" "$LOG_FILE" 2>/dev/null || echo "$entry" >> "$LOG_FILE"
}

# ── 위키 인덱스 출력 ───────────────────────────────────────────────────────
cmd_list() {
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "index.md 없음. ./scripts/ingest.sh --init 을 먼저 실행하세요."
    exit 1
  fi
  echo ""
  cat "$INDEX_FILE"
}

# ── 질의 실행 ──────────────────────────────────────────────────────────────
cmd_query() {
  local question="$1"
  local save_mode="${SAVE_MODE:-false}"
  local filter_tags="${FILTER_TAGS:-}"

  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "위키가 초기화되지 않았습니다. ./scripts/ingest.sh --init 을 먼저 실행하세요."
    exit 1
  fi

  log_info "질문: $question"
  [[ -n "$filter_tags" ]] && log_info "태그 필터: $filter_tags"

  local tag_instruction=""
  if [[ -n "$filter_tags" ]]; then
    tag_instruction="태그 필터: 아래 태그 중 하나라도 포함된 페이지만 참조해 → [${filter_tags}]"
  fi

  local save_instruction=""
  if [[ "$save_mode" == "true" ]]; then
    local slug
    slug="$(echo "$question" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9가-힣]/-/g' | cut -c1-40)"
    local out_file="$WIKI_DIR/q-${slug}.md"
    save_instruction="
6. 답변을 아래 경로에 새 위키 페이지로 저장해 (_templates/concept.md 기반):
   $out_file
7. wiki/index.md에 해당 페이지 한 줄 추가
8. wiki/log.md에 QUERY-SAVE 트랜잭션 기록"
    log_info "답변 저장 모드: $out_file"
  fi

  # Claude Code CLI를 통한 질의
  claude "CLAUDE.md와 AGENTS.md의 규칙을 따라 아래 질문에 답변해줘.

질문: ${question}

처리 순서:
1. wiki/index.md를 읽어 관련 페이지 슬러그를 파악해
2. ${tag_instruction:-관련성 높은 페이지를 최대 5개 선택해}
3. 선택된 페이지들을 모두 읽어 종합적으로 답변을 구성해
4. 답변은 한국어로, 출처 페이지를 [[wikilink]] 형식으로 인용해
5. 위키에 없는 내용은 '위키에 없음'이라고 명시해 (할루시네이션 금지)${save_instruction}"

  write_log "QUERY" "user-question" "wiki/" "q: ${question:0:60}"
  [[ "$save_mode" == "true" ]] && log_ok "답변이 위키 페이지로 저장되었습니다"
}

# ── 메인 ──────────────────────────────────────────────────────────────────
main() {
  if [[ $# -eq 0 ]]; then
    echo "사용법: $0 \"질문\" | --save \"질문\" | --tags <태그> \"질문\" | --list"
    exit 1
  fi

  SAVE_MODE=false
  FILTER_TAGS=""

  # 플래그 파싱
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        cmd_list
        exit 0
        ;;
      --save)
        SAVE_MODE=true
        shift
        ;;
      --tags)
        FILTER_TAGS="${2:-}"
        shift 2
        ;;
      *)
        QUESTION="$1"
        shift
        ;;
    esac
  done

  if [[ -z "${QUESTION:-}" ]]; then
    echo "질문을 입력해주세요."
    exit 1
  fi

  cmd_query "$QUESTION"
}

main "$@"
