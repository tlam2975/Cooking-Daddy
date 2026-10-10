import base64
import unittest
from unittest.mock import Mock, patch

from vercel_logs import read_runtime_logs

with patch('dotenv.load_dotenv'), patch('gemini_service.GeminiService'):
    import main


class OperatorPageTests(unittest.TestCase):
    def setUp(self):
        self.client = main.app.test_client()

    @staticmethod
    def auth(password):
        encoded = base64.b64encode(f'admin:{password}'.encode()).decode()
        return {'Authorization': f'Basic {encoded}'}

    def test_developer_home_and_endpoint_reference(self):
        home = self.client.get('/')
        docs = self.client.get('/docs')
        logo = self.client.get('/logo.png')
        self.assertEqual(home.status_code, 200)
        self.assertIn(b'Recipes, from a simple request.', home.data)
        self.assertIn(b'/api/smart-generate', home.data)
        self.assertEqual(docs.status_code, 200)
        self.assertIn(b'/api/energy-note', docs.data)
        self.assertEqual(logo.status_code, 200)
        self.assertEqual(logo.mimetype, 'image/png')
        logo.close()

    def test_log_routes_are_private_and_disabled_without_password(self):
        with patch.dict('os.environ', {'LOG_VIEWER_PASSWORD': ''}):
            self.assertEqual(self.client.get('/admin/logs').status_code, 404)
            self.assertEqual(self.client.get('/admin/logs/data').status_code, 404)
        with patch.dict('os.environ', {'LOG_VIEWER_PASSWORD': 'private-password'}):
            response = self.client.get('/admin/logs')
            self.assertEqual(response.status_code, 401)
            self.assertIn('Basic', response.headers['WWW-Authenticate'])
            self.assertEqual(self.client.get('/admin/logs/data',
                headers=self.auth('wrong')).status_code, 401)

    def test_authenticated_viewer_never_exposes_vercel_token(self):
        env = {'LOG_VIEWER_PASSWORD': 'private-password',
               'VERCEL_API_TOKEN': 'very-secret-token',
               'VERCEL_PROJECT_ID': 'prj_test',
               'VERCEL_DEPLOYMENT_ID': 'dpl_test'}
        with patch.dict('os.environ', env), patch.object(main, 'read_runtime_logs',
                return_value=[{'level': 'info', 'message': 'ready'}]) as fetch:
            page = self.client.get('/admin/logs', headers=self.auth('private-password'))
            data = self.client.get('/admin/logs/data', headers=self.auth('private-password'))
        self.assertEqual(page.status_code, 200)
        self.assertEqual(data.status_code, 200)
        self.assertEqual(data.json['logs'][0]['message'], 'ready')
        self.assertNotIn(b'very-secret-token', page.data + data.data)
        self.assertEqual(data.headers['Cache-Control'], 'no-store')
        fetch.assert_called_once_with('very-secret-token', 'prj_test', 'dpl_test', None)

    def test_log_stream_decodes_events_and_closes(self):
        response = Mock(status_code=200)
        response.iter_lines.return_value = [
            b'data: {"rowId":"one","timestampInMs":123,"level":"info",'
            b'"requestMethod":"GET","requestPath":"/health","message":"ok"}',
            b'',
        ]
        with patch('vercel_logs.requests.get', return_value=response) as get:
            rows = read_runtime_logs('token', 'prj_one', 'dpl_one', 'team_one')
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['path'], '/health')
        self.assertEqual(rows[0]['message'], 'ok')
        self.assertEqual(get.call_args.kwargs['params'], {'teamId': 'team_one'})
        response.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
