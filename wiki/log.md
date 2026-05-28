# Ingest Log

> 모든 컴파일 트랜잭션의 감사 원장입니다. 에이전트가 자동 기록합니다.

---

## 포맷

[2026-05-28 15:12] [INGEST] source: /Users/addie.lee/work/LLM-wiki/raw/videos/5uTpUYw8Of4.md → targets: wiki/ | sha: 28d4ad9d897252a7 | digest: intermediate/videos/5uTpUYw8Of4.digest.md```
[YYYY-MM-DD HH:MM] [ACTION] source: <경로> → targets: <위키 페이지들> | sha: <해시>
[2026-05-28 15:12] [INGEST] source: /Users/addie.lee/work/LLM-wiki/raw/videos/5uTpUYw8Of4.md → targets: wiki/ | sha: 28d4ad9d897252a7 | digest: intermediate/videos/5uTpUYw8Of4.digest.md```

---

## 트랜잭션 기록

[2026-05-28 15:12] [INGEST] source: /Users/addie.lee/work/LLM-wiki/raw/videos/5uTpUYw8Of4.md → targets: wiki/ | sha: 28d4ad9d897252a7 | digest: intermediate/videos/5uTpUYw8Of4.digest.md```
[2026-05-19 00:00] [INIT]   Wiki 저장소 초기화 완료
                            구조: raw/, wiki/, _templates/, scripts/, decisions/
                            CLAUDE.md, AGENTS.md 배포 완료
[2026-05-19 00:00] [INGEST] source: raw/articles/llm-wiki-karpathy.md
                            → targets: wiki/llm-wiki-pattern.md
                            sha: initial-seed
                            pages_created: 1 | pages_updated: 0
[2026-05-19 00:00] [INDEX]  wiki/index.md 갱신 — 총 1개 페이지
[2026-05-28 15:00] [INGEST] source: raw/videos/5uTpUYw8Of4.md
                            → targets: wiki/llm-wiki-pattern.md
                            sha: cb78d4ad13111834
                            pages_created: 0 | pages_updated: 1
                            notes: 영상 기반 사례 연구·실측 데이터·실전 팁 추가
[2026-05-28 15:00] [INDEX]  wiki/index.md last_updated 갱신
[2026-05-28 15:30] [INGEST] source: raw/videos/5uTpUYw8Of4.md
                            → targets: wiki/llm-wiki-pattern.md
                            sha: 28d4ad9d897252a7 (prev: cb78d4ad13111834)
                            pages_created: 0 | pages_updated: 1
                            notes: 동일 영상 재인입 — 디제스트 내용 기존 페이지에 모두 반영됨, sources.sha 갱신
[2026-05-28 15:30] [INDEX]  wiki/index.md last_updated 갱신
[2026-05-28 16:00] [INGEST] source: raw/videos/5uTpUYw8Of4.md
                            → targets: wiki/llm-wiki-pattern.md
                            sha: 28d4ad9d897252a7 (unchanged)
                            pages_created: 0 | pages_updated: 1
                            notes: idempotent re-ingest — content already reflected; last_updated refresh only
[2026-05-28 16:00] [INDEX]  wiki/index.md last_updated 갱신
[2026-05-28 17:00] [INGEST] source: raw/videos/5uTpUYw8Of4.md
                            → targets: wiki/llm-wiki-pattern.md
                            sha: 6c5d92812de0f5b1 (prev: 28d4ad9d897252a7)
                            pages_created: 0 | pages_updated: 1
                            notes: idempotent re-ingest — content already reflected; sources.sha refreshed only
[2026-05-28 17:00] [INDEX]  wiki/index.md last_updated 갱신
[2026-05-28 15:12] [INGEST] source: /Users/addie.lee/work/LLM-wiki/raw/videos/5uTpUYw8Of4.md → targets: wiki/ | sha: 28d4ad9d897252a7 | digest: intermediate/videos/5uTpUYw8Of4.digest.md```

---

## 통계

| 항목 | 값 |
|------|---|
| 총 인입 횟수 | 4 |
| 생성된 페이지 | 1 |
| 업데이트된 페이지 | 3 |
| Lint 실행 | 0 |
| 오류 발생 | 0 |
