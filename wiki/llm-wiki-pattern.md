---
title: "Karpathy LLM Wiki 패턴"
summary: "Ingest-time 컴파일로 RAG 한계를 극복하는 자가 성장형 마크다운 지식 베이스 패턴"
tags: [llm, ai, architecture, rag, obsidian, knowledge-management]
type: concept
created: 2026-05-19T00:00:00+09:00
last_updated: 2026-05-28T15:30:00+09:00
sources:
  - path: "raw/articles/llm-wiki-karpathy.md"
    sha: "gdoc-1k8Qh-irUsybmZIHit1MBAnysHsfzPP2TAmAcT3JJhcM"
  - path: "raw/videos/5uTpUYw8Of4.md"
    sha: "28d4ad9d897252a7"
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

---

## 사례 연구: LLM Wiki Compiler 실측 효과

한 개발자가 카파시의 개념을 바탕으로 **LLM Wiki Compiler 플러그인**을 구현하여
측정한 압축률과 토큰 절감 데이터 (raw/videos/5uTpUYw8Of4.md:317-377).

### 컴파일 압축률

| 입력 데이터 | 원본 규모 | 컴파일 결과 | 압축 비율 |
|------------|----------|------------|----------|
| 마크다운 문서 | 383개 / 13.1MB | 13개 기사 | **81×** |
| 회의 녹취록 | 130개 / 122,625줄 | 1개 파일 / 244줄 | **503×** |

> 압축의 원천은 알고리즘이 아닌 LLM의 **의미 추출**이다.
> 반복·잡담·중복 제거 후 핵심만 남기므로 가능 (raw/videos/5uTpUYw8Of4.md:349-357).

### 토큰 절감 (세션당)

| 항목 | RAG 방식 | LLM Wiki | 감소율 |
|-----|---------|----------|--------|
| 세션 초기 컨텍스트 로딩 | 47,000 tokens | 7,700 tokens | **84%** |
| 질의당 리서치 토큰 | 8,000 tokens | 600 tokens | **84%** |

(raw/videos/5uTpUYw8Of4.md:359-377)

### 비용 손익 분기점

- **초기 컴파일 비용**: $0.60 ~ $13 (모델에 따라)
- **증분 인입 비용**: $0.30 ~ $1.50 per 신규 문서 세션
- **손익 분기점**: 첫 번째 세션부터 회수 — 매 세션 47k 토큰을 태우던 비용이
  7.7k 토큰으로 줄어들므로 즉시 본전 (raw/videos/5uTpUYw8Of4.md:529-561).

---

## 실전 컨텍스트 관리 (Claude Code)

LLM Wiki 도입 이전에도 즉시 적용 가능한 토큰 절감 기법
(raw/videos/5uTpUYw8Of4.md:465-505).

### 1. `/compact` 명령어
- 대화가 길어져 컨텍스트가 가득 차면 사용
- 대화 히스토리를 요약하여 압축 — "연료 탱크의 찌꺼기를 빼고 순수 연료만 남기는" 효과

### 2. `/clear` 명령어
- 주제가 완전히 바뀔 때 사용
- 이전 대화의 잔재가 새 작업을 방해하는 것을 차단

### 3. `CLAUDE.md` 길이 최적화
- 권장 길이: **200 ~ 500줄**
- 너무 길면 매 세션 컨텍스트 토큰을 과소비
- 정말 중요한 규칙만 남기고 나머지는 제거

---

## AI의 구조적 약점: 세션 리셋

LLM은 매 질의마다 컨텍스트를 처음부터 다시 로딩하는 구조적 한계가 있다.
이는 비유적으로 **"매일 아침 기억이 리셋되는 신입 사원"**과 같다 —
어제 읽은 문서 100장을 오늘 다시 100장 복사해서 읽혀야 한다
(raw/videos/5uTpUYw8Of4.md:167-209).

이 문제의 RAG 식 해법은 "필요할 때마다 도서관에서 책을 다시 빌리는" 방식이고,
LLM Wiki 해법은 "미리 책상 위에 요약 노트를 만들어 두는" 방식이다
(raw/videos/5uTpUYw8Of4.md:295-317).

카파시의 표현: **"지식이 컴파일된 상태로 유지되기 때문에 매번 처음부터 다시 추출할 필요가 없다"**
(raw/videos/5uTpUYw8Of4.md:309-317).
