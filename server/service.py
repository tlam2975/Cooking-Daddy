from datetime import datetime
import time
import requests


class SmartRecipeService:
    def __init__(self, weather_api_key=None):
        self.weather_api_key = weather_api_key
        self._weather_cache = {}

    def build_context(self, req):
        now = datetime.now()
        hour = req.local_hour if req.local_hour is not None else now.hour

        meal_time = (
            'breakfast' if 5 <= hour < 9 else
            'lunch' if 11 <= hour < 14 else
            'dinner' if 17 <= hour < 21 else
            'snacks'
        )

        weather = self._get_weather(req.location) if req.location else None
        city = self._city_and_country(req.location)[0] if req.location else None

        return {
            "weather": weather,
            "city": city,
            "meal_time": meal_time,
            "hour": hour
        }

    def _get_weather(self, location):
        city, country = self._city_and_country(location)
        key = (city.strip().casefold(), (country or '').upper())
        cached = self._weather_cache.get(key)
        now = time.monotonic()
        if cached and now - cached[0] < 1800:
            return dict(cached[1])
        weather = self._get_open_meteo_weather(location)
        if weather is None:
            weather = self._get_open_weather_weather(location)
        if weather is not None:
            if len(self._weather_cache) >= 100:
                self._weather_cache.pop(next(iter(self._weather_cache)))
            self._weather_cache[key] = (now, dict(weather))
        elif cached and now - cached[0] < 21600:
            weather = {**cached[1], 'cached': True, 'ageMinutes': round((now - cached[0]) / 60)}
        return weather

    @staticmethod
    def _city_and_country(location):
        if isinstance(location, dict):
            return location['city'], location.get('countryCode')
        return location, None

    def _get_open_meteo_weather(self, location):
        try:
            city, country_code = self._city_and_country(location)
            params = {'name': city, 'count': 1, 'language': 'en', 'format': 'json'}
            if country_code:
                params['countryCode'] = country_code
            place_res = requests.get('https://geocoding-api.open-meteo.com/v1/search',
                                     params=params, timeout=5)
            place_res.raise_for_status()
            places = place_res.json().get('results') or []
            if not places:
                return None
            place = places[0]
            weather_res = requests.get('https://api.open-meteo.com/v1/forecast',
                                       params={
                                           'latitude': place['latitude'],
                                           'longitude': place['longitude'],
                                           'current': ('temperature_2m,apparent_temperature,'
                                                       'relative_humidity_2m,rain,weather_code'),
                                       }, timeout=5)
            weather_res.raise_for_status()
            current = weather_res.json()['current']
            code = current['weather_code']
            condition = self._condition(code)
            return {
                'temperature': current['temperature_2m'],
                'feels_like': current['apparent_temperature'],
                'condition': condition,
                'description': condition.lower(),
                'humidity': current['relative_humidity_2m'],
                'city': place['name'],
                'is_raining': (current.get('rain') or 0) > 0 or 51 <= code <= 67 or
                              80 <= code <= 82 or code >= 95,
            }
        except (requests.RequestException, AttributeError, KeyError, TypeError,
                ValueError, IndexError):
            return None

    def _get_open_weather_weather(self, location):
        if not self.weather_api_key:
            return None
        try:
            city, country_code = self._city_and_country(location)
            query = f'{city},{country_code}' if country_code else city
            place_res = requests.get(
                'https://api.openweathermap.org/geo/1.0/direct',
                params={'q': query, 'limit': 1, 'appid': self.weather_api_key},
                timeout=5,
            )
            place_res.raise_for_status()
            places = place_res.json()
            if not places:
                return None
            place = places[0]
            weather_res = requests.get(
                'https://api.openweathermap.org/data/2.5/weather',
                params={'lat': place['lat'], 'lon': place['lon'],
                        'appid': self.weather_api_key, 'units': 'metric'},
                timeout=5,
            )
            weather_res.raise_for_status()
            data = weather_res.json()
            condition = data['weather'][0]
            return {
                'temperature': data['main']['temp'],
                'feels_like': data['main']['feels_like'],
                'condition': condition['main'],
                'description': condition['description'],
                'humidity': data['main']['humidity'],
                'city': place['name'],
                'is_raining': (data.get('rain') or {}).get('1h', 0) > 0 or
                              condition['main'].lower() in ('rain', 'drizzle', 'thunderstorm'),
            }
        except (requests.RequestException, AttributeError, KeyError, TypeError,
                ValueError, IndexError):
            return None

    @staticmethod
    def _condition(code):
        if code == 0:
            return 'Clear'
        if code <= 3:
            return 'Cloudy'
        if code in (45, 48):
            return 'Foggy'
        if 51 <= code <= 67 or 80 <= code <= 82:
            return 'Rainy'
        if 71 <= code <= 77 or 85 <= code <= 86:
            return 'Snowy'
        if code >= 95:
            return 'Stormy'
        return 'Cloudy'
