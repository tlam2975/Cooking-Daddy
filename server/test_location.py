import unittest
from unittest.mock import Mock, patch
import requests

from models import SmartGenerateRequest
from prompts import build_smart_prompt
from service import SmartRecipeService


class LocationTests(unittest.TestCase):
    def test_city_is_geocoded_for_open_meteo_weather(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'localHour': 8,
                                    'location': {'city': 'Hanoi', 'countryCode': 'VN'}})
        geocoding = Mock()
        geocoding.json.return_value = {'results': [
            {'name': 'Hanoi', 'latitude': 21.03, 'longitude': 105.85}]}
        weather = Mock()
        weather.json.return_value = {'current': {
            'temperature_2m': 29, 'apparent_temperature': 32,
            'relative_humidity_2m': 80, 'rain': 0.5, 'weather_code': 61}}
        with patch('service.requests.get', side_effect=[geocoding, weather]) as get:
            context = SmartRecipeService('test-key').build_context(req)
        self.assertEqual(get.call_count, 2)
        self.assertIn('geocoding-api.open-meteo.com', get.call_args_list[0].args[0])
        self.assertEqual(get.call_args_list[0].kwargs['params']['name'], 'Hanoi')
        self.assertEqual(get.call_args_list[0].kwargs['params']['countryCode'], 'VN')
        self.assertIn('api.open-meteo.com', get.call_args_list[1].args[0])
        self.assertEqual(get.call_args_list[1].kwargs['params']['latitude'], 21.03)
        self.assertEqual(context['weather']['city'], 'Hanoi')
        self.assertEqual(context['weather']['condition'], 'Rainy')
        self.assertTrue(context['weather']['is_raining'])
        self.assertEqual(context['meal_time'], 'breakfast')

    def test_open_weather_map_follows_open_meteo_failure(self):
        req = SmartGenerateRequest({'ingredients': 'rice',
                                    'location': {'city': 'Hanoi', 'countryCode': 'VN'}})
        missing_city = Mock()
        missing_city.json.return_value = {'results': []}
        owm_city = Mock()
        owm_city.json.return_value = [
            {'name': 'Hanoi', 'lat': 21.03, 'lon': 105.85}]
        owm_weather = Mock()
        owm_weather.json.return_value = {
            'main': {'temp': 29, 'feels_like': 32, 'humidity': 80},
            'weather': [{'main': 'Rain', 'description': 'light rain'}],
            'rain': {'1h': 0.5},
        }
        with patch('service.requests.get', side_effect=[
                missing_city, owm_city, owm_weather]) as get:
            context = SmartRecipeService('test-key').build_context(req)
        self.assertEqual(get.call_count, 3)
        self.assertIn('geo/1.0/direct', get.call_args_list[1].args[0])
        self.assertEqual(get.call_args_list[1].kwargs['params']['q'], 'Hanoi,VN')
        self.assertEqual(get.call_args_list[1].kwargs['params']['appid'], 'test-key')
        self.assertIn('data/2.5/weather', get.call_args_list[2].args[0])
        self.assertEqual(get.call_args_list[2].kwargs['params']['lat'], 21.03)
        self.assertEqual(get.call_args_list[2].kwargs['params']['units'], 'metric')
        self.assertEqual(context['weather']['city'], 'Hanoi')
        self.assertEqual(context['weather']['temperature'], 29)
        self.assertTrue(context['weather']['is_raining'])

    def test_open_weather_map_follows_open_meteo_forecast_timeout(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'location': 'Hanoi'})
        meteo_city = Mock()
        meteo_city.json.return_value = {'results': [
            {'name': 'Hanoi', 'latitude': 21.03, 'longitude': 105.85}]}
        owm_city = Mock()
        owm_city.json.return_value = [
            {'name': 'Hanoi', 'lat': 21.03, 'lon': 105.85}]
        owm_weather = Mock()
        owm_weather.json.return_value = {
            'main': {'temp': 28, 'feels_like': 31, 'humidity': 70},
            'weather': [{'main': 'Clouds', 'description': 'scattered clouds'}],
        }
        with patch('service.requests.get', side_effect=[
                meteo_city, requests.Timeout, owm_city, owm_weather]) as get:
            context = SmartRecipeService('test-key').build_context(req)
        self.assertEqual(get.call_count, 4)
        self.assertEqual(context['weather']['condition'], 'Clouds')
        self.assertFalse(context['weather']['is_raining'])

    def test_no_permission_means_no_weather_request_or_default_city(self):
        req = SmartGenerateRequest({'ingredients': 'rice'})
        with patch('service.requests.get') as get:
            context = SmartRecipeService().build_context(req)
            get.assert_not_called()
        self.assertIsNone(context['weather'])

    def test_coordinates_and_bad_city_are_rejected(self):
        for location in ({'latitude': 10.78, 'longitude': 106.7},
                         {'city': ''}, {'city': 'Hanoi', 'countryCode': 'VNN'},
                         [], ''):
            with self.subTest(location=location), self.assertRaises(ValueError):
                SmartGenerateRequest({'ingredients': 'rice', 'location': location})

    def test_weather_failure_does_not_block_generation(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'location': 'Hanoi'})
        with patch('service.requests.get', side_effect=requests.Timeout):
            context = SmartRecipeService().build_context(req)
        self.assertIsNone(context['weather'])
        self.assertEqual(context['city'], 'Hanoi')
        prompt = build_smart_prompt('rice', None, None, 'short', 'easy',
                                    context['weather'], context['meal_time'],
                                    context['hour'], 'en', context['city'])
        self.assertIn('City: Hanoi', prompt)


if __name__ == '__main__':
    unittest.main()
