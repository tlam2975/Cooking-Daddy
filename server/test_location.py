import unittest
from unittest.mock import Mock, patch

from models import SmartGenerateRequest
from service import SmartRecipeService


class LocationTests(unittest.TestCase):
    def test_coordinates_are_used_in_weather_request(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'localHour': 8,
                                   'location': {'latitude': 10.78, 'longitude': 106.7}})
        payload = {'main': {'temp': 29, 'feels_like': 30, 'humidity': 80},
                   'weather': [{'main': 'Clouds', 'description': 'cloudy'}], 'name': 'Test City'}
        response = Mock(status_code=200)
        response.json.return_value = payload
        with patch('service.requests.get', return_value=response) as get:
            context = SmartRecipeService('test-key').build_context(req)
        self.assertEqual(get.call_args.kwargs['params']['lat'], 10.78)
        self.assertEqual(get.call_args.kwargs['params']['lon'], 106.7)
        self.assertNotIn('q', get.call_args.kwargs['params'])
        self.assertEqual(get.call_args.kwargs['timeout'], 5)
        self.assertEqual(context['weather']['city'], 'Test City')
        self.assertEqual(context['meal_time'], 'breakfast')

    def test_no_permission_means_no_weather_request_or_default_city(self):
        req = SmartGenerateRequest({'ingredients': 'rice'})
        with patch('service.requests.get') as get:
            context = SmartRecipeService('test-key').build_context(req)
            get.assert_not_called()
        self.assertIsNone(req.location)
        self.assertIsNone(context['weather'])

    def test_bad_coordinates_are_rejected(self):
        for location in ({'latitude': 91, 'longitude': 0}, {'latitude': 0},
                         {'latitude': True, 'longitude': 0}, [],
                         {'latitude': 0, 'longitude': float('nan')}):
            with self.subTest(location=location), self.assertRaises(ValueError):
                SmartGenerateRequest({'ingredients': 'rice', 'location': location})

    def test_weather_failure_does_not_block_generation(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'location': {'latitude': 0, 'longitude': 0}})
        with patch('service.requests.get', side_effect=TimeoutError):
            self.assertIsNone(SmartRecipeService('test-key').build_context(req)['weather'])

    def test_missing_weather_key_skips_the_network(self):
        req = SmartGenerateRequest({'ingredients': 'rice', 'location': 'Test City'})
        with patch('service.requests.get') as get:
            self.assertIsNone(SmartRecipeService(None).build_context(req)['weather'])
            get.assert_not_called()


if __name__ == '__main__':
    unittest.main()
