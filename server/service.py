from datetime import datetime
import requests


class SmartRecipeService:
    def __init__(self, weather_api_key):
        self.weather_api_key = weather_api_key

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

        return {
            "weather": weather,
            "meal_time": meal_time,
            "hour": hour
        }

    def _get_weather(self, location):
        if not self.weather_api_key:
            return None
        try:
            params = {'appid': self.weather_api_key, 'units': 'metric'}
            if isinstance(location, dict):
                params.update(lat=location['latitude'], lon=location['longitude'])
            else:
                params['q'] = location
            res = requests.get('https://api.openweathermap.org/data/2.5/weather',
                               params=params, timeout=5)

            if res.status_code != 200:
                return None

            data = res.json()

            return {
                'temperature': data['main']['temp'],
                'feels_like': data['main']['feels_like'],
                'condition': data['weather'][0]['main'],
                'description': data['weather'][0]['description'],
                'humidity': data['main']['humidity'],
                'city': data['name'],
                'is_raining': 'rain' in data and data['rain'].get('1h', 0) > 0
            }
        except:
            return None
