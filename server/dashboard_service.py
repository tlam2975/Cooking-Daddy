import re
from datetime import date, datetime, timezone

SUPPORTED_LANGUAGES = ("en", "vi")

_TITLES = {
    "en": "Daily kitchen note",
    "vi": "Ghi chú bếp hôm nay",
}

# Tips are paired by index so both languages show the same advice on a given day.
_TIPS = {
    "en": [
        "Prep one ingredient before opening the stove. Cooking feels calmer when the first move is already done.",
        "Taste before adding more salt. Acidity, sweetness, or fat may be what the dish is actually asking for.",
        "Use medium heat when you are unsure. You can always raise heat, but burnt garlic has opinions.",
        "Cut ingredients to similar sizes so they finish cooking at the same time.",
        "Rest cooked meat before slicing. A few quiet minutes keeps more juice in the food.",
    ],
    "vi": [
        "Sơ chế sẵn một nguyên liệu trước khi bật bếp. Bước đầu đã xong thì nấu sẽ thong thả hơn.",
        "Nếm trước khi thêm muối. Có khi món ăn cần thêm chút chua, ngọt hoặc béo chứ không phải mặn.",
        "Khi không chắc, hãy để lửa vừa. Tăng lửa lúc nào cũng được, nhưng tỏi cháy thì không cứu được.",
        "Thái nguyên liệu to nhỏ đều nhau để chúng chín cùng lúc.",
        "Để thịt nghỉ vài phút trước khi thái. Thịt sẽ giữ được nhiều nước hơn.",
    ],
}

_IMAGES = [
    "https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1506368249639-73a05d6f6488?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1514986888952-8cd320577b68?auto=format&fit=crop&w=1200&q=80",
]


def normalize_language(lang):
    code = (lang or "").strip().lower()[:2]
    return code if code in SUPPORTED_LANGUAGES else "en"


MAX_CACHED_BRIEFS = 256


def normalize_day(day):
    """A real YYYY-MM-DD date, else today (UTC). Keeps the cache bounded."""
    if isinstance(day, str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}', day):
        try:
            return date.fromisoformat(day).isoformat()
        except ValueError:
            pass
    return datetime.now(timezone.utc).date().isoformat()


class DashboardService:
    def __init__(self):
        self._cache = {}

    def get_daily_brief(self, day=None, lang=None):
        day_key = normalize_day(day)
        language = normalize_language(lang)
        cache_key = (day_key, language)
        if cache_key in self._cache:
            return self._cache[cache_key]

        index = sum(ord(char) for char in day_key) % len(_IMAGES)
        payload = {
            "date": day_key,
            "lang": language,
            "title": _TITLES[language],
            "tip": _TIPS[language][index],
            "imageUrl": _IMAGES[index],
            "source": "server-cache",
        }
        if len(self._cache) >= MAX_CACHED_BRIEFS:
            self._cache.pop(next(iter(self._cache)))
        self._cache[cache_key] = payload
        return payload
