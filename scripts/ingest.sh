#!/usr/bin/env bash
# =============================================================================
# ingest.sh — LLM Wiki Ingest Agent
# 원천 소스를 wiki로 컴파일합니다.
#
# 사용법:
#   ./scripts/ingest.sh <파일 경로>           # 단일 파일
#   ./scripts/ingest.sh --all-inbox           # inbox/ 전체
#   ./scripts/ingest.sh --url <URL>           # URL에서 직접 인입
#   ./scripts/ingest.sh --init                # 저장소 초기화
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(dirname "$SCRIPT_DIR")"
WIKI_DIR="$WIKI_ROOT/wiki"
RAW_DIR="$WIKI_ROOT/raw"
INTERMEDIATE_DIR="$WIKI_ROOT/intermediate"
LOG_FILE="$WIKI_DIR/log.md"
INDEX_FILE="$WIKI_DIR/index.md"
CLAUDE_MD="$WIKI_ROOT/CLAUDE.md"

# ── 색상 출력 ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${BLUE}[INGEST]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ── 타임스탬프 ──────────────────────────────────────────────────────────────
timestamp() { date '+%Y-%m-%d %H:%M'; }

# ── log.md에 트랜잭션 기록 ─────────────────────────────────────────────────
write_log() {
  local action="$1" source="$2" targets="$3" details="${4:-}"
  local ts
  ts="$(timestamp)"
  # log.md의 트랜잭션 기록 섹션 직후에 추가
  local entry="[${ts}] [${action}] source: ${source} → targets: ${targets}"
  [[ -n "$details" ]] && entry+=" | ${details}"

  # 마지막 ``` 코드블록 직전에 삽입
  sed -i '' "/^\`\`\`$/i\\
${entry}" "$LOG_FILE" 2>/dev/null || \
  echo "$entry" >> "$LOG_FILE"
}

make_relative_path() {
  local path="$1"
  echo "${path#$WIKI_ROOT/}"
}

