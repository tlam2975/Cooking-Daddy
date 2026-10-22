"""YouTube transcript fetching. Used by main.py's /api/generate-from-url route."""

import re

_LANGUAGES = ['vi', 'en']


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
        # The library defaults to English only; many cooking videos here have
        # Vietnamese captions alone.
        transcript_segments = ytt.fetch(video_id, languages=_LANGUAGES)
    except AttributeError:
        transcript_segments = YouTubeTranscriptApi.get_transcript(
            video_id, languages=_LANGUAGES
        )
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
    from urllib.parse import urlsplit, parse_qs
    if not isinstance(url, str) or len(url) > 2048:
        return None
    try:
        parsed = urlsplit(url.strip())
        if parsed.scheme not in ('http', 'https') or parsed.username or parsed.password or parsed.port:
            return None
        host = (parsed.hostname or '').lower()
        if host in ('youtu.be', 'www.youtu.be'):
            candidate = parsed.path.strip('/')
        elif host in ('youtube.com', 'www.youtube.com', 'm.youtube.com'):
            if parsed.path == '/watch':
                values = parse_qs(parsed.query).get('v', [])
                candidate = values[0] if len(values) == 1 else ''
            else:
                match = re.fullmatch(r'/(?:embed|shorts)/([0-9A-Za-z_-]{11})/?', parsed.path)
                candidate = match.group(1) if match else ''
        else:
            return None
        return candidate if re.fullmatch(r'[0-9A-Za-z_-]{11}', candidate) else None
    except (ValueError, TypeError):
        return None


def canonical_youtube_url(url):
    video_id = _extract_video_id(url)
    if not video_id:
        raise ValueError('Unsupported YouTube URL')
    return f'https://www.youtube.com/watch?v={video_id}'


def youtube_thumbnail(url):
    video_id = _extract_video_id(url)
    if not video_id:
        raise ValueError('Unsupported YouTube URL')
    return f'https://i.ytimg.com/vi/{video_id}/hqdefault.jpg'
