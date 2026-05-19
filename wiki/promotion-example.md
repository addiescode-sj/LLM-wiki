---
title: "지식 격상 워크플로우 예시"
summary: "개인 브랜치에서 팀 공유 브랜치로 지식을 격상하는 전체 흐름 예시"
tags: [workflow, knowledge-management, example, onboarding]
type: reference
created: 2026-05-19T00:00:00+09:00
last_updated: 2026-05-19T00:00:00+09:00
sources:
  - path: "raw/articles/llm-wiki-karpathy.md"
    sha: "gdoc-1k8Qh-irUsybmZIHit1MBAnysHsfzPP2TAmAcT3JJhcM"
related:
  - "[[llm-wiki-pattern]]"
  - "[[index]]"
status: stable
---

# 지식 격상 워크플로우 예시

개인 브랜치에서 지식을 쌓고 팀 브랜치로 격상하는 전체 흐름을 실제 시나리오로 설명한다.

---

## 시나리오

> Addie가 Redis 캐싱 전략을 조사하다가 팀 전체에 공유할 만한 내용을 정리했다.

---

## Step 1. 개인 브랜치 생성 및 전환

```bash
cd /Users/addie.lee/work/LLM-wiki

# 개인 브랜치 생성 (최초 1회)
git checkout -b personal/addie
git push -u origin personal/addie
```

---

## Step 2. 원천 소스 추가

조사한 내용을 `raw/articles/`에 마크다운 파일로 저장한다.

```bash
# 조사 내용을 raw/ 에 파일로 생성
cat > raw/articles/redis-caching-strategy.md << 'EOF'
# [RAW SOURCE] Redis 캐싱 전략 조사

> 출처: 내부 조사 + Redis 공식 문서
> 작성자: Addie
> 작성일: 2026-05-19

## Look-aside (Cache-aside) 패턴
- 캐시 미스 시 앱이 직접 DB 조회 후 캐시 저장
- 장점: 캐시 장애 시 DB로 폴백 가능
- 단점: Cold start 시 DB 부하

## Write-through 패턴
- 모든 쓰기를 캐시와 DB에 동시에
- 장점: 캐시 항상 최신
- 단점: 쓰기 지연 증가

## 우리 서비스 적용 기준
- 조회 빈도 높고 변경 낮은 데이터 → Look-aside
- 실시간성이 중요한 데이터 → Write-through
EOF

# 커밋 → post-commit 훅이 백그라운드에서 wiki/ 자동 컴파일
git add raw/articles/redis-caching-strategy.md
git commit -m "raw: add redis caching strategy research"
```

**자동으로 일어나는 일:**

```
[LLM Wiki] raw/ 변경 감지 → 백그라운드 인입 시작...
[LLM Wiki] 로그: /tmp/llm-wiki-async-ingest.log

# Claude Code가 백그라운드에서:
# 1. wiki/index.md 스캔 → 연관 페이지 확인
# 2. wiki/redis-caching-strategy.md 신규 생성
# 3. wiki/index.md에 한 줄 추가
# 4. wiki/log.md에 트랜잭션 기록
```

---

## Step 3. 개인 브랜치에서 검색/활용

개인 브랜치 상태에서 지식을 검색하고 활용한다.

```bash
# 위키에서 질의
./scripts/query.sh "Redis 캐싱 패턴 중 우리 서비스에 맞는 건?"

# 답변을 새 위키 페이지로 저장 (Compounding Loop)
./scripts/query.sh --save "Look-aside vs Write-through 비교"
```

이 시점에서 `wiki/redis-caching-strategy.md`와 파생 페이지들은
**내 개인 브랜치에만 존재**한다.

---

## Step 4. 격상 여부 판단

아래 질문에 답해본다:

- [ ] 팀원들이 반복해서 검색할 내용인가? → **Yes** (캐싱 전략은 공통 관심사)
- [ ] 검증된 내용인가? → **Yes** (실제 서비스 적용 기준 포함)
- [ ] lint를 통과하는가?

```bash
./scripts/lint.sh
# → 오류 0개 확인
```

→ **격상 결정.**

---

## Step 5. PR 생성

```bash
# 개인 브랜치 push
git push origin personal/addie

# GitHub에서 PR 오픈: personal/addie → main
```

PR 제목 예시:
```
[wiki] Redis 캐싱 전략 (Look-aside vs Write-through)
```

PR 본문은 `.github/PULL_REQUEST_TEMPLATE.md` 체크리스트를 채운다:

```
## 변경 요약
- [x] 새 wiki 페이지: wiki/redis-caching-strategy.md
- [x] 원천 소스: raw/articles/redis-caching-strategy.md

## Lint 체크리스트
오류: 0개, 경고: 0개

- [x] lint 통과
- [x] YAML 프론트매터 완비
- [x] index.md 업데이트됨
- [x] log.md 기록됨
- [x] sources.sha 기록됨
```

---

## Step 6. 팀 리뷰 & Merge

리뷰어가 확인할 내용:
- 내용이 팀 서비스에 실제로 관련 있는가?
- 기존 위키 내용과 충돌하지 않는가?
- 고아 wikilink는 없는가?

승인 후 **Squash Merge** → `main`에 반영.

---

## Step 7. 팀 전체 접근 가능

```bash
# 다른 팀원이 main 브랜치 pull
git checkout main
git pull origin main

# 이제 Redis 캐싱 지식 검색 가능
./scripts/query.sh "Redis 캐싱 전략"
```

---

## 전체 흐름 요약

```
개인 브랜치 (personal/addie)
  │
  ├── raw/articles/redis-caching-strategy.md  ← 원천 소스 추가
  │         ↓ (post-commit 훅 자동 실행)
  ├── wiki/redis-caching-strategy.md          ← AI가 컴파일
  │
  ├── lint 통과 확인
  │
  └── PR: personal/addie → main
                │
                ↓ (팀 리뷰 + 승인)
           main 브랜치
                │
                └── 팀 전체 접근 가능 ✅
```

---

## 관련 개념

- [[llm-wiki-pattern]] — LLM Wiki 전체 아키텍처
- [[index]] — 위키 마스터 인덱스
