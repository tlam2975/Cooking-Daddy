import re
from html import unescape
from urllib.parse import urljoin, urlparse

import requests

META_TAG_RE = re.compile(r"<meta\s+[^>]*>", re.IGNORECASE)
LINK_TAG_RE = re.compile(r"<link\s+[^>]*>", re.IGNORECASE)


def find_hero_image(url):
    """Return an absolute og/twitter image URL for a page, or None."""
    if not _is_http_url(url):
        return None

    try:
        response = requests.get(
            url,
            headers={"User-Agent": "CookingDaddyBot/1.0"},
            timeout=8,
        )
        response.raise_for_status()
    except requests.RequestException as exc:
        print(f"Hero image lookup failed: {exc}")
        return None

    return extract_hero_image(response.text, response.url)


def extract_hero_image(html, base_url):
    for tag in META_TAG_RE.findall(html or ""):
        marker = _attr(tag, "property") or _attr(tag, "name")
        if marker and marker.lower() in {"og:image", "twitter:image", "twitter:image:src"}:
            image_url = _attr(tag, "content")
            if image_url:
                return _absolute_url(image_url, base_url)

    for tag in LINK_TAG_RE.findall(html or ""):
        rel = (_attr(tag, "rel") or "").lower()
        if "image_src" in rel:
            image_url = _attr(tag, "href")
            if image_url:
                return _absolute_url(image_url, base_url)

    return None


def _attr(tag, name):
    match = re.search(
        rf"""\b{name}\s*=\s*(["'])(.*?)\1""",
        tag,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return None
    return unescape(match.group(2).strip())


def _absolute_url(image_url, base_url):
    absolute = urljoin(base_url, image_url)
    return absolute if _is_http_url(absolute) else None


def _is_http_url(url):
    parsed = urlparse(url or "")
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)