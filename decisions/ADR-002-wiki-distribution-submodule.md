---
title: "ADR-002: 위키 배포 — Git Submodule 임베딩 모델"
summary: "다른 프로덕트 레포에서 컴파일된 위키를 읽기 전용으로 임베드하기 위한 dist 브랜치 배포 구조"
tags: [decision, adr, distribution, submodule, knowledge-management]
type: decision
created: 2026-05-19T00:00:00+09:00
last_updated: 2026-05-19T00:00:00+09:00
sources: []
related:
  - "[[ADR-001-knowledge-promotion-policy]]"
  - "[[index]]"
status: stable
deciders: [팀 전체]
---

# ADR-002: 위키 배포 — Git Submodule 임베딩 모델

## 상태

`승인됨`

---

## 맥락 (Context)

LLM Wiki는 `main` 브랜치에 다음을 모두 포함한다:

- `raw/` — 불변 원천 (커질수록 무거워짐)
- `scripts/` — 인입/린트 자동화 (컨슈머에게 불필요)
- `wiki/` — 컴파일된 지식 (**컨슈머가 실제로 필요한 것**)
- `inbox/`, `_templates/`, `.obsidian/` — 워크스페이스 부속물

다른 프로덕트 레포(서비스 코드베이스)에서 이 지식을 참조하려고 할 때, `main`을 통째로 서브모듈로 잡으면 다음 문제가 발생한다:

1. **불필요한 비대화**: 컨슈머는 `raw/`, `scripts/`, Obsidian 설정까지 모두 클론한다.
2. **버전 불안정**: 매 ingest마다 main HEAD가 움직여 컨슈머가 의도치 않게 미검증 변경을 잡을 위험.
3. **경계 누수**: 컨슈머 개발자가 실수로 `raw/`나 `scripts/`를 참조/수정할 가능성.

---

## 결정 (Decision)

**같은 레포 내 orphan `dist` 브랜치를 배포 전용 채널로 운영한다.**

- `main`: 워크스페이스(에이전트가 관리, 인간이 읽기) — 변경됨
- `dist`: 배포 전용 브랜치 — `wiki/`와 `manifest.json`만 포함
- 컨슈머 레포는 `dist` 브랜치의 특정 **태그(SemVer)**를 서브모듈로 핀.

```
LLM-wiki (this repo)
├── main                         ← workspace
│   ├── raw/  scripts/  wiki/  ...
│
└── dist                         ← published, consumer-facing
    ├── wiki/                    ← compiled pages only
    └── manifest.json            ← version, source_commit, generated_at, page_count
```

### 버전 정책

- SemVer 태그: `wiki-v1.0.0`, `wiki-v1.1.0`, ...
- **MAJOR**: 페이지 슬러그 삭제/이름 변경 등 컨슈머가 깨질 변경
- **MINOR**: 신규 페이지 추가 (하위 호환)
- **PATCH**: 기존 페이지 내용 갱신 (스키마 동일)

### 발행 절차

**자동 (권장)** — `main`에 푸시되어 `wiki/**`가 바뀌면 [.github/workflows/publish.yml](../.github/workflows/publish.yml)이 트리거되어:
1. `scripts/publish.sh`를 실행해 `dist` 브랜치 갱신 + `wiki-vX.Y.Z` 태그
2. `gh release create`로 GitHub Release 생성 (직전 태그 이후 커밋이 자동으로 노트에 포함)

커밋 메시지 마커로 범프 레벨 제어: `[bump:major]`, `[bump:minor]`, `[bump:skip]`. 마커가 없으면 `patch`.

**수동** — `./scripts/publish.sh <bump> [--push]` 실행 (`bump` = major | minor | patch | X.Y.Z).

---

## 컨슈머 통합 가이드

### 최초 임베드

```bash
# 프로덕트 레포에서
git submodule add -b dist <wiki-repo-url> docs/wiki
git -C docs/wiki checkout wiki-v1.0.0
git add .gitmodules docs/wiki
git commit -m "docs: embed LLM wiki @ v1.0.0"
```

### 버전 업데이트

```bash
git -C docs/wiki fetch --tags
git -C docs/wiki checkout wiki-v1.1.0
git add docs/wiki
git commit -m "docs: bump LLM wiki to v1.1.0"
```

### 읽기 전용 강제

서브모듈 디렉터리 수정 차단은 **컨슈머 레포 측 CI**에서 수행한다 (워킹 트리가 컨슈머 쪽에 있으므로). 본 레포는 재사용 가능한 워크플로 예제를 [.github/consumer-examples/protect-wiki-submodule.yml](../.github/consumer-examples/protect-wiki-submodule.yml)로 제공한다. 이 워크플로는:

- PR에서 서브모듈 경로(`docs/wiki/` 등) 내부 파일 변경이 감지되면 실패.
- 서브모듈 HEAD가 `wiki-vX.Y.Z` 태그를 가리키지 않으면 실패 (floating HEAD 차단).

(선택) 컨슈머 측 pre-commit 훅으로 서브모듈 디렉터리 staging도 함께 차단할 수 있다.

---

## 대안 검토

| 대안 | 장점 | 단점 | 결정 |
|------|------|------|------|
| `main` 통째 서브모듈 | 단순 | 비대, 버전 불안정 | ❌ |
| 별도 레포 분리 (`llm-wiki-dist`) | 권한 분리 명확 | 두 레포 동기화 부담, 거버넌스 복잡 | ❌ |
| **Orphan `dist` 브랜치 (선택)** | 단일 레포, 컨슈머 최소 페이로드, 태그 핀 | 발행 스크립트 필요 | ✅ |
| 패키지 매니저 배포 (npm 등) | 표준 도구 | 마크다운 배포에 부적합, 인프라 과잉 | ❌ |

---

## 결과 (Consequences)

**긍정**

- 컨슈머는 컴파일된 지식만 받는다 (raw/, scripts/ 제외).
- 태그로 안정 버전을 핀할 수 있어 프로덕트 빌드가 결정론적이다.
- 단일 레포 유지 → 거버넌스, 검색, 이슈 트래킹 단일화.

**부정**

- 발행 단계가 한 번 더 생긴다 (`publish.sh` 실행).
- `dist` 브랜치 히스토리를 강제 갱신하므로 컨슈머가 임의로 `dist` HEAD를 추적하면 안 되고 **반드시 태그를 핀**해야 한다.

**완화책**

- `publish.sh`에 lint 통과 + clean working tree 가드 포함.
- `dist` 브랜치는 force-push 허용, 태그는 immutable로 보호 정책 설정.
