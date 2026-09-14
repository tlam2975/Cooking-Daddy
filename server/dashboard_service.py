from datetime import datetime


class DashboardService:
    def __init__(self):
        self._cache = {}
        self._tips = [
            "Prep one ingredient before opening the stove. Cooking feels calmer when the first move is already done.",
            "Taste before adding more salt. Acidity, sweetness, or fat may be what the dish is actually asking for.",
            "Use medium heat when you are unsure. You can always raise heat, but burnt garlic has opinions.",
            "Cut ingredients to similar sizes so they finish cooking at the same time.",
            "Rest cooked meat before slicing. A few quiet minutes keeps more juice in the food.",
        ]
        self._images = [
            "https://images.unsplash.com/photo-1495521821757-a1efb6729352?auto=format&fit=crop&w=1200&q=80",
            "https://images.unsplash.com/photo-1506368249639-73a05d6f6488?auto=format&fit=crop&w=1200&q=80",
            "https://images.unsplash.com/photo-1556911220-bff31c812dba?auto=format&fit=crop&w=1200&q=80",
            "https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=1200&q=80",
            "https://images.unsplash.com/photo-1514986888952-8cd320577b68?auto=format&fit=crop&w=1200&q=80",
        ]

    def get_daily_brief(self, day=None):
        day_key = day or datetime.utcnow().date().isoformat()
        if day_key in self._cache:
            return self._cache[day_key]

        index = sum(ord(char) for char in day_key) % len(self._tips)
        payload = {
            "date": day_key,
            "title": "Daily kitchen note",
            "tip": self._tips[index],
            "imageUrl": self._images[index],
            "source": "server-cache",
        }
        self._cache[day_key] = payload
        return payload
