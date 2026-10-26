import json
import unittest
from datetime import datetime, timezone, timedelta
from threading import Lock
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from quota_service import FirestoreQuotaStore, QuotaUnavailable
from youtube_service import _extract_video_id, canonical_youtube_url, youtube_thumbnail
from nutrition_service import NutritionService, NutritionLookupUnavailable
from test_quota_support import MemoryQuota

with patch('dotenv.load_dotenv'), patch('gemini_service.GeminiService'):
    import main

class Snapshot:
    def __init__(self, data): self.data = data
    def to_dict(self): return self.data
class Reference:
    def __init__(self, client, identity): self.client, self.id = client, identity
    def get(self, **kwargs): return Snapshot(self.client.records.get(self.id))
class Transaction:
    def __init__(self, client): self.client = client
    def set(self, ref, data, merge=False):
        self.client.records[ref.id] = {**(self.client.records.get(ref.id, {}) if merge else {}), **data}
class Client:
    def __init__(self): self.records, self.lock = {}, Lock()
    def collection(self, name): return self
    def document(self, identity): return Reference(self, identity)
    def transaction(self, **kwargs): return Transaction(self)
def transactional(function):
    def run(transaction):
        with transaction.client.lock: return function(transaction)
    return run

class ReliabilityTests(unittest.TestCase):
    def setUp(self):
        self.client = main.app.test_client()
        self.client.environ_base['HTTP_AUTHORIZATION'] = 'Bearer test-token'
        self.quota = MemoryQuota()
        for mock in (patch('api_auth.verify_user_token', return_value={'uid': 'A'}),
                     patch.object(main, 'quota_store', self.quota),
                     patch.object(main, 'DAILY_LIMIT', 1)):
            mock.start(); self.addCleanup(mock.stop)
        self.recipe = {'name': 'Soup', 'basePortions': 2, 'category': 'dinner', 'tags': ['dinner'],
            'ingredients': [{'name': 'onion', 'quantity': 100, 'unit': 'g'}], 'tools': [],
            'steps': [{'instruction': 'Stir soup', 'activityType': 'mix', 'whatToLookFor': 'Smooth'}]}

    def test_ready_and_health_distinguish_liveness_from_missing_ai(self):
        with patch.object(main.gemini_service, 'clients', []):
            self.assertEqual(self.client.get('/health').status_code, 200)
            self.assertFalse(self.client.get('/health').json['ai_ready'])
            self.assertEqual(self.client.get('/ready').status_code, 503)
            self.assertEqual(self.client.get('/api/quota').json['remaining'], 0)

    def test_strict_video_origin_and_id_validation_without_fetching(self):
        for url in ('http://localhost/?v=abcdefghijk', 'https://youtube.com.evil.test/watch?v=abcdefghijk',
                    'https://youtube.com@127.0.0.1/watch?v=abcdefghijk', 'file:///watch?v=abcdefghijk',
                    'https://www.youtube.com:8443/watch?v=abcdefghijk',
                    'https://youtu.be/abcdefghijk/suffix', 'https://youtube.com/watch?v=short',
                    'https://youtube.com/watch?v=abcdefghijk&v=ABCDEFGHIJK', None, []):
            with self.subTest(url=url), patch.object(main, 'get_youtube_transcript') as fetch:
                self.assertIsNone(_extract_video_id(url))
                self.assertEqual(self.client.post('/api/generate-from-url', json={'url': url}).status_code, 400)
                fetch.assert_not_called()
        for url in ('https://youtu.be/abcdefghijk?t=12', 'https://m.youtube.com/shorts/abcdefghijk',
                    'https://youtube.com/watch?v=abcdefghijk', 'https://www.youtube.com/embed/abcdefghijk'):
            self.assertEqual(canonical_youtube_url(url), 'https://www.youtube.com/watch?v=abcdefghijk')
            self.assertEqual(youtube_thumbnail(url), 'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg')

    def test_all_generation_routes_share_schema_servings_and_quota(self):
        with patch.object(main.gemini_service, 'generate', return_value=json.dumps(self.recipe)) as generate, \
             patch.object(main, 'get_youtube_transcript', return_value='serve two people'):
            imported = self.client.post('/api/generate-from-url', json={'url': 'https://youtu.be/abcdefghijk'})
            self.assertEqual(imported.status_code, 200)
            self.assertEqual(imported.json['recipe']['basePortions'], 2)
            self.assertEqual(imported.json['recipe']['url'], 'https://www.youtube.com/watch?v=abcdefghijk')
            self.assertEqual(imported.json['recipe']['imageUrl'], 'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg')
            self.assertEqual(imported.json['remaining_quota'], 0)
            self.assertEqual(self.client.get('/api/quota').json['remaining'], 0)
            for route, body in (('/api/smart-generate', {'ingredients': 'onion'}),
                                ('/api/generate-from-ingredients', {'ingredients': 'onion'}),
                                ('/api/remix', {'recipe': self.recipe}),
                                ('/api/generate-from-url', {'url': 'https://youtu.be/abcdefghijk'})):
                self.assertEqual(self.client.post(route, json=body).status_code, 429)
            generate.assert_called_once()
            self.assertEqual(generate.call_args.kwargs['thinking_budget'], 0)

    def test_import_provider_error_is_short_and_does_not_use_quota(self):
        with patch.object(main, 'get_youtube_transcript', side_effect=RuntimeError('long secret provider diagnostics')):
            response = self.client.post('/api/generate-from-url', json={'url': 'https://youtu.be/abcdefghijk'})
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json['error_code'], 'youtube_import_unavailable')
        self.assertNotIn('diagnostics', response.get_data(as_text=True))
        self.assertEqual(self.quota.snapshot('A', 1)['remaining'], 1)

    def test_import_uses_captions_sent_by_the_app_without_fetching(self):
        captions = 'crack two eggs into a bowl and whisk them with a pinch of salt'
        with patch.object(main.gemini_service, 'generate', return_value=json.dumps(self.recipe)) as generate, \
             patch.object(main, 'get_youtube_transcript') as fetch:
            response = self.client.post('/api/generate-from-url', json={
                'url': 'https://youtu.be/abcdefghijk', 'transcript': captions + ' x' * 20000})
        self.assertEqual(response.status_code, 200)
        fetch.assert_not_called()
        prompt = generate.call_args.args[0]
        self.assertIn(captions, prompt)
        self.assertLess(len(prompt), 30000 + 5000)

    def test_import_fetches_when_app_captions_are_missing_or_too_short(self):
        for body in ({}, {'transcript': 'hi'}, {'transcript': ['not', 'text']}):
            with self.subTest(body=body), \
                 patch.object(main.gemini_service, 'generate', return_value=json.dumps(self.recipe)), \
                 patch.object(main, 'get_youtube_transcript', return_value='serve two people') as fetch, \
                 patch.object(main, 'quota_store', MemoryQuota()):
                response = self.client.post('/api/generate-from-url', json={'url': 'https://youtu.be/abcdefghijk', **body})
                self.assertEqual(response.status_code, 200)
                fetch.assert_called_once()

    def test_no_recipe_flag_wins_even_when_other_fields_are_empty(self):
        reply = {**self.recipe, 'name': '', 'ingredients': [], 'error': 'Transcript does not contain a recipe'}
        with patch.object(main.gemini_service, 'generate', return_value=json.dumps(reply)), \
             patch.object(main, 'get_youtube_transcript', return_value='never gonna give you up'):
            response = self.client.post('/api/generate-from-url', json={'url': 'https://youtu.be/abcdefghijk'})
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json['error_code'], 'ai_not_a_recipe')
        self.assertEqual(self.quota.snapshot('A', 1)['remaining'], 1)

    def test_import_failure_is_logged_with_cause(self):
        with patch.object(main, 'get_youtube_transcript', side_effect=RuntimeError('blocked')), \
             self.assertLogs(main.app.logger, 'WARNING') as logs:
            self.client.post('/api/generate-from-url', json={'url': 'https://youtu.be/abcdefghijk'})
        self.assertIn('RuntimeError: blocked', logs.output[0])

    def test_firestore_counter_survives_instances_and_reserves_last_slot_once(self):
        database = Client(); now = datetime(2026, 10, 11, tzinfo=timezone.utc)
        store = FirestoreQuotaStore(lambda: database, lambda: now)
        with patch('quota_service.firestore.transactional', transactional):
            def claim(_):
                try: return store.reserve('A', 1)
                except Exception: return None
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(claim, range(8)))
            self.assertEqual(sum(r is not None for r in results), 1)
            restarted = FirestoreQuotaStore(lambda: database, lambda: now)
            self.assertEqual(restarted.snapshot('A', 1)['remaining'], 0)
            self.assertEqual(restarted.snapshot('B', 1)['remaining'], 1)
            reservation = next(r for r in results if r is not None)[0]
            tomorrow = FirestoreQuotaStore(lambda: database, lambda: now + timedelta(days=1))
            tomorrow.reserve('A', 1)
            tomorrow.release('A', reservation)
            self.assertEqual(tomorrow.snapshot('A', 1)['remaining'], 0)
            self.assertEqual(restarted.snapshot('A', 1)['remaining'], 1)

    def test_quota_outage_fails_closed(self):
        store = FirestoreQuotaStore(lambda: (_ for _ in ()).throw(RuntimeError('no credentials')))
        with self.assertRaises(QuotaUnavailable): store.reserve('A', 1)
        with patch.object(main, 'quota_store', store), patch.object(main.gemini_service, 'generate') as generate:
            response = self.client.post('/api/generate-from-ingredients', json={'ingredients': 'onion'})
            self.assertEqual(response.status_code, 503); generate.assert_not_called()

    def test_nutrition_rejects_work_that_cannot_finish_before_deadline(self):
        service = NutritionService(); service._last_search = 100
        with patch('nutrition_service.time.monotonic', return_value=100), \
             patch('nutrition_service.requests.get') as get, patch('nutrition_service.time.sleep') as sleep:
            with self.assertRaises(NutritionLookupUnavailable): service._search('onion', deadline=103)
            get.assert_not_called(); sleep.assert_not_called()
            self.assertTrue(service._lock.acquire(blocking=False)); service._lock.release()

if __name__ == '__main__': unittest.main()
