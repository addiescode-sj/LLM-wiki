# LLM Wiki

> 🇰🇷 한국어 | [🇺🇸 English](README.md)

[![Publish](https://github.com/addiescode-sj/LLM-wiki/actions/workflows/publish.yml/badge.svg?branch=main)](https://github.com/addiescode-sj/LLM-wiki/actions/workflows/publish.yml)

> Andrej Karpathy의 LLM Wiki 패턴 기반 팀 지식 공유 베이스

RAG의 "세션 건망증"을 극복하는 **Ingest-time 컴파일** 방식의 로컬 우선 마크다운 지식 베이스입니다.  
새 문서가 들어올 때마다 Claude Code가 자동으로 wiki/에 구조화하여 저장합니다.

---

## 빠른 시작

### 1. 사전 요구사항

```bash
# Claude Code CLI 설치 확인
claude --version

# Obsidian에서 이 폴더를 Vault로 열기
# → Community Plugins에서 아래 3개 설치 및 활성화:
#   - Obsidian Git
#   - Dataview
#   - Templater
```

### 2. 저장소 초기화 (첫 실행 시 1회)

```bash
./scripts/ingest.sh --init
./scripts/setup-hooks.sh    # 커밋 메시지 검증 훅 설치 (CLAUDE.md §8 참고)
```

### 3. 지식 추가

```bash
# 파일로 추가
./scripts/ingest.sh raw/articles/my-article.md

# URL로 추가
./scripts/ingest.sh --url https://example.com/paper

# inbox/ 전체 일괄 처리
./scripts/ingest.sh --all-inbox
```

### 4. 지식 검색

```bash
./scripts/query.sh "Transformer attention 메커니즘이란?"

# 답변을 위키 페이지로 저장
./scripts/query.sh --save "RAG와 LLM Wiki의 차이점은?"
```

### 5. 품질 관리

```bash
./scripts/lint.sh           # 전체 감사
./scripts/lint.sh --fix     # 자동 수복
./scripts/freshness.sh      # SHA 정합성 체크
```

---

## 디렉터리 구조

```
LLM-wiki/
├── CLAUDE.md              # 에이전트 헌법 (AI 행동 규칙)
├── AGENTS.md              # 에이전트 역할 명세
├── CONTRIBUTING.md        # 기여 가이드
│
├── raw/                   # ⚠️ 불변 원천 소스 (수정 금지)
│   ├── articles/          # 웹 클리핑, 블로그 포스트
│   ├── papers/            # 논문 PDF 요약
│   ├── videos/            # 유튜브/강의 스크립트
│   └── meetings/          # 미팅 노트
│
├── wiki/                  # 🤖 AI 단독 유지보수 (읽기 전용으로 탐색)
│   ├── index.md           # 마스터 인덱스 (에이전트 라우팅용)
│   ├── log.md             # 트랜잭션 감사 원장
│   └── *.md               # 컴파일된 위키 페이지
│
├── _templates/            # 문서 템플릿
│   ├── concept.md
│   ├── decision.md
│   └── meeting.md
│
├── inbox/                 # 처리 대기 파일 투입함
│
├── scripts/               # 자동화 스크립트
│   ├── ingest.sh          # Ingest Agent
│   ├── query.sh           # Query Agent
│   ├── lint.sh            # Lint Agent
│   ├── freshness.sh       # SHA 정합성 검증
│   └── async_ingest.sh    # Git hook용 비동기 인입
│
└── .obsidian/             # Obsidian 설정
```

---

## Git 자동화

`raw/`에 파일을 커밋하면 post-commit 훅이 자동으로 위키 컴파일을 시작합니다.

```bash
# 원천 소스 추가 → 커밋만 하면 자동 처리
git add raw/articles/new-article.md
git commit -m "raw: add new-article.md"
# → 백그라운드에서 wiki/ 자동 컴파일
# → 로그: /tmp/llm-wiki-async-ingest.log
```

---

## 개인 → 팀 지식 격상 정책

> **핵심 원칙**: 개인 브랜치에서 먼저 지식을 검증하고, 팀에게 가치 있는 것만 `main`으로 격상한다.

### 브랜치 구조

```
main                  ← 팀 공유 지식 (보호됨, 검증된 내용만)
  └── personal/addie  ← 개인 지식 (자유롭게 실험)
       └── feature/redis-research  ← 특정 주제 조사 시
```

### 격상 판단 기준

**격상 권장** — 팀 전체에 반복적으로 필요한 내용:
- 아키텍처 결정 (ADR), 기술 선택 근거
- 트러블슈팅 기록, 프로덕션 인시던트 회고
- 온보딩 필수 지식 (배포 절차, 환경 설정)
- 기술 리서치 결과 (벤치마크, 라이브러리 비교)

**개인 브랜치 유지** — 팀과 무관한 개인 맥락:
- 개인 학습 메모, 책 요약
- 특정 PR 작업 중 임시 메모
- 검증되지 않은 초안

### 격상 절차 (한눈에)

```
① 개인 브랜치에서 raw/ 추가 → 커밋
         ↓ (자동)
② wiki/ 컴파일 완료

③ lint 통과 확인
   ./scripts/lint.sh

④ PR 생성: personal/<이름> → main
   (체크리스트 작성)

⑤ 팀원 1인 리뷰 → Squash Merge

⑥ 팀 전체 접근 가능 ✅
```

### 빠른 시작 — 개인 브랜치 생성

```bash
# 처음 시작할 때
git checkout -b personal/your-name
git push -u origin personal/your-name
```

→ 실제 시나리오 예시: [wiki/promotion-example.md](wiki/promotion-example.md)  
→ 격상 정책 상세: [decisions/ADR-001-knowledge-promotion-policy.md](decisions/ADR-001-knowledge-promotion-policy.md)

---

## 배포 (다른 레포에 임베드)

컴파일된 `wiki/`는 별도 `dist` 브랜치로 발행되어, 다른 프로덕트 레포가 **읽기 전용 git submodule**로 임베드할 수 있습니다. 자세한 설계는 [decisions/ADR-002-wiki-distribution-submodule.md](decisions/ADR-002-wiki-distribution-submodule.md) 참조.

### 자동 발행 (main에 push 시)

`main`에 푸시되어 `wiki/**`가 변경되면 [Publish Wiki Release](.github/workflows/publish.yml) 워크플로가 자동 실행됩니다:

1. `scripts/publish.sh`로 `dist` 브랜치를 재빌드하고 `wiki-vX.Y.Z` 태그 부착.
2. 해당 태그로 GitHub Release 생성 (직전 태그 이후 커밋을 자동으로 노트에 포함).
3. README 뱃지는 shields.io가 최신 릴리즈 태그를 실시간으로 읽어 자동 갱신됩니다.

**버전 범프 레벨은 커밋 메시지로 결정합니다:**

| 커밋 메시지 마커 | Bump | 사용 시점 |
|------|------|------|
| _(없음)_ | `patch` | 기본값 — 내용 수정, 사소한 추가 |
| `[bump:minor]` | `minor` | 신규 페이지 추가 (하위 호환) |
| `[bump:major]` | `major` | 기존 페이지 슬러그 삭제/이름 변경 (컨슈머 깨짐) |
| `[bump:skip]` | _없음_ | 문서/메타만 변경, 발행 불필요 |

수동 실행도 가능합니다: **Actions → Publish Wiki Release → Run workflow** (범프 레벨 선택).

### 수동 발행 (로컬)

```bash
./scripts/publish.sh patch          # 1.0.0 → 1.0.1
./scripts/publish.sh minor --push   # 1.0.1 → 1.1.0 + 원격 푸시
./scripts/publish.sh major --push   # 버전 업 + 브랜치/태그 원격 푸시
```

### 컨슈머 레포에서 임베드

```bash
# 최초 임베드, 태그에 핀
git submodule add -b dist <wiki-repo-url> docs/wiki
git -C docs/wiki checkout wiki-v1.0.0
git add .gitmodules docs/wiki
git commit -m "docs: embed LLM wiki @ v1.0.0"

# 이후 버전 업데이트
git -C docs/wiki fetch --tags
git -C docs/wiki checkout wiki-v1.1.0
git add docs/wiki && git commit -m "docs: bump LLM wiki to v1.1.0"
```

컨슈머는 `wiki/`와 `manifest.json`만 받으며 `raw/`, `scripts/`, 워크스페이스 메타데이터는 제외됩니다.

---

## 팀 협업 워크플로우

자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.

---

## 아키텍처 참고

- 위키 패턴 상세: [wiki/llm-wiki-pattern.md](wiki/llm-wiki-pattern.md)
- 에이전트 규칙: [CLAUDE.md](CLAUDE.md)
- 에이전트 명세: [AGENTS.md](AGENTS.md)
