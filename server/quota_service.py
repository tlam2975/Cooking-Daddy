"""Daily per-account reservations shared across every worker and generation route."""
from datetime import datetime, timezone, timedelta
from hashlib import sha256
from firebase_admin import firestore
from api_auth import _firebase_app


class QuotaExceeded(Exception):
    pass


class QuotaUnavailable(Exception):
    pass


class FirestoreQuotaStore:
    def __init__(self, client_factory=None, now=None):
        self._client_factory = client_factory or (lambda: firestore.client(app=_firebase_app()))
        self._now = now or (lambda: datetime.now(timezone.utc))

    def _reference(self, uid, day=None):
        client = self._client_factory()
        day = day or self._now().date().isoformat()
        owner = sha256(uid.encode()).hexdigest()
        return client, client.collection('api_quotas').document(f'{owner}_{day}')

    def snapshot(self, uid, limit):
        try:
            _, reference = self._reference(uid)
            data = reference.get(timeout=5).to_dict() or {}
            return {'remaining': max(0, limit - data.get('count', 0)), 'limit': limit,
                    'resetAt': (datetime.combine(self._now().date(), datetime.min.time(),
                                tzinfo=timezone.utc) + timedelta(days=1)).isoformat()}
        except Exception as error:
            raise QuotaUnavailable from error

    def reserve(self, uid, limit):
        try:
            client, reference = self._reference(uid)
            @firestore.transactional
            def claim(transaction):
                data = reference.get(transaction=transaction, timeout=5).to_dict() or {}
                count = data.get('count', 0)
                if count >= limit:
                    raise QuotaExceeded
                transaction.set(reference, {'count': count + 1,
                    'expiresAt': self._now() + timedelta(days=7)})
                return max(0, limit - count - 1)
            remaining = claim(client.transaction(max_attempts=3))
            return reference.id, remaining
        except QuotaExceeded:
            raise
        except Exception as error:
            raise QuotaUnavailable from error

    def release(self, uid, reservation):
        # A reservation keeps its original date even when generation crosses midnight.
        day = reservation.rsplit('_', 1)[-1]
        try:
            client, reference = self._reference(uid, day)
            @firestore.transactional
            def refund(transaction):
                data = reference.get(transaction=transaction, timeout=5).to_dict() or {}
                transaction.set(reference, {'count': max(0, data.get('count', 0) - 1)}, merge=True)
            refund(client.transaction(max_attempts=3))
        except Exception as error:
            raise QuotaUnavailable from error
