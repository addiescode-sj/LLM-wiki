# CLAUDE.md — LLM Wiki 에이전트 헌법

이 파일은 LLM Wiki를 구동하는 모든 AI 에이전트(Claude Code 등)의
**작동 제약과 처리 원칙**을 선언합니다.
에이전트는 이 파일을 항상 최우선으로 참조해야 합니다.

---

## 1. 핵심 철학

- **Ingest-time 컴파일**: 질의 시점(Query-time)이 아닌 **데이터 입력 시점**에 지식을 구조화한다.
- **표현 우선**: 검색 최적화보다 **논리적 연속성과 계층 구조 보존**을 우선한다.
- **불변 원천(Immutable Raw)**: `/raw` 폴더의 파일은 절대 수정하지 않는다.
- **에이전트 전용 위키**: `/wiki` 폴더 문서는 에이전트가 단독 유지보수한다. 인간은 읽기 전용.
- **Local-first**: 모든 지식은 마크다운 파일로 로컬에 영구 저장한다.

---

## 2. 사실 검증 원칙 (Hallucination 방지)

```
FACT-CHECKING RULES:
1. 모든 아키텍처 설명은 반드시 소스 파일 경로와 라인 번호를 인용해야 한다.
   형식: (path:start_line-end_line)

2. 불확실한 내부 상태를 암시하는 추측성 문구는 컴파일 오류로 분류한다.
   금지 예시: "이 메서드는 아마도 DB 장애를 처리할 것이다"

3. HEAD 기준 현재 파일에서 명시적으로 증명되지 않은 외부 API 모델을 참조하지 않는다.

4. 동작이 단위 테스트에 의존하는 경우, 반드시 해당 테스트 파일 경로를 인용한다.

5. 불확실한 정보는 [UNVERIFIED] 태그로 명시하고 검증 후 제거한다.
```

---

## 3. 노트 처리 프로토콜

### 3-1. 신규 문서 인입 순서
1. **Resolve**: 원본 파일 → 평문 텍스트 스트림으로 변환
2. **Route**: `wiki/index.md` 스키마 인덱스를 먼저 읽고, 연관 위키 페이지 슬러그만 추출
3. **Synthesize**: 기존 문서 보존하며 새 정보 병합 (덮어쓰기 금지)
4. **Index**: `wiki/index.md` 한 줄 요약 갱신 + `wiki/log.md` 트랜잭션 기록

### 3-2. 금지 행위
- `/raw` 파일 수정 또는 삭제
- `wiki/` 문서를 인간이 직접 수동 편집 (읽기는 허용)
- 출처 없는 내용 추가
- 기존 내용 삭제 없이 덮어쓰기

---

## 4. YAML 프론트매터 필수 스키마

모든 `/wiki` 문서는 아래 YAML 프론트매터를 반드시 포함해야 한다:

```yaml
---
title: "문서 제목"
summary: "한 줄 요약 (index.md용)"
tags: [태그1, 태그2]
type: concept | architecture | decision | reference | meeting
created: YYYY-MM-DDTHH:MM:SS+09:00
last_updated: YYYY-MM-DDTHH:MM:SS+09:00
sources:
  - path: "raw/파일명.md"
    sha: "git-sha 또는 url-hash"
related:
  - "[[연관-페이지-슬러그]]"
status: draft | reviewed | stable
---
```

---

## 5. 라우팅 효율화 규칙

- 새 문서 인입 시 전체 wiki를 재생성하지 않는다
- `wiki/index.md`의 one-line summary만 스캔하여 연관 페이지를 선택한다
- 연관성 점수가 낮은 페이지(< 0.3)는 건너뛴다
- API 비용 절감을 위해 프론트매터만 먼저 읽고 필요한 경우에만 본문 로드

---

## 6. 품질 감사 (Lint) 기준

- 고아 링크 (`[[존재하지 않는 페이지]]`) → 즉시 수정 또는 페이지 생성
- 소스 SHA 불일치 → `status: outdated` 표시 후 재컴파일 예약
- 모순 감지 → `[CONFLICT]` 태그 삽입 후 사람에게 검토 요청
- 빈 `related` 섹션 → 링크 밀도 분석 후 최소 1개 연결 권장

---

## 7. 팀 공유 전환 기준

개인 브랜치 → `main` PR 조건:
- [ ] 모든 노트에 valid YAML 프론트매터 존재
- [ ] 소스 경로가 실제 `/raw` 파일과 매핑
- [ ] `wiki/log.md`에 인입 기록 존재
- [ ] `lint` 스크립트 통과 (0 오류)
- [ ] 최소 1명 팀원 리뷰 승인

---

## 8. 커밋 컨벤션 (필수)

모든 커밋은 아래 포맷을 따른다. 사용자가 LLM에게 `commit` 또는 `커밋해`라고
지시하면 이 컨벤션에 맞춰 메시지를 **반드시** 생성한 뒤 커밋해야 한다.
`.githooks/commit-msg` 훅이 규칙을 강제하므로, 어긴 커밋은 거부된다.

### 8-1. 메시지 포맷

```
<type>(<scope>): <subject> [bump:<level>]

<body (선택)>
```

- **type** (필수): `feat | fix | docs | refactor | chore | raw | wiki | publish | test`
- **scope** (선택): 영향 영역 (예: `ingest`, `lint`, `adr`, 페이지 슬러그)
- **subject** (필수): 명령형, 마침표 없음, **72자 이내**
- **bump marker** (조건부 필수): `wiki/` 페이지(`log.md`, `lint-report.md` 제외)가
  변경된 커밋이면 아래 중 하나를 **반드시** 포함:
  - `[bump:patch]` — 기존 페이지 내용 갱신 (스키마/슬러그 동일)
  - `[bump:minor]` — 신규 페이지 추가 (하위 호환)
  - `[bump:major]` — 기존 페이지 슬러그 **삭제/이름 변경** (컨슈머 깨짐)
  - `[bump:skip]` — 발행 불필요 (예: 오타 수정 후 별도 릴리즈 원치 않을 때)

> bump 마커 결정 시 우선순위: **major > minor > patch > skip**.
> 하나의 커밋에 슬러그 변경이 섞여 있으면 무조건 `major`다.

### 8-2. 예시

```
wiki(transformer): add attention mechanism page [bump:minor]
fix(lint): handle empty wiki/ dir in YAML check
raw: ingest karpathy llm-wiki article
docs(adr): record submodule distribution decision
wiki: rename llm-wiki-pattern to llm-wiki-overview [bump:major]
chore(hooks): install commit-msg validator
```

### 8-3. LLM 지시 매핑

사용자가 `commit` 또는 `커밋해`라고 명령하면 다음 절차를 따른다:

1. `git status` / `git diff --cached`로 스테이지된 변경을 파악한다.
2. `wiki/*.md` 변경 여부 확인 (단, `log.md`, `lint-report.md`는 제외):
   - 변경 없음 → bump 마커 생략
   - 기존 페이지 슬러그 삭제/이름 변경 감지 → `[bump:major]`
   - 신규 페이지 추가 → `[bump:minor]`
   - 그 외 내용 수정 → `[bump:patch]`
3. type/scope/subject를 §8-1 포맷에 맞게 작성한다.
4. `git commit -m "..."` (멀티라인이면 heredoc) 으로 커밋하고
   `commit-msg` 훅 결과를 확인한다. 훅이 실패하면 메시지를 고쳐 재커밋한다.
