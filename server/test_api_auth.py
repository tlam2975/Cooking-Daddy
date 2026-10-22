import unittest
from unittest.mock import patch

from firebase_admin import auth
import api_auth
from test_quota_support import MemoryQuota

with patch('dotenv.load_dotenv'), patch('gemini_service.GeminiService'):
    import main


USER = {'uid': 'signed-in-user', 'firebase': {'sign_in_provider': 'google.com'}}
HEADERS = {'Authorization': 'Bearer test-token'}


class ApiAuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.client = main.app.test_client()
        quota = patch.object(main, 'quota_store', MemoryQuota())
        quota.start()
        self.addCleanup(quota.stop)

    def test_every_api_route_rejects_missing_and_malformed_credentials(self):
        with patch('api_auth.verify_user_token') as verify, \
                patch.object(main.gemini_service, 'generate') as generate, \
                patch.object(main.nutrition_service, 'build_note') as nutrition, \
                patch.object(main.smart_service, 'build_context') as context:
            for rule in main.app.url_map.iter_rules():
                if not rule.rule.startswith('/api/'):
                    continue
                method = 'GET' if 'GET' in rule.methods else 'POST'
                for header in ('', 'Basic abc', 'Bearer', 'Bearer one two'):
                    with self.subTest(path=rule.rule, header=header):
                        response = self.client.open(rule.rule, method=method,
                            headers={'Authorization': header}, json={})
                        self.assertEqual(response.status_code, 401)
                        self.assertEqual(response.json['error_code'], 'auth_required')
                        self.assertEqual(response.headers['WWW-Authenticate'], 'Bearer')
                        self.assertEqual(response.headers['Cache-Control'], 'no-store')
            verify.assert_not_called()
            generate.assert_not_called()
            nutrition.assert_not_called()
            context.assert_not_called()

    def test_invalid_expired_revoked_and_disabled_users_cannot_generate(self):
        errors = [auth.InvalidIdTokenError('invalid'),
                  auth.ExpiredIdTokenError('expired', None),
                  auth.RevokedIdTokenError('revoked'),
                  auth.UserDisabledError('disabled'),
                  auth.UserNotFoundError('deleted')]
        for error in errors:
            with self.subTest(error=type(error).__name__), \
                    patch('api_auth.verify_user_token', side_effect=error), \
                    patch.object(main.gemini_service, 'generate') as generate:
                response = self.client.post('/api/smart-generate',
                    headers=HEADERS, json={'ingredients': 'rice'})
                self.assertEqual(response.status_code, 401)
                generate.assert_not_called()

    def test_verified_user_can_access_api_without_shared_caching(self):
        with patch('api_auth.verify_user_token', return_value=USER) as verify:
            response = self.client.get('/api/quota', headers=HEADERS)
        self.assertEqual(response.status_code, 200)
        self.assertIn('remaining', response.json)
        self.assertEqual(response.headers['Cache-Control'], 'no-store')
        verify.assert_called_once_with('test-token')

    def test_anonymous_and_missing_identity_are_rejected(self):
        for claims in ({'uid': 'guest', 'firebase': {'sign_in_provider': 'anonymous'}}, {}):
            with patch('api_auth.verify_user_token', return_value=claims):
                response = self.client.get('/api/quota', headers=HEADERS)
                self.assertEqual(response.status_code, 401)

    def test_auth_outage_and_configuration_error_fail_closed_without_secret_leaks(self):
        for error in (auth.CertificateFetchError('certificate unavailable', None),
                      ValueError('private credential details')):
            with patch('api_auth.verify_user_token', side_effect=error), \
                    patch.object(main.app.logger, 'error') as log, \
                    patch.object(main.gemini_service, 'generate') as generate:
                response = self.client.post('/api/remix', headers=HEADERS, json={})
                self.assertEqual(response.status_code, 503)
                self.assertEqual(response.json['error_code'], 'auth_unavailable')
                self.assertNotIn(b'private credential', response.data)
                self.assertNotIn('private credential', str(log.call_args_list))
                generate.assert_not_called()

    def test_health_docs_and_preflight_do_not_need_user_tokens(self):
        with patch('api_auth.verify_user_token') as verify:
            for path in ('/', '/docs', '/health'):
                self.assertEqual(self.client.get(path).status_code, 200)
            response = self.client.options('/api/remix', headers={
                'Origin': 'https://app.example.com',
                'Access-Control-Request-Method': 'POST',
                'Access-Control-Request-Headers': 'Authorization, Content-Type',
            })
            self.assertEqual(response.status_code, 200)
            self.assertIn('Authorization', response.headers['Access-Control-Allow-Headers'])
            verify.assert_not_called()

    def test_sdk_verifies_tokens_and_checks_revocation(self):
        with patch('api_auth._firebase_app', return_value='configured-app'), \
                patch('api_auth.auth.verify_id_token', return_value=USER) as verify:
            self.assertEqual(api_auth.verify_user_token('token'), USER)
            verify.assert_called_once_with('token', app='configured-app', check_revoked=True)

    def test_emulator_cannot_bypass_signature_verification(self):
        with patch.dict('os.environ', {'FIREBASE_AUTH_EMULATOR_HOST': 'localhost:9099'}):
            with self.assertRaises(ValueError):
                api_auth._firebase_app()

    def test_credentials_for_another_project_are_rejected(self):
        with patch.dict('os.environ', {'FIREBASE_AUTH_EMULATOR_HOST': '',
                'FIREBASE_SERVICE_ACCOUNT_JSON': '{}', 'FIREBASE_PROJECT_ID': api_auth.PROJECT_ID}), \
                patch('api_auth.firebase_admin.get_app', side_effect=ValueError), \
                patch('api_auth.credentials.Certificate') as certificate, \
                patch('api_auth.firebase_admin.initialize_app') as initialize:
            certificate.return_value.project_id = 'another-project'
            with self.assertRaises(ValueError):
                api_auth._firebase_app()
            initialize.assert_not_called()


if __name__ == '__main__':
    unittest.main()
