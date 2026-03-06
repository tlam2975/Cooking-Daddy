import re
import logging
import requests
from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import (
    TranscriptsDisabled, 
    NoTranscriptFound, 
    VideoUnavailable
)
from fastapi import HTTPException

logger = logging.getLogger(__name__)

class YouTubeService:
    """YouTube service for extracting video metadata and transcripts"""
    
    def extract_video_id(self, url: str) -> str:
        """Extract video ID from YouTube URL"""
        patterns = [
            r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\n?#]+)',
            r'youtube\.com\/embed\/([^&\n?#]+)',
            r'youtube\.com\/v\/([^&\n?#]+)',
            r'youtube\.com\/shorts\/([^&\n?#]+)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        
        raise ValueError("Invalid YouTube URL")
    
    def get_video_metadata(self, url: str) -> dict:
        """Get video metadata using YouTube oEmbed API"""
        try:
            video_id = self.extract_video_id(url)
            
            oembed_url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={video_id}&format=json"
            
            response = requests.get(oembed_url, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            return {
                'id': video_id,
                'title': data.get('title', 'Unknown Title'),
                'thumbnail': data.get('thumbnail_url', ''),
                'uploader': data.get('author_name', 'Unknown'),
                'uploader_url': data.get('author_url', ''),
            }
            
        except Exception as e:
            logger.error(f"Error getting metadata: {e}")
            raise Exception(f"Could not get video metadata: {str(e)}")
    
    def _merge_transcript_segments(self, raw_segments: list, max_duration: float = 15.0) -> list:
        """Merge small transcript segments into complete sentences"""
        if not raw_segments:
            return []
        
        merged = []
        current_sentence = {'texts': [], 'start': None, 'end': None}
        sentence_enders = {'.', '!', '?'}
        
        for segment in raw_segments:
            text = segment.get('text', '').strip()
            if not text:
                continue
            
            if current_sentence['start'] is None:
                current_sentence['start'] = segment.get('start', 0)
            
            current_sentence['texts'].append(text)
            current_sentence['end'] = segment.get('start', 0) + segment.get('duration', 0)
            
            # Check if sentence should end
            ends_with_punct = any(text.endswith(p) for p in sentence_enders)
            duration = current_sentence['end'] - current_sentence['start']
            
            if ends_with_punct or duration >= max_duration:
                merged_text = ' '.join(current_sentence['texts']).strip()
                if merged_text:
                    merged.append({
                        'text': merged_text,
                        'start': current_sentence['start'],
                        'duration': duration
                    })
                current_sentence = {'texts': [], 'start': None, 'end': None}
        
        # Add remaining
        if current_sentence['texts']:
            merged_text = ' '.join(current_sentence['texts']).strip()
            if merged_text:
                merged.append({
                    'text': merged_text,
                    'start': current_sentence['start'],
                    'duration': current_sentence['end'] - current_sentence['start']
                })
        
        return merged
    
    def get_transcript_detailed(self, video_id: str, languages: list = None) -> list:
        if languages is None:
            languages = ["en", "vi", "en-US", "en-GB"]
        
        try:
            # Simpler API - get transcript directly
            raw_transcript = YouTubeTranscriptApi.get_transcript(
                video_id, 
                languages=languages
            )
            
            print(f'📥 Got {len(raw_transcript)} raw segments')
            
            # Merge segments
            merged = self._merge_transcript_segments(raw_transcript)
            
            print(f'✅ Merged to {len(merged)} sentences')
            
            return merged
            
        except Exception as e:
            logger.error(f"Error getting transcript: {e}")
            raise Exception(f"No subtitles available for this video. Please try a different video with captions.")