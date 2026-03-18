"""
YouTube Transcript Fetcher
Requires: pip install youtube-transcript-api
"""

import re
from youtube_transcript_api import YouTubeTranscriptApi, NoTranscriptFound, TranscriptsDisabled
from youtube_transcript_api._errors import VideoUnavailable


def get_youtube_transcript(url: str) -> str:
    """
    Fetches the full transcript of a YouTube video as plain text.

    Compatible with both legacy (<0.6.0) and newer (>=0.6.0) versions
    of youtube-transcript-api.

    Args:
        url: A YouTube video URL (supports standard, shortened, and embed formats).

    Returns:
        The full transcript as a single plain-text string.

    Raises:
        ValueError: If the URL is invalid or no video ID can be extracted.
        RuntimeError: If no transcript is available for the video.
    """
    video_id = _extract_video_id(url)
    if not video_id:
        raise ValueError(f"Could not extract a valid YouTube video ID from URL: {url}")

    try:
        # Works for youtube-transcript-api >= 0.6.0
        ytt = YouTubeTranscriptApi()
        transcript_segments = ytt.fetch(video_id)
    except AttributeError:
        # Fallback for older versions
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
    """
    Extracts the YouTube video ID from various URL formats:
      - https://www.youtube.com/watch?v=VIDEO_ID
      - https://youtu.be/VIDEO_ID
      - https://www.youtube.com/embed/VIDEO_ID
      - https://www.youtube.com/shorts/VIDEO_ID
    """
    patterns = [
        r"(?:v=)([0-9A-Za-z_-]{11})",       # standard ?v=
        r"(?:youtu\.be/)([0-9A-Za-z_-]{11})", # shortened
        r"(?:embed/)([0-9A-Za-z_-]{11})",      # embed
        r"(?:shorts/)([0-9A-Za-z_-]{11})",     # shorts
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


# --- Example usage ---
if __name__ == "__main__":
    test_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    try:
        transcript = get_youtube_transcript(test_url)
        print(transcript)
    except (ValueError, RuntimeError) as e:
        print(f"Error: {e}")