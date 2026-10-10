"""Firebase authentication for the mobile API; no unauthenticated fallback."""

import json
import os
from threading import Lock

import firebase_admin
from firebase_admin import auth, credentials
from flask import g, jsonify, request


PROJECT_ID = 'cooking-daddy-83353'
_app_lock = Lock()


def _firebase_app():
    # The emulator accepts unsigned tokens. It must never authenticate this API.
    if os.getenv('FIREBASE_AUTH_EMULATOR_HOST'):
        raise ValueError('Firebase Auth emulator is not supported by this API')
    with _app_lock:
        try:
            return firebase_admin.get_app('cooking-daddy-api')
        except ValueError:
            project_id = os.getenv('FIREBASE_PROJECT_ID', PROJECT_ID)
            service_account = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
            credential = (credentials.Certificate(json.loads(service_account))
                          if service_account else credentials.ApplicationDefault())
            if credential.project_id != project_id:
                raise ValueError('Firebase credential project does not match the app')
            return firebase_admin.initialize_app(
                credential, {'projectId': project_id, 'httpTimeout': 5},
                name='cooking-daddy-api',
            )


def verify_user_token(token):
    return auth.verify_id_token(token, app=_firebase_app(), check_revoked=True)


def _error(status, code, message):
    response = jsonify(success=False, error=message, error_code=code)
    response.status_code = status
    response.headers['Cache-Control'] = 'no-store'
    if status == 401:
        response.headers['WWW-Authenticate'] = 'Bearer'
    return response


def protect_api(app):
    @app.before_request
    def authenticate_api_request():
        if not request.path.startswith('/api/') or request.method == 'OPTIONS':
            return None
        parts = request.headers.get('Authorization', '').split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return _error(401, 'auth_required', 'Sign in to use the API')
        try:
            claims = verify_user_token(parts[1])
        except auth.CertificateFetchError:
            return _error(503, 'auth_unavailable', 'Authentication is temporarily unavailable')
        except (auth.InvalidIdTokenError, auth.RevokedIdTokenError,
                auth.UserDisabledError, auth.UserNotFoundError):
            return _error(401, 'auth_required', 'Sign in again to use the API')
        except Exception:
            # Avoid logging credentials, tokens, or SDK exception payloads.
            app.logger.error('Firebase authentication unavailable; check server configuration and connectivity')
            return _error(503, 'auth_unavailable', 'Authentication is temporarily unavailable')
        if not claims.get('uid') or claims.get('firebase', {}).get('sign_in_provider') == 'anonymous':
            return _error(401, 'auth_required', 'Sign in to use the API')
        g.user_id = claims['uid']
        return None

    @app.after_request
    def prevent_shared_api_cache(response):
        if request.path.startswith('/api/'):
            response.headers['Cache-Control'] = 'no-store'
        return response
