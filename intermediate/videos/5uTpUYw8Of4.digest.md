# Video Digest: AI 토큰 84% 절감 LLM Wiki 패턴, Karpathy가 제안한 컨텍스트 관리법

## Source
- raw: raw/videos/5uTpUYw8Of4.md
- segments: raw/videos/5uTpUYw8Of4.segments.jsonl
- transcript_quality: generated
- language: ko

## Executive Summary
- Andrej Karpathy's "LLM Wiki" pattern restructures knowledge at ingest-time (not query-time), so an AI references a pre-compiled wiki instead of re-reading raw documents on every query.
- A reference implementation reports loading-context drop from 47,000 → 7,700 tokens per session (~84%) and per-query research tokens from ~8,000 → 600 (~84%).
- Architecture is three layers: raw source corpus → wiki layer (AI-summarized topical notes) → schema layer (rules/index, analogous to a `CLAUDE.md`).
- Lifecycle has three loops: Ingest (one new doc typically updates 10–15 wiki pages), Query (good Q&A is written back — "knowledge consolidation"), and Lint (periodic consistency/freshness/orphan-link checks).
- Same-day tactics for Claude Code users without the plugin: `/compact`, `/clear`, and keeping `CLAUDE.md` at 200–500 lines.

## Key Claims
- 383 markdown files (~13.1 MB) compressed to 13 wiki articles — claimed 81× compression. (segments 1, 151–154)
- 130 meeting transcripts totaling 122,625 lines compressed to one 244-line summary — claimed 503× compression. (segments 156–160)
- Session loading context drops 47,000 → 7,700 tokens, ~84% reduction. (segments 167–169)
- Per-query research tokens drop ~8,000 → 600, ~84% reduction. Transcript says "8,개" which is likely "8,000" (ASR noise). (segments 170–172) [UNVERIFIED — needs source confirmation]
- One ingested document typically affects 10–15 wiki pages. (segment 187)
- Initial compile cost ≈ $0.60–$13 per run (≈₩3,500–₩8,000). (segments 254–257) [transcript says "이 달러 60에서 13달러"; "0.60" inferred from context]
- Incremental cost per new doc ≈ $0.30–$1.50 (≈₩400–₩2,000). (segments 258–261)
- Break-even is the first session, since wiki saves 47,000 − 7,700 tokens immediately. (segments 263–267)
- Karpathy framed the wiki as "knowledge kept in a compiled state" so it does not have to be re-extracted each time. (segments 137–141)
- Karpathy is described as former Tesla AI director and OpenAI founding member. (segments 7–8, 107–112) [externally verifiable]

## Metrics
| Metric | Value | Segment range | Note |
|---|---:|---|---|
| Markdown files compressed | 383 → 13 articles | 1, 151–154 | "81× compression" claim |
| Source corpus size | 13.1 MB | 152 | Transcript redundantly says "13.1MB의 1MB" — ASR noise |
| Meeting transcript lines | 122,625 → 244 | 156–160 | "503× compression" claim |
| Session loading context | 47,000 → 7,700 tokens | 167–169 | ~84% reduction |
| Per-query research tokens | ~8,000 → 600 | 170–172 | "8,개" likely "8,000" [UNVERIFIED] |
| Wiki pages touched per ingest | 10–15 | 187 | |
| Initial compile cost | $0.60–$13 | 254–257 | ≈₩3,500–₩8,000 |
| Incremental cost / new doc | $0.30–$1.50 | 258–261 | ≈₩400–₩2,000 |
| Recommended CLAUDE.md length | 200–500 lines | 235–238 | |
| Video duration | 10:59 | raw metadata | |

## Workflow / Recommendations
1. Treat raw documents as immutable source; build a compiled wiki layer on top.
2. Define a schema layer (rules + index) — a `CLAUDE.md`-style file — that governs wiki structure.
3. Ingest loop: on a new document, extract key facts and update only the affected wiki pages (typically 10–15), instead of regenerating the whole wiki.
4. Query loop: write strong Q&A answers back into the wiki so knowledge consolidates over time.
5. Lint loop: schedule periodic checks for contradictions, stale info, and orphan links.
6. Same-day Claude Code hygiene (no plugin required):
   - Use `/compact` when conversation context fills up.
   - Use `/clear` on topic changes to drop stale context.
   - Keep `CLAUDE.md` between 200–500 lines, rules only.
7. For full pattern: install the "LLM Wiki Compiler" plugin (per video, distributed via GitHub) to auto-compile project docs into a wiki Claude Code consults instead of the raw docs. [UNVERIFIED — plugin name and distribution not cross-checked]

## Concepts To Merge Into Wiki
- `llm-wiki-pattern` — core 3-layer pattern (raw / wiki / schema); already exists in `wiki/`. Add cited metrics and the three-loop lifecycle.
- `ingest-time-compilation` (new) — concept page for "knowledge kept compiled" framing; link from `llm-wiki-pattern`.
- `context-management-claude-code` (new or existing) — actionable tactics: `/compact`, `/clear`, `CLAUDE.md` length budget.
- `wiki-lifecycle-loops` (new) — Ingest / Query / Lint loops with the 10–15-page fan-out rule.
- `token-cost-benchmarks` (new) — table of compression ratios and $/₩ costs from this video for future comparison.
- `karpathy-references` (new or existing) — collect Karpathy-sourced ideas; link source URL.

## Removed Noise
- CTA ("댓글로 알려주세요", "영상을 끝까지 보시면")
- Repeated intro hooks ("이게 말이 됩니까? 되더라고요")
- Sponsor/ad block for "핑크닷" / "핑거" video tool (segments ~92–104)
- Rhetorical analogies retained only where they aid comprehension (amnesiac new-hire metaphor compressed; "소 잃고 외양간" idiom dropped)
- Closing recap that duplicates Executive Summary
- Filler ("자, 그러면", "기가 막히죠", "이쯤 되면")

## Verification Notes
- Transcript is auto-generated Korean (`is_generated: true`); numeric tokens are the most error-prone parts.
  - "총 13.1MB의 1MB의 문서가" — duplicated unit, likely just 13.1 MB.
  - "8,개에서 600개로" — almost certainly "8,000 → 600" given the stated 84% ratio.
  - "이 달러 60에서 13달러" — read as "$0.60–$13" based on KRW range that follows.
  - "30에서 1달러 50c 하나로" — read as "$0.30–$1.50".
- Compression ratios (81×, 503×) and 84% reduction figures come from a single unnamed "developer's plugin"; treat as illustrative until the underlying repo/article is cited. [UNVERIFIED]
- Karpathy's exact wording ("compiled knowledge") is paraphrased by the narrator; the original Karpathy source URL is not provided in the transcript and should be located before quoting.
- Plugin install instructions ("깃업에서 다운로드") are vague; the actual repo URL is not in the transcript.
- Upload date in raw metadata is `20260409` — verify whether this is a real future date or a typo before citing chronology.
