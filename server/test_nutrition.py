import unittest
from unittest.mock import Mock, patch
import requests

from nutrition_service import NutritionLookupUnavailable, NutritionService

with patch('dotenv.load_dotenv'), patch('gemini_service.GeminiService'):
    import main


class NutritionTests(unittest.TestCase):
    def test_macros_preserve_unknowns_and_reject_invalid_numbers(self):
        result = NutritionService._pick_match('onion', [{'product_name': 'Onion',
            'code': '123456789', 'allergens_tags': ['en:milk'],
            'nutriments': {'energy-kcal_100g': 40, 'proteins_100g': 1.1,
                'fat_100g': 0, 'fiber_100g': float('nan'), 'salt_100g': -2}}])
        self.assertEqual(result['nutrients'], {'proteins': 1.1, 'fat': 0})
        self.assertEqual(result['allergens'], ['en:milk'])
        self.assertEqual(result['code'], '123456789')

    def test_malformed_provider_payload_is_unavailable(self):
        service = NutritionService()
        service.SEARCH_INTERVAL_SECONDS = 0
        response = Mock()
        response.json.return_value = []
        with patch('nutrition_service.requests.get', return_value=response):
            with self.assertRaises(NutritionLookupUnavailable):
                service.build_note({'ingredients': [{'name': 'onion'}]})

    def test_product_data_is_labeled_as_an_example(self):
        service = NutritionService()
        service.SEARCH_INTERVAL_SECONDS = 0
        response = Mock()
        response.json.return_value = {'products': [
            {'product_name': 'Onion', 'nutriments': {'energy-kcal_100g': 40}},
            {'product_name': 'Onion rings', 'nutriments': {'energy-kcal_100g': 400}},
        ]}
        with patch('nutrition_service.requests.get', return_value=response) as get:
            result = service.build_note({'ingredients': [
                {'name': 'onion', 'quantity': 100, 'unit': 'g'}]})
            cached = service.build_note({'ingredients': [
                {'name': 'onion', 'quantity': 100, 'unit': 'g'}]})
        self.assertEqual(get.call_count, 1)
        self.assertIn('Onion: 40 kcal/100 g', result['energyNote'])
        self.assertIn('not a whole-recipe total', result['energyNote'])
        self.assertEqual(cached, result)

    def test_missing_data_does_not_invent_calories(self):
        service = NutritionService()
        service.SEARCH_INTERVAL_SECONDS = 0
        response = Mock()
        response.json.return_value = {'products': []}
        with patch('nutrition_service.requests.get', return_value=response):
            result = service.build_note({'language': 'vi', 'ingredients': [
                {'name': 'rau lạ', 'quantity': 100, 'unit': 'g'}]})
        self.assertEqual(result['matchedIngredients'], 0)
        self.assertNotIn('kcal', result['energyNote'])

    def test_energy_endpoint_does_not_call_gemini(self):
        with patch.object(main.nutrition_service, 'build_note', return_value={
            'energyNote': 'Open Food Facts product examples: Onion: 40 kcal/100 g.',
            'nutritionSource': 'Open Food Facts', 'matchedIngredients': 1,
        }), patch.object(main.gemini_service, 'generate') as generate:
            response = main.app.test_client().post('/api/energy-note', json={
                'ingredients': [{'name': 'onion'}]})
            generate.assert_not_called()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json['nutritionSource'], 'Open Food Facts')

    def test_provider_outage_is_not_reported_as_missing_nutrition(self):
        service = NutritionService()
        service.SEARCH_INTERVAL_SECONDS = 0
        with patch('nutrition_service.requests.get', side_effect=requests.Timeout):
            with self.assertRaises(NutritionLookupUnavailable):
                service.build_note({'ingredients': [{'name': 'onion'}]})
        with patch.object(main.nutrition_service, 'build_note',
                          side_effect=NutritionLookupUnavailable):
            response = main.app.test_client().post('/api/energy-note', json={
                'ingredients': [{'name': 'onion'}]})
        self.assertEqual(response.status_code, 503)


if __name__ == '__main__':
    unittest.main()