generate_video_digest() {
  local raw_file="$1" source_sha="$2"
  local video_id segments_file digest_file raw_rel segments_rel digest_rel

  video_id="$(basename "$raw_file" .md)"
  segments_file="$(dirname "$raw_file")/${video_id}.segments.jsonl"
  digest_file="$INTERMEDIATE_DIR/videos/${video_id}.digest.md"

  if [[ ! -f "$segments_file" ]]; then
    log_error "Video segment file not found: $segments_file"
    return 1
  fi

  mkdir -p "$(dirname "$digest_file")"

  raw_rel="$(make_relative_path "$raw_file")"
  segments_rel="$(make_relative_path "$segments_file")"
  digest_rel="$(make_relative_path "$digest_file")"

  log_info "Generating context-optimized video digest: $digest_rel"

  claude "<orchestration name=\"youtube-video-ingest\">
  <role>Parent coordinator for LLM Wiki video ingest.</role>

  <inputs>
    <raw_markdown>${raw_rel}</raw_markdown>
    <segments_jsonl>${segments_rel}</segments_jsonl>
    <digest_output>${digest_rel}</digest_output>
    <source_sha>${source_sha}</source_sha>
  </inputs>

  <agents>
    <agent name=\"digest_agent\">
      <goal>Create a context-optimized digest from the transcript without modifying raw files.</goal>
      <rules>
        <rule>Remove CTA, sponsor, intro hooks, repeated framing, and rhetorical filler.</rule>
        <rule>Preserve definitions, metrics, workflows, claims, examples, and timestamps.</rule>
        <rule>Mark generated transcript uncertainty when wording may be noisy.</rule>
        <rule>Write the digest to ${digest_rel} and do not edit raw/videos/*.</rule>
      </rules>
    </agent>
  </agents>
</orchestration>

Create ${digest_rel} using this exact Markdown contract:

# Video Digest: <title>

## Source
- raw: ${raw_rel}
- segments: ${segments_rel}
- transcript_quality: generated | manual
- language: ko | en

## Executive Summary
- 3-5 bullets.

## Key Claims
- Claim with segment range.

## Metrics
| Metric | Value | Segment range | Note |
|---|---:|---|---|

## Workflow / Recommendations
1. Actionable step.

## Concepts To Merge Into Wiki
- Suggested wiki slug and relationship.

## Removed Noise
- CTA
- repeated intro
- sponsor/ad
- rhetorical repetition

## Verification Notes
- Caption quality issues.
- Claims needing external verification.

Digest rules:
1. Use ${segments_rel} as timestamp evidence.
2. Use ${raw_rel} as the source of truth.
3. Do not summarize away measurable claims.
4. Keep the digest compact enough for wiki synthesis.
5. Do not update wiki/ in this step." || {
    log_error "Video digest generation failed"
    return 1
  }

  if [[ ! -s "$digest_file" ]]; then
    log_error "Video digest was not created: $digest_file"
    return 1
  fi

  return 0
}

compile_video_digest() {
  local raw_file="$1" digest_file="$2" source_sha="$3"
  local raw_rel digest_rel

  raw_rel="$(make_relative_path "$raw_file")"
  digest_rel="$(make_relative_path "$digest_file")"

  log_info "Starting Claude Code wiki compile from video digest..."

  claude "<orchestration name=\"youtube-video-ingest\">
  <role>Parent coordinator for LLM Wiki video ingest.</role>

  <inputs>
    <raw_markdown>${raw_rel}</raw_markdown>
    <digest>${digest_rel}</digest>
    <source_sha>${source_sha}</source_sha>
  </inputs>

  <agents>
    <agent name=\"wiki_compiler_agent\">
      <goal>Synthesize the digest into wiki/ according to CLAUDE.md and AGENTS.md.</goal>
      <rules>
        <rule>Use ${digest_rel} for context efficiency.</rule>
        <rule>Use ${raw_rel} as the cited source of truth.</rule>
        <rule>Set YAML sources.path to ${raw_rel}.</rule>
        <rule>Set YAML sources.sha to ${source_sha}.</rule>
      </rules>
    </agent>
  </agents>
</orchestration>

Compile ${digest_rel} into wiki/ according to CLAUDE.md and AGENTS.md.

Required steps:
1. Read wiki/index.md first and identify related page slugs.
2. Use the digest for synthesis, but cite ${raw_rel} for source-backed claims.
3. If related pages exist, preserve existing content and merge only source-backed updates.
4. If this is a new concept, create a new page from _templates/concept.md.
5. Update wiki/index.md and wiki/log.md.
6. Follow all YAML frontmatter rules.
7. Set sources.path to '${raw_rel}' and sources.sha to '${source_sha}'.
8. Do not cite ${digest_rel} as the authoritative source." 2>&1 | tee -a "$LOG_FILE"
}

# ── 초기화 모드 ────────────────────────────────────────────────────────────
cmd_init() {
  log_info "저장소 초기화 시작..."
  mkdir -p "$WIKI_DIR" "$RAW_DIR"/{articles,papers,videos,meetings}
  mkdir -p "$INTERMEDIATE_DIR/videos"
  log_ok "디렉터리 구조 생성 완료"

  if [[ ! -f "$LOG_FILE" ]]; then
    log_warn "log.md 없음 — 생성합니다"
  fi
  log_ok "초기화 완료"
}

# ── URL 인입 모드 ──────────────────────────────────────────────────────────
cmd_url() {
  local url="$1"
  log_info "URL 인입: $url"

  # URL 유형 감지
  local dest_type="articles"
  if echo "$url" | grep -qi "youtube\|youtu\.be"; then
    dest_type="videos"
  fi

  local dest_file
  if [[ "$dest_type" == "videos" ]]; then
    log_info "Resolving YouTube raw source..."
    dest_file="$(python3 "$SCRIPT_DIR/resolve_youtube.py" --output-dir "$RAW_DIR/videos" --print-path "$url")" || {
      log_error "YouTube raw source resolution failed"
      exit 1
    }
  else
    # 파일명 생성 (URL에서 슬러그 추출)
    local slug
    slug="$(echo "$url" | sed 's|https\?://||' | sed 's|[/\?=&]|-|g' | cut -c1-60)"
    dest_file="$RAW_DIR/$dest_type/${slug}.md"

    log_info "대상 파일: $dest_file"

    # Claude Code로 URL 내용 추출 + 마크다운 변환
    cat > "$dest_file" <<EOF
# [RAW SOURCE] ${url}

> ⚠️ 이 파일은 수정 불가능한 원천 소스입니다.
> 출처: ${url}
> 인입 일시: $(timestamp)
> SHA: $(echo "$url" | shasum -a 256 | cut -c1-16)

---

[Claude Code가 URL 내용을 여기에 추출합니다]

EOF
  fi

  local sha
  sha="$(git hash-object "$dest_file" | cut -c1-16)"

  log_ok "URL 소스 파일 생성: $dest_file"
  log_info "SHA: $sha"

  if [[ "$dest_type" == "videos" ]]; then
    local video_id digest_file
    video_id="$(basename "$dest_file" .md)"
    digest_file="$INTERMEDIATE_DIR/videos/${video_id}.digest.md"
    generate_video_digest "$dest_file" "$sha"
    compile_video_digest "$dest_file" "$digest_file" "$sha"
    write_log "INGEST" "$dest_file" "wiki/" "sha: $sha | digest: $(make_relative_path "$digest_file")"
    log_ok "Video ingest completed: $dest_file"
    return 0
  fi

  log_info "Claude Code로 위키 컴파일을 시작합니다..."

  claude "Compile '$dest_file' into wiki/ according to CLAUDE.md and AGENTS.md.

Source file: $dest_file
Source SHA: $sha

Required steps:
1. Read wiki/index.md first and identify related page slugs.
2. If related pages exist, synthesize by preserving existing content and merging source-backed updates.
3. If this is a new concept, create a new page from _templates/concept.md.
4. Update wiki/index.md and wiki/log.md.
5. Follow all YAML frontmatter rules.
6. Set sources.sha to '$sha'." 2>&1 | tee -a "$LOG_FILE" || true
}

# ── 단일 파일 인입 ─────────────────────────────────────────────────────────
cmd_file() {
  local source_file="$1"

  if [[ ! -f "$source_file" ]]; then
    log_error "파일을 찾을 수 없습니다: $source_file"
    exit 1
  fi

  # Resolve to absolute path so the raw/ check below works regardless of
  # whether the caller passed a relative or absolute path.
  source_file="$(cd "$(dirname "$source_file")" && pwd)/$(basename "$source_file")"

  log_info "파일 인입 시작: $source_file"

  # raw/ 경로가 아닌 경우에만 raw/articles/로 복사
  if [[ "$source_file" != "$RAW_DIR"/* ]]; then
    local basename
    basename="$(basename "$source_file")"
    local dest="$RAW_DIR/articles/$basename"
    cp "$source_file" "$dest"
    log_info "→ raw/articles/$basename 으로 복사됨"
    source_file="$dest"
  fi

  # SHA 계산 — §8-4 ADR 트리거와 알고리즘 통일을 위해 git hash-object 사용
  local sha
  sha="$(git hash-object "$source_file" | cut -c1-16)"

  log_info "SHA: $sha"
  log_info "Claude Code로 위키 컴파일 시작..."

  claude "CLAUDE.md와 AGENTS.md의 규칙을 엄격히 따라 아래 파일을 wiki/로 컴파일해줘.

소스 파일: $source_file
소스 SHA: $sha

처리 순서:
1. wiki/index.md를 먼저 읽어 연관 위키 페이지 슬러그 파악
2. 관련 있는 페이지만 선택 (연관성 0.3 미만 스킵)
3. 선택된 페이지: Synthesize (기존 내용 보존하면서 새 정보 자연스럽게 병합)
4. 새로운 개념이면: _templates/concept.md 기반으로 신규 페이지 생성
5. wiki/index.md 테이블에 한 줄 요약 추가/갱신
6. wiki/log.md에 트랜잭션 기록 — **반드시 '## 트랜잭션 기록' 섹션 안의 코드블록(\`\`\`...\`\`\`) 마지막 [INDEX] 라인 바로 다음 줄에만** 추가한다. '## 포맷' 섹션, 헤더, 코드블록 바깥에는 절대 끼워넣지 말 것.
7. YAML 프론트매터의 sources.sha를 '$sha'로 설정" || {
    log_error "Claude Code 실행 실패"
    write_log "ERROR" "$source_file" "N/A" "Claude Code 실행 실패"
    exit 1
  }

  write_log "INGEST" "$source_file" "wiki/" "sha: $sha"
  log_ok "인입 완료: $source_file"
}

# ── inbox 전체 인입 ────────────────────────────────────────────────────────
cmd_all_inbox() {
  log_info "inbox/ 전체 인입 시작..."
  local count=0

  for f in "$WIKI_ROOT/inbox"/*; do
    [[ -f "$f" ]] || continue
    log_info "처리 중: $f"
    cmd_file "$f"
    # inbox → raw로 이동 완료 후 inbox에서 삭제
    mv "$f" "$RAW_DIR/articles/"
    ((count++))
    sleep 1  # API rate limit 방지
  done

  log_ok "inbox 인입 완료: ${count}개 파일 처리"
}

# ── 메인 ──────────────────────────────────────────────────────────────────
main() {
  if [[ $# -eq 0 ]]; then
    echo "사용법: $0 <파일경로> | --init | --all-inbox | --url <URL>"
    exit 1
  fi

  case "$1" in
    --init)       cmd_init ;;
    --all-inbox)  cmd_all_inbox ;;
    --url)        [[ -n "${2:-}" ]] || { log_error "--url 다음에 URL을 입력하세요"; exit 1; }
                  cmd_url "$2" ;;
    *)            cmd_file "$1" ;;
  esac
}

main "$@"
