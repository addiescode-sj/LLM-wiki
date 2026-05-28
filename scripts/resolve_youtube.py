#!/usr/bin/env python3
"""Resolve a YouTube URL into immutable raw video source files."""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


LANGUAGE_PREFERENCES = ("ko", "en")
OPENAI_MODEL = os.environ.get("LLM_WIKI_TRANSCRIBE_MODEL", "gpt-4o-mini-transcribe")
MAX_AUDIO_BYTES = int(os.environ.get("LLM_WIKI_TRANSCRIBE_MAX_BYTES", str(25 * 1024 * 1024)))


class ResolveError(RuntimeError):
    """Raised when a video cannot be resolved into a raw source."""


def utc_timestamp() -> str:
    return dt.datetime.now(dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def sanitize_url(url: str) -> str:
    return url.strip().replace("\\", "")


def extract_video_id(url: str) -> str:
    url = sanitize_url(url)
    parsed = urlparse(url)
    host = parsed.netloc.lower().removeprefix("www.")
    path_parts = [part for part in parsed.path.split("/") if part]

    if host == "youtu.be" and path_parts:
        return path_parts[0]

    if host.endswith("youtube.com") or host.endswith("youtube-nocookie.com"):
        query_id = parse_qs(parsed.query).get("v", [""])[0]
        if query_id:
            return query_id

        if len(path_parts) >= 2 and path_parts[0] in {"shorts", "embed", "live"}:
            return path_parts[1]

    raise ResolveError(f"Could not extract a YouTube video id from URL: {url}")


def canonical_youtube_url(video_id: str) -> str:
    return f"https://www.youtube.com/watch?v={video_id}"


def run_command(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise ResolveError(f"Required command not found: {args[0]}") from exc
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.strip() or exc.stdout.strip()
        raise ResolveError(f"Command failed: {' '.join(args)}\n{detail}") from exc


def load_metadata(url: str) -> dict[str, Any]:
    if shutil.which("yt-dlp") is None:
        return {}

    try:
        result = run_command(["yt-dlp", "--dump-single-json", "--skip-download", url])
        return json.loads(result.stdout)
    except (ResolveError, json.JSONDecodeError):
        return {}


def normalize_snippet(snippet: Any) -> dict[str, Any]:
    if isinstance(snippet, dict):
        text = snippet.get("text", "")
        start = snippet.get("start")
        duration = snippet.get("duration")
    else:
        text = getattr(snippet, "text", "")
        start = getattr(snippet, "start", None)
        duration = getattr(snippet, "duration", None)

    return {
        "start": start,
        "duration": duration,
        "text": html.unescape(str(text)).replace("\n", " ").strip(),
    }


def normalize_transcript_result(result: Any) -> list[dict[str, Any]]:
    snippets = getattr(result, "snippets", result)
    return [segment for segment in (normalize_snippet(item) for item in snippets) if segment["text"]]


def fetch_with_youtube_transcript_api(video_id: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError as exc:
        raise ResolveError("youtube-transcript-api is not installed") from exc

    try:
        api = YouTubeTranscriptApi()
        transcript_list = api.list(video_id)
    except AttributeError:
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)
    except TypeError:
        transcript_list = YouTubeTranscriptApi.list_transcripts(video_id)

    transcript = None
    transcript_kind = "unknown"

    for finder_name, kind in (
        ("find_manually_created_transcript", "manual"),
        ("find_generated_transcript", "generated"),
        ("find_transcript", "available"),
    ):
        finder = getattr(transcript_list, finder_name, None)
        if finder is None:
            continue
        try:
            transcript = finder(list(LANGUAGE_PREFERENCES))
            transcript_kind = kind
            break
        except Exception:
            continue

    if transcript is None:
        raise ResolveError("No Korean or English transcript found via youtube-transcript-api")

    fetched = transcript.fetch()
    segments = normalize_transcript_result(fetched)
    if not segments:
        raise ResolveError("youtube-transcript-api returned an empty transcript")

    metadata = {
        "method": "youtube-transcript-api",
        "language": getattr(transcript, "language_code", None),
        "language_name": getattr(transcript, "language", None),
        "is_generated": bool(getattr(transcript, "is_generated", transcript_kind == "generated")),
        "transcript_kind": transcript_kind,
    }
    return segments, metadata


def parse_vtt_timestamp(value: str) -> float:
    parts = value.replace(",", ".").split(":")
    seconds = float(parts[-1])
    minutes = int(parts[-2]) if len(parts) >= 2 else 0
    hours = int(parts[-3]) if len(parts) >= 3 else 0
    return hours * 3600 + minutes * 60 + seconds


def parse_vtt(path: Path) -> list[dict[str, Any]]:
    segments: list[dict[str, Any]] = []
    current_start: float | None = None
    current_end: float | None = None
    current_lines: list[str] = []

    def flush() -> None:
        nonlocal current_start, current_end, current_lines
        if current_start is None or not current_lines:
            current_start = None
            current_end = None
            current_lines = []
            return
        text = " ".join(current_lines)
        text = re.sub(r"<[^>]+>", "", text)
        text = re.sub(r"\s+", " ", html.unescape(text)).strip()
        if text:
            segments.append(
                {
                    "start": current_start,
                    "duration": None if current_end is None else max(0.0, current_end - current_start),
                    "text": text,
                }
            )
        current_start = None
        current_end = None
        current_lines = []

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line:
            flush()
            continue
        if line == "WEBVTT" or line.startswith(("Kind:", "Language:", "NOTE")):
            continue
        if "-->" in line:
            flush()
            start_text, end_text = [part.strip().split()[0] for part in line.split("-->", 1)]
            current_start = parse_vtt_timestamp(start_text)
            current_end = parse_vtt_timestamp(end_text)
            continue
        if current_start is not None and not line.isdigit():
            current_lines.append(line)

    flush()
    return segments


def fetch_with_ytdlp_subtitles(url: str, video_id: str, output_dir: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if shutil.which("yt-dlp") is None:
        raise ResolveError("yt-dlp is not installed")

    with tempfile.TemporaryDirectory(prefix="llm-wiki-ytdlp-") as temp_name:
        temp_dir = Path(temp_name)
        output_template = str(temp_dir / "%(id)s.%(ext)s")
        run_command(
            [
                "yt-dlp",
                "--skip-download",
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs",
                "ko.*,ko,en.*,en",
                "--sub-format",
                "vtt",
                "-o",
                output_template,
                url,
            ]
        )

        candidates = sorted(temp_dir.glob(f"{video_id}*.vtt"), key=subtitle_preference_score)
        if not candidates:
            raise ResolveError("yt-dlp did not produce Korean or English subtitle files")

        subtitle_path = candidates[0]
        segments = parse_vtt(subtitle_path)
        if not segments:
            raise ResolveError(f"Subtitle file was empty or unsupported: {subtitle_path.name}")

        preserved_path = output_dir / subtitle_path.name
        shutil.copy2(subtitle_path, preserved_path)

    language = "ko" if ".ko" in preserved_path.name else "en" if ".en" in preserved_path.name else None
    metadata = {
        "method": "yt-dlp-subtitles",
        "language": language,
        "language_name": language,
        "is_generated": "auto" in preserved_path.name,
        "transcript_kind": "subtitle",
        "preserved_subtitle": preserved_path.name,
    }
    return segments, metadata


def subtitle_preference_score(path: Path) -> tuple[int, str]:
    name = path.name
    if ".ko" in name:
        return (0, name)
    if ".en" in name:
        return (1, name)
    return (2, name)


def download_audio(url: str, video_id: str, temp_dir: Path) -> Path:
    if shutil.which("yt-dlp") is None:
        raise ResolveError("yt-dlp is required for OpenAI ASR fallback audio extraction")

    output_template = str(temp_dir / f"{video_id}.%(ext)s")
    run_command(["yt-dlp", "-f", "ba/bestaudio", "--no-playlist", "-o", output_template, url])

    candidates = [path for path in temp_dir.iterdir() if path.is_file() and path.stem == video_id]
    if not candidates:
        raise ResolveError("yt-dlp did not produce an audio file for ASR fallback")
    return candidates[0]


def fetch_with_openai_asr(url: str, video_id: str, metadata: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if not os.environ.get("OPENAI_API_KEY"):
        raise ResolveError("OPENAI_API_KEY is not set for OpenAI ASR fallback")

    try:
        from openai import OpenAI
    except ImportError as exc:
        raise ResolveError("openai Python package is not installed") from exc

    with tempfile.TemporaryDirectory(prefix="llm-wiki-audio-") as temp_name:
        audio_path = download_audio(url, video_id, Path(temp_name))
        audio_size = audio_path.stat().st_size
        if audio_size > MAX_AUDIO_BYTES:
            raise ResolveError(
                f"Audio file is {audio_size} bytes, above LLM_WIKI_TRANSCRIBE_MAX_BYTES={MAX_AUDIO_BYTES}"
            )

        prompt_parts = [
            "This is a transcript for an LLM Wiki raw source.",
            "Prefer Korean terms when the source is Korean and preserve technical terms.",
        ]
        if metadata.get("title"):
            prompt_parts.append(f"Video title: {metadata['title']}")

        client = OpenAI()
        with audio_path.open("rb") as audio_file:
            transcription = client.audio.transcriptions.create(
                model=OPENAI_MODEL,
                file=audio_file,
                response_format="text",
                prompt=" ".join(prompt_parts),
            )

    text = str(transcription).strip()
    if not text:
        raise ResolveError("OpenAI ASR returned an empty transcript")

    segments = [{"start": None, "duration": None, "text": text}]
    return segments, {
        "method": "openai-asr",
        "language": None,
        "language_name": None,
        "is_generated": True,
        "transcript_kind": "asr",
        "asr_model": OPENAI_MODEL,
    }


def resolve_transcript(
    url: str, video_id: str, output_dir: Path, video_metadata: dict[str, Any]
) -> tuple[list[dict[str, Any]], dict[str, Any], list[str]]:
    attempts: list[str] = []

    resolvers = (
        ("youtube-transcript-api", lambda: fetch_with_youtube_transcript_api(video_id)),
        ("yt-dlp-subtitles", lambda: fetch_with_ytdlp_subtitles(url, video_id, output_dir)),
        ("openai-asr", lambda: fetch_with_openai_asr(url, video_id, video_metadata)),
    )

    for resolver_name, resolver in resolvers:
        try:
            segments, transcript_metadata = resolver()
            return segments, transcript_metadata, attempts
        except Exception as exc:
            attempts.append(f"{resolver_name}: {type(exc).__name__}: {exc}")

    raise ResolveError("All transcript resolvers failed:\n- " + "\n- ".join(attempts))


def write_jsonl(path: Path, video_id: str, segments: list[dict[str, Any]], transcript_metadata: dict[str, Any]) -> None:
    temp_path = path.with_suffix(path.suffix + ".tmp")
    with temp_path.open("w", encoding="utf-8") as handle:
        for index, segment in enumerate(segments, start=1):
            payload = {
                "video_id": video_id,
                "index": index,
                "start": segment.get("start"),
                "duration": segment.get("duration"),
                "text": segment.get("text"),
                "language": transcript_metadata.get("language"),
                "source": transcript_metadata.get("method"),
                "is_generated": transcript_metadata.get("is_generated"),
            }
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    temp_path.replace(path)


def format_duration(seconds: Any) -> str:
    if seconds is None:
        return "unknown"
    try:
        total = int(float(seconds))
    except (TypeError, ValueError):
        return str(seconds)
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def write_markdown(
    path: Path,
    url: str,
    submitted_url: str,
    video_id: str,
    segments_path: Path,
    segments: list[dict[str, Any]],
    video_metadata: dict[str, Any],
    transcript_metadata: dict[str, Any],
    attempts: list[str],
) -> None:
    title = video_metadata.get("title") or f"YouTube video {video_id}"
    uploader = video_metadata.get("uploader") or video_metadata.get("channel") or "unknown"
    upload_date = video_metadata.get("upload_date") or "unknown"
    duration = format_duration(video_metadata.get("duration"))
    extracted_at = utc_timestamp()
    transcript_text = "\n\n".join(segment["text"] for segment in segments if segment.get("text"))
    preserved_subtitle = transcript_metadata.get("preserved_subtitle")

    lines = [
        f"# [RAW SOURCE] {title}",
        "",
        "> This file is an immutable raw source for LLM Wiki.",
        f"> Source: {url}",
        f"> Video ID: {video_id}",
        f"> Extracted at: {extracted_at}",
        "",
        "## Metadata",
        "",
        f"- URL: {url}",
    ]

    cleaned_submitted_url = sanitize_url(submitted_url)
    if cleaned_submitted_url != url:
        lines.append(f"- Submitted URL: {cleaned_submitted_url}")

    lines.extend(
        [
            f"- Title: {title}",
            f"- Uploader: {uploader}",
            f"- Upload date: {upload_date}",
            f"- Duration: {duration}",
            f"- Transcript method: {transcript_metadata.get('method')}",
            f"- Transcript language: {transcript_metadata.get('language') or 'unknown'}",
            f"- Transcript generated: {str(bool(transcript_metadata.get('is_generated'))).lower()}",
            f"- Segment file: {segments_path.name}",
        ]
    )

    if transcript_metadata.get("asr_model"):
        lines.append(f"- ASR model: {transcript_metadata['asr_model']}")
    if preserved_subtitle:
        lines.append(f"- Preserved subtitle: {preserved_subtitle}")
    if attempts:
        lines.append(f"- Resolver fallbacks: {' | '.join(attempts)}")

    lines.extend(
        [
            "",
            "## Transcript Quality Notes",
            "",
            "- Manual captions are preferred over generated captions when available.",
            "- Generated captions or ASR transcripts should be treated as source-derived but potentially noisy.",
            "- The JSONL segment file preserves timestamp data when the source resolver provides it.",
            "",
            "## Transcript",
            "",
            transcript_text,
            "",
        ]
    )

    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text("\n".join(lines), encoding="utf-8")
    temp_path.replace(path)


def resolve_youtube(url: str, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    video_id = extract_video_id(url)
    canonical_url = canonical_youtube_url(video_id)
    video_metadata = load_metadata(canonical_url)
    segments, transcript_metadata, attempts = resolve_transcript(canonical_url, video_id, output_dir, video_metadata)

    markdown_path = output_dir / f"{video_id}.md"
    segments_path = output_dir / f"{video_id}.segments.jsonl"

    write_jsonl(segments_path, video_id, segments, transcript_metadata)
    write_markdown(
        markdown_path,
        canonical_url,
        url,
        video_id,
        segments_path,
        segments,
        video_metadata,
        transcript_metadata,
        attempts,
    )
    return markdown_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve a YouTube URL into raw Markdown and JSONL files.")
    parser.add_argument("url", nargs="?", help="YouTube URL to resolve.")
    parser.add_argument("--output-dir", default="raw/videos", help="Directory for generated raw video files.")
    parser.add_argument("--print-path", action="store_true", help="Print the generated Markdown path.")
    parser.add_argument("--print-video-id", metavar="URL", help="Print the parsed YouTube video id and exit.")
    args = parser.parse_args()

    try:
        if args.print_video_id:
            print(extract_video_id(args.print_video_id))
            return 0
        if not args.url:
            parser.error("url is required unless --print-video-id is used")

        markdown_path = resolve_youtube(args.url, Path(args.output_dir))
        if args.print_path:
            print(markdown_path)
        return 0
    except ResolveError as exc:
        print(f"resolve_youtube.py: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
