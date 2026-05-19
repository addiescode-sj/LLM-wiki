# LLM Wiki

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

## 팀 협업 워크플로우

```
개인 브랜치 작업          PR 리뷰               팀 공유
personal/<이름>   →→→   lint 통과 + 리뷰   →→→   main
```

자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.

---

## 아키텍처 참고

- 위키 패턴 상세: [wiki/llm-wiki-pattern.md](wiki/llm-wiki-pattern.md)
- 에이전트 규칙: [CLAUDE.md](CLAUDE.md)
- 에이전트 명세: [AGENTS.md](AGENTS.md)
