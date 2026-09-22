import math


class SmartGenerateRequest:
    def __init__(self, data: dict):
        if not isinstance(data, dict):
            raise ValueError("Invalid request")

        self.ingredients = str(data.get('ingredients', '')).strip()
        self.tools = str(data.get('tools', '')).strip() or None
        self.dish = str(data.get('dish', '')).strip() or 'Main'
        self.session_length = data.get('sessionLength', 'short')
        self.difficulty = data.get('difficulty', 'normal')
        self.location = data.get('location')
        self.language = data.get('language', 'en')
        self.local_hour = data.get('localHour')

        if self.language not in ('en', 'vi'):
            raise ValueError('Invalid language')
        if self.local_hour is not None and (type(self.local_hour) is not int or not 0 <= self.local_hour <= 23):
            raise ValueError('Invalid local hour')
        if isinstance(self.location, dict):
            for key, limit in (('latitude', 90), ('longitude', 180)):
                value = self.location.get(key)
                if type(value) not in (int, float) or not math.isfinite(value) or not -limit <= value <= limit:
                    raise ValueError('Invalid location coordinates')
            self.location = {key: self.location[key] for key in ('latitude', 'longitude')}
        elif self.location is not None and not isinstance(self.location, str):
            raise ValueError('Invalid location')

        if not self.ingredients:
            raise ValueError("Ingredients required")
