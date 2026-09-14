"""YouTube transcript fetching. Used by main.py's /api/generate-from-url route."""

import re


def get_youtube_transcript(url: str) -> str:
    from youtube_transcript_api import (
        NoTranscriptFound,
        TranscriptsDisabled,
        YouTubeTranscriptApi,
    )
    from youtube_transcript_api._errors import VideoUnavailable

    video_id = _extract_video_id(url)
    if not video_id:
        raise ValueError(f"Could not extract a valid YouTube video ID from URL: {url}")

    try:
        ytt = YouTubeTranscriptApi()
        transcript_segments = ytt.fetch(video_id)
    except AttributeError:
        transcript_segments = YouTubeTranscriptApi.get_transcript(video_id)
    except TranscriptsDisabled:
        raise RuntimeError(f"Transcripts are disabled for video: {video_id}")
    except NoTranscriptFound:
        raise RuntimeError(f"No transcript found for video: {video_id}")
    except VideoUnavailable:
        raise RuntimeError(f"Video is unavailable: {video_id}")

    full_text = " ".join(
        segment.text if hasattr(segment, "text") else segment["text"]
        for segment in transcript_segments
    )
    return full_text


def _extract_video_id(url: str) -> str | None:
    patterns = [
        r"(?:v=)([0-9A-Za-z_-]{11})",
        r"(?:youtu\.be/)([0-9A-Za-z_-]{11})",
        r"(?:embed/)([0-9A-Za-z_-]{11})",
        r"(?:shorts/)([0-9A-Za-z_-]{11})",
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None
