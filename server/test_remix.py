import copy
import json
import unittest
from unittest.mock import patch

from prompts import build_remix_prompt

# Tests never create live Gemini clients or read local API keys.
with patch('dotenv.load_dotenv'), patch('gemini_service.GeminiService'):
    import main


class RemixTests(unittest.TestCase):
    def setUp(self):
        self.client = main.app.test_client()
        self.recipe = {
            'name': 'Beef stir-fry', 'category': 'dinner', 'basePortions': 2,
            'ingredients': [{'name': 'beef', 'quantity': 300, 'unit': 'g'}],
            'tools': [{'name': 'pan', 'quantity': 1}],
            'steps': [{'instruction': 'Fry beef.', 'time': 180}],
        }
        self.generated = copy.deepcopy(self.recipe)
        self.generated['name'] = 'Tofu stir-fry'
        self.generated['ingredients'][0]['name'] = 'tofu'
        self.generated['steps'][0]['instruction'] = 'Fry tofu.'
        self.quota = patch.multiple(main, request_count=0, DAILY_LIMIT=30)
        self.quota.start()
        self.addCleanup(self.quota.stop)

    def post(self, **overrides):
        return self.client.post('/api/remix', json={
            'recipe': self.recipe, 'instructions': 'Use tofu', 'language': 'vi',
            **overrides,
        })

    def test_ai_receives_source_and_request_and_returns_modified_recipe(self):
        with patch.object(main.gemini_service, 'generate', return_value=json.dumps(self.generated)) as generate:
            response = self.post()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json['recipe']['name'], 'Tofu stir-fry')
        prompt = generate.call_args.args[0]
        for expected in ('Use tofu', 'Beef stir-fry', 'Vietnamese', 'portions: 2', '180'):
            self.assertIn(expected, prompt)
        self.assertEqual(main.request_count, 1)
        self.assertEqual(self.recipe['ingredients'][0]['name'], 'beef')

    def test_empty_request_asks_for_a_variation(self):
        prompt = build_remix_prompt(self.recipe, '')
        self.assertIn('creative variation', prompt)
        self.assertIn('English', prompt)

    def test_invalid_inputs_do_not_call_ai(self):
        with patch.object(main.gemini_service, 'generate') as generate:
            for overrides in ({'recipe': {}}, {'recipe': []}, {'instructions': 12},
                              {'instructions': 'a' * 1001}, {'language': 'xx'},
                              {'recipe': {**self.recipe, 'basePortions': 0}}):
                with self.subTest(overrides=overrides):
                    self.assertEqual(self.post(**overrides).status_code, 400)
            self.assertEqual(self.client.post('/api/remix', json=[]).status_code, 400)
            generate.assert_not_called()

    def test_quota_prevents_ai_call(self):
        main.request_count = main.DAILY_LIMIT
        with patch.object(main.gemini_service, 'generate') as generate:
            self.assertEqual(self.post().status_code, 429)
            generate.assert_not_called()

    def test_invalid_ai_responses_do_not_create_recipes(self):
        for value in ('not json', '[]', '{"error":"Cannot remix"}',
                      json.dumps({**self.generated, 'steps': []}),
                      json.dumps({**self.generated, 'steps': [{'instruction': 'Cook', 'time': 'ten'}]})):
            with self.subTest(value=value), patch.object(main.gemini_service, 'generate', return_value=value):
                response = self.post()
                self.assertEqual(response.status_code, 422)
                self.assertFalse(response.json['success'])
                self.assertNotIn('recipe', response.json)

    def test_fenced_json_is_accepted(self):
        with patch.object(main.gemini_service, 'generate', return_value='```json\n' + json.dumps(self.generated) + '\n```'):
            self.assertEqual(self.post().status_code, 200)

    def test_provider_failure_is_not_reported_as_success(self):
        with patch.object(main.gemini_service, 'generate', side_effect=RuntimeError('provider failed')), patch.object(main.app.logger, 'exception'):
            response = self.post()
        self.assertEqual(response.status_code, 503)
        self.assertFalse(response.json['success'])
        self.assertEqual(main.request_count, 0)


if __name__ == '__main__':
    unittest.main()
