---
title: "Karpathy LLM Wiki 패턴"
summary: "Ingest-time 컴파일로 RAG 한계를 극복하는 자가 성장형 마크다운 지식 베이스 패턴"
tags: [llm, ai, architecture, rag, obsidian, knowledge-management]
type: concept
created: 2026-05-19T00:00:00+09:00
last_updated: 2026-05-19T00:00:00+09:00
sources:
  - path: "raw/articles/llm-wiki-karpathy.md"
    sha: "gdoc-1k8Qh-irUsybmZIHit1MBAnysHsfzPP2TAmAcT3JJhcM"
related:
  - "[[index]]"
status: stable
---

# Karpathy LLM Wiki 패턴

Andrej Karpathy가 제안한 **LLM Wiki**는 기존 RAG(Retrieval-Augmented Generation)의
구조적 한계를 극복하기 위해 지식 처리 시점을 전환하는 아키텍처 패턴이다.

---

## 핵심 아이디어: Ingest-time 컴파일

전통적 RAG는 사용자 질의 시점(Query-time)에 문서를 검색하고 처리한다.
이로 인해 매 세션마다 맥락이 초기화되는 **"세션 기반 건망증"** 문제가 발생한다.

LLM Wiki는 새로운 정보가 유입되는 **인입 시점(Ingest-time)**에 LLM을 활성화해
지식을 구조화하고 기존 지식망과 연결한 뒤, 고밀도 마크다운 파일 네트워크로 컴파일해 둔다.

> 소프트웨어 컴파일러가 소스 코드를 최적화된 바이너리로 사전 변환하는 것과 같은 원리.

---

## RAG vs LLM Wiki 비교

| 비교 범주 | 전통적 RAG | LLM Wiki |
|-----------|-----------|----------|
| 추론 시점 | Query-time | Ingest-time |
| 저장 구조 | 벡터 청크 (Vector DB) | 의미론적 완결 마크다운 |
| 상호 참조 | 청크 간 교차 링크 불가 | `[[wikilink]]` 연결망 |
| 인프라 의존도 | 임베딩 모델 + 벡터 DB 필수 | 파일 시스템 + 마크다운 에디터 |
| 지식 가시성 | 이진 벡터 공간 (비가시) | Obsidian Graph View로 시각화 |
| 데이터 소유권 | SaaS 벤더 의존 | Local-first, 완전 소유 |

---

## 3계층 아키텍처

```
Layer 3: CLAUDE.md / AGENTS.md (거버넌스 규격 — 에이전트 헌법)
    ↕ 정책 강제
Layer 2: /wiki/ (가공 위키 — AI 단독 유지보수)
    ↕ 에이전트 제어 하에 변환
Layer 1: /raw/ (원천 소스 — 불변 Immutable)
```

### Layer 1: Raw Sources (불변 원천)
- 웹 클리핑, 논문 PDF, 미팅 스크립트, 코드 diff
- **절대 수정 금지** — 재컴파일의 안전장치
- 파일별 SHA 해시로 위키 문서와 정합성 관리

### Layer 2: The Wiki (가공 위키)
- LLM 에이전트가 단독 소유권 행사
- 인간은 **읽기 전용**으로 탐색
- 핵심 파일: `index.md` (마스터 지도), `log.md` (트랜잭션 감사)

### Layer 3: The Schema (거버넌스)
- `CLAUDE.md`: 에이전트 제약 헌법
- `AGENTS.md`: 에이전트 역할 및 호출 명세
- 처리 정책, 템플릿 표준, 용어 정의 규칙 선언

---

## 4대 에이전트 루프

### 1. Init (초기화)
```bash
./scripts/ingest.sh --init
```
- `/raw`, `/wiki` 디렉터리 초기화
- `index.md`, `log.md` 부트스트랩

### 2. Ingest (컴파일 인입)
```bash
./scripts/ingest.sh raw/articles/my-article.md
```
처리 흐름:
1. **Resolve**: 다양한 소스 → 평문 텍스트 스트림
2. **Route**: index.md 스캔 → 연관 페이지 슬러그 추출 (전체 재생성 방지)
3. **Synthesize**: 기존 내용 보존 + 새 정보 병합
4. **Index**: index.md 갱신 + log.md 기록

### 3. Query (지식 질의)
```bash
./scripts/query.sh "Transformer attention 메커니즘을 설명해줘"
./scripts/query.sh --save "질문" # Compounding Loop: 답변을 새 위키 페이지로 저장
```

### 4. Lint (품질 감사)
```bash
./scripts/lint.sh
```
- 고아 링크 추적/수복
- 소스 SHA 불일치 감지
- 모순(Contradiction) 리포트
- 정합성 만료 페이지 표시

---

## YAML 프론트매터 표준

```yaml
---
title: "문서 제목"
summary: "한 줄 요약"
tags: [태그1, 태그2]
type: concept | architecture | decision | reference | meeting
created: 2026-05-19T00:00:00+09:00
last_updated: 2026-05-19T00:00:00+09:00
sources:
  - path: "raw/파일명.md"
    sha: "파일 해시"
related:
  - "[[연관-페이지]]"
status: draft | reviewed | stable
---
```

> 프론트매터만 고속 스캔하여 API 비용 최대 90% 절감 가능.

---

## 핵심 장점

1. **지식 복리 효과**: 새 문서 추가 시 기존 링크 밀도가 기하급수적으로 증가
2. **컨텍스트 부채 제거**: 세션 종료 후에도 지식 구조 완전 보존
3. **데이터 소유권**: Local-first, 벤더 록인 없음
4. **가시성**: Obsidian Graph View로 지식 흐름 시각화
5. **스케일 유연성**: Medium(마크다운만) → Enterprise(벡터DB + 그래프DB) 점진적 확장

---

## 관련 개념

- [[index]] — 전체 위키 마스터 인덱스
- `RAG (Retrieval-Augmented Generation)` — 대안 아키텍처
- `Obsidian` — 로컬 마크다운 IDE/뷰어
- `Claude Code` — AI 컴파일 엔진
- `Transactional Outbox Pattern` — 이벤트 정합성 유사 패턴
