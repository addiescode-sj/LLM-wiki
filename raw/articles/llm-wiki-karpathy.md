# [RAW SOURCE] Karpathy LLM Wiki 패러다임 분석

> ⚠️ 이 파일은 **수정 불가능한 원천 소스**입니다. 절대 편집하지 마세요.
> 출처: 팀 내부 조사 자료 (2026-05-19)
> SHA: gdoc-1k8Qh-irUsybmZIHit1MBAnysHsfzPP2TAmAcT3JJhcM

---

## 핵심 개념

- LLM Wiki = 지식 처리를 Query-time → Ingest-time으로 이동
- Obsidian = IDE 역할, LLM = 백그라운드 프로그래머, Markdown repo = 코드베이스
- RAG 대비: 벡터 청크 vs 의미론적으로 완결된 마크다운 파일
- Local-first: File-over-app 철학, 벤더 록인 없음

## 3계층 아키텍처

1. Layer 1 (Raw Sources): 불변 원천 소스
2. Layer 2 (Wiki): LLM 에이전트 단독 유지보수 마크다운
3. Layer 3 (Schema): CLAUDE.md / AGENTS.md — 에이전트 제약 헌법

## 4대 에이전트 루프

- Init: 디렉터리 초기화, index.md/log.md 부트스트랩
- Ingest: Resolve → Route → Synthesize → Embed & Index
- Query: 임베딩 유사도 → 위키 페이지 필터링 → 답변 (--save 시 피드백 루프)
- Lint: 고아 링크 수복, 모순 감지, 갭 채우기

## YAML 프론트매터 표준

- title, summary, tags, type, created, last_updated, sources, related, status 필수
- 프론트매터만 고속 스캔 → API 비용 최대 90% 절감

## 팀 워크스페이스 구조

- Git Hook (post-commit) → 자동 코드 문서화
- Slack/Teams 대화 → ADR 마크다운 변환 (Chat-to-Doc)
- Atlassian MCP → Jira/Confluence 연동

## 스케일 기준

- Medium (100~200 페이지, 400K 단어 이하): 파일 시스템만으로 충분
- Enterprise: Weaviate(벡터) + Neo4j(그래프) + Dify 오케스트레이터
