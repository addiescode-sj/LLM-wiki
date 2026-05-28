# YouTube Video Ingest Guide

This guide explains how to submit a YouTube link to LLM Wiki and how to verify that the video ingest pipeline is working.

## Prerequisites

Install the optional video ingest dependencies once:

```bash
python3 -m pip install -r requirements-video.txt
```

OpenAI ASR fallback is optional. It is only needed when a video has no usable captions.

```bash
export OPENAI_API_KEY="..."
```

## Supported URL Formats

Always wrap YouTube URLs in quotes. YouTube URLs often contain `?`, `=`, and `&`, which shells can interpret incorrectly.

Do not add backslashes inside the quoted URL. Use `"https://youtu.be/VIDEO_ID?si=..."`, not `"https://youtu.be/VIDEO_ID\?si\=..."`.

```bash
# Standard watch URL
./scripts/ingest.sh --url "https://www.youtube.com/watch?v=aircAruvnKk"

# Short URL
./scripts/ingest.sh --url "https://youtu.be/aircAruvnKk"

# Shorts URL
./scripts/ingest.sh --url "https://www.youtube.com/shorts/VIDEO_ID"

# Embed URL
./scripts/ingest.sh --url "https://www.youtube.com/embed/VIDEO_ID"

# Live URL
./scripts/ingest.sh --url "https://www.youtube.com/live/VIDEO_ID"
```

## Quick Resolver Test

Use the resolver-only command when you want to test transcript extraction without changing `raw/` or `wiki/`.

```bash
scripts/resolve_youtube.py \
  --output-dir /tmp/llm-wiki-youtube-test \
  --print-path \
  "https://www.youtube.com/watch?v=aircAruvnKk"
```

Expected output:

```text
/tmp/llm-wiki-youtube-test/aircAruvnKk.md
```

Verify the generated files:

```bash
ls -la /tmp/llm-wiki-youtube-test
sed -n '1,80p' /tmp/llm-wiki-youtube-test/aircAruvnKk.md
head -3 /tmp/llm-wiki-youtube-test/aircAruvnKk.segments.jsonl
```

A successful resolver run creates:

```text
aircAruvnKk.md
aircAruvnKk.segments.jsonl
```

The Markdown source should include metadata like:

```md
- Transcript method: youtube-transcript-api
- Transcript language: ko
- Transcript generated: false
- Segment file: aircAruvnKk.segments.jsonl
```

## Full Wiki Ingest Test

After the resolver test passes, run the full ingest command:

```bash
./scripts/ingest.sh --url "https://www.youtube.com/watch?v=aircAruvnKk"
```

This command:

1. Extracts the YouTube video ID.
2. Resolves transcript evidence, preferring Korean captions and then English captions.
3. Creates `raw/videos/<video-id>.md`.
4. Creates `raw/videos/<video-id>.segments.jsonl`.
5. Computes the raw Markdown source SHA.
6. Calls the normal Ingest Agent to compile the source into `wiki/`.
7. Updates `wiki/index.md` and `wiki/log.md`.

Verify raw video outputs:

```bash
ls -la raw/videos
sed -n '1,80p' raw/videos/aircAruvnKk.md
head -3 raw/videos/aircAruvnKk.segments.jsonl
```

Run repository validation:

```bash
./scripts/lint.sh
./scripts/freshness.sh
```

## Troubleshooting

If Python modules are missing:

```text
youtube-transcript-api is not installed
openai Python package is not installed
```

Install dependencies:

```bash
python3 -m pip install -r requirements-video.txt
```

If ASR fallback is needed but no API key is set:

```text
OPENAI_API_KEY is not set for OpenAI ASR fallback
```

Set the key and retry:

```bash
export OPENAI_API_KEY="..."
./scripts/ingest.sh --url "https://www.youtube.com/watch?v=VIDEO_ID"
```

If YouTube returns `Video unavailable`, the video may be private, deleted, region-restricted, age-restricted, or temporarily inaccessible. Test with a public captioned video first.

If `yt-dlp` returns `HTTP Error 429: Too Many Requests`, YouTube is rate-limiting subtitle access from the current network/session. Retry later, test with a different public captioned video, or use OpenAI ASR fallback with `OPENAI_API_KEY` when the video is accessible but subtitles cannot be retrieved.

## Expected Source Priority

The resolver tries transcript sources in this order:

1. `youtube-transcript-api`
2. `yt-dlp` subtitles
3. OpenAI speech-to-text ASR

Manual captions are preferred over generated captions. Generated captions and ASR transcripts are preserved as source-derived evidence, but they should be treated as potentially noisy.
