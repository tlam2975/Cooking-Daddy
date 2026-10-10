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
            city = self.location.get('city')
            country_code = self.location.get('countryCode')
            if not isinstance(city, str) or not 1 < len(city.strip()) <= 100:
                raise ValueError('Invalid location city')
            if country_code is not None and (not isinstance(country_code, str) or
                                             len(country_code) != 2 or not country_code.isalpha()):
                raise ValueError('Invalid location country')
            self.location = {'city': city.strip(),
                             'countryCode': country_code.upper() if country_code else None}
        elif self.location is not None and not isinstance(self.location, str):
            raise ValueError('Invalid location')
        elif isinstance(self.location, str):
            self.location = self.location.strip()
            if not 1 < len(self.location) <= 100:
                raise ValueError('Invalid location city')

        if not self.ingredients:
            raise ValueError("Ingredients required")
