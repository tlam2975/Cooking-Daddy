"""YouTube transcript fetching. Used by main.py's /api/generate-from-url route."""

import os
import re

_LANGUAGES = ['vi', 'en']
# A cooking video rarely needs more than this; longer transcripts only add
# token cost and push the request past the function timeout.
_MAX_TRANSCRIPT_CHARS = 30000


def get_youtube_transcript(url: str) -> str:
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api.proxies import GenericProxyConfig

    video_id = _extract_video_id(url)
    if not video_id:
        raise ValueError(f"Could not extract a valid YouTube video ID from URL: {url}")

    # YouTube often rejects datacenter IPs (e.g. Vercel); a proxy is the
    # supported workaround, so allow one to be configured per deployment.
    proxy = os.getenv('YOUTUBE_PROXY_URL')
    proxy_config = GenericProxyConfig(http_url=proxy, https_url=proxy) if proxy else None
    # The library defaults to English only; many cooking videos here have
    # Vietnamese captions alone.
    segments = YouTubeTranscriptApi(proxy_config=proxy_config).fetch(video_id, languages=_LANGUAGES)
    return " ".join(segment.text for segment in segments)[:_MAX_TRANSCRIPT_CHARS]


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
