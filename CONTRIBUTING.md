# Contributing Guide

## 브랜치 전략

```
main (팀 공유 지식 — 보호됨)
  └── personal/<이름>   (개인 지식 브랜치 — 기본 작업 공간)
       └── feature/<주제>  (특정 주제 추가 시)
```

### 개인 브랜치 생성
```bash
git checkout -b personal/your-name
```

### PR 조건 (main 병합 기준)
- `./scripts/lint.sh` 통과 (오류 0개)
- YAML 프론트매터 유효
- `wiki/log.md` 트랜잭션 기록 있음
- 1인 이상 팀원 리뷰

---

## 워크플로우

### 1. 원천 소스 추가
```bash
# raw/ 디렉터리에 파일 복사 후 커밋
cp article.md raw/articles/
git add raw/articles/article.md
git commit -m "raw: add article.md"
# → post-commit 훅이 자동으로 wiki/ 컴파일 시작
```

### 2. 수동 인입
```bash
./scripts/ingest.sh raw/articles/article.md
./scripts/ingest.sh --url https://example.com/article
```

### 3. 위키 검색
```bash
./scripts/query.sh "Transformer attention 메커니즘이란?"
./scripts/query.sh --save "RAG와 LLM Wiki 차이점"  # 답변 → 위키 저장
```

### 4. 품질 검사
```bash
./scripts/lint.sh           # 전체 감사
./scripts/lint.sh --fix     # 자동 수복
./scripts/freshness.sh      # SHA 정합성 체크
```

### 5. PR 올리기
```bash
git push origin personal/your-name
# GitHub에서 personal/your-name → main PR 생성
```

---

## 파일 구조 원칙

| 경로 | 역할 | 수정 권한 |
|------|------|-----------|
| `raw/` | 불변 원천 소스 | ❌ 절대 수정 금지 |
| `wiki/` | 컴파일된 지식 | 🤖 AI 단독 유지보수 |
| `CLAUDE.md` | 에이전트 헌법 | 👥 팀 합의 후 수정 |
| `_templates/` | 문서 템플릿 | 👥 팀 합의 후 수정 |
| `scripts/` | 자동화 스크립트 | 👥 기여 환영 |

---

## 커밋 메시지 컨벤션

```
raw: <설명>         # 원천 소스 추가
wiki: <설명>        # 위키 페이지 수정 (AI 생성 제외)
scripts: <설명>     # 스크립트 수정
config: <설명>      # 설정 파일 변경
docs: <설명>        # 문서 업데이트
```
