# AGENTS.md — 에이전트 행동 명세

LLM Wiki에서 구동되는 에이전트의 **역할, 진입점, 호출 방법**을 정의합니다.

---

## 에이전트 역할 분류

| 에이전트 | 역할 | 진입 스크립트 |
|---------|------|-------------|
| **Ingest Agent** | 원천 소스 → 위키 컴파일 | `scripts/ingest.sh` |
| **Query Agent** | 위키 기반 질의응답 | `scripts/query.sh` |
| **Lint Agent** | 품질 감사 및 고아 링크 수정 | `scripts/lint.sh` |
| **Freshness Agent** | 코드-위키 SHA 정합성 검증 | `scripts/freshness.sh` |

---

## 1. Ingest Agent

### 호출 방법
```bash
# 단일 파일 인입
./scripts/ingest.sh raw/articles/my-article.md

# 전체 inbox 일괄 인입
./scripts/ingest.sh --all-inbox

# URL에서 직접 인입 (YouTube, 웹 아티클)
./scripts/ingest.sh --url "https://..."
```

### 처리 순서
1. 입력 파일을 `/raw/` 적절한 서브폴더에 저장 (불변 보관)
2. `wiki/index.md` 스키마 인덱스 읽기
3. 연관 위키 페이지 슬러그 추출
4. 대상 페이지만 선택적 업데이트 (Synthesize)
5. `wiki/log.md` 트랜잭션 기록
6. `wiki/index.md` 한 줄 요약 갱신

### 금지 사항
- `/raw` 내용 변경
- 기존 위키 내용 삭제
- 출처 없는 내용 추가

---

## 2. Query Agent

### 호출 방법
```bash
# 기본 질의
./scripts/query.sh "React 서버 컴포넌트와 클라이언트 컴포넌트의 차이는?"

# 질의 결과를 새 wiki 페이지로 저장 (Compounding Loop)
./scripts/query.sh --save "Transformer attention 메커니즘 설명해줘"
```

### 처리 순서
1. `wiki/index.md` + 프론트매터 고속 스캔
2. 코사인 유사도로 상위 관련 페이지 필터링
3. 선택된 페이지 본문 로드 → 답변 생성
4. `--save` 플래그 시: 답변을 `/wiki/` 신규 페이지로 인입

---

## 3. Lint Agent

### 호출 방법
```bash
# 전체 위키 감사
./scripts/lint.sh

# 특정 폴더만
./scripts/lint.sh wiki/

# 자동 수정 모드
./scripts/lint.sh --fix
```

### 감사 항목
- [ ] 고아 링크 (`[[존재하지 않는 슬러그]]`)
- [ ] YAML 프론트매터 누락 또는 불완전
- [ ] `sources` 경로가 실제 파일과 불일치
- [ ] `status: outdated` 문서 목록 리포트
- [ ] `[CONFLICT]` 또는 `[UNVERIFIED]` 태그 잔존

---

## 4. Freshness Agent

### 호출 방법
```bash
# SHA 정합성 전체 검사
./scripts/freshness.sh

# 특정 소스 파일 검사
./scripts/freshness.sh src/auth/session.ts
```

### 처리 순서
1. `/wiki/` 전체 파일의 `sources[].sha` 추출
2. 현재 파일의 실제 SHA와 비교
3. 불일치 발견 시 → `status: outdated` 표시
4. 재컴파일 필요 목록 출력

---

## Claude Code 연동

```bash
# Claude Code로 ingest 실행
claude "raw/articles/my-article.md 파일을 CLAUDE.md 규칙에 따라 위키로 컴파일해줘"

# Claude Code로 질의
claude "wiki/ 폴더를 기반으로 LLM attention mechanism을 설명해줘"

# Claude Code로 lint
claude "wiki/ 폴더 전체를 감사하고 고아 링크와 YAML 오류를 수정해줘"
```

---

## 팀 공유 워크플로우

```
개인 브랜치 (addie/personal)
    │
    ├── ingest 실행 → wiki/ 업데이트
    ├── lint 통과 확인
    │
    ▼
git push origin addie/personal
    │
    ▼
GitHub PR → main
    │
    ├── PR 템플릿 작성
    ├── lint CI 통과
    └── 팀원 리뷰 1명 이상
    │
    ▼
main 병합 → 팀 공유 지식
```
