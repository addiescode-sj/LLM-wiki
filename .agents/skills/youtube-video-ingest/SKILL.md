---
name: youtube-video-ingest
description: Use this when ingesting YouTube or lecture video URLs into LLM Wiki. Resolve transcript evidence into raw/videos, create a context-optimized digest, then synthesize wiki pages from the digest while citing raw sources. Do not use for ordinary web articles or local Markdown files.
---

# YouTube Video Ingest

Use this workflow for YouTube URLs that should become LLM Wiki source material.

## Orchestration

1. Resolve Agent: convert the video URL into immutable raw files.
2. Digest Agent: compact the transcript into `intermediate/videos/<video-id>.digest.md`.
3. Wiki Compiler Agent: synthesize the digest into `wiki/` according to `CLAUDE.md` and `AGENTS.md`.

Preferred command:

```bash
./scripts/ingest.sh --url "https://www.youtube.com/watch?v=VIDEO_ID"
```

Resolver-only command for troubleshooting:

```bash
./scripts/resolve_youtube.py --print-path "https://www.youtube.com/watch?v=VIDEO_ID"
```

Install the optional video ingest dependencies with:

```bash
python3 -m pip install -r requirements-video.txt
```

## Source Rules

- Never compact by editing `raw/videos/*`.
- Store the human-readable raw source as `raw/videos/<video-id>.md`.
- Store timestamped transcript segments as `raw/videos/<video-id>.segments.jsonl`.
- Preserve original VTT/SRT subtitle files only when `yt-dlp` produced them.
- Treat `*.segments.jsonl` as timestamp evidence.
- Treat `intermediate/videos/*.digest.md` as a generated optimization artifact, not a source of truth.
- Keep wiki frontmatter `sources.path` pointed at `raw/videos/<video-id>.md`.
- If digest generation fails, stop before wiki synthesis.

## Transcript Resolution

The resolver supports these tools opportunistically:

- `youtube-transcript-api` for the first transcript attempt.
- `yt-dlp` for metadata and subtitle fallback.
- `openai` Python package plus `OPENAI_API_KEY` for ASR fallback.

Prefer Korean captions, then English captions. Manual captions are preferred over generated captions.

## Digest Contract

Generate `intermediate/videos/<video-id>.digest.md` before wiki compile when a transcript is non-trivial.

The digest must use this structure:

```md
# Video Digest: <title>

## Source
- raw: raw/videos/<id>.md
- segments: raw/videos/<id>.segments.jsonl
- transcript_quality: generated | manual
- language: ko | en

## Executive Summary
- 3-5 bullets.

## Key Claims
- Claim with segment range.

## Metrics
| Metric | Value | Segment range | Note |
|---|---:|---|---|

## Workflow / Recommendations
1. Actionable step.

## Concepts To Merge Into Wiki
- Suggested wiki slug and relationship.

## Removed Noise
- CTA
- repeated intro
- sponsor/ad
- rhetorical repetition

## Verification Notes
- Caption quality issues.
- Claims needing external verification.
```

## Digest Optimization Rules

Remove:

- greetings, subscribe/comment calls, sponsor mentions, and ending CTAs.
- repeated framing such as "today's video" or repeated summaries.
- rhetorical filler and duplicated emphasis.
- long analogies after extracting the underlying lesson.

Preserve:

- definitions, claims, metrics, workflow steps, commands, and cost/token estimates.
- segment indexes or timestamp ranges for source-backed claims.
- uncertainty markers for generated captions or likely transcription errors.

## Wiki Compile Rules

- Compile wiki pages from the digest for context efficiency.
- Cite raw source paths and raw line or segment references.
- Do not cite the digest as the authoritative source.
- Preserve existing wiki content and merge only source-backed updates.
- Follow all YAML frontmatter rules from `CLAUDE.md`.

If all transcript resolvers fail, do not create a wiki page. Report the missing tool, unavailable transcript, authorization issue, or audio size limit from the resolver output.
