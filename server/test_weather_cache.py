import unittest
from unittest.mock import patch
from service import SmartRecipeService


class WeatherCacheTests(unittest.TestCase):
    def test_fresh_cache_then_stale_fallback_then_expiration(self):
        service = SmartRecipeService()
        city = {'city': 'Hanoi', 'countryCode': 'VN'}
        weather = {'temperature': 30, 'condition': 'clear'}
        with patch('service.time.monotonic', return_value=100), patch.object(
                service, '_get_open_meteo_weather', return_value=weather) as meteo:
            self.assertEqual(service._get_weather(city), weather)
            self.assertEqual(service._get_weather(city), weather)
            self.assertEqual(meteo.call_count, 1)
        with patch('service.time.monotonic', return_value=2000), patch.object(
                service, '_get_open_meteo_weather', return_value=None), patch.object(
                service, '_get_open_weather_weather', return_value=None):
            self.assertTrue(service._get_weather(city)['cached'])
            self.assertIsNone(service._get_weather({'city': 'Paris', 'countryCode': 'FR'}))
        with patch('service.time.monotonic', return_value=22000), patch.object(
                service, '_get_open_meteo_weather', return_value=None), patch.object(
                service, '_get_open_weather_weather', return_value=None):
            self.assertIsNone(service._get_weather(city))
